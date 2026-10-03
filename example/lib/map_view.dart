import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'map_data.dart';
import 'rain_look.dart';

/// A map drawn from the baked Natural Earth outlines in [mapCountries], in
/// either [Look].
///
/// Lambert azimuthal equal-area, centred on [lon0], [lat0]: the standard
/// projection for a continent. [radius] is the pixels from the centre to the
/// edge of a sphere's quarter-turn, so it is the zoom.
class MapView {
  const MapView({required this.lon0, required this.lat0, required this.radius, this.centre = Offset.zero});

  final double lon0, lat0, radius;

  /// Where on the canvas the map's centre goes.
  final Offset centre;

  Offset project(double lon, double lat) {
    final double l = (lon - lon0) * math.pi / 180, p = lat * math.pi / 180, p0 = lat0 * math.pi / 180;
    final double c = 1 + math.sin(p0) * math.sin(p) + math.cos(p0) * math.cos(p) * math.cos(l);
    final double k = math.sqrt(2 / math.max(c, 1e-6));
    return centre +
        Offset(
          radius * k * math.cos(p) * math.sin(l),
          -radius * k * (math.cos(p0) * math.sin(p) - math.sin(p0) * math.cos(p) * math.cos(l)),
        );
  }

  Path ring(List<double> lonLat) {
    final Path path = Path();
    for (int i = 0; i < lonLat.length; i += 2) {
      final Offset o = project(lonLat[i], lonLat[i + 1]);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    return path..close();
  }

  Path country(String name) {
    final Path out = Path();
    for (final List<double> r in mapCountries[name] ?? const <List<double>>[]) {
      out.addPath(ring(r), Offset.zero);
    }
    return out;
  }

  /// A longitude/latitude polygon: [points] is lon, lat, lon, lat...
  Path polygon(List<double> points) => ring(points);
}

/// The last glacial maximum's ice, roughly: Scandinavia and the Baltic, the
/// north of the British Isles and the north Russian plain, as one polygon of
/// longitude, latitude. It is a hand-placed approximation of the published
/// extent, enough for a viewer to see "ice to the north".
const List<double> iceSheetLonLat = <double>[
  -14, 57, -10, 53.5, -6.5, 52.4, -3, 53.2, 1, 53.8, 6, 54.6, 10, 54.6, 14, 53.8, 19, 53.9, 24, 55, 30, 56.5, 36, 59.5, 42, 62, 52, 64, 62, 66.5, 70, 68, 75, 70, 75, 74, -32, 74, -32, 62,
];

class MapPainter extends CustomPainter {
  const MapPainter({
    required this.look,
    required this.view,
    this.highlight = const <String>{},
    this.highlightAmount = 1,
    this.ice = 0,
    this.frame = 0,
  });

  final Look look;
  final MapView view;
  final Set<String> highlight;
  final double highlightAmount;

  /// How much of the ice sheet to show, 0 to 1.
  final double ice;

  /// The frame, so a doodle's lines can boil.
  final int frame;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect all = Offset.zero & size;
    // Sea.
    if (look.doodle) {
      canvas.drawRect(all, Paint()..color = const Color(0xFFCFE6EA));
    } else {
      canvas.drawRect(
        all,
        Paint()..shader = const RadialGradient(colors: <Color>[Color(0xFF223A63), Color(0xFF0E1B38)], radius: 0.9).createShader(all),
      );
    }
    // Land, a country at a time, so the borders come free.
    final Color land = look.doodle ? const Color(0xFFF3E3B4) : const Color(0xFF4D6A78);
    final Color accent = look.doodle ? const Color(0xFFF08A5D) : const Color(0xFFE9A25A);
    for (final String name in mapCountries.keys) {
      final bool hot = highlight.contains(name);
      final Path p = view.country(name);
      final Color fill = hot ? Color.lerp(land, accent, highlightAmount)! : land;
      if (look.doodle) {
        canvas.drawPath(p, Paint()..color = fill);
        canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = hot ? 5 : 2.2..strokeJoin = StrokeJoin.round..color = look.ink);
      } else {
        canvas.drawPath(p, Paint()..color = fill);
        canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeJoin = StrokeJoin.round..color = const Color(0x6694B4C4));
      }
    }
    // The coast, heavier than the borders.
    final Path everything = Path();
    for (final String name in mapCountries.keys) {
      everything.addPath(view.country(name), Offset.zero);
    }
    canvas.drawPath(
      everything,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = look.doodle ? 6 : 2.5
        ..color = look.doodle ? look.ink : const Color(0xFF9CC0D0),
    );
    // Ice.
    if (ice > 0) {
      final Path sheet = view.polygon(iceSheetLonLat);
      canvas.save();
      canvas.clipPath(everything);
      canvas.drawPath(sheet, Paint()..color = (look.doodle ? const Color(0xFFFFFFFF) : const Color(0xFFEAF3FF)).withValues(alpha: (look.doodle ? 0.9 : 0.78) * ice));
      canvas.restore();
      if (look.doodle) {
        canvas.save();
        canvas.clipPath(everything);
        canvas.drawPath(sheet, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = look.ink.withValues(alpha: ice));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(MapPainter old) =>
      old.look != look || old.view != view || old.highlightAmount != highlightAmount || old.ice != ice || old.frame != frame || old.highlight != highlight;
}
