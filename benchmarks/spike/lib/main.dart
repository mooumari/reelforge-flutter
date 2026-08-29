// Throughput + determinism spike for a Flutter-as-video-engine renderer.
//
// Renders a detached (offscreen) widget tree frame-by-frame at video
// resolution and measures where the time actually goes:
//   pump (build+layout+paint)  ->  toImage (raster)  ->  readback (GPU->CPU)
//
// Also checks byte-level determinism and does an end-to-end ffmpeg encode.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Where the run writes its numbers.
///
/// A macOS app's working directory is `/`, so this has to be absolute, and it
/// cannot be hard-coded to one machine. Pass it in:
///
/// ```
/// flutter run -d macos --release \
///   --dart-define=reportPath="$PWD/bench_result.json"
/// ```
/// The ffmpeg the end-to-end encode pipes into.
///
/// An app launched from Finder does not inherit a shell's PATH, so this cannot
/// be a bare `ffmpeg`.
const String kFfmpegPath = String.fromEnvironment(
  'ffmpegPath',
  defaultValue: '/opt/homebrew/bin/ffmpeg',
);

const String kReportPath = String.fromEnvironment(
  'reportPath',
  defaultValue: '/tmp/reelforge_bench_result.json',
);

double interpolate(int frame, List<double> input, List<double> output) {
  if (frame <= input.first) return output.first;
  if (frame >= input.last) return output.last;
  for (int i = 0; i < input.length - 1; i++) {
    if (frame >= input[i] && frame <= input[i + 1]) {
      final double t = (frame - input[i]) / (input[i + 1] - input[i]);
      return output[i] + (output[i + 1] - output[i]) * t;
    }
  }
  return output.last;
}

/// A widget tree that lives outside the app's view, rendered on demand.
class OffscreenComposition {
  OffscreenComposition({
    required this.size,
    required this.builder,
    this.devicePixelRatio = 1.0,
  }) {
    _renderView = RenderView(
      view: ui.PlatformDispatcher.instance.implicitView!,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size * devicePixelRatio),
        devicePixelRatio: devicePixelRatio,
      ),
    );
    _pipelineOwner = PipelineOwner();
    _pipelineOwner.rootNode = _renderView;
    _renderView.prepareInitialFrame();

    _buildOwner = BuildOwner(focusManager: FocusManager());
    _element = RenderObjectToWidgetAdapter<RenderBox>(
      container: _renderView,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(size: size, devicePixelRatio: devicePixelRatio),
          child: RepaintBoundary(
            child: ValueListenableBuilder<int>(
              valueListenable: _frame,
              builder: (context, frame, _) => builder(frame),
            ),
          ),
        ),
      ),
    ).attachToRenderTree(_buildOwner);
  }

  final Size size;
  final double devicePixelRatio;
  final Widget Function(int frame) builder;

  final ValueNotifier<int> _frame = ValueNotifier<int>(-1);

  late final RenderView _renderView;
  late final PipelineOwner _pipelineOwner;
  late final BuildOwner _buildOwner;
  late final RenderObjectToWidgetElement<RenderBox> _element;

  // Directionality/MediaQuery are InheritedWidgets (no RenderObject), so the
  // RepaintBoundary is RenderView's direct child.
  RenderRepaintBoundary get _boundary =>
      _renderView.child! as RenderRepaintBoundary;

  /// Build + layout + paint for [frame]. Synchronous, no engine frame involved.
  void pump(int frame) {
    _frame.value = frame;
    _buildOwner.buildScope(_element);
    _buildOwner.finalizeTree();
    _pipelineOwner.flushLayout();
    _pipelineOwner.flushCompositingBits();
    _pipelineOwner.flushPaint();
  }

  Future<ui.Image> toImage() => _boundary.toImage(pixelRatio: devicePixelRatio);

  ui.Image toImageSync() => _boundary.toImageSync(pixelRatio: devicePixelRatio);
}

// ---------------------------------------------------------------------------
// Compositions under test
// ---------------------------------------------------------------------------

