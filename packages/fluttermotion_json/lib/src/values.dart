import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';
import 'package:fluttermotion_schema/fluttermotion_schema.dart';

import 'motion_scope.dart';

/// What every name in the document format actually means, and how a stored
/// value becomes a number, a colour or a curve on a given frame.
///
/// The names themselves live in `fluttermotion_schema`, which has no Flutter
/// in it. Each table here has to cover exactly the matching name set, and
/// `test/vocabulary_test.dart` fails if it does not -- a curve accepted by the
/// validator with nothing to build from it would otherwise be a document that
/// passes `validate` and renders wrong.

// ---------------------------------------------------------------------------
// Name tables
// ---------------------------------------------------------------------------

/// Curves a document may name. Covers [curveNames].
const Map<String, Curve> namedCurves = <String, Curve>{
  'linear': Curves.linear,
  'ease': Curves.ease,
  'easeIn': Curves.easeIn,
  'easeOut': Curves.easeOut,
  'easeInOut': Curves.easeInOut,
  'inQuad': Curves.easeInQuad,
  'outQuad': Curves.easeOutQuad,
  'inOutQuad': Curves.easeInOutQuad,
  'inCubic': Curves.easeInCubic,
  'outCubic': Curves.easeOutCubic,
  'inOutCubic': Curves.easeInOutCubic,
  'inQuart': Curves.easeInQuart,
  'outQuart': Curves.easeOutQuart,
  'inOutQuart': Curves.easeInOutQuart,
  'inExpo': Curves.easeInExpo,
  'outExpo': Curves.easeOutExpo,
  'inOutExpo': Curves.easeInOutExpo,
  'inCirc': Curves.easeInCirc,
  'outCirc': Curves.easeOutCirc,
  'inBack': Curves.easeInBack,
  'outBack': Curves.easeOutBack,
  'inOutBack': Curves.easeInOutBack,
  'outElastic': Curves.elasticOut,
  'outBounce': Curves.bounceOut,
};

/// Covers [alignmentNames].
const Map<String, Alignment> namedAlignments = <String, Alignment>{
  'topLeft': Alignment.topLeft,
  'topCenter': Alignment.topCenter,
  'topRight': Alignment.topRight,
  'centerLeft': Alignment.centerLeft,
  'center': Alignment.center,
  'centerRight': Alignment.centerRight,
  'bottomLeft': Alignment.bottomLeft,
  'bottomCenter': Alignment.bottomCenter,
  'bottomRight': Alignment.bottomRight,
};

/// Covers [fitNames].
const Map<String, BoxFit> namedFits = <String, BoxFit>{
  'cover': BoxFit.cover,
  'contain': BoxFit.contain,
  'fill': BoxFit.fill,
  'fitWidth': BoxFit.fitWidth,
  'fitHeight': BoxFit.fitHeight,
  'none': BoxFit.none,
  'scaleDown': BoxFit.scaleDown,
};

/// Covers [mainAxisNames].
const Map<String, MainAxisAlignment> namedMainAxis =
    <String, MainAxisAlignment>{
      'start': MainAxisAlignment.start,
      'end': MainAxisAlignment.end,
      'center': MainAxisAlignment.center,
      'spaceBetween': MainAxisAlignment.spaceBetween,
      'spaceAround': MainAxisAlignment.spaceAround,
      'spaceEvenly': MainAxisAlignment.spaceEvenly,
    };

/// Covers [crossAxisNames].
const Map<String, CrossAxisAlignment> namedCrossAxis =
    <String, CrossAxisAlignment>{
      'start': CrossAxisAlignment.start,
      'end': CrossAxisAlignment.end,
      'center': CrossAxisAlignment.center,
      'stretch': CrossAxisAlignment.stretch,
      'baseline': CrossAxisAlignment.baseline,
    };

/// Covers [kitCrossAxisNames].
const Map<String, CrossAxisAlignment> namedKitCrossAxis =
    <String, CrossAxisAlignment>{
      'start': CrossAxisAlignment.start,
      'end': CrossAxisAlignment.end,
      'center': CrossAxisAlignment.center,
      'stretch': CrossAxisAlignment.stretch,
    };

