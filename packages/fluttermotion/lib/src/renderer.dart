import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

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
    Map<ImageProvider<Object>, ui.Image>? images,
  }) : images = images ?? const <ImageProvider<Object>, ui.Image>{} {
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
                      child: Builder(builder: composition.builder),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ).attachToRenderTree(_buildOwner);
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

  final ValueNotifier<int> _frame = ValueNotifier<int>(-1);

  late final RenderView _renderView;
  late final PipelineOwner _pipelineOwner;
  late final BuildOwner _buildOwner;
  late final RenderObjectToWidgetElement<RenderBox> _element;

  bool _disposed = false;

  RenderRepaintBoundary get _boundary =>
      _renderView.child! as RenderRepaintBoundary;

  /// Build, lay out, and paint [frame]. Synchronous and cheap (~0.5 ms even
  /// for a busy composition); rasterisation is the expensive half.
  void pump(int frame) {
    assert(!_disposed, 'CompositionRenderer used after dispose().');
    _frame.value = frame;
    _buildOwner.buildScope(_element);
    _buildOwner.finalizeTree();
    _pipelineOwner.flushLayout();
    _pipelineOwner.flushCompositingBits();
    _pipelineOwner.flushPaint();
  }

  /// Builds and lays out [frame] without painting it.
  ///
  /// Used by the declaration pass, which only needs to know which widgets are
  /// mounted. Layout still runs, because widgets under a [LayoutBuilder] would
  /// otherwise never build and their declarations would be missed.
  void pumpWithoutPaint(int frame) {
    assert(!_disposed, 'CompositionRenderer used after dispose().');
    _frame.value = frame;
    _buildOwner.buildScope(_element);
    _buildOwner.finalizeTree();
    _pipelineOwner.flushLayout();
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

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Order matters: clearing rootNode detaches the RenderView, which
    // RenderObjectElement.deactivate asserts on.
    _pipelineOwner.rootNode = null;
    _element.deactivate();
    _buildOwner.finalizeTree();
    _pipelineOwner.dispose();
    _frame.dispose();
  }
}
