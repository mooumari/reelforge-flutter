import AVFoundation
import Accelerate

#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif

/// Encodes raw RGBA frames to H.264 using the platform's own hardware encoder.
///
/// The point of this plugin is that a shipping app can export video with no
/// ffmpeg binary anywhere near it. Everything above this file -- compositions,
/// the declaration pass, the detached render tree -- is already pure Dart and
/// runs unchanged on a phone; this is the one step that has to be native.
public class FluttermotionEncoderPlugin: NSObject, FlutterPlugin {
  private var writer: AVAssetWriter?
  private var input: AVAssetWriterInput?
  private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
  private var outputURL: URL?
  private var width = 0
  private var height = 0
  private var fps = 30
  private var finished = false
  private var totalFrames = 0

  /// The declared sounds, assembled into one timeline. Built during `start`
  /// because the writer's audio input has to exist before writing begins.
  private var audioInput: AVAssetWriterInput?
  private var audioComposition: AVMutableComposition?
  private var audioMix: AVAudioMix?

  /// Frames are converted and appended off the platform thread so the UI keeps
  /// running -- an in-app export that freezes the app is not much of a feature.
  private let queue = DispatchQueue(label: "fluttermotion.encoder", qos: .userInitiated)

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(
      name: "fluttermotion/encoder", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(FluttermotionEncoderPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start": start(call, result)
    case "addFrame": addFrame(call, result)
    case "finish": finish(result)
    case "dispose": dispose(result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - start

  private func start(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let path = args["path"] as? String,
      let w = args["width"] as? Int,
      let h = args["height"] as? Int,
      let rate = args["fps"] as? Int,
      let bitrate = args["bitrate"] as? Int
    else {
      result(FlutterError(code: "bad-args", message: "start() needs path, width, height, fps, bitrate", details: nil))
      return
    }

    tearDown(deleteOutput: true)

    width = w
    height = h
    fps = rate
    finished = false
    totalFrames = args["totalFrames"] as? Int ?? 0

    let url = URL(fileURLWithPath: path)
    outputURL = url
    try? FileManager.default.removeItem(at: url)

    // Create the containing directory rather than failing on a path the caller
    // reasonably expected to work.
    try? FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

    do {
      let assetWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)

      let videoInput = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: [
          AVVideoCodecKey: AVVideoCodecType.h264,
          AVVideoWidthKey: w,
          AVVideoHeightKey: h,
          AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: bitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            // A keyframe every two seconds keeps seeking usable without
            // spending the whole bitrate on I-frames.
            AVVideoMaxKeyFrameIntervalKey: rate * 2,
          ],
        ])
      // Frames arrive as fast as they render, not on a wall clock.
      videoInput.expectsMediaDataInRealTime = false

      let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: videoInput,
        sourcePixelBufferAttributes: [
          kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
          kCVPixelBufferWidthKey as String: w,
          kCVPixelBufferHeightKey as String: h,
          kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ])

      guard assetWriter.canAdd(videoInput) else {
        result(FlutterError(code: "start-failed", message: "Writer rejected the video input", details: nil))
        return
      }
      assetWriter.add(videoInput)

      // Audio is optional and must never be able to lose a video export: a
      // timeline that cannot be built leaves the file silent rather than
      // unwritten.
      if let clips = args["audio"] as? [[String: Any]], !clips.isEmpty,
        let built = buildAudioTimeline(clips: clips, fps: rate)
      {
        let track = AVAssetWriterInput(
          mediaType: .audio,
          outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 192000,
          ])
        track.expectsMediaDataInRealTime = false
        if assetWriter.canAdd(track) {
          assetWriter.add(track)
          audioInput = track
          audioComposition = built.composition
          audioMix = built.mix
        }
      }

      guard assetWriter.startWriting() else {
        result(FlutterError(code: "start-failed", message: assetWriter.error?.localizedDescription ?? "startWriting() failed", details: nil))
        return
      }
      assetWriter.startSession(atSourceTime: .zero)

      // The whole sound goes in before the first frame, and the audio input is
      // finished immediately. An AVAssetWriter with two live inputs expects
      // them to be fed in step: leave one silent and it stops readying the
      // other, which stalls the export part way through with no error at all.
      // Audio does not depend on any frame, so there is nothing to wait for.
      if let audioInput = audioInput {
        writeAudio(into: audioInput, writer: assetWriter)
        audioInput.markAsFinished()
      }

