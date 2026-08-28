import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:reelforge/reelforge.dart';
import 'package:reelforge_json/reelforge_json.dart';

/// The same reel as `longform.dart`, described in JSON instead of Dart.
///
/// It exists to be compared, not admired. `assets/longform.json` says the same
/// eight scenes, the same stings, the same two clips and the same numbers as
/// the Dart version, and `example/test/longform_json_test.dart` renders both
/// and asserts their declaration manifests are identical -- same duration,
/// same audio at the same frames, same video windows and trims.
///
/// That equality is the whole claim of `reelforge_json`: a document is not
/// a lesser way to describe a video, it is the same widgets reached by a
/// different route. Anything the JSON path could not express would show up
/// here as a difference.
late final Composition longformJson;

/// The parsed document and the data filling it, kept for the comparison test.
///
/// The test needs to build the same tree at a size it can actually rasterise,
/// which means supplying its own wrapper -- and a document's wrapper is where
/// its theme and its data scope live. Exposing the parts is what lets the test
/// rebuild that wrapper faithfully instead of approximating it.
late final MotionDocument longformDocument;
late final Map<String, Object?> longformData;

Future<void> loadLongformJson() async {
  final String document = await rootBundle.loadString('assets/longform.json');
  final String data = await rootBundle.loadString('assets/report.json');
  longformDocument = MotionDocument.parse(document);
  longformData = jsonDecode(data) as Map<String, Object?>;
  longformJson = longformDocument.toComposition(data: longformData);
}
