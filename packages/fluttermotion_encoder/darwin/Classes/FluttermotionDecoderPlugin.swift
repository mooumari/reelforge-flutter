import AVFoundation
import Accelerate

#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif

/// Decodes video frames with AVFoundation, so a composition containing a
/// `VideoClip` can be exported from inside an app.
///
/// The counterpart to `FluttermotionEncoderPlugin`: the one platform-specific
/// step on the way *in*. On a laptop the CLI shells out to ffmpeg for this; a
/// shipping app cannot, and on iOS could not even if it wanted to.
///
/// ## Landing on the same frames ffmpeg does
///
/// Frames are rendered by several processes over different ranges, so a
/// decoder has to land on the *same* source frame whether it entered the clip
/// at its start or half way through -- and the CLI and the app have to agree
/// with each other too, or the same composition exports differently depending
/// on where you exported it from.
///
/// `AVAssetReader.timeRange` gives that, but only if the start time is exact.
/// A seek expressed in floating-point seconds does not survive the trip:
/// `CMTime(seconds: 1.483333, preferredTimescale: 600)` truncates to 889/600,
/// a hair *before* frame 89 at 60fps, and the reader then starts on frame 88 --
/// one whole frame early, silently, only for some seeks. So the seek is a
/// rational by construction: `CMTime(value: sourceFrame, timescale: fps)`.
///
/// Measured against ffmpeg's `fps=N:start_time=T` grid on a file whose frames
/// encode their own index, the two agree frame-for-frame from zero, from
/// mid-stream, and at the tail, and run dry at the same frame.
public class FluttermotionDecoderPlugin: NSObject, FlutterPlugin {
  private var sources: [Int: DecodeSource] = [:]
  private var nextHandle = 1

