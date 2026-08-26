import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../composition.dart';
import '../declarations/assets.dart';
import '../declarations/pass.dart';
import '../export/encoder.dart';
import '../export/exporter.dart';
import '../frame.dart';
import '../media/ffmpeg_paths.dart';
import '../media/video_store.dart';
import 'controls.dart';
import 'export_panel.dart';
import 'scrubber.dart';
import 'theme.dart';

/// Plays a [Composition] with a scrubbable timeline.
///
/// The preview builds the *same* widget tree the exporter rasterises, wrapped
/// in the same [VideoFrame] and laid out at the composition's true size, then
/// scaled to fit. What you scrub to is what renders.
///
/// Wall-clock time is used in exactly one place: choosing which frame the
/// playhead is on. The composition itself never sees it.
class CompositionPlayer extends StatefulWidget {
  const CompositionPlayer({
    super.key,
    required this.composition,
    this.projectPath,
    this.encoderFactory,
    this.exportPathBuilder,
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

  @override
  State<CompositionPlayer> createState() => _CompositionPlayerState();
}

class _CompositionPlayerState extends State<CompositionPlayer>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  final FocusNode _focusNode = FocusNode();

  int _frame = 0;
  double _playhead = 0;
  Duration? _lastTick;
  bool _playing = false;
  bool _loop = true;
  bool _wasPlayingBeforeScrub = false;

  Map<ImageProvider<Object>, ui.Image>? _images;
  VideoFrames? _video;

  /// Video decodes asynchronously while the playhead moves on. Rather than
  /// queueing every frame the scrubber passes over -- a decoder is one pipe and
  /// cannot serve two reads at once -- only the most recent request is kept.
  ExportProgress? _exportProgress;
  ExportResult? _exportResult;
  String? _exportError;
  ExportCancellation? _exportCancellation;

  bool get _exporting => _exportCancellation != null;

  bool _decoding = false;
  int? _queuedFrame;
  String? _videoError;

  int get _lastFrame => widget.composition.durationInFrames - 1;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _prepare();
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
      setState(() {
        _images = null;
        _videoError = null;
      });
      _prepare();
    }
  }

  /// Sweep the timeline and decode assets, exactly as the exporter does, so
  /// the preview cannot show something the render would not.
  Future<void> _prepare() async {
    final Composition composition = widget.composition;
    final String? ffmpeg = FfmpegPaths.find('ffmpeg');
    final String? ffprobe = FfmpegPaths.find('ffprobe');

    try {
      final PreparedComposition prepared = await DeclarationPass.prepare(
        composition,
        ffmpeg: ffmpeg,
        ffprobe: ffprobe,
        projectPath: widget.projectPath ?? Directory.current.path,
      );
      if (!mounted || !identical(widget.composition, composition)) {
        await prepared.dispose();
        return;
      }
      setState(() {
        _images = prepared.images;
        _video = prepared.videoFrames;
        // A composition with video and no ffmpeg previews without it. Saying
        // so beats scrubbing past a silently empty rectangle.
        _videoError = prepared.manifest.video.isNotEmpty &&
                prepared.videoFrames == null
            ? 'ffmpeg not found -- video is not shown'
            : null;
      });
      _requestVideo(_frame);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _images = const <ImageProvider<Object>, ui.Image>{};
        _videoError = '$error'.split('\n').first;
      });
      debugPrint('FlutterMotion: preparing assets failed: $error');
    }
  }

  /// Decodes [frame]'s video, coalescing anything that arrives mid-decode.
  void _requestVideo(int frame) {
    final VideoFrames? video = _video;
    if (video == null || video.isEmpty) return;
    if (_decoding) {
      _queuedFrame = frame;
      return;
    }
    _decoding = true;
    video.advanceTo(frame).then((_) {
      _decoding = false;
      if (!mounted) return;
      setState(() {});
      final int? queued = _queuedFrame;
      _queuedFrame = null;
      if (queued != null && queued != frame) _requestVideo(queued);
    }).catchError((Object error) {
      _decoding = false;
      if (!mounted) return;
      setState(() => _videoError = '$error'.split('\n').first);
    });
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
        ffmpeg: FfmpegPaths.find('ffmpeg'),
        ffprobe: FfmpegPaths.find('ffprobe'),
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

  @override
  void dispose() {
    _disposeVideo();
    _ticker.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final Duration last = _lastTick ?? elapsed;
    _lastTick = elapsed;
    final double dt = (elapsed - last).inMicroseconds / 1e6;

    final int duration = widget.composition.durationInFrames;
    double next = _playhead + dt * widget.composition.fps;
    // Wrap at the duration, not at the last frame: a 120-frame composition
    // runs 0..119, so anything at or past 120 belongs to the next pass.
    // Comparing against _lastFrame left the playhead parked on the final
    // frame for an extra tick before wrapping.
    if (next >= duration) {
      if (_loop) {
        next = next % duration;
      } else {
        next = _lastFrame.toDouble();
        _pause();
      }
    }
    _playhead = next;
    final int rounded = next.floor().clamp(0, _lastFrame);
    if (rounded != _frame) {
      setState(() => _frame = rounded);
      _requestVideo(rounded);
    }
  }

  void _play() {
    if (_playing) return;
    // Restarting from the end should replay, not sit still.
    if (_frame >= _lastFrame) {
      _playhead = 0;
      _frame = 0;
    }
    _lastTick = null;
    _ticker.start();
    setState(() => _playing = true);
  }

  void _pause() {
    if (!_playing) return;
    _ticker.stop();
    _lastTick = null;
    setState(() => _playing = false);
  }

  void _togglePlay() => _playing ? _pause() : _play();

  void _seek(int frame) {
    final int clamped = frame.clamp(0, _lastFrame);
    _playhead = clamped.toDouble();
    if (clamped != _frame) {
      setState(() => _frame = clamped);
      // Scrubbing backwards restarts the decoder, which is the one expensive
      // path -- coalescing in _requestVideo keeps a fast drag to one restart
      // per settled position rather than one per frame crossed.
      _requestVideo(clamped);
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
                frame: _frame,
                images: _images,
                video: _video,
                videoError: _videoError,
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
    required this.frame,
    required this.images,
    required this.video,
    required this.videoError,
    required this.exportPanel,
  });

  final Composition composition;
  final int frame;

  /// Null until the declaration pass finishes. Deliberately not an empty map:
  /// an empty map means "preloaded, and this image genuinely is missing",
  /// which declaring widgets are entitled to treat as an error.
  final Map<ImageProvider<Object>, ui.Image>? images;

  /// Open decoders, or null when the composition has no video.
  final VideoFrames? video;

  /// Set when video could not be prepared, so the canvas can say so rather
  /// than showing an unexplained gap.
  final String? videoError;

  /// Drawn over the composition, so an export cannot be mistaken for the
  /// frame itself.
  final Widget exportPanel;

  /// The composition, wrapped in whatever has been prepared for it.
  Widget _content() {
    Widget child = Builder(builder: composition.builder);
    if (video != null) {
      child = DecodedVideoFrames(frames: video, child: child);
    }
    if (images != null) {
      child = ResolvedImages(images: images!, child: child);
    }
    return child;
  }

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
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: Color(0x99000000), blurRadius: 32),
                      ],
                    ),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: composition.width.toDouble(),
                        height: composition.height.toDouble(),
                        child: MediaQuery(
                          data: MediaQueryData(
                            size: composition.size,
                            devicePixelRatio: 1,
                          ),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: VideoFrame(
                              frame: frame,
                              fps: composition.fps,
                              durationInFrames: composition.durationInFrames,
                              width: composition.width,
                              height: composition.height,
                              child: _content(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Row(
                  children: <Widget>[
                    if (images == null) ...<Widget>[
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
