import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../composition.dart';
import '../declarations/pass.dart';
import '../export/encoder.dart';
import '../export/exporter.dart';
import '../media/video_backend.dart';
import '../media/video_store.dart';
import '../renderer.dart';
import 'controls.dart';
import 'export_panel.dart';
import 'scrubber.dart';
import 'theme.dart';

/// Plays a [Composition] with a scrubbable timeline.
///
/// The preview draws frames through the *same* [CompositionRenderer] the
/// exporter uses and displays the result, rather than building the
/// composition live in the app's tree. That makes "what you scrub to is what
/// renders" structural rather than a promise: there is one rasteriser, so
/// there is nothing for the two paths to disagree about. It also matters for
/// widgets that animate on their own [Ticker], which only land on the right
/// frame because the renderer drives the animation clock -- built live they
/// would animate against the wall clock while you scrub.
///
/// Wall-clock time is used in exactly one place: choosing which frame the
/// playhead is on. That clock is a [Stopwatch] rather than a [Ticker],
/// precisely because the renderer moves the binding's own notion of time
/// around and the playhead must not follow it.
class CompositionPlayer extends StatefulWidget {
  const CompositionPlayer({
    super.key,
    required this.composition,
    this.projectPath,
    this.encoderFactory,
    this.exportPathBuilder,
    this.stopwatchFactory,
  });

  final Composition composition;

  /// Root that a clip's `src` is resolved against. Defaults to the process's
  /// working directory, which is the project root under `flutter run`.
  final String? projectPath;

  /// Supplies an encoder for in-app export. Null hides the Export button.
  ///
  /// Injected rather than imported so the framework never depends on a plugin
  /// with native code: an app that only previews pays nothing for an encoder
  /// it does not use.
  final VideoEncoder Function()? encoderFactory;

  /// Where an export is written. Defaults to the temp directory.
  final String Function(Composition composition)? exportPathBuilder;

  /// Supplies the playback clock.
  ///
  /// A plain [Stopwatch] is right in production -- it reads the monotonic
  /// clock and so is immune to the renderer moving [SchedulerBinding]'s notion
  /// of time to composition time. It is also immune to the fake clock in a
  /// widget test, where no real time passes, so tests hand in one backed by
  /// the test binding's clock instead.
  @visibleForTesting
  final Stopwatch Function()? stopwatchFactory;

  @override
  State<CompositionPlayer> createState() => _CompositionPlayerState();
}

class _CompositionPlayerState extends State<CompositionPlayer> {
  final FocusNode _focusNode = FocusNode();

  /// Playback clock. Deliberately not a [Ticker]: rendering a frame drives
  /// [SchedulerBinding] to composition time, which would drag a ticker-based
  /// playhead along with it.
  late final Stopwatch _clock = widget.stopwatchFactory?.call() ?? Stopwatch();
  Timer? _playTimer;
  double _playheadAtPlay = 0;

  int _frame = 0;
  double _playhead = 0;
  bool _playing = false;
  bool _loop = true;
  bool _wasPlayingBeforeScrub = false;

  Map<ImageProvider<Object>, ui.Image>? _images;
  VideoFrames? _video;

  /// The one rasteriser, shared with the exporter.
  CompositionRenderer? _renderer;

  /// The most recently rasterised frame. Owned here, disposed on replacement.
  ui.Image? _image;

  /// Video decodes asynchronously while the playhead moves on. Rather than
  /// queueing every frame the scrubber passes over -- a decoder is one pipe and
  /// cannot serve two reads at once -- only the most recent request is kept.
  ExportProgress? _exportProgress;
  ExportResult? _exportResult;
  String? _exportError;
  ExportCancellation? _exportCancellation;

  bool get _exporting => _exportCancellation != null;

  bool _rendering = false;
  int? _queuedFrame;
  String? _videoError;
  String? _renderError;

  int get _lastFrame => widget.composition.durationInFrames - 1;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void reassemble() {
    super.reassemble();
    // The renderer's tree has its own BuildOwner, which the binding never
    // reassembles, so a hot reload would otherwise leave the preview drawing
    // the code that was running when it started.
    _renderer?.reassemble();
    _requestFrame(_frame);
  }

