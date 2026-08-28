package com.reelforge.reelforge_encoder

import android.media.Image
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/// Decodes video frames for `VideoClip`, so a composition with footage can be
/// exported by the app itself.
///
/// The unit everything speaks in is a frame of the *composition*, not of the
/// source. A source may run at any rate of its own, so [DecodeSource.frameAt]
/// is asked for an instant and finds whichever of its frames is on screen then
/// -- the same rule ffmpeg's `fps` filter applies, so the two decoders pick the
/// same frame. Taking simply the next frame instead plays 60fps footage at half
/// speed in a 30fps composition, which is a mistake this codebase has already
/// made once on the other platform.
class ReelForgeDecoderPlugin : MethodChannel.MethodCallHandler {
  private var channel: MethodChannel? = null
  private val worker = Executors.newSingleThreadExecutor()
  private val main = Handler(Looper.getMainLooper())

  private val sources = HashMap<Int, DecodeSource>()
  private var nextHandle = 1

  fun attach(messenger: BinaryMessenger) {
    channel = MethodChannel(messenger, "reelforge/decoder").also {
      it.setMethodCallHandler(this)
    }
  }

  fun detach() {
    channel?.setMethodCallHandler(null)
    channel = null
    worker.execute {
      sources.values.forEach { it.close() }
      sources.clear()
    }
    worker.shutdown()
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "probe" -> probe(call, result)
      "open" -> open(call, result)
      "seek" -> seek(call, result)
      "nextFrame" -> nextFrame(call, result)
      "close" -> close(call, result)
      else -> result.notImplemented()
    }
  }

  private fun probe(call: MethodCall, result: MethodChannel.Result) {
    val path = call.argument<String>("path")
      ?: return result.error("bad-args", "probe needs a path", null)
    worker.execute {
      var extractor: MediaExtractor? = null
      try {
        if (!File(path).exists()) throw IllegalArgumentException("no file at $path")
        extractor = MediaExtractor().also { it.setDataSource(path) }
        val track = videoTrackOf(extractor)
        val format = extractor.getTrackFormat(track)
        val info = HashMap<String, Any>()
        info["width"] = format.getInteger(MediaFormat.KEY_WIDTH)
        info["height"] = format.getInteger(MediaFormat.KEY_HEIGHT)
        info["duration"] = format.getLong(MediaFormat.KEY_DURATION) / 1_000_000.0
        main.post { result.success(info) }
      } catch (error: Throwable) {
        main.post { result.error("probe-failed", "could not probe $path: ${error.message}", null) }
      } finally {
        extractor?.release()
      }
    }
  }

  private fun open(call: MethodCall, result: MethodChannel.Result) {
    val path = call.argument<String>("path")
    val fps = call.argument<Int>("fps")
    val startSourceFrame = call.argument<Int>("startSourceFrame") ?: 0
    val width = call.argument<Int>("width")
    val height = call.argument<Int>("height")
    if (path == null || fps == null) {
      return result.error("bad-args", "open needs a path and fps", null)
    }
    worker.execute {
      try {
        val source = DecodeSource(path, fps, width, height)
        source.restartAt(startSourceFrame.toLong())
        val handle = nextHandle++
        sources[handle] = source
        val opened = HashMap<String, Any>()
        opened["handle"] = handle
        opened["width"] = source.width
        opened["height"] = source.height
        main.post { result.success(opened) }
      } catch (error: Throwable) {
        main.post { result.error("open-failed", "could not open $path: ${error.message}", null) }
      }
    }
  }

  private fun seek(call: MethodCall, result: MethodChannel.Result) {
    val handle = call.argument<Int>("handle")
    val sourceFrame = call.argument<Int>("sourceFrame")
    if (handle == null || sourceFrame == null) {
      return result.error("bad-args", "seek needs a handle and sourceFrame", null)
    }
    worker.execute {
      val source = sources[handle]
      if (source == null) {
        main.post { result.error("no-handle", "no decoder $handle", null) }
        return@execute
      }
      try {
        source.restartAt(sourceFrame.toLong())
        main.post { result.success(null) }
      } catch (error: Throwable) {
        main.post { result.error("seek-failed", "${source.path}: ${error.message}", null) }
      }
    }
  }

  private fun nextFrame(call: MethodCall, result: MethodChannel.Result) {
    val handle = call.argument<Int>("handle")
    val sourceFrame = call.argument<Int>("sourceFrame")
    if (handle == null || sourceFrame == null) {
      return result.error("bad-args", "nextFrame needs a handle and sourceFrame", null)
    }
    worker.execute {
      val source = sources[handle]
      if (source == null) {
        main.post { result.error("no-handle", "no decoder $handle", null) }
        return@execute
      }
      try {
        val bytes = source.frameAt(sourceFrame.toLong())
        main.post { result.success(bytes) }
      } catch (error: Throwable) {
        main.post { result.error("decode-failed", "${source.path}: ${error.message}", null) }
      }
    }
  }

  private fun close(call: MethodCall, result: MethodChannel.Result) {
    val handle = call.argument<Int>("handle")
      ?: return result.error("bad-args", "close needs a handle", null)
    worker.execute {
      sources.remove(handle)?.close()
      main.post { result.success(null) }
    }
  }

  companion object {
    fun videoTrackOf(extractor: MediaExtractor): Int {
      for (i in 0 until extractor.trackCount) {
        val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
        if (mime.startsWith("video/")) {
          extractor.selectTrack(i)
          return i
        }
      }
      throw IllegalArgumentException("the file has no video track")
    }
  }
}

