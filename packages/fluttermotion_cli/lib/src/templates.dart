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
    //
    // A spring overshoots its target and settles back -- that overshoot is
    // what makes the motion feel like motion, and it is why `rise` drives the
    // offset rather than the opacity. `Opacity` asserts 0..1 and a spring will
    // hand it 1.03.
    final double rise = spring(frame - 6, fps: 30, stiffness: 120, damping: 14);
    final double fade = interpolate(
      frame,
      <num>[6, 22],
      <num>[0, 1],
      easing: Curves.easeOut,
    );
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
          opacity: fade,
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

String previewMainTemplate() => r'''
import 'package:fluttermotion/fluttermotion.dart';

import 'compositions.dart';

/// Preview app. Run it with `fluttermotion preview`, then scrub.
///
/// Hot reload applies to compositions like any other Flutter code: edit a
/// widget, save, and the frame you are parked on redraws immediately. Because
/// the preview draws through the same rasteriser the exporter uses, what you
/// scrub to is what renders -- there is one rasteriser, so there is nothing for
/// the two paths to disagree about.
///
/// This is the same list `render_main.dart` serves. Keeping them in one place
/// is worth doing once there is more than one composition:
///
/// ```dart
/// // lib/video/compositions.dart
/// final List<Composition> compositions = <Composition>[intro];
/// ```
///
/// If your app has the `fluttermotion_encoder` plugin, passing it here adds an
/// Export button that writes the MP4 inside this app, and lets video clips
/// decode without ffmpeg on the machine:
///
/// ```dart
/// previewMain(
///   <Composition>[intro],
///   encoderFactory: NativeVideoEncoder.new,
///   videoBackendFactory: NativeVideoBackend.new,
/// );
/// ```
void main() => previewMain(<Composition>[intro]);
''';

/// A starter composition document.
///
/// Deliberately not a hello-world rectangle: the thing a document is *for* is a
/// video that is a function of data, so the starter binds to some, repeats over
/// a list, and counts a number. Change `reel_data.json` and every frame
/// changes with it, which is the whole idea in three scenes.
String documentTemplate() => r'''
{
  "version": 1,
  "id": "Reel",
  "width": 1080,
  "height": 1920,
  "fps": 30,

  "theme": {"palette": "dark"},

  "scenes": [
    {
      "seconds": 4,
      "child": {
        "type": "titleCard",
        "kicker": "{{ period }}",
        "headline": "{{ headline }}",
        "subhead": "{{ weeks.0.label }} to {{ weeks.3.label }}"
      }
    },
    {
      "seconds": 6,
      "child": {
        "type": "labelledScene",
        "label": "Shipped per week",
        "child": {
          "type": "barChart",
          "bars": {
            "repeat": "weeks",
            "as": {"value": "{{ shipped }}", "label": "{{ label }}"}
          }
        }
      }
    },
    {
      "seconds": 4,
      "child": {
        "type": "padding",
        "padding": 80,
        "child": {
          "type": "bigStatList",
          "children": [
            {
              "type": "bigStat",
              "label": "shipped in total",
              "value": {"type": "counter", "to": "{{ total }}", "delay": 6}
            }
          ]
        }
      }
    }
  ]
}
''';

/// The data the starter document reads.
String documentDataTemplate() => r'''
{
  "period": "Q3 2026",
  "headline": "Shipped more, broke less",
  "total": 83,
  "weeks": [
    {"label": "W27", "shipped": 12},
    {"label": "W28", "shipped": 18},
    {"label": "W29", "shipped": 24},
    {"label": "W30", "shipped": 29}
  ]
}
''';
