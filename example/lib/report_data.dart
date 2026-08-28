import 'dart:convert';

import 'package:flutter/services.dart';

/// The data the reel is made of, loaded once before the first frame.
///
/// This is the shape of the thing ReelForge exists for: a video that is a
/// function of data, not a timeline someone dragged clips onto. Change the JSON
/// and every scene, bar height, label and stagger below changes with it.
///
/// Loaded through a top-level `late final` rather than a FutureBuilder on
/// purpose. A composition has to be a pure function of frame number, and a
/// widget that is still loading on frame 0 is not: it would render a spinner
/// into the video. So the load happens in `main`, before `renderMain` is
/// called, and the composition only ever sees data that is already there.
late final Report report;

Future<void> loadReport() async {
  final String raw = await rootBundle.loadString('assets/report.json');
  report = Report.fromJson(jsonDecode(raw) as Map<String, Object?>);
}

class Report {
  Report({
    required this.period,
    required this.headline,
    required this.releases,
    required this.incidents,
    required this.uptime,
    required this.weeks,
    required this.teams,
  });

  factory Report.fromJson(Map<String, Object?> json) {
    final Map<String, Object?> totals = json['totals']! as Map<String, Object?>;
    return Report(
      period: json['period']! as String,
      headline: json['headline']! as String,
      releases: totals['releases']! as int,
      incidents: totals['incidents']! as int,
      uptime: (totals['uptime']! as num).toDouble(),
      weeks: <Week>[
        for (final Object? week in json['weeks']! as List<Object?>)
          Week.fromJson(week! as Map<String, Object?>),
      ],
      teams: <Team>[
        for (final Object? team in json['teams']! as List<Object?>)
          Team.fromJson(team! as Map<String, Object?>),
      ],
    );
  }

  final String period;
  final String headline;
  final int releases;
  final int incidents;
  final double uptime;
  final List<Week> weeks;
  final List<Team> teams;

  int get peakShipped =>
      weeks.map((Week w) => w.shipped).reduce((int a, int b) => a > b ? a : b);
}

class Week {
  const Week({required this.label, required this.shipped, required this.reverted});

  factory Week.fromJson(Map<String, Object?> json) => Week(
        label: json['label']! as String,
        shipped: json['shipped']! as int,
        reverted: json['reverted']! as int,
      );

  final String label;
  final int shipped;
  final int reverted;
}

class Team {
  const Team({required this.name, required this.delta, required this.owner});

  factory Team.fromJson(Map<String, Object?> json) => Team(
        name: json['name']! as String,
        delta: (json['delta']! as num).toDouble(),
        owner: json['owner']! as String,
      );

  final String name;
  final double delta;
  final String owner;
}
