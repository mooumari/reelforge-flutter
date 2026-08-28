import 'package:flutter/widgets.dart';
import 'package:reelforge_schema/reelforge_schema.dart';

import 'motion_scope.dart';
import 'values.dart';

/// How one node type turns into a widget.
typedef NodeBuilder = Widget Function(BuildContext context, MotionNode node);

final Map<String, NodeBuilder> _builders = <String, NodeBuilder>{};

/// Attaches a builder to a node type this package's schema already declares.
///
/// The name has to exist in `reelforge_schema` first. That direction
/// matters: the schema is what a validator, an editor and a server read, so a
/// node that can be built but not described is a node that renders in the app
/// and fails `validate` -- the worst of the two failures to have.
void registerBuilder(String name, NodeBuilder build) {
  if (!knownNodeTypes.containsKey(name)) {
    throw StateError(
      'No schema for node type "$name". Declare it in '
      'reelforge_schema first; a builder without one would render '
      'something no validator can check.',
    );
  }
  _builders[name] = build;
}

/// The builder for [name], or null if the schema declares a node this build
/// cannot draw.
NodeBuilder? builderFor(String name) => _builders[name];

/// Node types the schema declares with no builder attached.
///
/// Empty in a correct build. `test/vocabulary_test.dart` asserts it.
Iterable<String> get unbuildableNodeTypes =>
    knownNodeTypes.keys.where((String name) => !_builders.containsKey(name));

/// Everything a [MotionNode] can do once there is a Flutter engine under it.
///
/// An extension rather than a subclass, so the tree a validator walks and the
/// tree a renderer builds are the same tree, parsed once. Nothing below adds
/// state; it all reads the node's raw JSON against the frame it is asked on.
extension MotionNodeBuilding on MotionNode {
  /// The widget for this node, with an element of its own.
  ///
  /// The indirection is load-bearing. A node's properties are evaluated
  /// against the context it builds in -- that is how a `sequence` rebases the
  /// frame beneath it and a `stagger` offsets its children. Building directly
  /// from the parent would evaluate the child at the *parent's* context, so
  /// every animation inside a sequence would read the composition's frame
  /// instead of the scene's and quietly play at the wrong time.
  Widget widget() =>
      type.parentData ? Builder(builder: buildDirect) : NodeWidget(this);

  /// Builds against [context] with no element in between.
  ///
  /// Only for a [NodeType.parentData] node, and for the composition root,
  /// which already has one.
  Widget buildDirect(BuildContext context) {
    final NodeBuilder? build = builderFor(type.name);
    if (build == null) {
      throw StateError(
        'No builder for node type "${type.name}" at $path. This build of '
        'reelforge_json knows the type but cannot draw it.',
      );
    }
    return build(context, this);
  }

  // -- property access, all raw-spec aware ---------------------------------

  Widget? slot(BuildContext context, String key) => slots[key]?.widget();

  List<Widget> children(BuildContext context, String key) {
    final ChildList? list = lists[key];
    if (list == null) return const <Widget>[];
    if (!list.repeats) {
      return <Widget>[for (final MotionNode node in list.nodes) node.widget()];
    }
    return <Widget>[
      for (final ScopedNode each in list.resolve(MotionScope.of(context)))
        MotionScope(
          scope: each.scope,
          // The template has to build *below* the new scope, or it would read
          // the enclosing one and every item would come out identical.
          child: each.node.widget(),
        ),
    ];
  }

  /// The objects of a chart data list, each with the scope it resolves in.
  List<ScopedSpec> data(BuildContext context, String key) =>
      specs[key]?.resolve(MotionScope.of(context)) ?? const <ScopedSpec>[];

  String text(BuildContext context, String key, {String fallback = ''}) =>
      resolveString(context, props[key], fallback: fallback);

  String? optionalText(BuildContext context, String key) =>
      resolveOptionalString(context, props[key]);

  double number(BuildContext context, String key, {double fallback = 0}) =>
      resolveNumber(context, props[key], fallback: fallback);

  double? optionalNumber(BuildContext context, String key) =>
      resolveOptionalNumber(context, props[key]);

  int integer(BuildContext context, String key, {int fallback = 0}) =>
      props[key] == null ? fallback : number(context, key).round();

  int? optionalInteger(BuildContext context, String key) =>
      resolveOptionalInt(context, props[key]);

  bool flag(BuildContext context, String key, {bool fallback = false}) =>
      resolveBool(context, props[key], fallback: fallback);

  Color? colour(BuildContext context, String key) =>
      resolveColour(context, props[key]);

  EdgeInsets? insets(BuildContext context, String key) =>
      resolveInsets(context, props[key]);

  Curve curve(String key, {Curve fallback = Curves.linear}) =>
      resolveCurve(props[key], fallback: fallback);
}

/// Reading one object of a chart data list against the frame.
extension ScopedSpecBuilding on ScopedSpec {
  String text(BuildContext context, String key, {String fallback = ''}) =>
      resolveString(context, json[key], fallback: fallback, scope: scope);

  double number(BuildContext context, String key, {double fallback = 0}) =>
      resolveNumber(context, json[key], fallback: fallback, scope: scope);

  Color? colour(BuildContext context, String key) =>
      resolveColour(context, json[key], scope: scope);
}

/// One node, with an element of its own so its context is its own.
class NodeWidget extends StatelessWidget {
  const NodeWidget(this.node, {super.key});

  final MotionNode node;

  @override
  Widget build(BuildContext context) => node.buildDirect(context);
}
