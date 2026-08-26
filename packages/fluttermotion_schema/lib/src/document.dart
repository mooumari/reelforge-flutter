import 'dart:convert';

import 'errors.dart';
import 'names.dart';
import 'node.dart';
import 'reader.dart';
import 'schema/kit.dart';
import 'schema/layout.dart';
import 'schema/media.dart';

/// The document format version this package writes and reads.
///
/// Checked rather than ignored: a document is a thing that gets stored and
/// sent, so the first breaking change has to be able to say "this file is
/// newer than the runtime reading it" instead of rendering it wrong.
const int currentDocumentVersion = 1;

bool _registered = false;

void _ensureRegistered() {
  if (_registered) return;
  _registered = true;
  registerLayoutSchema();
  registerMediaSchema();
  registerKitSchema();
}

/// The node vocabulary, for editors and validators to enumerate.
Map<String, NodeType> get knownNodeTypes {
  _ensureRegistered();
  return Map<String, NodeType>.unmodifiable(nodeRegistry);
}

/// A composition described in JSON, parsed and checked but not built.
///
/// Two shapes, because there are two kinds of video people actually make. A
/// document with `scenes` is a storyboard -- a list of cuts with durations,
/// which is what a report or a reel is. One with `root` is a single tree over
/// an explicit `durationInFrames`, for when the timeline is expressed inside
/// the tree with `sequence` nodes instead.
///
/// This is the whole document as data. Rendering it is
/// `fluttermotion_json`'s job; validating it, storing it, diffing it or
/// serving it needs nothing more than what is here.
class DocumentSpec {
  DocumentSpec._({
    required this.id,
    required this.width,
    required this.height,
    required this.fps,
    required this.durationInFrames,
    required this.theme,
    required this.scenes,
    required this.root,
    required this.bed,
    required this.defaultTransition,
  });

  final String id;
  final int width;
  final int height;
  final int fps;
  final int durationInFrames;
  final ThemeSpec theme;

  /// The storyboard form, empty when the document uses `root`.
  final List<SceneSpec> scenes;

  /// The single-tree form, null when the document uses `scenes`.
  final MotionNode? root;

  final MotionNode? bed;
  final TransitionSpec defaultTransition;

  /// Parses [source], which may be a JSON string or already-decoded JSON.
  ///
  /// Throws [SchemaException] carrying *every* problem found, not the first.
  /// A document with four mistakes should take one round trip to fix, not
  /// four.
  static DocumentSpec parse(Object? source) {
    _ensureRegistered();
    final Problems problems = Problems();
    final DocumentSpec? document = _parse(_decode(source, problems), problems);
    problems.throwIfAny();
    if (document == null) {
      throw SchemaException(<SchemaProblem>[
        const SchemaProblem('', 'could not be read'),
      ]);
    }
    return document;
  }

  /// Everything wrong with [source], without building anything.
  ///
  /// The entry point an editor, a CLI or a server validating user input wants:
  /// it answers "would this render" in this process, with no Flutter engine
  /// and nothing to build first.
  static List<SchemaProblem> problemsIn(Object? source) {
    _ensureRegistered();
    final Problems problems = Problems();
    _parse(_decode(source, problems), problems);
    return problems.found;
  }
}

/// One cut of a storyboard.
class SceneSpec {
  const SceneSpec({
    required this.frames,
    required this.child,
    this.sting,
    this.transition,
  });

  final int frames;
  final MotionNode child;
  final MotionNode? sting;

  /// Null means "whatever the document's default transition is".
  final TransitionSpec? transition;
}

/// A scene transition, as named rather than as built.
///
/// Every field is filled in at parse time, defaults included. How long a
/// document's fade lasts when it does not say is a decision about the
/// *format*, so it is written here, once, rather than by whatever happens to
/// build the transition.
class TransitionSpec {
  const TransitionSpec.none()
    : type = 'none',
      frames = 0,
      x = 0,
      y = 0,
      scale = 1,
      curve = 'linear',
      fade = false;

