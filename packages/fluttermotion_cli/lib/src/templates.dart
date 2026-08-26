/// The files `init` writes.
///
/// Kept as strings rather than assets so the CLI stays a single `dart run`
/// away from working, with nothing to resolve at runtime.
library;

String renderMainTemplate() => r'''
import 'package:fluttermotion/fluttermotion.dart';

import 'video/compositions.dart';

/// Render host. The FlutterMotion CLI builds this entry point and drives it;
/// your app itself never links it.
///
/// Anything your app sets up before its first frame has to be set up here too.
/// If a composition mounts widgets that read providers, and those providers
/// read a store that is opened asynchronously at startup, this is where it gets
/// opened:
///
/// ```dart
/// Future<void> main(List<String> args) async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await openTheStore();
///   await renderMain(args, <Composition>[intro]);
/// }
/// ```
void main(List<String> args) => renderMain(args, <Composition>[intro]);
''';

String compositionsTemplate(String appName) => '''
import 'package:flutter/material.dart';
import 'package:fluttermotion/fluttermotion.dart';

/// A composition is a function from frame number to a widget tree.
///
/// That is the whole contract, and everything else follows from it: frame 300
/// looks the same however it was reached, so the renderer can seek to it, scrub
/// backwards through it, or hand it to one of four processes rendering the
/// range in parallel.
///
/// What it means in practice is that nothing here may remember anything. No
/// `setState` driving the animation, no elapsed wall time, no counter that goes
/// up. Read the frame, compute what it looks like, return it.
final Composition intro = Composition(
  id: 'Intro',
  width: 1080,
  height: 1920,
  fps: 30,
  durationInFrames: 90,
  // Ambient state your own widgets expect goes here, assembled the way
  // `main.dart` assembles it: your app's Theme, a ProviderScope with the same
  // overrides, and whatever InheritedWidgets your widgets reach for. Without
  // it, `Theme.of` quietly returns stock Material and your brand card renders
  // in somebody else's purple.
  //
  // wrapper: (BuildContext context, Widget child) =>
  //     Theme(data: myAppTheme, child: child),
  builder: (BuildContext context) => const _Intro(),
);

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    final int frame = Video.frame(context);

    // Every value below depends on `frame` and nothing else.
    final double rise = spring(frame - 6, fps: 30, stiffness: 120, damping: 14);
    final double settle = interpolate(
      frame,
      <num>[24, 54],
      <num>[0, 1],
      easing: Curves.easeOutCubic,
    );

    return ColoredBox(
      color: const Color(0xFF101216),
      child: Center(
        child: Opacity(
          opacity: rise,
          child: Transform.translate(
            offset: Offset(0, (1 - rise) * 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$appName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFF4F5F7),
                    fontSize: 96,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 24),
                Opacity(
                  opacity: settle,
                  child: const Text(
                    'rendered by its own widgets',
                    style: TextStyle(
                      color: Color(0xFF8A8F98),
                      fontSize: 34,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
''';
