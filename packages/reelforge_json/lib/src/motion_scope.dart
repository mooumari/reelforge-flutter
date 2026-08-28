import 'package:flutter/widgets.dart';
import 'package:reelforge_schema/reelforge_schema.dart';

/// Carries a [DataScope] down the widget tree.
class MotionScope extends InheritedWidget {
  const MotionScope({super.key, required this.scope, required super.child});

  final DataScope scope;

  static DataScope of(BuildContext context) {
    final MotionScope? found = context
        .dependOnInheritedWidgetOfExactType<MotionScope>();
    assert(
      found != null,
      'No MotionScope found. A document built by MotionDocument always '
      'provides one; a node used on its own has to be wrapped in it.',
    );
    return found?.scope ?? const DataScope(data: <String, Object?>{});
  }

  @override
  bool updateShouldNotify(MotionScope oldWidget) =>
      !identical(scope.data, oldWidget.scope.data) ||
      !identical(scope.item, oldWidget.scope.item) ||
      scope.itemIndex != oldWidget.scope.itemIndex;
}