Widget simpleComposition(int frame) {
  final double scale = interpolate(frame, [0, 30], [0, 1]);
  final double opacity = interpolate(frame, [0, 20], [0, 1]);
  return ColoredBox(
    color: const Color(0xFF0B0B10),
    child: Center(
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: const Text(
            'Hello Flutter',
            style: TextStyle(
              fontSize: 80,
              color: Color(0xFFFFFFFF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Deliberately expensive: gradients, 40 shadowed cards, a blur, a CustomPaint
/// chart, and a lot of text layout. Meant to represent a realistic ad/story
/// template rather than a best case.
Widget complexComposition(int frame) {
  final double t = frame / 60.0;
  return Stack(
    fit: StackFit.expand,
    children: <Widget>[
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color.lerp(const Color(0xFF1B1035), const Color(0xFF0C2A4D), t)!,
              const Color(0xFF05060A),
            ],
          ),
        ),
      ),
      for (int i = 0; i < 40; i++)
        Positioned(
          left: 40 + (i % 4) * 250.0,
          top: 120 +
              (i ~/ 4) * 180.0 +
              math.sin((frame + i * 7) / 18.0) * 14.0,
          child: Transform.rotate(
            angle: math.sin((frame + i * 11) / 40.0) * 0.05,
            child: Container(
              width: 220,
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF14161F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0x22FFFFFF)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: const Color(0x66000000),
                    blurRadius: 24,
                    offset: Offset(0, 8 + math.sin(t + i) * 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Product ${i + 1}',
                    style: const TextStyle(
                      fontSize: 22,
                      color: Color(0xFFFFFFFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${(19.99 + i * 3.5).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Color(0xFF7DE2A8),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 8,
                    child: CustomPaint(
                      size: const Size(190, 8),
                      painter: _BarPainter(phase: frame + i * 5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      Positioned(
        left: 0,
        right: 0,
        bottom: interpolate(frame, [0, 30], [-200, 0]),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 180,
              color: const Color(0x33FFFFFF),
              alignment: Alignment.center,
              child: const Text(
                'WEEKLY DEALS',
                style: TextStyle(
                  fontSize: 56,
                  color: Color(0xFFFFFFFF),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.phase});
  final int phase;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = const Color(0xFF4C7DFF);
    const int bars = 14;
    final double w = size.width / (bars * 1.6);
    for (int i = 0; i < bars; i++) {
      final double h =
          (0.5 + 0.5 * math.sin((phase + i * 9) / 12.0)) * size.height;
      canvas.drawRect(
        Rect.fromLTWH(i * w * 1.6, size.height - h, w, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) => oldDelegate.phase != phase;
}

// ---------------------------------------------------------------------------
// Benchmarks
// ---------------------------------------------------------------------------

final Map<String, dynamic> report = <String, dynamic>{
  'flutter': '3.47.2',
  'device': 'Apple M3 Max',
  'mode': kReleaseMode ? 'release' : (kProfileMode ? 'profile' : 'debug'),
  'benchmarks': <Map<String, dynamic>>[],
};

Future<Map<String, dynamic>> benchmark({
  required String name,
  required Size size,
  required Widget Function(int) builder,
  int frames = 120,
  bool readback = true,
}) async {
  final OffscreenComposition comp =
      OffscreenComposition(size: size, builder: builder);

  // Warm up: shader compilation, font loading, first-paint costs.
  for (int i = 0; i < 10; i++) {
    comp.pump(i);
    final ui.Image img = await comp.toImage();
    if (readback) await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    img.dispose();
  }

  int pumpUs = 0, imageUs = 0, readbackUs = 0;
  final Stopwatch total = Stopwatch()..start();
  final Stopwatch sw = Stopwatch();

  for (int f = 0; f < frames; f++) {
    sw
      ..reset()
      ..start();
    comp.pump(f);
    pumpUs += sw.elapsedMicroseconds;

    sw
      ..reset()
      ..start();
    final ui.Image img = await comp.toImage();
    imageUs += sw.elapsedMicroseconds;

    if (readback) {
      sw
        ..reset()
        ..start();
      await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      readbackUs += sw.elapsedMicroseconds;
    }
    img.dispose();
  }
  total.stop();

  final double seconds = total.elapsedMicroseconds / 1e6;
  final Map<String, dynamic> result = <String, dynamic>{
    'name': name,
    'resolution': '${size.width.toInt()}x${size.height.toInt()}',
    'frames': frames,
    'readback': readback,
    'total_s': double.parse(seconds.toStringAsFixed(3)),
    'fps': double.parse((frames / seconds).toStringAsFixed(2)),
    'ms_per_frame': double.parse((seconds * 1000 / frames).toStringAsFixed(2)),
    'breakdown_ms': <String, double>{
      'pump': double.parse((pumpUs / 1000 / frames).toStringAsFixed(2)),
      'toImage': double.parse((imageUs / 1000 / frames).toStringAsFixed(2)),
      'readback': double.parse((readbackUs / 1000 / frames).toStringAsFixed(2)),
    },
    'realtime_ratio_at_60fps':
        double.parse(((frames / seconds) / 60).toStringAsFixed(2)),
  };
  (report['benchmarks'] as List).add(result);
  debugPrint('BENCH ${jsonEncode(result)}');
  return result;
}

/// Same work as [benchmark], but keeps [depth] frames in flight so the CPU
/// pump overlaps with GPU rasterisation instead of stalling on it.
Future<Map<String, dynamic>> benchmarkPipelined({
  required String name,
  required Size size,
  required Widget Function(int) builder,
  int frames = 120,
  int depth = 3,
}) async {
  final OffscreenComposition comp =
      OffscreenComposition(size: size, builder: builder);
  for (int i = 0; i < 10; i++) {
    comp.pump(i);
    final ui.Image w = await comp.toImage();
    await w.toByteData(format: ui.ImageByteFormat.rawRgba);
    w.dispose();
  }

  final Stopwatch total = Stopwatch()..start();
  final List<Future<void>> inflight = <Future<void>>[];
  for (int f = 0; f < frames; f++) {
    comp.pump(f);
    inflight.add(comp.toImage().then((ui.Image img) async {
      await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      img.dispose();
    }));
    if (inflight.length >= depth) {
      await inflight.removeAt(0);
    }
  }
  await Future.wait(inflight);
  total.stop();

  final double seconds = total.elapsedMicroseconds / 1e6;
  final Map<String, dynamic> result = <String, dynamic>{
    'name': name,
    'resolution': '${size.width.toInt()}x${size.height.toInt()}',
    'frames': frames,
    'pipeline_depth': depth,
    'total_s': double.parse(seconds.toStringAsFixed(3)),
    'fps': double.parse((frames / seconds).toStringAsFixed(2)),
    'ms_per_frame': double.parse((seconds * 1000 / frames).toStringAsFixed(2)),
    'realtime_ratio_at_60fps':
        double.parse(((frames / seconds) / 60).toStringAsFixed(2)),
  };
  (report['benchmarks'] as List).add(result);
  debugPrint('BENCH ${jsonEncode(result)}');
  return result;
}

Future<String> _hash(ui.Image img) async {
  final ByteData data =
      (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final Uint8List bytes = data.buffer.asUint8List();
  // FNV-1a over the raw pixels.
  int h = 0xcbf29ce484222325;
  for (int i = 0; i < bytes.length; i++) {
    h ^= bytes[i];
    h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
  }
  return h.toRadixString(16);
}

Future<void> determinismCheck() async {
  const Size size = Size(1080, 1920);

  // Same frame, fresh composition each time.
  final List<String> isolated = <String>[];
  for (int run = 0; run < 3; run++) {
    final OffscreenComposition c =
        OffscreenComposition(size: size, builder: complexComposition);
    c.pump(37);
    final ui.Image img = await c.toImage();
    isolated.add(await _hash(img));
    img.dispose();
  }

  // Same frame reached by scrubbing forward through a sequence, then again
  // by scrubbing backward -- catches order-dependent state.
  final OffscreenComposition seq =
      OffscreenComposition(size: size, builder: complexComposition);
  for (int f = 0; f <= 37; f++) {
    seq.pump(f);
  }
  final ui.Image fwd = await seq.toImage();
  final String forwardHash = await _hash(fwd);
  fwd.dispose();

  for (int f = 90; f >= 37; f--) {
    seq.pump(f);
  }
  final ui.Image bwd = await seq.toImage();
  final String backwardHash = await _hash(bwd);
  bwd.dispose();

  report['determinism'] = <String, dynamic>{
    'isolated_hashes': isolated,
    'isolated_stable': isolated.toSet().length == 1,
    'forward_scrub': forwardHash,
    'backward_scrub': backwardHash,
    'scrub_order_independent': forwardHash == backwardHash,
    'matches_isolated': forwardHash == isolated.first,
  };
  debugPrint('DETERMINISM ${jsonEncode(report['determinism'])}');
}

/// Overlapping frames is only legal if a later pump() cannot mutate the Scene
/// already captured by an in-flight toImage(). Verify byte-for-byte.
Future<void> pipelineCorrectness() async {
  const Size size = Size(1080, 1920);
  const int n = 24;

  final OffscreenComposition serial =
      OffscreenComposition(size: size, builder: complexComposition);
  final List<String> serialHashes = <String>[];
  for (int f = 0; f < n; f++) {
    serial.pump(f);
    final ui.Image img = await serial.toImage();
    serialHashes.add(await _hash(img));
    img.dispose();
  }

  final OffscreenComposition piped =
      OffscreenComposition(size: size, builder: complexComposition);
  final List<Future<String>> futures = <Future<String>>[];
  for (int f = 0; f < n; f++) {
    piped.pump(f);
    futures.add(piped.toImage().then((ui.Image img) async {
      final String h = await _hash(img);
      img.dispose();
      return h;
    }));
  }
  final List<String> pipedHashes = await Future.wait(futures);

  int mismatches = 0;
  for (int i = 0; i < n; i++) {
    if (serialHashes[i] != pipedHashes[i]) mismatches++;
  }
  report['pipeline_correctness'] = <String, dynamic>{
    'frames_compared': n,
    'mismatches': mismatches,
    'safe': mismatches == 0,
  };
  debugPrint('PIPELINE ${jsonEncode(report['pipeline_correctness'])}');
}

Future<void> endToEndEncode() async {
  const Size size = Size(1080, 1920);
  const int frames = 300; // 5 s @ 60fps
  final OffscreenComposition comp =
      OffscreenComposition(size: size, builder: complexComposition);

  // Next to the report, for the same reason the report is passed in: a
  // hard-coded absolute path belongs to whoever's machine it was written on,
  // and ffmpeg answers a missing directory with exit 254 and an empty file
  // rather than anything that reads like an error.
  final String outPath =
      '${File(kReportPath).parent.path}${Platform.pathSeparator}out.mp4';
  final Process ff = await Process.start(kFfmpegPath, <String>[
    '-y',
    '-f', 'rawvideo',
    '-pix_fmt', 'rgba',
    '-s', '${size.width.toInt()}x${size.height.toInt()}',
    '-r', '60',
    '-i', '-',
    '-c:v', 'h264_videotoolbox',
    '-b:v', '12M',
    '-pix_fmt', 'yuv420p',
    outPath,
  ]);
  ff.stderr.drain<void>();
  ff.stdout.drain<void>();

  final Stopwatch sw = Stopwatch()..start();
  for (int f = 0; f < frames; f++) {
    comp.pump(f);
    final ui.Image img = await comp.toImage();
    final ByteData data =
        (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    img.dispose();
    ff.stdin.add(data.buffer.asUint8List());
    await ff.stdin.flush();
  }
  await ff.stdin.close();
  final int code = await ff.exitCode;
  sw.stop();

  final File out = File(outPath);
  report['end_to_end'] = <String, dynamic>{
    'frames': frames,
    'video_duration_s': frames / 60,
    'encode_wall_s': double.parse((sw.elapsedMicroseconds / 1e6).toStringAsFixed(2)),
    'realtime_ratio': double.parse(
        ((frames / 60) / (sw.elapsedMicroseconds / 1e6)).toStringAsFixed(2)),
    'ffmpeg_exit': code,
    'output_bytes': out.existsSync() ? out.lengthSync() : 0,
  };
  debugPrint('E2E ${jsonEncode(report['end_to_end'])}');
}

Future<void> runAll() async {
  await benchmark(
    name: 'simple / no readback',
    size: const Size(1080, 1920),
    builder: simpleComposition,
    readback: false,
  );
  await benchmark(
    name: 'simple',
    size: const Size(1080, 1920),
    builder: simpleComposition,
  );
  await benchmark(
    name: 'complex',
    size: const Size(1080, 1920),
    builder: complexComposition,
  );
  await benchmark(
    name: 'complex / 1920x1080',
    size: const Size(1920, 1080),
    builder: complexComposition,
  );
  await benchmark(
    name: 'complex / 4K',
    size: const Size(2160, 3840),
    builder: complexComposition,
    frames: 60,
  );
  await benchmarkPipelined(
    name: 'complex / pipelined d=2',
    size: const Size(1080, 1920),
    builder: complexComposition,
    depth: 2,
  );
  await benchmarkPipelined(
    name: 'complex / pipelined d=4',
    size: const Size(1080, 1920),
    builder: complexComposition,
    depth: 4,
  );
  await benchmarkPipelined(
    name: 'complex / pipelined d=8',
    size: const Size(1080, 1920),
    builder: complexComposition,
    depth: 8,
  );
  await determinismCheck();
  await pipelineCorrectness();
  await endToEndEncode();

  File(kReportPath).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(report));
  debugPrint('REPORT WRITTEN $kReportPath');
  exit(0);
}

void main() {
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  binding.addPostFrameCallback((_) async {
    try {
      await runAll();
    } catch (e, st) {
      debugPrint('SPIKE FAILED: $e\n$st');
      File(kReportPath).writeAsStringSync(jsonEncode(<String, String>{
        'error': e.toString(),
        'stack': st.toString(),
      }));
      exit(1);
    }
  });
  runApp(const ColoredBox(color: Color(0xFF000000)));
}
