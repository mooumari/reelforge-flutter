import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';
import 'package:fluttermotion_schema/fluttermotion_schema.dart';

import 'motion_scope.dart';
import 'node.dart';
import 'nodes/kit.dart';
import 'nodes/layout.dart';
import 'nodes/media.dart';
import 'values.dart';

bool _registered = false;

void ensureBuildersRegistered() {
  if (_registered) return;
  _registered = true;
  registerLayoutBuilders();
  registerMediaBuilders();
  registerKitBuilders();
}

/// A composition described in JSON.
///
/// The document itself -- its shape, its vocabulary, and everything that can
/// be wrong with it -- is `fluttermotion_schema`'s [DocumentSpec], which needs
/// no Flutter. This adds the half that does: palettes, curves, widgets and a
/// [Composition] to render.
class MotionDocument {
  MotionDocument._(this.spec);

  /// The parsed document, as data.
  final DocumentSpec spec;

  String get id => spec.id;
  int get width => spec.width;
  int get height => spec.height;
  int get fps => spec.fps;
  int get durationInFrames => spec.durationInFrames;

  late final MotionPalette palette = _palette(spec.theme);
  late final MotionTypography typography = _typography(spec.theme);

  /// Parses [source], which may be a JSON string or already-decoded JSON.
  ///
  /// Throws [SchemaException] carrying *every* problem found, not the first.
  /// A document with four mistakes should take one round trip to fix, not
  /// four.
  static MotionDocument parse(Object? source) {
    ensureBuildersRegistered();
    return MotionDocument._(DocumentSpec.parse(source));
  }

  /// Everything wrong with [source], without building anything.
  ///
  /// A straight pass-through to [DocumentSpec.problemsIn], which is pure Dart:
  /// checking a document needs neither this class nor a Flutter binding.
  static List<SchemaProblem> problemsIn(Object? source) =>
      DocumentSpec.problemsIn(source);

  /// A [Composition] ready to render, filled from [data].
  Composition toComposition({
    Map<String, Object?> data = const <String, Object?>{},
  }) {
    return Composition(
      id: id,
      width: width,
      height: height,
      fps: fps,
      durationInFrames: durationInFrames,
      wrapper: (BuildContext context, Widget child) => MotionSurface(
        palette: palette,
        typography: typography,
        child: MotionScope(
          scope: DataScope(data: data),
          child: child,
        ),
      ),
      builder: build,
    );
  }

  /// The widget tree, below the wrapper [toComposition] provides.
  Widget build(BuildContext context) {
    final MotionNode? root = spec.root;
    if (root != null) return root.buildDirect(context);
    return Storyboard(
      transition: sceneTransition(spec.defaultTransition),
      bed: spec.bed?.widget(),
      scenes: <Scene>[
        for (final SceneSpec scene in spec.scenes)
          Scene(
            frames: scene.frames,
            transition: scene.transition == null
                ? null
                : sceneTransition(scene.transition!),
            sting: scene.sting?.widget(),
            builder: scene.child.buildDirect,
          ),
      ],
    );
  }
}

/// The kit transition a [TransitionSpec] names.
///
/// Every number comes off the spec, which filled its own defaults at parse
/// time -- nothing is invented here.
SceneTransition sceneTransition(TransitionSpec spec) => switch (spec.type) {
  'none' => const SceneTransition.none(),
  'slide' => SceneTransition.slide(
    frames: spec.frames,
    offset: Offset(spec.x, spec.y),
    curve: namedCurves[spec.curve] ?? Curves.linear,
    fade: spec.fade,
  ),
  'scale' => SceneTransition.scale(
    frames: spec.frames,
    scale: spec.scale,
    curve: namedCurves[spec.curve] ?? Curves.linear,
    fade: spec.fade,
  ),
  _ => SceneTransition.fade(frames: spec.frames),
};

MotionPalette _palette(ThemeSpec theme) {
  MotionPalette palette = basePalette(theme.base);
  if (theme.roles.isEmpty) return palette;
  Color? role(String name) {
    final int? hex = theme.roles[name];
    return hex == null ? null : Color(hex);
  }

  return palette = palette.copyWith(
    background: role('background'),
    foreground: role('foreground'),
    muted: role('muted'),
    accent: role('accent'),
    warning: role('warning'),
    surface: role('surface'),
    outline: role('outline'),
  );
}

MotionTypography _typography(ThemeSpec theme) =>
    const MotionTypography().copyWith(
      fontFamily: theme.fontFamily,
      scale: theme.scale,
      display: theme.sizes['display'],
      headline: theme.sizes['headline'],
      title: theme.sizes['title'],
      body: theme.sizes['body'],
      label: theme.sizes['label'],
      caption: theme.sizes['caption'],
      statistic: theme.sizes['statistic'],
    );
