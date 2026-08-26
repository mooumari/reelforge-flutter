/// FlutterMotion — a deterministic video composition engine built on Flutter.
///
/// `data -> Flutter widgets -> frames -> MP4`. A composition is a pure
/// function of frame number, not a running animation.
library;

export 'src/composition.dart';
export 'src/frame.dart';
export 'src/interpolate.dart';
export 'src/preview/preview_app.dart' show FlutterMotionPreview, previewMain;
export 'src/preview/player.dart' show CompositionPlayer;
export 'src/preview/scrubber.dart' show Scrubber;
export 'src/render_host.dart' show renderMain;
export 'src/renderer.dart';
export 'src/sequence.dart';
