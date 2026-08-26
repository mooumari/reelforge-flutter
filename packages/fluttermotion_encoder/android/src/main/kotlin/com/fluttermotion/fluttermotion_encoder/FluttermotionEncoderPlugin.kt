package com.fluttermotion.fluttermotion_encoder

import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.os.Build
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/// Encodes raw RGBA frames to H.264 using the device's own hardware encoder.
///
/// The Apple half of this plugin hands AVAssetWriter a BGRA pixel buffer and
/// lets it convert. MediaCodec has no such courtesy: it takes YUV, so the
/// colour conversion happens here, in [fillImage], and the exact matrix is part
/// of the file's meaning rather than an implementation detail. It is written
/// into the format as well as applied to the pixels, so a decoder converts back
/// with the same numbers.
class FluttermotionEncoderPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
  private lateinit var channel: MethodChannel
  private var decoder: FluttermotionDecoderPlugin? = null

  /// Frames are converted and queued off the platform thread, so the UI keeps
  /// running -- an in-app export that freezes the app is not much of a feature.
  private val worker = Executors.newSingleThreadExecutor()
  private val main = Handler(Looper.getMainLooper())

  private var codec: MediaCodec? = null
  private var muxer: MediaMuxer? = null
  private var videoTrack = -1
  private var muxerStarted = false
  private var finished = false

  private var width = 0
  private var height = 0
  private var fps = 30
  private var outputPath: String? = null

  private val bufferInfo = MediaCodec.BufferInfo()

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "fluttermotion/encoder")
    channel.setMethodCallHandler(this)

    // The pubspec names one plugin class and Flutter's generated registrant
    // calls only that one. Decoding is a separate channel with separate state,
    // so it is a separate class -- registered from here rather than asking
    // every app to know about it.
    decoder = FluttermotionDecoderPlugin().also { it.attach(binding.binaryMessenger) }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    decoder?.detach()
    decoder = null
    tearDown(deleteOutput = !finished)
    worker.shutdown()
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "start" -> start(call, result)
      "addFrame" -> addFrame(call, result)
      "finish" -> finish(result)
      "dispose" -> dispose(result)
      else -> result.notImplemented()
    }
  }

  // MARK: - start

  private fun start(call: MethodCall, result: MethodChannel.Result) {
    val path = call.argument<String>("path")
    val w = call.argument<Int>("width")
    val h = call.argument<Int>("height")
    val rate = call.argument<Int>("fps")
    val bitrate = call.argument<Int>("bitrate")
    if (path == null || w == null || h == null || rate == null || bitrate == null) {
      return result.error("bad-args", "start() needs path, width, height, fps and bitrate", null)
    }

    worker.execute {
      try {
        // An odd dimension has no representation in 4:2:0, and the encoder
        // will either round it silently or reject the buffer half way in.
        if (w % 2 != 0 || h % 2 != 0) {
          throw IllegalArgumentException("$w x $h is not even; 4:2:0 cannot represent it")
        }

        File(path).parentFile?.mkdirs()
        File(path).delete()

        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, w, h).apply {
          setInteger(
            MediaFormat.KEY_COLOR_FORMAT,
            MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible
          )
          setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
          // Constant rather than variable rate. A variable-rate encoder is
          // free to decide a flat frame two grey levels off the last one is
          // not worth any bits, which is correct for a camera and wrong for a
          // composition: the flat frames are the content. Measured on
          // EncoderProbe, which is nothing but flat frames.
          setInteger(
            MediaFormat.KEY_BITRATE_MODE,
            MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR
          )
          setInteger(MediaFormat.KEY_FRAME_RATE, rate)
          // A keyframe every two seconds keeps seeking usable without spending
          // the whole bitrate on I-frames.
          setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 2)
          // A ceiling on the quantiser, not just a floor on the bitrate.
          // Rate control alone will still throw away a two-level residual on
          // a flat frame, because it is judging perceptual cost on footage and
          // a composition is not footage: its flat areas are the content, and
          // a smudged one reads as banding.
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            setInteger(MediaFormat.KEY_VIDEO_QP_MAX, 20)
          }
          // Says what fillImage() actually did. Without these the file carries
          // no colour metadata and a decoder is left to guess, which is how the
          // same pixels come back looking different.
          setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
          setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT601_NTSC)
          setInteger(MediaFormat.KEY_COLOR_TRANSFER, MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
        }

        val encoder = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        encoder.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        encoder.start()

        codec = encoder
        muxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        videoTrack = -1
        muxerStarted = false
        finished = false
        width = w
        height = h
        fps = rate
        outputPath = path

        main.post { result.success(null) }
      } catch (error: Throwable) {
        tearDown(deleteOutput = true)
        main.post { result.error("start-failed", error.message ?: "could not start the encoder", null) }
      }
    }
  }

  // MARK: - addFrame

  private fun addFrame(call: MethodCall, result: MethodChannel.Result) {
    val rgba = call.argument<ByteArray>("frame")
    val index = call.argument<Int>("index")
    if (rgba == null || index == null) {
      return result.error("bad-args", "addFrame() needs frame and index", null)
    }

    worker.execute {
      val encoder = codec
      if (encoder == null) {
        main.post { result.error("not-started", "addFrame() before start()", null) }
        return@execute
      }
      try {
        val expected = width * height * 4
        if (rgba.size != expected) {
          throw IllegalArgumentException(
            "frame $index is ${rgba.size} bytes; ${width}x$height RGBA is $expected"
          )
        }

        // Blocking, deliberately. The Dart side awaits every frame, so waiting
        // here for a free input buffer is what keeps memory flat over a long
        // export rather than queueing frames faster than they compress.
        var inputIndex = -1
        while (inputIndex < 0) {
          inputIndex = encoder.dequeueInputBuffer(TIMEOUT_US)
          if (inputIndex < 0) drain(endOfStream = false)
        }

        val image = encoder.getInputImage(inputIndex)
          ?: throw IllegalStateException("the encoder gave no input image for frame $index")
        fillImage(image, rgba, width, height)

        // Presentation time comes from the frame index, never from a clock.
        val pts = index.toLong() * 1_000_000L / fps.toLong()
        encoder.queueInputBuffer(inputIndex, 0, imageSize(image), pts, 0)

        drain(endOfStream = false)
        main.post { result.success(null) }
      } catch (error: Throwable) {
        main.post { result.error("append-failed", error.message ?: "frame $index was rejected", null) }
      }
    }
  }

  // MARK: - finish

  private fun finish(result: MethodChannel.Result) {
    worker.execute {
      val encoder = codec
      if (encoder == null) {
        main.post { result.error("not-started", "finish() before start()", null) }
        return@execute
      }
      try {
        val inputIndex = encoder.dequeueInputBuffer(TIMEOUT_US * 10)
        if (inputIndex >= 0) {
          encoder.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
        }
        drain(endOfStream = true)

        muxer?.let { if (muxerStarted) it.stop() }
        finished = true
        tearDown(deleteOutput = false)
        main.post { result.success(null) }
      } catch (error: Throwable) {
        tearDown(deleteOutput = true)
        main.post { result.error("finish-failed", error.message ?: "the muxer did not complete", null) }
      }
    }
  }

  private fun dispose(result: MethodChannel.Result) {
    // A cancelled or failed export must not leave a half-written file that
    // looks playable until someone opens it.
    tearDown(deleteOutput = !finished)
    result.success(null)
  }

  // MARK: - the encoder loop

  /// Moves whatever the encoder has finished compressing into the muxer.
  ///
  /// [endOfStream] keeps pulling until the encoder says it is done; otherwise
  /// this takes what is ready and returns, so a frame is never held up waiting
  /// for output that has not been produced yet.
  private fun drain(endOfStream: Boolean) {
    val encoder = codec ?: return
    val output = muxer ?: return

    while (true) {
      val index = encoder.dequeueOutputBuffer(bufferInfo, if (endOfStream) TIMEOUT_US else 0)
      when {
        index == MediaCodec.INFO_TRY_AGAIN_LATER -> if (!endOfStream) return
        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
          // The real format, carrying the codec-specific data the muxer needs,
          // only exists once the encoder has seen a frame. This fires exactly
          // once, and starting the muxer before it is what produces a file
          // with no decodable stream in it.
          if (muxerStarted) throw IllegalStateException("the output format changed twice")
          videoTrack = output.addTrack(encoder.outputFormat)
          output.start()
          muxerStarted = true
        }
        index >= 0 -> {
          val encoded = encoder.getOutputBuffer(index)
            ?: throw IllegalStateException("the encoder gave no output buffer")
          if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) {
            // Already handed to the muxer with the format above.
            bufferInfo.size = 0
          }
          if (bufferInfo.size > 0 && muxerStarted) {
            encoded.position(bufferInfo.offset)
            encoded.limit(bufferInfo.offset + bufferInfo.size)
            output.writeSampleData(videoTrack, encoded, bufferInfo)
          }
          encoder.releaseOutputBuffer(index, false)
          if (bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) return
        }
      }
    }
  }

  private fun tearDown(deleteOutput: Boolean) {
    try { codec?.stop() } catch (_: Throwable) {}
    try { codec?.release() } catch (_: Throwable) {}
    try { if (!finished && muxerStarted) muxer?.stop() } catch (_: Throwable) {}
    try { muxer?.release() } catch (_: Throwable) {}
    codec = null
    muxer = null
    muxerStarted = false
    videoTrack = -1
    if (deleteOutput) outputPath?.let { File(it).delete() }
    outputPath = null
  }

  companion object {
    private const val TIMEOUT_US = 10_000L

    /// How many bytes of the input image were filled.
    ///
    /// Y at full resolution plus two half-resolution chroma planes: the 1.5
    /// bytes per pixel that 4:2:0 means.
    fun imageSize(image: Image): Int = image.width * image.height * 3 / 2

    /// RGBA to YUV 4:2:0, BT.601 limited range.
    ///
    /// Written against the [Image] planes rather than a flat array, because
    /// planar and semi-planar encoders both appear behind
    /// COLOR_FormatYUV420Flexible and only the plane's own pixel stride says
    /// which one this device has. Assuming one of them works on the machine it
    /// was written on and produces green frames on half the others.
    fun fillImage(image: Image, rgba: ByteArray, width: Int, height: Int) {
      val yPlane = image.planes[0]
      val uPlane = image.planes[1]
      val vPlane = image.planes[2]
      val yBuffer: ByteBuffer = yPlane.buffer
      val uBuffer: ByteBuffer = uPlane.buffer
      val vBuffer: ByteBuffer = vPlane.buffer
      val yStride = yPlane.rowStride
      val uStride = uPlane.rowStride
      val vStride = vPlane.rowStride
      val uPixel = uPlane.pixelStride
      val vPixel = vPlane.pixelStride

      var source = 0
      for (y in 0 until height) {
        val row = y * yStride
        for (x in 0 until width) {
          val r = rgba[source].toInt() and 0xFF
          val g = rgba[source + 1].toInt() and 0xFF
          val b = rgba[source + 2].toInt() and 0xFF
          source += 4
          val luma = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
          yBuffer.put(row + x, luma.coerceIn(16, 235).toByte())
        }
      }

      // Chroma is averaged over each 2x2 block rather than point-sampled, so a
      // hard colour edge lands between the two colours instead of on whichever
      // pixel happened to be top-left.
      for (j in 0 until height / 2) {
        val uRow = j * uStride
        val vRow = j * vStride
        for (i in 0 until width / 2) {
          var rs = 0
          var gs = 0
          var bs = 0
          for (dy in 0..1) {
            var at = (((j * 2 + dy) * width) + i * 2) * 4
            for (dx in 0..1) {
              rs += rgba[at].toInt() and 0xFF
              gs += rgba[at + 1].toInt() and 0xFF
              bs += rgba[at + 2].toInt() and 0xFF
              at += 4
            }
          }
          val r = rs shr 2
          val g = gs shr 2
          val b = bs shr 2
          val cb = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
          val cr = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
          uBuffer.put(uRow + i * uPixel, cb.coerceIn(16, 240).toByte())
          vBuffer.put(vRow + i * vPixel, cr.coerceIn(16, 240).toByte())
        }
      }
    }
  }
}
