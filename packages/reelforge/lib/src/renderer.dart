import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'animation/frame_clock.dart';
import 'animation/ticker_gate.dart';
import 'composition.dart';
import 'declarations/assets.dart';
import 'declarations/scope.dart';
import 'media/video_store.dart';
import 'frame.dart';

/// Rasterises a [Composition] frame by frame, off screen.
///
/// The tree lives in its own [PipelineOwner] and [BuildOwner], detached from
/// the binding's view. Nothing here is driven by the engine's frame loop --
/// [pump] is a synchronous build + layout + paint, so frame `n` depends on
/// nothing but `n`.
class CompositionRenderer {
  CompositionRenderer(
    this.composition, {
    this.scale = 1.0,
    this.collector,
    this.videoFrames,
    this.driveAnimationClock = true,
    Map<ImageProvider<Object>, ui.Image>? images,
  })  : images = images ?? const <ImageProvider<Object>, ui.Image>{},
        _clock = FrameClock(fps: composition.fps) {
    final Size size = composition.size;

    _renderView = RenderView(
      view: ui.PlatformDispatcher.instance.implicitView!,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size * scale),
        devicePixelRatio: scale,
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
          data: MediaQueryData(size: size, devicePixelRatio: scale),
          // The RepaintBoundary must be the outermost RenderObject so it can
          // be reached via _renderView.child -- GlobalKey.currentContext
          // resolves against the *binding's* BuildOwner, not ours, and is
          // therefore useless in a detached tree.
          child: RepaintBoundary(
            child: DeclarationScope(
              collector: collector,
              child: ResolvedImages(
                images: this.images,
                child: DecodedVideoFrames(
                  frames: videoFrames,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _frame,
                    builder: (BuildContext context, int frame, _) =>
                        VideoFrame(
                      frame: frame,
                      fps: composition.fps,
                      durationInFrames: composition.durationInFrames,
                      width: composition.width,
                      height: composition.height,
                      child: _gate.wrap(
                        Builder(builder: composition.buildContent),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).attachToRenderTree(_buildOwner);

    // Building the tree creates its tickers, and a ticker anchors its zero on
    // whichever frame reaches it first. In a live app the engine is still
    // delivering real frames, and one of those arriving before the first pump
    // would anchor the whole composition at wall-clock time. So the gate is
    // shut the moment there is anything behind it.
    _gate.close();
  }

  final Composition composition;

  /// Output pixel scale. `1.0` renders at the composition's exact size.
  final double scale;

  /// Set during a declaration pass so declaring widgets can register
  /// themselves. Null while rasterising.
  final DeclarationCollector? collector;

  /// Images already decoded by the preloader.
  final Map<ImageProvider<Object>, ui.Image> images;

  /// Video frames for the frame currently being rendered. The caller must
  /// have awaited [VideoFrames.advanceTo] for that frame before pumping.
  final VideoFrames? videoFrames;

  /// Whether to slave Flutter's animation clock to the frame being rendered,
  /// so that widgets animating on their own [Ticker] are deterministic.
  final bool driveAnimationClock;

  final FrameClock _clock;
  final TickerGate _gate = TickerGate();
  bool _primed = false;

  final ValueNotifier<int> _frame = ValueNotifier<int>(-1);

  late final RenderView _renderView;
  late final PipelineOwner _pipelineOwner;
  late final BuildOwner _buildOwner;
  late final RenderObjectToWidgetElement<RenderBox> _element;

  bool _disposed = false;

  RenderRepaintBoundary get _boundary =>
      _renderView.child! as RenderRepaintBoundary;

  /// Plays the timeline up to [frame] without painting, once, before the
  /// first real render.
  ///
  /// A [Ticker] treats its *first* tick as elapsed zero. A renderer that
  /// enters the timeline half way through would therefore start every
  /// animation over, which is exactly the shard boundary bug and is close to
  /// invisible -- video that is one animation out still looks like video. It
  /// is not enough to mount at frame 0 either: a widget inside a [Sequence]
  /// mounts when the sequence says so, and its ticker has to anchor *there*.
  ///
  /// So the tree is walked forward the way a play-through would walk it, which
  /// anchors every ticker at the frame it really mounts on. This is the same
  /// sweep the declaration pass already performs over the whole timeline, and
  /// it stops at [frame] rather than the end, so it is strictly cheaper than a
  /// pass that has already been paid for. Determinism is untouched: the sweep
  /// always starts at zero, so frame `n` is still the same everywhere.
  void _primeTo(int frame) {
    if (_primed) return;
    _primed = true;
    if (!driveAnimationClock) return;
    // Up to, not including: the caller drives [frame] itself. Driving it
    // twice would settle a post-frame callback a frame earlier than a
    // play-through does, which is precisely the divergence being closed.
    for (int f = 0; f < frame; f++) {
      _gate.open();
      _clock.driveTo(f);
      _frame.value = f;
      _buildOwner.buildScope(_element);
      _buildOwner.finalizeTree();
      _pipelineOwner.flushLayout();
      _gate.close();
    }
  }

  /// Build, lay out, and paint [frame]. Synchronous and cheap (~0.5 ms even
  /// for a busy composition); rasterisation is the expensive half.
  void pump(int frame) {
    assert(!_disposed, 'CompositionRenderer used after dispose().');
    _primeTo(frame);
    if (driveAnimationClock) {
      _gate.open();
      _clock.driveTo(frame);
    }
    _frame.value = frame;
    _buildOwner.buildScope(_element);
    _buildOwner.finalizeTree();
    _pipelineOwner.flushLayout();
    _pipelineOwner.flushCompositingBits();
    _pipelineOwner.flushPaint();
    // Closed *after* painting, not after driving: the tree is only settled
    // once layout and paint have run, and the engine gets no chance to
    // interleave a frame of its own in between.
    _gate.close();
  }

  /// Builds and lays out [frame] without painting it.
  ///
  /// Used by the declaration pass, which only needs to know which widgets are
  /// mounted. Layout still runs, because widgets under a [LayoutBuilder] would
  /// otherwise never build and their declarations would be missed.
  void pumpWithoutPaint(int frame) {
    assert(!_disposed, 'CompositionRenderer used after dispose().');
    _primeTo(frame);
    if (driveAnimationClock) {
      _gate.open();
      _clock.driveTo(frame);
    }
    _frame.value = frame;
    _buildOwner.buildScope(_element);
    _buildOwner.finalizeTree();
    _pipelineOwner.flushLayout();
    _gate.close();
  }

  /// Rasterises [frame]. The caller owns the returned image and must dispose
  /// it.
  Future<ui.Image> renderFrame(int frame) {
    pump(frame);
    return _boundary.toImage(pixelRatio: scale);
  }

  /// Rasterises [frame] as raw RGBA, ready to hand to an encoder.
  Future<ByteData> renderFrameRgba(int frame) async {
    final ui.Image image = await renderFrame(frame);
    try {
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) {
        throw StateError('Rasterisation of frame $frame produced no bytes.');
      }
      return data;
    } finally {
      image.dispose();
    }
  }

  /// Rasterises [frame] as PNG.
  Future<ByteData> renderFramePng(int frame) async {
    final ui.Image image = await renderFrame(frame);
    try {
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('PNG encoding of frame $frame produced no bytes.');
      }
      return data;
    } finally {
      image.dispose();
    }
  }

  /// Rebuilds the whole tree after a hot reload.
  ///
  /// A detached tree has its own [BuildOwner], which the binding knows nothing
  /// about and therefore never reassembles. Without this a preview would keep
  /// drawing the code that was running when it started.
  void reassemble() {
    assert(!_disposed, 'CompositionRenderer used after dispose().');
    _buildOwner.reassemble(_element);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Take the tree apart the way the framework does: hand the root adapter a
    // null child and let an ordinary rebuild do the removal. That routes every
    // element through deactivateChild and finalizeTree, which is the only path
    // that runs State.dispose -- an AnimationController inside a composition is
    // released here or not at all.
    //
    // Calling _element.deactivate() directly, which is what this used to do,
    // deactivates the root and nothing below it: the subtree is never added to
    // the inactive list, so finalizeTree finds nothing to unmount.
    RenderObjectToWidgetAdapter<RenderBox>(
      container: _renderView,
    ).attachToRenderTree(_buildOwner, _element);
    _buildOwner.buildScope(_element);
    _buildOwner.finalizeTree();
    // Only now: unmounting a RenderObjectElement detaches its render object,
    // so the render tree has to outlive the widgets that point into it.
    _pipelineOwner.rootNode = null;
    _pipelineOwner.dispose();
    _frame.dispose();
  }
}