  /// Decoding happens off the platform thread: a frame is a few milliseconds
  /// of work and the UI has to keep running through an export.
  private let queue = DispatchQueue(label: "fluttermotion.decoder", qos: .userInitiated)

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(
      name: "fluttermotion/decoder", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(FluttermotionDecoderPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "probe": probe(call, result)
    case "open": open(call, result)
    case "seek": seek(call, result)
    case "nextFrame": nextFrame(call, result)
    case "close": close(call, result)
    default: result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - probe

  private func probe(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let path = args["path"] as? String
    else { return result(argumentError("probe needs a path")) }

    queue.async {
      let asset = AVURLAsset(url: URL(fileURLWithPath: path))
      guard let track = asset.tracks(withMediaType: .video).first else {
        return result(
          FlutterError(
            code: "no_video_track",
            message: "\(path) has no video track. AVFoundation opened it, but there is "
              + "nothing in it to show.", details: nil))
      }
      // naturalSize is pre-rotation; a portrait phone video reports landscape
      // until the transform is applied.
      let size = track.naturalSize.applying(track.preferredTransform)
      result([
        "width": Int(abs(size.width)),
        "height": Int(abs(size.height)),
        "duration": CMTimeGetSeconds(asset.duration),
      ])
    }
  }

  // MARK: - open

  private func open(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let path = args["path"] as? String,
      let fps = args["fps"] as? Int
    else { return result(argumentError("open needs a path and fps")) }

    let width = args["width"] as? Int
    let height = args["height"] as? Int
    let startSourceFrame = args["startSourceFrame"] as? Int ?? 0

    queue.async {
      do {
        let source = try DecodeSource(
          path: path, fps: Int32(fps), width: width, height: height)
        try source.restart(atSourceFrame: Int64(startSourceFrame))
        let handle = self.nextHandle
        self.nextHandle += 1
        self.sources[handle] = source
        result(["handle": handle, "width": source.width, "height": source.height])
      } catch {
        result(self.decodeError(path, error))
      }
    }
  }

  // MARK: - seek

  private func seek(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let handle = args["handle"] as? Int,
      let frame = args["sourceFrame"] as? Int
    else { return result(argumentError("seek needs a handle and sourceFrame")) }

    queue.async {
      guard let source = self.sources[handle] else {
        return result(self.unknownHandle(handle))
      }
      do {
        try source.restart(atSourceFrame: Int64(frame))
        result(nil)
      } catch {
        result(self.decodeError(source.path, error))
      }
    }
  }

  // MARK: - nextFrame

  /// The next frame as RGBA bytes, or nil once the source has run out.
  ///
  /// Running out is not an error: a clip mounted for longer than it lasts
  /// holds its last frame, and the framework has already warned about that by
  /// name during the declaration pass.
  private func nextFrame(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let handle = args["handle"] as? Int
    else { return result(argumentError("nextFrame needs a handle")) }

    queue.async {
      guard let source = self.sources[handle] else {
        return result(self.unknownHandle(handle))
      }
      do {
        guard let bytes = try source.nextFrame() else { return result(nil) }
        result(FlutterStandardTypedData(bytes: bytes))
      } catch {
        result(self.decodeError(source.path, error))
      }
    }
  }

  // MARK: - close

  private func close(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let handle = args["handle"] as? Int
    else { return result(argumentError("close needs a handle")) }

    queue.async {
      self.sources.removeValue(forKey: handle)?.cancel()
      result(nil)
    }
  }

  // MARK: - errors

  private func argumentError(_ message: String) -> FlutterError {
    FlutterError(code: "bad_arguments", message: message, details: nil)
  }

  private func unknownHandle(_ handle: Int) -> FlutterError {
    FlutterError(
      code: "unknown_handle",
      message: "No open decoder \(handle). It was closed, or belonged to an export that "
        + "has already finished.", details: nil)
  }

  private func decodeError(_ path: String, _ error: Error) -> FlutterError {
    FlutterError(
      code: "decode_failed",
      message: "Could not decode \(path): \(error.localizedDescription)", details: nil)
  }
}

/// One clip's reader, and the frames it hands out in order.
private class DecodeSource {
  init(path: String, fps: Int32, width: Int?, height: Int?) throws {
    self.path = path
    self.fps = fps
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .video).first else {
      throw DecodeError.noVideoTrack
    }
    self.asset = asset
    self.track = track

    let natural = track.naturalSize.applying(track.preferredTransform)
    self.width = width ?? Int(abs(natural.width))
    self.height = height ?? Int(abs(natural.height))
  }

  let path: String
  private let fps: Int32
  private let asset: AVURLAsset
  private let track: AVAssetTrack
  let width: Int
  let height: Int

  private var reader: AVAssetReader?
  private var output: AVAssetReaderTrackOutput?

  /// Points the reader at an exact source frame.
  ///
  /// A reader cannot be rewound, so a seek is a new reader. That is the
  /// expensive path, and the Dart side only takes it for a non-adjacent jump.
  func restart(atSourceFrame frame: Int64) throws {
    cancel()

    let reader = try AVAssetReader(asset: asset)
    if frame > 0 {
      // Rational, not seconds: see the note on the plugin. This is exactly the
      // instant frame `frame` is presented at, with no rounding anywhere.
      reader.timeRange = CMTimeRange(
        start: CMTime(value: frame, timescale: fps), duration: .positiveInfinity)
    }

    // BGRA is what VideoToolbox produces natively; asking for RGBA here would
    // make AVFoundation convert on the CPU. The permute below is cheaper, and
    // the width/height keys let the GPU do any downscale on the way out.
    var settings: [String: Any] = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    let natural = track.naturalSize.applying(track.preferredTransform)
    if width != Int(abs(natural.width)) || height != Int(abs(natural.height)) {
      settings[kCVPixelBufferWidthKey as String] = width
      settings[kCVPixelBufferHeightKey as String] = height
    }

    let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
    // Without this the buffer is recycled under us and every frame reads back
    // as the first one.
    output.alwaysCopiesSampleData = true
    reader.add(output)
    guard reader.startReading() else { throw reader.error ?? DecodeError.readFailed }

    self.reader = reader
    self.output = output
  }

  /// The next frame's pixels as RGBA, or nil at the end of the source.
  func nextFrame() throws -> Data? {
    guard let reader = reader, let output = output else { throw DecodeError.notOpen }
    guard let sample = output.copyNextSampleBuffer() else {
      if reader.status == .failed { throw reader.error ?? DecodeError.readFailed }
      return nil
    }
    guard let buffer = CMSampleBufferGetImageBuffer(sample) else {
      throw DecodeError.notAnImage
    }

    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

    guard let base = CVPixelBufferGetBaseAddress(buffer) else {
      throw DecodeError.notAnImage
    }
    let bufferWidth = CVPixelBufferGetWidth(buffer)
    let bufferHeight = CVPixelBufferGetHeight(buffer)
    let stride = CVPixelBufferGetBytesPerRow(buffer)

    var packed = Data(count: bufferWidth * bufferHeight * 4)
    packed.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
      guard let destination = raw.baseAddress else { return }
      var source = vImage_Buffer(
        data: base, height: vImagePixelCount(bufferHeight),
        width: vImagePixelCount(bufferWidth), rowBytes: stride)
      var target = vImage_Buffer(
        data: destination, height: vImagePixelCount(bufferHeight),
        width: vImagePixelCount(bufferWidth), rowBytes: bufferWidth * 4)
      // BGRA -> RGBA. Also drops the row padding, which Flutter's
      // decodeImageFromPixels does not take.
      var map: [UInt8] = [2, 1, 0, 3]
      vImagePermuteChannels_ARGB8888(&source, &target, &map, vImage_Flags(kvImageNoFlags))
    }
    return packed
  }

  func cancel() {
    reader?.cancelReading()
    reader = nil
    output = nil
  }

  deinit { cancel() }
}

private enum DecodeError: LocalizedError {
  case noVideoTrack
  case readFailed
  case notOpen
  case notAnImage

  var errorDescription: String? {
    switch self {
    case .noVideoTrack: return "the file has no video track"
    case .readFailed: return "the reader stopped without saying why"
    case .notOpen: return "the decoder is not open"
    case .notAnImage: return "a sample came back without pixels"
    }
  }
}