  @override
  void didUpdateWidget(CompositionPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Hot reload can shorten a composition out from under the playhead.
    if (_frame > _lastFrame) {
      _seek(_lastFrame);
    }
    if (!identical(widget.composition, oldWidget.composition)) {
      _disposeVideo();
      _disposeRenderer();
      setState(() {
        _images = null;
        _videoError = null;
        _renderError = null;
      });
      _prepare();
    }
  }

  /// Sweep the timeline and decode assets, exactly as the exporter does, so
  /// the preview cannot show something the render would not.
  Future<void> _prepare() async {
    final Composition composition = widget.composition;
    try {
      final PreparedComposition prepared = await DeclarationPass.prepare(
        composition,
        videoBackend: FfmpegVideoBackend.findOnPath(),
        projectPath: widget.projectPath ?? Directory.current.path,
      );
      if (!mounted || !identical(widget.composition, composition)) {
        await prepared.dispose();
        return;
      }
      _disposeRenderer();
      setState(() {
        _images = prepared.images;
        _video = prepared.videoFrames;
        _renderer = CompositionRenderer(
          composition,
          images: prepared.images,
          videoFrames: prepared.videoFrames,
        );
        // A composition with video and no ffmpeg previews without it. Saying
        // so beats scrubbing past a silently empty rectangle.
        _videoError = prepared.manifest.video.isNotEmpty &&
                prepared.videoFrames == null
            ? 'ffmpeg not found -- video is not shown'
            : null;
      });
      _requestFrame(_frame);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _images = const <ImageProvider<Object>, ui.Image>{};
        _videoError = '$error'.split('\n').first;
      });
      debugPrint('FlutterMotion: preparing assets failed: $error');
    }
  }

  /// Renders [frame], coalescing anything that arrives mid-render.
  ///
  /// A drag crosses many frames while one is still rasterising, so only the
  /// most recent request is kept: a fast scrub costs one render per settled
  /// position rather than one per frame crossed. Video is advanced first and
  /// awaited, in the same order the exporter uses.
  void _requestFrame(int frame) {
    final CompositionRenderer? renderer = _renderer;
    if (renderer == null) return;
    if (_rendering) {
      _queuedFrame = frame;
      return;
    }
    _rendering = true;
    unawaited(_renderFrame(renderer, frame));
  }

  Future<void> _renderFrame(CompositionRenderer renderer, int frame) async {
    try {
      await _video?.advanceTo(frame);
      // Rendering drives the binding's frame loop, which is only legal
      // between frames. This runs from a timer or from an await that may have
      // resumed inside one.
      if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
        await SchedulerBinding.instance.endOfFrame;
      }
      final ui.Image image = await renderer.renderFrame(frame);
      if (!mounted || !identical(renderer, _renderer)) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _image = image;
        _renderError = null;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _renderError = '$error'.split('\n').first);
      }
    } finally {
      _rendering = false;
      final int? queued = _queuedFrame;
      _queuedFrame = null;
      if (queued != null && queued != frame && mounted) {
        _requestFrame(queued);
      }
    }
  }

  Future<void> _startExport() async {
    if (_exporting) return;
    _pause();

    final Composition composition = widget.composition;
    final ExportCancellation cancellation = ExportCancellation();
    final String path = widget.exportPathBuilder?.call(composition) ??
        '${Directory.systemTemp.path}/${composition.id}.mp4';

    setState(() {
      _exportCancellation = cancellation;
      _exportResult = null;
      _exportError = null;
      _exportProgress = ExportProgress(
        frame: 0,
        totalFrames: composition.durationInFrames,
        elapsed: Duration.zero,
      );
    });

    try {
      final ExportResult result = await InAppExporter.export(
        composition: composition,
        encoder: widget.encoderFactory!(),
        outputPath: path,
        cancellation: cancellation,
        videoBackend: FfmpegVideoBackend.findOnPath(),
        projectPath: widget.projectPath ?? Directory.current.path,
        onProgress: (ExportProgress progress) {
          if (!mounted) return;
          setState(() => _exportProgress = progress);
        },
      );
      if (!mounted) return;
      setState(() {
        _exportProgress = null;
        _exportCancellation = null;
        _exportResult = result;
      });
    } on ExportCancelled {
      if (!mounted) return;
      // Cancelling is a decision, not a failure -- just close the panel.
      setState(() {
        _exportProgress = null;
        _exportCancellation = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _exportProgress = null;
        _exportCancellation = null;
        _exportError = '$error';
      });
    }
  }

  void _disposeVideo() {
    final VideoFrames? video = _video;
    _video = null;
    _queuedFrame = null;
    video?.dispose();
  }

  void _disposeRenderer() {
    _renderer?.dispose();
    _renderer = null;
    _image?.dispose();
    _image = null;
  }

  @override
  void dispose() {
    _playTimer?.cancel();
    _disposeVideo();
    _disposeRenderer();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTick() {
    final int duration = widget.composition.durationInFrames;
    final double elapsedFrames =
        _clock.elapsedMicroseconds / 1e6 * widget.composition.fps;
    double next = _playheadAtPlay + elapsedFrames;

    // Wrap at the duration, not at the last frame: a 120-frame composition
    // runs 0..119, so anything at or past 120 belongs to the next pass.
    if (next >= duration) {
      if (_loop) {
        next %= duration;
        // Rebase rather than letting the stopwatch grow without bound.
        _playheadAtPlay = next;
        _clock
          ..reset()
          ..start();
      } else {
        next = _lastFrame.toDouble();
        _pause();
      }
    }
    _playhead = next;
    final int rounded = next.floor().clamp(0, _lastFrame);
    if (rounded != _frame) {
      setState(() => _frame = rounded);
      _requestFrame(rounded);
    }
  }

  void _play() {
    if (_playing) return;
    // Restarting from the end should replay, not sit still.
    if (_frame >= _lastFrame) {
      _playhead = 0;
      _frame = 0;
    }
    _playheadAtPlay = _playhead;
    _clock
      ..reset()
      ..start();
    // Polled far faster than a frame so the playhead lands exactly on each
    // one rather than up to a poll late. Each tick is a subtraction and only
    // calls setState when the frame actually changes, and rendering is
    // coalesced on top of that, so the rate costs nothing worth saving.
    _playTimer =
        Timer.periodic(const Duration(milliseconds: 1), (Timer _) => _onTick());
    setState(() => _playing = true);
    _requestFrame(_frame);
  }

  void _pause() {
    if (!_playing) return;
    _playTimer?.cancel();
    _playTimer = null;
    _clock.stop();
    setState(() => _playing = false);
  }

  void _togglePlay() => _playing ? _pause() : _play();

  void _seek(int frame) {
    final int clamped = frame.clamp(0, _lastFrame);
    _playhead = clamped.toDouble();
    if (clamped != _frame) {
      setState(() => _frame = clamped);
      // Scrubbing backwards restarts the decoder, which is the one expensive
      // path -- coalescing in _requestFrame keeps a fast drag to one restart
      // per settled position rather than one per frame crossed.
      _requestFrame(clamped);
    }
  }

  void _step(int delta) {
    _pause();
    _seek(_frame + delta);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final bool shift = HardwareKeyboard.instance.isShiftPressed;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _togglePlay();
      case LogicalKeyboardKey.arrowLeft:
        _step(shift ? -10 : -1);
      case LogicalKeyboardKey.arrowRight:
        _step(shift ? 10 : 1);
      case LogicalKeyboardKey.home:
        _step(-_lastFrame - 1);
      case LogicalKeyboardKey.end:
        _step(_lastFrame + 1);
      case LogicalKeyboardKey.keyL:
        setState(() => _loop = !_loop);
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final Composition c = widget.composition;
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GestureDetector(
        // Clicking the canvas returns keyboard focus after any chrome
        // interaction, so space keeps working.
        onTap: _focusNode.requestFocus,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _Canvas(
                composition: c,
                image: _image,
                preparing: _images == null,
                videoError: _renderError ?? _videoError,
                exportPanel: ExportPanel(
                  progress: _exportProgress,
                  result: _exportResult,
                  error: _exportError,
                  onCancel: () => _exportCancellation?.cancel(),
                  onDismiss: () => setState(() {
                    _exportResult = null;
                    _exportError = null;
                  }),
                ),
              ),
            ),
            _transport(c),
          ],
        ),
      ),
    );
  }

  Widget _transport(Composition c) {
    return Container(
      decoration: const BoxDecoration(
        color: PreviewColors.chrome,
        border: Border(top: BorderSide(color: PreviewColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Column(
        children: <Widget>[
          Scrubber(
            frame: _frame,
            durationInFrames: c.durationInFrames,
            fps: c.fps,
            onSeek: _seek,
            onScrubStart: () {
              _wasPlayingBeforeScrub = _playing;
              _pause();
            },
            onScrubEnd: () {
              if (_wasPlayingBeforeScrub) _play();
            },
          ),
          const SizedBox(height: 6),
          // The transport has to survive a narrow window: drop the readouts
          // before the controls, and never let the row overflow.
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool showChips = constraints.maxWidth >= 620;
              final bool showTimecode = constraints.maxWidth >= 480;
              return Row(
                children: <Widget>[
                  TransportButton(
                    icon: TransportIcon.toStart,
                    onPressed: () => _step(-_lastFrame - 1),
                  ),
                  TransportButton(
                    icon: TransportIcon.stepBack,
                    onPressed: () => _step(-1),
                  ),
                  TransportButton(
                    icon: _playing ? TransportIcon.pause : TransportIcon.play,
                    onPressed: _togglePlay,
                    size: 34,
                  ),
                  TransportButton(
                    icon: TransportIcon.stepForward,
                    onPressed: () => _step(1),
                  ),
                  TransportButton(
                    icon: TransportIcon.toEnd,
                    onPressed: () => _step(_lastFrame + 1),
                  ),
                  const SizedBox(width: 8),
                  TransportButton(
                    icon: TransportIcon.loop,
                    active: _loop,
                    onPressed: () => setState(() => _loop = !_loop),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      '${_frame.toString().padLeft(4)} / ${c.durationInFrames}',
                      style: PreviewText.mono,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                    ),
                  ),
                  if (showTimecode) ...<Widget>[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${formatTimecode(_frame, c.fps)} / '
                        '${formatTimecode(c.durationInFrames, c.fps)}',
                        style: PreviewText.monoDim,
                        overflow: TextOverflow.clip,
                        softWrap: false,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (showChips) ...<Widget>[
                    InfoChip(label: '${c.width}x${c.height}', dim: true),
                    const SizedBox(width: 6),
                    InfoChip(label: '${c.fps} fps', dim: true),
                  ],
                  if (widget.encoderFactory != null) ...<Widget>[
                    const SizedBox(width: 10),
                    PreviewButton(
                      label: _exporting ? 'Exporting' : 'Export',
                      primary: true,
                      onPressed: _exporting ? null : _startExport,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Lays the composition out at its real size, then scales the whole thing to
/// fit. Layout inside is therefore identical to the exporter's -- a 1080-wide
/// composition is laid out at 1080 even in a 600px window.
class _Canvas extends StatelessWidget {
  const _Canvas({
    required this.composition,
    required this.image,
    required this.preparing,
    required this.videoError,
    required this.exportPanel,
  });

  final Composition composition;

  /// The most recently rasterised frame, or null before the first one lands.
  final ui.Image? image;

  /// True until the declaration pass has finished.
  final bool preparing;

  /// Set when a frame could not be prepared or rasterised, so the canvas can
  /// say so rather than showing an unexplained gap.
  final String? videoError;

  /// Drawn over the composition, so an export cannot be mistaken for the
  /// frame itself.
  final Widget exportPanel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PreviewColors.canvas,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          const double padding = 24;
          final double availableWidth =
              math.max(1, constraints.maxWidth - padding * 2);
          final double availableHeight =
              math.max(1, constraints.maxHeight - padding * 2);
          final double scale = math.min(
            availableWidth / composition.width,
            availableHeight / composition.height,
          );

          return Stack(
            children: <Widget>[
              Center(
                child: SizedBox(
                  width: composition.width * scale,
                  height: composition.height * scale,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFF000000),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: Color(0x99000000), blurRadius: 32),
                      ],
                    ),
                    // Rasterised by the same renderer the exporter uses, so
                    // this is the exported frame, not a second rendering of
                    // the same widgets.
                    child: image == null
                        ? const SizedBox.expand()
                        : RawImage(image: image, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Row(
                  children: <Widget>[
                    if (preparing) ...<Widget>[
                      const InfoChip(label: 'preparing assets', dim: true),
                      const SizedBox(width: 6),
                    ],
                    if (videoError != null) ...<Widget>[
                      InfoChip(label: videoError!, dim: true),
                      const SizedBox(width: 6),
                    ],
                    InfoChip(label: '${(scale * 100).round()}%', dim: true),
                  ],
                ),
              ),
              exportPanel,
            ],
          );
        },
      ),
    );
  }
}
