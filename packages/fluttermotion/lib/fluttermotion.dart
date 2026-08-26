/// FlutterMotion — a deterministic video composition engine built on Flutter.
///
/// `data -> Flutter widgets -> frames -> MP4`. A composition is a pure
/// function of frame number, not a running animation.
library;

export 'src/animation/ticker_gate.dart' show MotionTickerShield;
export 'src/composition.dart';
export 'src/declarations/assets.dart';
export 'src/declarations/manifest.dart';
export 'src/declarations/pass.dart';
export 'src/declarations/scope.dart' show DeclarationCollector, DeclarationScope;
export 'src/export/audio_sources.dart';
export 'src/export/audio_track.dart';
export 'src/export/encoder.dart';
export 'src/export/exporter.dart';
export 'src/frame.dart';
export 'src/interpolate.dart';
export 'src/media/video_store.dart'
    show DecodedVideoFrames, VideoFrames, VideoPreloader;
export 'src/preview/preview_app.dart' show FlutterMotionPreview, previewMain;
export 'src/preview/player.dart' show CompositionPlayer;
export 'src/preview/scrubber.dart' show Scrubber;
export 'src/render_host.dart' show renderMain;
export 'src/renderer.dart';
export 'src/sequence.dart';
export 'src/widgets/audio.dart';
export 'src/widgets/motion_image.dart';
export 'src/widgets/video_clip.dart';