      writer = assetWriter
      input = videoInput
      adaptor = pixelAdaptor
      result(nil)
    } catch {
      result(FlutterError(code: "start-failed", message: error.localizedDescription, details: nil))
    }
  }

  // MARK: - addFrame

  private func addFrame(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let typed = args["frame"] as? FlutterStandardTypedData,
      let index = args["index"] as? Int
    else {
      result(FlutterError(code: "bad-args", message: "addFrame() needs frame and index", details: nil))
      return
    }
    guard let writer = writer, let input = input, let adaptor = adaptor else {
      result(FlutterError(code: "not-started", message: "addFrame() before start()", details: nil))
      return
    }

    let expected = width * height * 4
    guard typed.data.count == expected else {
      result(FlutterError(code: "bad-frame", message: "Frame \(index) is \(typed.data.count) bytes, expected \(expected) for \(width)x\(height) RGBA", details: nil))
      return
    }

    let data = typed.data
    let w = width
    let h = height
    let rate = fps

    queue.async { [weak self] in
      func fail(_ code: String, _ message: String) {
        DispatchQueue.main.async {
          result(FlutterError(code: code, message: message, details: nil))
        }
      }

      // The writer accepts frames as fast as it can compress them; this is the
      // backpressure that keeps memory flat on a long export.
      while !input.isReadyForMoreMediaData {
        if writer.status != .writing {
          fail("write-failed", writer.error?.localizedDescription ?? "Writer stopped")
          return
        }
        Thread.sleep(forTimeInterval: 0.002)
      }

      guard let pool = adaptor.pixelBufferPool else {
        fail("no-pool", "Pixel buffer pool unavailable")
        return
      }

      var maybeBuffer: CVPixelBuffer?
      guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &maybeBuffer) == kCVReturnSuccess,
        let buffer = maybeBuffer
      else {
        fail("no-buffer", "Could not allocate a pixel buffer")
        return
      }

      CVPixelBufferLockBaseAddress(buffer, [])
      guard let base = CVPixelBufferGetBaseAddress(buffer) else {
        CVPixelBufferUnlockBaseAddress(buffer, [])
        fail("no-buffer", "Pixel buffer had no base address")
        return
      }

      // Flutter hands over RGBA; VideoToolbox wants BGRA. vImage does the
      // swap a few GB/s faster than a Dart or Swift byte loop would, and
      // honours the pixel buffer's row padding, which is rarely width * 4.
      data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
        var source = vImage_Buffer(
          data: UnsafeMutableRawPointer(mutating: raw.baseAddress!),
          height: vImagePixelCount(h),
          width: vImagePixelCount(w),
          rowBytes: w * 4)
        var destination = vImage_Buffer(
          data: base,
          height: vImagePixelCount(h),
          width: vImagePixelCount(w),
          rowBytes: CVPixelBufferGetBytesPerRow(buffer))
        var map: [UInt8] = [2, 1, 0, 3]
        vImagePermuteChannels_ARGB8888(&source, &destination, &map, vImage_Flags(kvImageNoFlags))
      }
      CVPixelBufferUnlockBaseAddress(buffer, [])

      // Presentation time is derived from the frame index, never from a clock.
      let time = CMTime(value: CMTimeValue(index), timescale: CMTimeScale(rate))
      guard adaptor.append(buffer, withPresentationTime: time) else {
        fail("append-failed", writer.error?.localizedDescription ?? "Frame \(index) was rejected")
        return
      }

      _ = self
      DispatchQueue.main.async { result(nil) }
    }
  }

  // MARK: - finish

  private func finish(_ result: @escaping FlutterResult) {
    guard let writer = writer, let input = input else {
      result(FlutterError(code: "not-started", message: "finish() before start()", details: nil))
      return
    }
    queue.async { [weak self] in
      input.markAsFinished()
      writer.finishWriting {
        self?.finished = writer.status == .completed
        DispatchQueue.main.async {
          if writer.status == .completed {
            result(nil)
          } else {
            result(FlutterError(code: "finish-failed", message: writer.error?.localizedDescription ?? "Writer did not complete", details: nil))
          }
        }
      }
    }
  }

  // MARK: - dispose

  private func dispose(_ result: @escaping FlutterResult) {
    // A cancelled or failed export must not leave a half-written file that
    // looks playable until someone opens it.
    tearDown(deleteOutput: !finished)
    result(nil)
  }

  private func tearDown(deleteOutput: Bool) {
    if let writer = writer, writer.status == .writing {
      writer.cancelWriting()
    }
    if deleteOutput, let url = outputURL {
      try? FileManager.default.removeItem(at: url)
    }
    writer = nil
    input = nil
    adaptor = nil
    outputURL = nil
    audioInput = nil
    audioComposition = nil
    audioMix = nil
  }

  // MARK: - audio

  private struct AudioTimeline {
    let composition: AVMutableComposition
    let mix: AVAudioMix
  }

  /// Lays the declared clips out on one timeline, at their volumes.
  ///
  /// Each clip gets its own composition track so that overlapping sounds sum
  /// rather than replacing one another, and so that each can carry its own
  /// volume -- an `AVAudioMix` addresses a whole track, not a range of one.
  ///
  /// Returns nil if nothing usable was found, which leaves the export silent
  /// rather than failed.
  private func buildAudioTimeline(clips: [[String: Any]], fps: Int) -> AudioTimeline? {
    let composition = AVMutableComposition()
    let scale = CMTimeScale(fps)
    var parameters: [AVMutableAudioMixInputParameters] = []

    for clip in clips {
      guard let path = clip["path"] as? String,
        let startFrame = clip["startFrame"] as? Int,
        let endFrame = clip["endFrame"] as? Int
      else { continue }

      let volume = (clip["volume"] as? NSNumber)?.floatValue ?? 1
      let trimStart = clip["trimStartInFrames"] as? Int ?? 0
      let loop = clip["loop"] as? Bool ?? false

      let asset = AVURLAsset(url: URL(fileURLWithPath: path))
      guard let source = asset.tracks(withMediaType: .audio).first,
        asset.duration > .zero,
        let track = composition.addMutableTrack(
          withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
      else { continue }

      let start = CMTime(value: CMTimeValue(startFrame), timescale: scale)
      var remaining = CMTime(value: CMTimeValue(endFrame - startFrame + 1), timescale: scale)
      var readFrom = CMTime(value: CMTimeValue(trimStart), timescale: scale)

      // The silence before the clip is stated rather than assumed. A track
      // whose first edit begins at zero would play the sound early, which is
      // the sort of mistake nobody sees in a diff.
      if start > .zero {
        track.insertEmptyTimeRange(CMTimeRange(start: .zero, duration: start))
      }

      var cursor = start
      while remaining > .zero {
        if readFrom >= asset.duration {
          guard loop else { break }
          readFrom = .zero
        }
        let available = asset.duration - readFrom
        let take = min(available, remaining)
        guard take > .zero else { break }
        do {
          try track.insertTimeRange(
            CMTimeRange(start: readFrom, duration: take), of: source, at: cursor)
        } catch {
          break
        }
        cursor = cursor + take
        remaining = remaining - take
        readFrom = readFrom + take
      }

      if volume != 1 {
        let parameter = AVMutableAudioMixInputParameters(track: track)
        parameter.setVolume(volume, at: .zero)
        parameters.append(parameter)
      }
    }

    guard !composition.tracks(withMediaType: .audio).isEmpty else { return nil }

    let mix = AVMutableAudioMix()
    mix.inputParameters = parameters
    return AudioTimeline(composition: composition, mix: mix)
  }

  /// Reads the mixed timeline and hands it to the writer.
  ///
  /// Clamped to the composition's own length, so a music bed longer than the
  /// video does not leave the file playing over a frozen last frame.
  private func writeAudio(into audioInput: AVAssetWriterInput, writer: AVAssetWriter) {
    guard let composition = audioComposition, totalFrames > 0 else { return }

    let duration = CMTime(value: CMTimeValue(totalFrames), timescale: CMTimeScale(fps))
    guard let reader = try? AVAssetReader(asset: composition) else { return }
    reader.timeRange = CMTimeRange(start: .zero, duration: duration)

    let output = AVAssetReaderAudioMixOutput(
      audioTracks: composition.tracks(withMediaType: .audio),
      audioSettings: [
        AVFormatIDKey: kAudioFormatLinearPCM,
        AVSampleRateKey: 48000,
        AVNumberOfChannelsKey: 2,
        AVLinearPCMBitDepthKey: 16,
        AVLinearPCMIsFloatKey: false,
        AVLinearPCMIsBigEndianKey: false,
        AVLinearPCMIsNonInterleaved: false,
      ])
    output.audioMix = audioMix
    guard reader.canAdd(output) else { return }
    reader.add(output)
    guard reader.startReading() else { return }

    while reader.status == .reading {
      guard let sample = output.copyNextSampleBuffer() else { break }
      while !audioInput.isReadyForMoreMediaData {
        if writer.status != .writing { return }
        Thread.sleep(forTimeInterval: 0.002)
      }
      if !audioInput.append(sample) { return }
    }
  }
}