  const TransitionSpec.fade({this.frames = 8})
    : type = 'fade',
      x = 0,
      y = 0,
      scale = 1,
      curve = 'linear',
      fade = true;

  const TransitionSpec.slide({
    this.frames = 12,
    this.x = 0,
    this.y = 60,
    this.curve = 'outCubic',
    this.fade = true,
  }) : type = 'slide',
       scale = 1;

  const TransitionSpec.scale({
    this.frames = 12,
    this.scale = 0.94,
    this.curve = 'outCubic',
    this.fade = true,
  }) : type = 'scale',
       x = 0,
       y = 0;

  /// One of [transitionNames].
  final String type;

  final int frames;
  final double x;
  final double y;
  final double scale;

  /// One of [curveNames].
  final String curve;

  final bool fade;
}

/// A document's theme, as numbers and names rather than as Flutter objects.
///
/// Sizes and role colours are held only where the document actually set them.
/// A default restated here is a default that can drift away from the one the
/// components use, which is exactly the bug class this format is prone to.
class ThemeSpec {
  const ThemeSpec({
    this.base = 'dark',
    this.roles = const <String, int>{},
    this.fontFamily,
    this.scale = 1.0,
    this.sizes = const <String, double>{},
  });

  /// One of [paletteNames].
  final String base;

  /// Role name to ARGB, for the roles the document overrode.
  final Map<String, int> roles;

  final String? fontFamily;
  final double scale;

  /// Text role to size, for the roles the document set.
  final Map<String, double> sizes;
}

Object? _decode(Object? source, Problems problems) {
  if (source is! String) return source;
  try {
    return jsonDecode(source);
  } on FormatException catch (error) {
    problems.add('', 'is not valid JSON: ${error.message}');
    return null;
  }
}

DocumentSpec? _parse(Object? json, Problems problems) {
  if (json is! Map<String, Object?>) {
    if (json != null) problems.add('', 'must be a JSON object');
    return null;
  }

  final Reader reader = Reader(json, '', problems)
    ..rejectUnknownKeys(<String>{
      'version',
      'id',
      'width',
      'height',
      'fps',
      'durationInFrames',
      'theme',
      'scenes',
      'root',
      'bed',
      'transition',
    });

  final int? version = reader.plainInt('version');
  if (version != null && version > currentDocumentVersion) {
    problems.add(
      'version',
      'is $version, but this build of fluttermotion_schema understands up to '
          '$currentDocumentVersion',
    );
  }

  final String id = reader.string('id', required: true) ?? 'Document';
  final int width = reader.plainInt('width', required: true) ?? 1080;
  final int height = reader.plainInt('height', required: true) ?? 1920;
  final int fps = reader.plainInt('fps', required: true) ?? 30;
  for (final (String name, int value) in <(String, int)>[
    ('width', width),
    ('height', height),
    ('fps', fps),
  ]) {
    if (value <= 0) problems.add(name, 'must be greater than zero, got $value');
  }

  final ThemeSpec theme = _parseTheme(json['theme'], 'theme', problems);

  final MotionNode? bed = json['bed'] == null
      ? null
      : parseNode(json['bed'], 'bed', problems);

  final TransitionSpec defaultTransition =
      _parseTransition(json['transition'], 'transition', problems) ??
      const TransitionSpec.fade();

  final bool hasScenes = json['scenes'] != null;
  final bool hasRoot = json['root'] != null;
  if (hasScenes == hasRoot) {
    problems.add(
      '',
      hasScenes
          ? 'has both "scenes" and "root"; a document is either a storyboard '
                'or a single tree, not both'
          : 'needs either "scenes" (a storyboard) or "root" (a single tree)',
    );
    return null;
  }

  if (hasRoot) {
    final MotionNode? root = parseNode(json['root'], 'root', problems);
    final int? duration = reader.plainInt('durationInFrames', required: true);
    if (duration != null && duration <= 0) {
      problems.add('durationInFrames', 'must be at least one frame');
    }
    if (root == null || duration == null) return null;
    return DocumentSpec._(
      id: id,
      width: width,
      height: height,
      fps: fps,
      durationInFrames: duration,
      theme: theme,
      scenes: const <SceneSpec>[],
      root: root,
      bed: bed,
      defaultTransition: defaultTransition,
    );
  }

  if (json.containsKey('durationInFrames')) {
    problems.add(
      'durationInFrames',
      'is set by the scenes; remove it, or use "root" instead of "scenes"',
    );
  }

  final Object? sceneList = json['scenes'];
  if (sceneList is! List<Object?> || sceneList.isEmpty) {
    problems.add('scenes', 'must be a list with at least one scene');
    return null;
  }

  final List<SceneSpec> scenes = <SceneSpec>[];
  for (int i = 0; i < sceneList.length; i++) {
    final SceneSpec? scene = _parseScene(
      sceneList[i],
      index('scenes', i),
      fps,
      problems,
    );
    if (scene != null) scenes.add(scene);
  }
  if (scenes.isEmpty) return null;

  return DocumentSpec._(
    id: id,
    width: width,
    height: height,
    fps: fps,
    durationInFrames: scenes.fold(0, (int sum, SceneSpec s) => sum + s.frames),
    theme: theme,
    scenes: scenes,
    root: null,
    bed: bed,
    defaultTransition: defaultTransition,
  );
}