/// Covers [mainAxisSizeNames].
const Map<String, MainAxisSize> namedMainAxisSize = <String, MainAxisSize>{
  'min': MainAxisSize.min,
  'max': MainAxisSize.max,
};

/// Covers [stackFitNames].
const Map<String, StackFit> namedStackFits = <String, StackFit>{
  'loose': StackFit.loose,
  'expand': StackFit.expand,
  'passthrough': StackFit.passthrough,
};

/// Covers [fontWeightNames].
const Map<String, FontWeight> namedWeights = <String, FontWeight>{
  'thin': FontWeight.w100,
  'light': FontWeight.w300,
  'regular': FontWeight.w400,
  'medium': FontWeight.w500,
  'semibold': FontWeight.w600,
  'bold': FontWeight.w700,
  'black': FontWeight.w900,
};

/// Covers [textAlignNames].
const Map<String, TextAlign> namedTextAligns = <String, TextAlign>{
  'left': TextAlign.left,
  'right': TextAlign.right,
  'center': TextAlign.center,
  'justify': TextAlign.justify,
  'start': TextAlign.start,
  'end': TextAlign.end,
};

/// Covers [axisNames].
const Map<String, Axis> namedAxes = <String, Axis>{
  'horizontal': Axis.horizontal,
  'vertical': Axis.vertical,
};

/// The scaled size for one of [textRoles].
double roleSize(MotionTypography type, String role) => switch (role) {
  'display' => type.displaySize,
  'headline' => type.headlineSize,
  'title' => type.titleSize,
  'label' => type.labelSize,
  'caption' => type.captionSize,
  'statistic' => type.statisticSize,
  _ => type.bodySize,
};

/// The colour a palette gives one of [paletteRoles].
Color roleColour(MotionPalette palette, String name) => switch (name) {
  'background' => palette.background,
  'foreground' => palette.foreground,
  'muted' => palette.muted,
  'accent' => palette.accent,
  'warning' => palette.warning,
  'surface' => palette.surface,
  _ => palette.outline,
};

/// The palette one of [paletteNames] means.
MotionPalette basePalette(String name) =>
    name == 'light' ? MotionPalette.light : MotionPalette.dark;

// ---------------------------------------------------------------------------
// Resolution
// ---------------------------------------------------------------------------

/// The frame an animated value is measured against.
///
/// Local to the enclosing `Sequence` -- so a scene's animations start at zero
/// wherever the scene sits on the timeline -- and offset by any stagger, which
/// is what makes `repeat` inside a `stagger` come in one after another without
/// each item needing its own delay.
int localFrame(BuildContext context) =>
    Video.frame(context) - StaggerDelay.of(context);

/// Evaluates a literal, binding, keyframe or spring spec to a number.
double resolveNumber(
  BuildContext context,
  Object? spec, {
  double fallback = 0,
  DataScope? scope,
}) {
  if (spec == null) return fallback;
  if (spec is num) return spec.toDouble();

  if (spec is String) {
    final Object? bound = fillValue(scope ?? MotionScope.of(context), spec);
    if (bound is num) return bound.toDouble();
    if (bound is String) return double.tryParse(bound) ?? fallback;
    return fallback;
  }

  if (spec is! Map<String, Object?>) return fallback;

  final int frame = localFrame(context);

  final Object? keyframes = spec['keyframes'];
  if (keyframes is List<Object?>) {
    final int delay = (spec['delay'] as num?)?.round() ?? 0;
    final List<num> inputs = <num>[];
    final List<num> outputs = <num>[];
    for (final Object? pair in keyframes) {
      if (pair is List<Object?> && pair.length == 2) {
        inputs.add(pair[0]! as num);
        outputs.add(pair[1]! as num);
      }
    }
    if (inputs.length < 2) return fallback;
    return interpolate(
      frame - delay,
      inputs,
      outputs,
      easing: namedCurves[spec['ease']] ?? Curves.linear,
    );
  }

  final Object? springSpec = spec['spring'];
  if (springSpec is Map<String, Object?>) {
    final int delay = (springSpec['delay'] as num?)?.round() ?? 0;
    return spring(
      frame - delay,
      fps: Video.fps(context),
      from: (springSpec['from'] as num?)?.toDouble() ?? 0,
      to: (springSpec['to'] as num?)?.toDouble() ?? 1,
      mass: (springSpec['mass'] as num?)?.toDouble() ?? 1,
      stiffness: (springSpec['stiffness'] as num?)?.toDouble() ?? 100,
      damping: (springSpec['damping'] as num?)?.toDouble() ?? 10,
      initialVelocity: (springSpec['velocity'] as num?)?.toDouble() ?? 0,
    );
  }

  return fallback;
}

