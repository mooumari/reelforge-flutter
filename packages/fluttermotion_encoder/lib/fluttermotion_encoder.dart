/// The platform half of FlutterMotion: encodes rendered frames to MP4 using
/// the device's own hardware encoder, so a shipping app can export video
/// without ffmpeg.
library;

export 'src/native_decoder.dart';
export 'src/native_encoder.dart';
