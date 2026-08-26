// Placeholder app entry point.
//
// Compositions are rendered through lib/render_main.dart, which the
// fluttermotion CLI builds and drives:
//
//   dart run bin/fluttermotion.dart render --project ../../example \
//     --composition WeeklyDeals
//
// The preview scrubber will live here once it exists.
import 'package:flutter/widgets.dart';

void main() => runApp(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: Color(0xFF0B0B10),
          child: Center(
            child: Text(
              'Run compositions via lib/render_main.dart',
              style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18),
            ),
          ),
        ),
      ),
    );
