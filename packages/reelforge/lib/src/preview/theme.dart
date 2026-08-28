import 'package:flutter/widgets.dart';

/// Preview chrome colours.
///
/// Deliberately neutral and dark: the chrome must never be mistaken for part
/// of the composition, and a light UI would bias how you judge contrast in the
/// frame you are editing.
abstract final class PreviewColors {
  static const Color background = Color(0xFF0A0A0C);
  static const Color chrome = Color(0xFF141419);
  static const Color chromeRaised = Color(0xFF1E1E26);
  static const Color border = Color(0xFF2A2A34);
  static const Color text = Color(0xFFE6E6EC);
  static const Color textDim = Color(0xFF8A8A99);
  static const Color accent = Color(0xFF5B8CFF);
  static const Color accentDim = Color(0xFF33406B);

  /// Behind the composition. A checkerboard would fight with the content, so
  /// the canvas surround is flat and darker than the chrome.
  static const Color canvas = Color(0xFF050507);
}

abstract final class PreviewText {
  static const TextStyle label = TextStyle(
    fontSize: 12,
    color: PreviewColors.text,
    fontWeight: FontWeight.w500,
    height: 1.2,
  );
  static const TextStyle dim = TextStyle(
    fontSize: 12,
    color: PreviewColors.textDim,
    height: 1.2,
  );
  static const TextStyle mono = TextStyle(
    fontSize: 12,
    color: PreviewColors.text,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    height: 1.2,
  );
  static const TextStyle monoDim = TextStyle(
    fontSize: 12,
    color: PreviewColors.textDim,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    height: 1.2,
  );
}

/// `0:04.37` — short enough to read at a glance while scrubbing.
String formatTimecode(int frame, int fps) {
  final double seconds = frame / fps;
  final int minutes = seconds ~/ 60;
  final double rest = seconds - minutes * 60;
  return '$minutes:${rest.toStringAsFixed(2).padLeft(5, '0')}';
}