SceneSpec? _parseScene(Object? json, String path, int fps, Problems problems) {
  if (json is! Map<String, Object?>) {
    problems.add(path, 'must be an object');
    return null;
  }

  final Reader reader = Reader(json, path, problems)
    ..rejectUnknownKeys(<String>{
      'seconds',
      'frames',
      'child',
      'sting',
      'transition',
    });

  final num? seconds = reader.plainNumber('seconds');
  final int? frames = reader.plainInt('frames');
  if ((seconds == null) == (frames == null)) {
    problems.add(path, 'needs exactly one of "seconds" or "frames"');
  }
  final int length = frames ?? (seconds == null ? 0 : (seconds * fps).round());
  if (length <= 0 && (seconds != null || frames != null)) {
    problems.add(path, 'is $length frames long; a scene needs at least one');
  }

  final MotionNode? content = parseNode(
    json['child'],
    child(path, 'child'),
    problems,
  );
  final MotionNode? sting = json['sting'] == null
      ? null
      : parseNode(json['sting'], child(path, 'sting'), problems);
  final TransitionSpec? transition = _parseTransition(
    json['transition'],
    child(path, 'transition'),
    problems,
  );

  if (content == null || length <= 0) return null;
  return SceneSpec(
    frames: length,
    child: content,
    sting: sting,
    transition: transition,
  );
}

