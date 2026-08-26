import 'package:flutter/widgets.dart';

/// The colours a composition draws itself in.
///
/// Deliberately small, and named by *role* rather than by hue. A component
/// that asks for `accent` keeps working when the accent turns orange; one that
/// asks for green does not.
@immutable
class MotionPalette {
  const MotionPalette({
    required this.background,
    required this.foreground,
    required this.muted,
    required this.accent,
    required this.warning,
    required this.surface,
    required this.outline,
  });

  /// Behind everything.
  final Color background;

  /// Body text and anything that has to be read.
  final Color foreground;

  /// Labels, axes, captions -- present but not competing.
  final Color muted;

  /// The one colour that means "look here". Used for positive numbers.
  final Color accent;

  /// Used for negative numbers and anything going the wrong way.
  final Color warning;

  /// Cards and panels sitting on [background].
  final Color surface;

  /// Hairlines around [surface].
  final Color outline;

  /// The palette the example reel uses: near-black, off-white, green and red.
  static const MotionPalette dark = MotionPalette(
    background: Color(0xFF0B0D11),
    foreground: Color(0xFFF2F4F8),
    muted: Color(0xFF7C8596),
    accent: Color(0xFF4ADE80),
    warning: Color(0xFFF97066),
    surface: Color(0xFF141821),
    outline: Color(0xFF1F2531),
  );

  static const MotionPalette light = MotionPalette(
    background: Color(0xFFF7F8FA),
    foreground: Color(0xFF0B0D11),
    muted: Color(0xFF6B7280),
    accent: Color(0xFF16A34A),
    warning: Color(0xFFDC2626),
    surface: Color(0xFFFFFFFF),
    outline: Color(0xFFE3E6EC),
  );

  MotionPalette copyWith({
    Color? background,
    Color? foreground,
    Color? muted,
    Color? accent,
    Color? warning,
    Color? surface,
    Color? outline,
  }) =>
      MotionPalette(
        background: background ?? this.background,
        foreground: foreground ?? this.foreground,
        muted: muted ?? this.muted,
        accent: accent ?? this.accent,
        warning: warning ?? this.warning,
        surface: surface ?? this.surface,
        outline: outline ?? this.outline,
      );

  /// [accent] when [value] is zero or above, [warning] when it is below.
  ///
  /// The sign-to-colour rule appears in every data scene there is, and getting
  /// it inconsistent between two of them looks like a bug in the data.
  Color forSign(num value) => value >= 0 ? accent : warning;

  @override
  bool operator ==(Object other) =>
      other is MotionPalette &&
      other.background == background &&
      other.foreground == foreground &&
      other.muted == muted &&
      other.accent == accent &&
      other.warning == warning &&
      other.surface == surface &&
      other.outline == outline;

  @override
  int get hashCode => Object.hash(background, foreground, muted, accent,
      warning, surface, outline);
}

/// Type sizes, expressed as one scale rather than as a table.
///
/// Video type is much larger than screen type and the sizes are far apart --
/// a 1080-wide vertical frame wants a 116pt headline over a 40pt body. A
/// single [scale] moves all of them together, which is what you actually want
/// when the same composition has to render at 1080 and at 720.
@immutable
class MotionTypography {
  const MotionTypography({
    this.fontFamily,
    this.scale = 1.0,
    this.display = 116,
    this.headline = 58,
    this.title = 44,
    this.body = 40,
    this.label = 30,
    this.caption = 22,
    this.statistic = 150,
  });

  /// The family every component draws in.
  ///
  /// Leave it null only if the composition sets a `DefaultTextStyle` itself.
  /// A composition that names no font is not portable: the same widget tree
  /// renders in SF on macOS and Roboto on Android, and every glyph differs.
  final String? fontFamily;

  final double scale;
  final double display;
  final double headline;
  final double title;
  final double body;
  final double label;
  final double caption;

  /// The size for a single number that is the whole point of the frame.
  final double statistic;

  double get displaySize => display * scale;
  double get headlineSize => headline * scale;
  double get titleSize => title * scale;
  double get bodySize => body * scale;
  double get labelSize => label * scale;
  double get captionSize => caption * scale;
  double get statisticSize => statistic * scale;

  MotionTypography copyWith({String? fontFamily, double? scale}) =>
      MotionTypography(
        fontFamily: fontFamily ?? this.fontFamily,
        scale: scale ?? this.scale,
        display: display,
        headline: headline,
        title: title,
        body: body,
        label: label,
        caption: caption,
        statistic: statistic,
      );

  @override
  bool operator ==(Object other) =>
      other is MotionTypography &&
      other.fontFamily == fontFamily &&
      other.scale == scale &&
      other.display == display &&
      other.headline == headline &&
      other.title == title &&
      other.body == body &&
      other.label == label &&
      other.caption == caption &&
      other.statistic == statistic;

  @override
  int get hashCode => Object.hash(
      fontFamily, scale, display, headline, title, body, label, caption,
      statistic);
}

/// Palette and type for everything below it.
///
/// Every kit component reads this rather than taking colours as arguments, so
/// restyling a composition is one widget at the top rather than an edit in
/// each scene. There is a default, so a component works with no theme above
/// it -- but a composition that means to look like anything should set one.
class MotionTheme extends InheritedWidget {
  const MotionTheme({
    super.key,
    this.palette = MotionPalette.dark,
    this.typography = const MotionTypography(),
    required super.child,
  });

  final MotionPalette palette;
  final MotionTypography typography;

  static const MotionTheme _fallback =
      MotionTheme(palette: MotionPalette.dark, child: SizedBox.shrink());

  static MotionTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionTheme>() ?? _fallback;

  static MotionPalette paletteOf(BuildContext context) => of(context).palette;

  static MotionTypography typeOf(BuildContext context) => of(context).typography;

  /// A [TextStyle] in this theme's family, for components building their own.
  TextStyle textStyle({
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w500,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: typography.fontFamily,
        fontSize: size,
        color: color,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        height: height,
      );

  @override
  bool updateShouldNotify(MotionTheme oldWidget) =>
      palette != oldWidget.palette || typography != oldWidget.typography;
}

/// Paints [MotionPalette.background] and sets the default text style.
///
/// The thing you want as a composition's `wrapper`: it puts the theme in the
/// tree, fills the frame, and makes unstyled `Text` legible rather than
/// black-on-black.
class MotionSurface extends StatelessWidget {
  const MotionSurface({
    super.key,
    this.palette = MotionPalette.dark,
    this.typography = const MotionTypography(),
    required this.child,
  });

  final MotionPalette palette;
  final MotionTypography typography;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MotionTheme(
      palette: palette,
      typography: typography,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: typography.fontFamily,
          color: palette.foreground,
          fontSize: typography.bodySize,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        child: ColoredBox(
          color: palette.background,
          child: SizedBox.expand(child: child),
        ),
      ),
    );
  }
}