/// One open decode of one file.
class DecodeSource(
  val path: String,
  private val fps: Int,
  requestedWidth: Int?,
  requestedHeight: Int?,
) {
  private var extractor = MediaExtractor()
  private var codec: MediaCodec? = null
  private val bufferInfo = MediaCodec.BufferInfo()

  val width: Int
  val height: Int
  private val sourceWidth: Int
  private val sourceHeight: Int

  /// How long one frame of the *source* lasts, in microseconds.
  ///
  /// Not the composition's frame duration. The two are only the same when the
  /// footage happens to run at the composition's rate, and the interesting
  /// case is when it does not: 60fps footage in a 30fps composition wants
  /// every second frame, and slack measured in composition frames would be a
  /// whole source frame wide -- enough to take the next frame at every instant
  /// that lands exactly on one.
  private val sourceFrameDurationUs: Long

  /// Whether the source declares (or, failing that, implies) BT.709.
  private val sourceIsHd: Boolean

  /// The frame on screen, and the one after it once it has been read. The
  /// lookahead is what makes "is this still the right frame for this instant?"
  /// answerable, since a decoder cannot be asked to put a frame back.
  private var heldPixels: ByteArray? = null
  private var heldTime = -1L
  private var pendingPixels: ByteArray? = null
  private var pendingTime = -1L
  private var ranOut = false
  private var inputDone = false

  init {
    if (!File(path).exists()) throw IllegalArgumentException("no file at $path")
    extractor.setDataSource(path)
    val track = ReelForgeDecoderPlugin.videoTrackOf(extractor)
    val format = extractor.getTrackFormat(track)
    sourceWidth = format.getInteger(MediaFormat.KEY_WIDTH)
    sourceHeight = format.getInteger(MediaFormat.KEY_HEIGHT)
    width = requestedWidth ?: sourceWidth
    height = requestedHeight ?: sourceHeight

    val sourceFps = if (format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
      // The extractor hands this back as an Int on most devices and a Float on
      // some; asking for the wrong one throws rather than converting.
      try {
        format.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()
      } catch (_: ClassCastException) {
        format.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble()
      }
    } else {
      fps.toDouble()
    }
    sourceFrameDurationUs =
      if (sourceFps > 0) (1_000_000.0 / sourceFps).toLong() else 1_000_000L / fps

    // What the file says, if it says anything. Most do not, and then the
    // convention is the same one every encoder uses: high definition means
    // BT.709.
    sourceIsHd = if (format.containsKey(MediaFormat.KEY_COLOR_STANDARD)) {
      format.getInteger(MediaFormat.KEY_COLOR_STANDARD) ==
        MediaFormat.COLOR_STANDARD_BT709
    } else {
      sourceHeight >= 720
    }
  }

  /// Points the decode at an exact source frame.
  ///
  /// A codec cannot be rewound, so this tears down and rebuilds. The Dart side
  /// only asks for it on a backwards jump; forward is handled by reading on.
  fun restartAt(frame: Long) {
    close(keepExtractor = true)

    val time = frame * 1_000_000L / fps.toLong()
    // Land on the nearest keyframe at or before the instant, then decode
    // forward to it. Seeking to the closest sync frame instead can land
    // *after* the target, which silently skips the start of a clip.
    extractor.seekTo(time, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

    val format = extractor.getTrackFormat(extractor.sampleTrackIndex.coerceAtLeast(0))
    val decoder = MediaCodec.createDecoderByType(
      format.getString(MediaFormat.KEY_MIME) ?: "video/avc"
    )
    decoder.configure(format, null, null, 0)
    decoder.start()
    codec = decoder

    heldPixels = null
    heldTime = -1L
    pendingPixels = null
    pendingTime = -1L
    ranOut = false
    inputDone = false
  }

  /// The pixels of the frame on screen at a composition instant, or null past
  /// the end of the source.
  fun frameAt(frame: Long): ByteArray? {
    val target = frame * 1_000_000L / fps.toLong()
    // Half a source frame of slack. Presentation times are integers of the
    // source's own timebase and the target is an integer of the composition's,
    // so an instant that is conceptually exactly on a frame can land a
    // microsecond under it and take the frame before. Half a frame is the
    // widest this can be without reaching the *next* frame, which is the
    // failure VideoProbeHalf exists to catch.
    val slack = sourceFrameDurationUs / 2

    if (heldPixels == null) {
      if (!advance()) return null
    }

    while (true) {
      if (pendingPixels == null && !ranOut) advance()
      if (pendingPixels == null) break
      if (pendingTime <= target + slack) {
        heldPixels = pendingPixels
        heldTime = pendingTime
        pendingPixels = null
        pendingTime = -1L
      } else {
        break
      }
    }

    // Nothing follows, and the instant asked for is past the last frame's own
    // moment: the clip has run out rather than being held.
    if (ranOut && pendingPixels == null && heldTime >= 0 &&
      target > heldTime + sourceFrameDurationUs
    ) {
      return null
    }
    return heldPixels
  }

  /// Decodes one more frame into [pendingPixels], or sets [ranOut].
  private fun advance(): Boolean {
    val decoder = codec ?: throw IllegalStateException("the decoder is not open")

    while (true) {
      if (!inputDone) {
        val inputIndex = decoder.dequeueInputBuffer(TIMEOUT_US)
        if (inputIndex >= 0) {
          val buffer = decoder.getInputBuffer(inputIndex)!!
          val read = extractor.readSampleData(buffer, 0)
          if (read < 0) {
            decoder.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            inputDone = true
          } else {
            decoder.queueInputBuffer(inputIndex, 0, read, extractor.sampleTime, 0)
            extractor.advance()
          }
        }
      }

      val outputIndex = decoder.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
      when {
        outputIndex >= 0 -> {
          val endOfStream = bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
          if (bufferInfo.size > 0) {
            val image = decoder.getOutputImage(outputIndex)
            if (image != null) {
              if (pendingPixels == null) {
                pendingPixels = toRgba(image, width, height, sourceIsHd)
                pendingTime = bufferInfo.presentationTimeUs
              }
              image.close()
            }
          }
          decoder.releaseOutputBuffer(outputIndex, false)
          if (endOfStream) {
            ranOut = true
            return pendingPixels != null
          }
          if (pendingPixels != null) {
            if (heldPixels == null) {
              heldPixels = pendingPixels
              heldTime = pendingTime
              pendingPixels = null
              pendingTime = -1L
            }
            return true
          }
        }
        outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER -> if (inputDone) {
          ranOut = true
          return false
        }
      }
    }
  }

  fun close() = close(keepExtractor = false)

  private fun close(keepExtractor: Boolean) {
    try { codec?.stop() } catch (_: Throwable) {}
    try { codec?.release() } catch (_: Throwable) {}
    codec = null
    if (!keepExtractor) {
      try { extractor.release() } catch (_: Throwable) {}
    }
  }

  companion object {
    private const val TIMEOUT_US = 10_000L

    /// YUV 4:2:0 to RGBA, BT.601 limited range, scaling by nearest neighbour
    /// when a decode size was asked for.
    ///
    /// Nearest neighbour rather than anything better because the point of a
    /// decode size is to stop paying for pixels that will never be painted; a
    /// clip drawn at its natural size never comes through here at all. It is
    /// not the same filter ffmpeg's `scale` uses, so a downscaled clip will
    /// differ slightly between the two decoders in a way a full-size one does
    /// not.
    fun toRgba(
      image: Image,
      width: Int,
      height: Int,
      hd: Boolean = height >= 720,
    ): ByteArray {
      // The inverse of the matrix the source was written with: BT.709 for high
      // definition, BT.601 below it. Inverting with the wrong one does not
      // fail, it tints, so a clip decoded here and the same clip decoded by
      // ffmpeg would quietly disagree on colour.
      val crR = if (hd) 459 else 409
      val cbG = if (hd) -55 else -100
      val crG = if (hd) -136 else -208
      val cbB = if (hd) 541 else 516
      val out = ByteArray(width * height * 4)
      val yPlane = image.planes[0]
      val uPlane = image.planes[1]
      val vPlane = image.planes[2]
      val yBuffer = yPlane.buffer
      val uBuffer = uPlane.buffer
      val vBuffer = vPlane.buffer
      val yStride = yPlane.rowStride
      val uStride = uPlane.rowStride
      val vStride = vPlane.rowStride
      val uPixel = uPlane.pixelStride
      val vPixel = vPlane.pixelStride

      // The crop rectangle, not the buffer: a decoder is free to hand back a
      // padded surface, and reading the padding puts a green band down the
      // side of every frame.
      val crop = image.cropRect
      val sourceWidth = crop.width()
      val sourceHeight = crop.height()

      var at = 0
      for (y in 0 until height) {
        val sy = crop.top + if (height == sourceHeight) y else y * sourceHeight / height
        val cy = sy shr 1
        for (x in 0 until width) {
          val sx = crop.left + if (width == sourceWidth) x else x * sourceWidth / width
          val cx = sx shr 1

          val luma = (yBuffer.get(sy * yStride + sx).toInt() and 0xFF) - 16
          val cb = (uBuffer.get(cy * uStride + cx * uPixel).toInt() and 0xFF) - 128
          val cr = (vBuffer.get(cy * vStride + cx * vPixel).toInt() and 0xFF) - 128

          val c = 298 * luma
          out[at] = (((c + crR * cr + 128) shr 8).coerceIn(0, 255)).toByte()
          out[at + 1] =
            (((c + cbG * cb + crG * cr + 128) shr 8).coerceIn(0, 255)).toByte()
          out[at + 2] = (((c + cbB * cb + 128) shr 8).coerceIn(0, 255)).toByte()
          out[at + 3] = -1
          at += 4
        }
      }
      return out
    }
  }
}
