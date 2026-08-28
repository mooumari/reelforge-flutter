package com.reelforge.reelforge_encoder

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteBuffer
import kotlin.math.max
import kotlin.math.min

/// Builds one audio timeline out of the clips a composition declared.
///
/// The Apple half of this plugin does not have to do any of this: it hands
/// AVFoundation an `AVMutableComposition` of the clips and an `AVAudioMix` of
/// the volumes, and the framework mixes, resamples and encodes. Android has no
/// equivalent -- `MediaMuxer` only muxes, and `MediaCodec` only codes one
/// stream at a time -- so the mix itself is written out here: decode every
/// clip to PCM, sum them onto one timeline at their own offsets and volumes,
/// and encode the result once.
///
/// Summing rather than averaging is deliberate and matches the Apple path: two
/// clips over the same frames are heard together at their own volumes, not
/// quietened by each other's presence.
class AudioMixer(
  private val tracks: List<Map<String, Any?>>,
  private val fps: Int,
  private val totalFrames: Int,
) {
  /// One encoded AAC packet, held until the muxer exists to take it.
  class Packet(val data: ByteArray, val timeUs: Long, val flags: Int)

  class Result(val format: MediaFormat, val packets: List<Packet>)

  /// Decodes, mixes and encodes. Null when there is nothing to mix.
  ///
  /// Everything happens before the first video frame is submitted, because
  /// `MediaMuxer` will not accept a track added after `start()` and the video
  /// track cannot be added until the encoder has produced its format. Holding
  /// the encoded audio in memory is what squares that: a minute of stereo AAC
  /// at 128 kbps is under a megabyte.
  fun mix(): Result? {
    if (tracks.isEmpty() || totalFrames <= 0) return null

    val totalSamples = (totalFrames.toLong() * RATE / fps).toInt()
    if (totalSamples <= 0) return null

    val mix = FloatArray(totalSamples * CHANNELS)
    var mixed = 0

    for (track in tracks) {
      val path = track["path"] as? String ?: continue
      if (!File(path).exists()) continue
      val startFrame = (track["startFrame"] as? Int) ?: 0
      val endFrame = (track["endFrame"] as? Int) ?: (totalFrames - 1)
      val volume = ((track["volume"] as? Number)?.toDouble() ?: 1.0).toFloat()
      val trimStart = (track["trimStartInFrames"] as? Int) ?: 0
      val loop = (track["loop"] as? Boolean) ?: false

      val pcm = decode(path) ?: continue
      if (pcm.isEmpty()) continue

      // Frames are inclusive at both ends, and the clip is clamped to the
      // video: sound that outlasts the picture is silence nobody hears.
      val from = max(0, (startFrame.toLong() * RATE / fps).toInt())
      val until = min(totalSamples, ((endFrame + 1).toLong() * RATE / fps).toInt())
      if (until <= from) continue

      val trimSamples = (trimStart.toLong() * RATE / fps).toInt() * CHANNELS
      val available = pcm.size - trimSamples
      if (available <= 0) continue

      for (s in from until until) {
        var at = trimSamples + (s - from) * CHANNELS
        if (loop) {
          at = trimSamples + ((s - from) * CHANNELS) % available
        } else if (at + CHANNELS > pcm.size) {
          break
        }
        for (c in 0 until CHANNELS) {
          mix[s * CHANNELS + c] += pcm[at + c] * volume
        }
      }
      mixed++
    }

    if (mixed == 0) return null

    // An AAC encoder emits priming samples before the audio it was given, so
    // everything comes out late by exactly that much -- 46ms at 44.1kHz, which
    // on AudioProbe put a click meant for frame 60 at frame 62.79. Padding the
    // front to a whole number of AAC frames and then dropping that many
    // packets cancels it exactly, rather than approximately.
    val delay = ENCODER_DELAY_SAMPLES
    val pad = (PACKET_SAMPLES - delay % PACKET_SAMPLES) % PACKET_SAMPLES
    val padded = FloatArray(pad * CHANNELS + mix.size)
    mix.copyInto(padded, pad * CHANNELS)
    return encode(padded, drop = (delay + pad) / PACKET_SAMPLES)
  }

  /// One clip decoded to interleaved float PCM at [RATE] and [CHANNELS].
  private fun decode(path: String): FloatArray? {
    val extractor = MediaExtractor()
    try {
      extractor.setDataSource(path)
      var track = -1
      for (i in 0 until extractor.trackCount) {
        val mime = extractor.getTrackFormat(i).getString(MediaFormat.KEY_MIME) ?: continue
        if (mime.startsWith("audio/")) {
          track = i
          break
        }
      }
      if (track < 0) return null
      extractor.selectTrack(track)

      val inputFormat = extractor.getTrackFormat(track)
      val codec = MediaCodec.createDecoderByType(
        inputFormat.getString(MediaFormat.KEY_MIME)!!
      )
      codec.configure(inputFormat, null, null, 0)
      codec.start()

      // The *decoder's* rate and channel count, not the extractor's: they
      // usually agree and occasionally do not, and the one that matters is
      // the one describing the samples actually coming out.
      var rate = inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
      var channels = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)

      val info = MediaCodec.BufferInfo()
      val raw = ArrayList<Short>()
      var inputDone = false
      var outputDone = false

      while (!outputDone) {
        if (!inputDone) {
          val index = codec.dequeueInputBuffer(TIMEOUT_US)
          if (index >= 0) {
            val buffer = codec.getInputBuffer(index)!!
            val read = extractor.readSampleData(buffer, 0)
            if (read < 0) {
              codec.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
              inputDone = true
            } else {
              codec.queueInputBuffer(index, 0, read, extractor.sampleTime, 0)
              extractor.advance()
            }
          }
        }

        val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
        when {
          index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
            rate = codec.outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            channels = codec.outputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
          }
          index >= 0 -> {
            if (info.size > 0) {
              val buffer = codec.getOutputBuffer(index)!!
              buffer.position(info.offset)
              buffer.limit(info.offset + info.size)
              val shorts = buffer.asShortBuffer()
              while (shorts.hasRemaining()) raw.add(shorts.get())
            }
            codec.releaseOutputBuffer(index, false)
            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
          }
        }
      }

      codec.stop()
      codec.release()
      return conform(raw, rate, channels)
    } catch (_: Throwable) {
      // A clip that cannot be decoded is dropped rather than failing the
      // export; the exporter has already warned about anything it could not
      // resolve, and a silent track beats no video.
      return null
    } finally {
      try { extractor.release() } catch (_: Throwable) {}
    }
  }

  /// Interleaved 16-bit PCM at any rate and channel count, as float at ours.
  ///
  /// Linear interpolation for the rate, and the two obvious channel moves:
  /// mono is copied to both sides, anything wider is taken from its first two.
  private fun conform(raw: List<Short>, rate: Int, channels: Int): FloatArray {
    if (channels <= 0 || raw.isEmpty()) return FloatArray(0)
    val frames = raw.size / channels
    val outFrames = (frames.toLong() * RATE / rate).toInt()
    val out = FloatArray(outFrames * CHANNELS)

    for (f in 0 until outFrames) {
      val position = f.toDouble() * rate / RATE
      val a = position.toInt()
      val b = min(a + 1, frames - 1)
      val t = (position - a).toFloat()
      for (c in 0 until CHANNELS) {
        val source = if (channels == 1) 0 else min(c, channels - 1)
        val left = raw[a * channels + source] / 32768f
        val right = raw[b * channels + source] / 32768f
        out[f * CHANNELS + c] = left + (right - left) * t
      }
    }
    return out
  }

  /// The mixed timeline as AAC, held as packets for the muxer.
  private fun encode(mix: FloatArray, drop: Int): Result {
    val format = MediaFormat.createAudioFormat(
      MediaFormat.MIMETYPE_AUDIO_AAC, RATE, CHANNELS
    ).apply {
      setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
      setInteger(MediaFormat.KEY_BIT_RATE, 128_000)
      setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, INPUT_BYTES)
    }

    val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
    codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
    codec.start()

    val info = MediaCodec.BufferInfo()
    val packets = ArrayList<Packet>()
    var outputFormat: MediaFormat? = null
    var produced = 0
    var at = 0
    var inputDone = false
    var outputDone = false

    while (!outputDone) {
      if (!inputDone) {
        val index = codec.dequeueInputBuffer(TIMEOUT_US)
        if (index >= 0) {
          val buffer = codec.getInputBuffer(index)!!
          buffer.clear()
          val room = min(buffer.capacity() / 2, INPUT_BYTES / 2)
          val take = min(room, mix.size - at)
          if (take <= 0) {
            codec.queueInputBuffer(index, 0, 0, timeOf(at), MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            inputDone = true
          } else {
            val shorts = buffer.asShortBuffer()
            for (i in 0 until take) {
              val v = mix[at + i]
              // Clamp rather than wrap: summed clips can exceed full scale,
              // and an overflow that wraps is a click rather than a loud note.
              shorts.put((max(-1f, min(1f, v)) * 32767f).toInt().toShort())
            }
            codec.queueInputBuffer(index, 0, take * 2, timeOf(at), 0)
            at += take
          }
        }
      }

      val index = codec.dequeueOutputBuffer(info, TIMEOUT_US)
      when {
        index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> outputFormat = codec.outputFormat
        index >= 0 -> {
          if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
            if (produced >= drop) {
              val buffer = codec.getOutputBuffer(index)!!
              buffer.position(info.offset)
              buffer.limit(info.offset + info.size)
              val bytes = ByteArray(info.size)
              buffer.get(bytes)
              // Rebased, so the first packet kept is time zero.
              packets.add(
                Packet(
                  bytes,
                  info.presentationTimeUs - drop.toLong() * PACKET_SAMPLES * 1_000_000L / RATE,
                  info.flags
                )
              )
            }
            produced++
          }
          codec.releaseOutputBuffer(index, false)
          if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
        }
      }
    }

    codec.stop()
    codec.release()
    return Result(outputFormat ?: format, packets)
  }

  private fun timeOf(sample: Int): Long =
    sample.toLong() / CHANNELS * 1_000_000L / RATE

  companion object {
    const val RATE = 44_100
    const val CHANNELS = 2

    /// Samples an AAC LC encoder emits ahead of the audio it was handed.
    ///
    /// Fixed by the format rather than by the device: the filter bank needs a
    /// window of history before it can produce the first real output, and the
    /// standard's answer is two packets' worth.
    private const val ENCODER_DELAY_SAMPLES = 2048

    /// Samples in one AAC frame.
    private const val PACKET_SAMPLES = 1024
    private const val TIMEOUT_US = 10_000L
    private const val INPUT_BYTES = 16_384
  }
}