/// Same as [resolveNumber] but preserves "not given" so a widget can keep its
/// own default rather than being handed a zero.
double? resolveOptionalNumber(
  BuildContext context,
  Object? spec, {
  DataScope? scope,
}) => spec == null ? null : resolveNumber(context, spec, scope: scope);

int? resolveOptionalInt(
  BuildContext context,
  Object? spec, {
  DataScope? scope,
}) => spec == null ? null : resolveNumber(context, spec, scope: scope).round();

/// Fills every `{{ }}` in a string.
String resolveString(
  BuildContext context,
  Object? spec, {
  String fallback = '',
  DataScope? scope,
}) {
  if (spec == null) return fallback;
  if (spec is! String) return spec.toString();
  if (!isBinding(spec)) return spec;
  return fillString(scope ?? MotionScope.of(context), spec);
}

String? resolveOptionalString(
  BuildContext context,
  Object? spec, {
  DataScope? scope,
}) => spec == null ? null : resolveString(context, spec, scope: scope);

bool resolveBool(
  BuildContext context,
  Object? spec, {
  bool fallback = false,
  DataScope? scope,
}) {
  if (spec is bool) return spec;
  if (spec is String && isBinding(spec)) {
    final Object? bound = fillValue(scope ?? MotionScope.of(context), spec);
    if (bound is bool) return bound;
    if (bound is num) return bound != 0;
    if (bound is String) return bound == 'true';
  }
  return fallback;
}

Color? resolveColour(BuildContext context, Object? spec, {DataScope? scope}) {
  if (spec is! String) return null;
  final String value = isBinding(spec)
      ? fillString(scope ?? MotionScope.of(context), spec)
      : spec;
  if (paletteRoles.contains(value)) {
    return roleColour(MotionTheme.paletteOf(context), value);
  }
  final int? hex = parseHex(value);
  return hex == null ? null : Color(hex);
}

EdgeInsets? resolveInsets(BuildContext context, Object? spec) {
  if (spec == null) return null;
  if (spec is num) return EdgeInsets.all(spec.toDouble());
  if (spec is List<Object?>) {
    final List<double> values = <double>[
      for (final Object? v in spec) (v as num?)?.toDouble() ?? 0,
    ];
    if (values.length == 2) {
      return EdgeInsets.symmetric(horizontal: values[0], vertical: values[1]);
    }
    if (values.length == 4) {
      return EdgeInsets.fromLTRB(values[0], values[1], values[2], values[3]);
    }
    return null;
  }
  if (spec is Map<String, Object?>) {
    double edge(String key, String pair) =>
        (spec[key] as num?)?.toDouble() ??
        (spec[pair] as num?)?.toDouble() ??
        (spec['all'] as num?)?.toDouble() ??
        0;
    return EdgeInsets.fromLTRB(
      edge('left', 'horizontal'),
      edge('top', 'vertical'),
      edge('right', 'horizontal'),
      edge('bottom', 'vertical'),
    );
  }
  return null;
}

Curve resolveCurve(Object? spec, {Curve fallback = Curves.linear}) =>
    namedCurves[spec] ?? fallback;