ThemeSpec _parseTheme(Object? json, String path, Problems problems) {
  if (json == null) return const ThemeSpec();

  if (json is! Map<String, Object?>) {
    problems.add(path, 'must be an object');
    return const ThemeSpec();
  }

  final Reader reader = Reader(json, path, problems)
    ..rejectUnknownKeys(<String>{'palette', 'font', 'scale', 'sizes'})
    ..plainNumber('scale');

  String base = 'dark';
  final Map<String, int> roles = <String, int>{};

  final Object? paletteSpec = json['palette'];
  if (paletteSpec is String) {
    base = _basePalette(paletteSpec, child(path, 'palette'), problems);
  } else if (paletteSpec is Map<String, Object?>) {
    base = _basePalette(
      (paletteSpec['base'] as String?) ?? 'dark',
      child(path, 'palette.base'),
      problems,
    );
    Reader(
      paletteSpec,
      child(path, 'palette'),
      problems,
    ).rejectUnknownKeys(<String>{'base', ...paletteRoles});
    for (final String name in paletteRoles) {
      final Object? value = paletteSpec[name];
      if (value == null) continue;
      // A role may not name another role: `accent: "warning"` is a cycle
      // waiting to be written and buys nothing a hex does not.
      if (value is String && paletteRoles.contains(value)) {
        problems.add(
          child(path, 'palette.$name'),
          'must be a #hex colour; a palette cannot define a role as another '
          'role',
        );
        continue;
      }
      final Problems local = Problems();
      checkColour(value, child(path, 'palette.$name'), local);
      if (!local.isEmpty) {
        for (final SchemaProblem problem in local.found) {
          problems.add(problem.path, problem.message);
        }
        continue;
      }
      final int? hex = parseHex(value as String);
      if (hex != null) roles[name] = hex;
    }
  } else if (paletteSpec != null) {
    problems.add(child(path, 'palette'), 'must be a name or an object');
  }

  final Map<String, double> sizes = <String, double>{};
  final Object? sizeSpec = json['sizes'];
  if (sizeSpec is Map<String, Object?>) {
    final Reader sizeReader = Reader(sizeSpec, child(path, 'sizes'), problems)
      ..rejectUnknownKeys(textRoles);
    for (final String role in textRoles) {
      final num? value = sizeReader.plainNumber(role);
      if (value != null) sizes[role] = value.toDouble();
    }
  } else if (sizeSpec != null) {
    problems.add(child(path, 'sizes'), 'must be an object');
  }

  return ThemeSpec(
    base: base,
    roles: roles,
    fontFamily: reader.string('font'),
    scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
    sizes: sizes,
  );
}

String _basePalette(String name, String path, Problems problems) {
  if (paletteNames.contains(name)) return name;
  problems.add(
    path,
    '"$name" is not a palette; use ${(paletteNames.toList()..sort()).join(' or ')}',
  );
  return 'dark';
}

TransitionSpec? _parseTransition(Object? json, String path, Problems problems) {
  if (json == null) return null;
  if (json is! Map<String, Object?>) {
    problems.add(path, 'must be an object with a "type"');
    return null;
  }

  final Reader reader = Reader(json, path, problems);
  final String? type = reader.oneOf('type', transitionNames, required: true);

  switch (type) {
    case 'none':
      reader.rejectUnknownKeys(<String>{'type'});
      return const TransitionSpec.none();
    case 'fade':
      reader.rejectUnknownKeys(<String>{'type', 'frames'});
      final int? frames = reader.plainInt('frames');
      return frames == null
          ? const TransitionSpec.fade()
          : TransitionSpec.fade(frames: frames);
    case 'slide':
      reader
        ..rejectUnknownKeys(<String>{
          'type',
          'frames',
          'x',
          'y',
          'curve',
          'fade',
        })
        ..oneOf('curve', curveNames);
      const TransitionSpec fallback = TransitionSpec.slide();
      return TransitionSpec.slide(
        frames: reader.plainInt('frames') ?? fallback.frames,
        x: reader.plainNumber('x')?.toDouble() ?? fallback.x,
        y: reader.plainNumber('y')?.toDouble() ?? fallback.y,
        curve: (json['curve'] as String?) ?? fallback.curve,
        fade: reader.boolean('fade') ?? fallback.fade,
      );
    case 'scale':
      reader
        ..rejectUnknownKeys(<String>{
          'type',
          'frames',
          'scale',
          'curve',
          'fade',
        })
        ..oneOf('curve', curveNames);
      const TransitionSpec fallback = TransitionSpec.scale();
      return TransitionSpec.scale(
        frames: reader.plainInt('frames') ?? fallback.frames,
        scale: reader.plainNumber('scale')?.toDouble() ?? fallback.scale,
        curve: (json['curve'] as String?) ?? fallback.curve,
        fade: reader.boolean('fade') ?? fallback.fade,
      );
    default:
      return null;
  }
}
