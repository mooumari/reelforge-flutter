import 'dart:math' as math;
import 'dart:ui';

import 'package:reelforge_stage/reelforge_stage.dart';

/// Numbers that say whether a [Walk] looks like a person moving, taken from
/// the walk itself rather than from pixels, so they can be asserted.
///
/// Each is something a viewer sees as wrongness:
///  * [slide]: how far a planted foot moves while it is meant to be planted.
///  * [overreach]: how far the planned ankle is beyond what the leg can reach
///    from its hip -- the leg stretches or the hips collapse.
///  * [hipJerk]: the largest frame-to-frame change in hip speed, a bounce.
///  * [stopJerk]: the same, over the last second only -- a stop that rings.
///  * [lowestHip]: the lowest the hips drop, as a fraction of standing height
///    -- splayed, sitting legs show up here.
class WalkReport {
  WalkReport(this.slide, this.overreach, this.hipJerk, this.stopJerk, this.lowestHip, this.flightFrames);

  final double slide, overreach, hipJerk, stopJerk, lowestHip;
  final int flightFrames;

  @override
  String toString() =>
      'slide ${slide.toStringAsFixed(2)}px  overreach ${overreach.toStringAsFixed(1)}px  hipJerk ${hipJerk.toStringAsFixed(2)}  '
      'stopJerk ${stopJerk.toStringAsFixed(2)}  lowestHip ${lowestHip.toStringAsFixed(2)}  flight ${flightFrames}f';
}

WalkReport reportOn(Walk walk, {required int from, required int to, required String hip, required double standingHipY, required double legReach, required double scale}) {
  double slide = 0, overreach = 0, jerk = 0, stopJerk = 0, lowest = 1;
  int flight = 0;
  double? prevY, prevV;
  final Map<int, double?> planted = <int, double?>{0: null, 1: null};
  for (int f = from; f <= to; f++) {
    final Posed p = walk.at(f);
    final Offset root = p.part.at;
    final double y = root.dy;
    if (prevY != null) {
      final double v = y - prevY;
      if (prevV != null) {
        final double j = (v - prevV).abs() / (legReach * scale);
        jerk = math.max(jerk, j);
        if (f > to - 30) stopJerk = math.max(stopJerk, j);
      }
      prevV = v;
    }
    prevY = y;
    lowest = math.min(lowest, 1 - (y - standingHipY) / (legReach * scale));
    for (int foot = 0; foot < 2; foot++) {
      final Offset ankle = walk.ankleAt(foot, f);
      if (walk.plantedAt(foot, f)) {
        final double? was = planted[foot];
        if (was != null) slide = math.max(slide, (ankle.dx - was).abs());
        planted[foot] = ankle.dx;
      } else {
        planted[foot] = null;
      }
      final Offset hipAt = frameOf(p.part, p.pose, foot == 0 ? 'hipF' : 'hipB').origin;
      if (walk.plantedAt(foot, f)) overreach = math.max(overreach, (ankle - hipAt).distance - legReach * scale);
    }
    if (!walk.plantedAt(0, f) && !walk.plantedAt(1, f)) flight++;
  }
  return WalkReport(slide, overreach, jerk, stopJerk, lowest, flight);
}
