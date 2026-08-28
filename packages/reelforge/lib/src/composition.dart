import 'package:flutter/widgets.dart';

/// A video composition: a deterministic function of frame number.
///
/// A composition is *not* a running animation. Frame `n` must always produce
/// the same pixels, whether it is reached by playing forward, scrubbing
/// backward, or rendering in isolation on another machine.
@immutable
class Composition {
  const Composition({
    required this.id,
    required this.width,
    required this.height,
    required this.fps,
    required this.durationInFrames,
    required this.builder,
    this.wrapper,
  })  : assert(width > 0 && height > 0),
        assert(fps > 0),
        assert(durationInFrames > 0);

  /// Stable identifier used to address this composition from the CLI.
  final String id;

  final int width;
  final int height;
  final int fps;
  final int durationInFrames;

  /// Builds the frame. Read the current frame with [Video.frame].
  final WidgetBuilder builder;

  /// Wraps the composition in whatever inherited widgets its content expects.
  ///
  /// A widget lifted out of a real app is usually written against that app's
  /// ambient state -- `Theme.of`, a `Provider`, `Localizations`. A composition
  /// renders in a detached tree that has none of it, and the failure is quiet:
  /// `Theme.of` returns a fallback rather than throwing, so the card renders in
  /// stock Material purple instead of your brand colour and nothing says a
  /// word.
  ///
  /// ```dart
  /// Composition(
  ///   // ...
  ///   wrapper: (BuildContext context, Widget child) =>
  ///       Theme(data: myAppTheme, child: child),
  ///   builder: (BuildContext context) => const ProductCard(),
  /// )
  /// ```
  ///
  /// The wrapper sits inside [Video.frame]'s scope, so it may read the frame.
  final Widget Function(BuildContext context, Widget child)? wrapper;

  /// The composition's content, wrapped as [wrapper] asks.
  ///
  /// Both the renderer and the preview build through here, so there is no way
  /// for one to apply the wrapper and the other to forget.
  Widget buildContent(BuildContext context) {
    final Widget child = Builder(builder: builder);
    return wrapper?.call(context, child) ?? child;
  }

  Size get size => Size(width.toDouble(), height.toDouble());

  Duration get duration =>
      Duration(microseconds: (durationInFrames * 1000000) ~/ fps);

  Composition copyWith({
    int? width,
    int? height,
    int? fps,
    int? durationInFrames,
  }) {
    return Composition(
      id: id,
      width: width ?? this.width,
      height: height ?? this.height,
      fps: fps ?? this.fps,
      durationInFrames: durationInFrames ?? this.durationInFrames,
      builder: builder,
      wrapper: wrapper,
    );
  }

  @override
  String toString() =>
      'Composition($id, ${width}x$height @${fps}fps, $durationInFrames frames)';
}
