import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:fluttermotion/fluttermotion.dart';
import 'package:fluttermotion_kit/fluttermotion_kit.dart';

import 'errors.dart';
import 'node.dart';
import 'nodes/kit.dart';
import 'nodes/layout.dart';
import 'nodes/media.dart';
import 'scope.dart';
import 'values.dart';

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
  registerLayoutNodes();
  registerMediaNodes();
  registerKitNodes();
}

/// The node vocabulary, for editors and validators to enumerate.
Map<String, NodeType> get knownNodeTypes {
  _ensureRegistered();
  return Map<String, NodeType>.unmodifiable(nodeRegistry);
}

/// A composition described in JSON.
///
/// Two shapes, because there are two kinds of video people actually make. A
/// document with `scenes` is a storyboard -- a list of cuts with durations,
/// which is what a report or a reel is. One with `root` is a single tree over
/// an explicit `durationInFrames`, for when the timeline is expressed inside
/// the tree with `sequence` nodes instead.
class MotionDocument {
  MotionDocument._({
    required this.id,
    required this.width,
    required this.height,
    required this.fps,
    required this.durationInFrames,
    required this.palette,
    required this.typography,
    required List<_SceneSpec> scenes,
    required MotionNode? root,
    required this.bed,
    required this.defaultTransition,
  })  : _scenes = scenes,
        _root = root;

  final String id;
  final int width;
  final int height;
  final int fps;
  final int durationInFrames;
  final MotionPalette palette;
  final MotionTypography typography;

  /// The storyboard form, empty when the document uses `root`.
  final List<_SceneSpec> _scenes;

  /// The single-tree form, null when the document uses `scenes`.
  final MotionNode? _root;

  final MotionNode? bed;
  final SceneTransition defaultTransition;

  /// Parses [source], which may be a JSON string or already-decoded JSON.
  ///
  /// Throws [SchemaException] carrying *every* problem found, not the first.
  /// A document with four mistakes should take one round trip to fix, not
  /// four.
  static MotionDocument parse(Object? source) {
    _ensureRegistered();
    final Problems problems = Problems();
    final MotionDocument? document = _parse(_decode(source, problems), problems);
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
  /// The entry point an editor or a server validating user input wants: it
  /// answers "would this render" without needing a Flutter binding.
  static List<SchemaProblem> problemsIn(Object? source) {
    _ensureRegistered();
    final Problems problems = Problems();
    _parse(_decode(source, problems), problems);
    return problems.found;
  }

  /// A [Composition] ready to render, filled from [data].
  Composition toComposition({Map<String, Object?> data = const <String, Object?>{}}) {
    return Composition(
      id: id,
      width: width,
      height: height,
      fps: fps,
      durationInFrames: durationInFrames,
      wrapper: (BuildContext context, Widget child) => MotionSurface(
        palette: palette,
        typography: typography,
        child: MotionScope(scope: DataScope(data: data), child: child),
      ),
      builder: build,
    );
  }

  /// The widget tree, below the wrapper [toComposition] provides.
  Widget build(BuildContext context) {
    if (_root != null) return _root.buildDirect(context);
    return Storyboard(
      transition: defaultTransition,
      bed: bed?.widget(),
      scenes: <Scene>[
        for (final _SceneSpec spec in _scenes)
          Scene(
            frames: spec.frames,
            transition: spec.transition,
            sting: spec.sting?.widget(),
            builder: spec.child.buildDirect,
          ),
      ],
    );
  }
}

class _SceneSpec {
  const _SceneSpec({
    required this.frames,
    required this.child,
    this.sting,
    this.transition,
  });

  final int frames;
  final MotionNode child;
  final MotionNode? sting;
  final SceneTransition? transition;
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

MotionDocument? _parse(Object? json, Problems problems) {
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
      'is $version, but this build of fluttermotion_json understands up to '
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

  final (MotionPalette palette, MotionTypography typography) =
      _parseTheme(json['theme'], 'theme', problems);

  final MotionNode? bed = json['bed'] == null
      ? null
      : parseNode(json['bed'], 'bed', problems);

  final SceneTransition defaultTransition =
      _parseTransition(json['transition'], 'transition', problems) ??
          const SceneTransition.fade();

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
    return MotionDocument._(
      id: id,
      width: width,
      height: height,
      fps: fps,
      durationInFrames: duration,
      palette: palette,
      typography: typography,
      scenes: const <_SceneSpec>[],
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

  final List<_SceneSpec> scenes = <_SceneSpec>[];
  for (int i = 0; i < sceneList.length; i++) {
    final _SceneSpec? scene =
        _parseScene(sceneList[i], index('scenes', i), fps, problems);
    if (scene != null) scenes.add(scene);
  }
  if (scenes.isEmpty) return null;

  return MotionDocument._(
    id: id,
    width: width,
    height: height,
    fps: fps,
    durationInFrames:
        scenes.fold(0, (int sum, _SceneSpec s) => sum + s.frames),
    palette: palette,
    typography: typography,
    scenes: scenes,
    root: null,
    bed: bed,
    defaultTransition: defaultTransition,
  );
}

_SceneSpec? _parseScene(
  Object? json,
  String path,
  int fps,
  Problems problems,
) {
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
    problems.add(
      path,
      'needs exactly one of "seconds" or "frames"',
    );
  }
  final int length = frames ?? (seconds == null ? 0 : (seconds * fps).round());
  if (length <= 0 && (seconds != null || frames != null)) {
    problems.add(path, 'is $length frames long; a scene needs at least one');
  }

  final MotionNode? content =
      parseNode(json['child'], child(path, 'child'), problems);
  final MotionNode? sting = json['sting'] == null
      ? null
      : parseNode(json['sting'], child(path, 'sting'), problems);
  final SceneTransition? transition =
      _parseTransition(json['transition'], child(path, 'transition'), problems);

  if (content == null || length <= 0) return null;
  return _SceneSpec(
    frames: length,
    child: content,
    sting: sting,
    transition: transition,
  );
}

(MotionPalette, MotionTypography) _parseTheme(
  Object? json,
  String path,
  Problems problems,
) {
  MotionPalette palette = MotionPalette.dark;
  MotionTypography typography = const MotionTypography();
  if (json == null) return (palette, typography);

  if (json is! Map<String, Object?>) {
    problems.add(path, 'must be an object');
    return (palette, typography);
  }

  final Reader reader = Reader(json, path, problems)
    ..rejectUnknownKeys(<String>{'palette', 'font', 'scale', 'sizes'})
    ..plainNumber('scale');

  final Object? paletteSpec = json['palette'];
  if (paletteSpec is String) {
    palette = _basePalette(paletteSpec, child(path, 'palette'), problems);
  } else if (paletteSpec is Map<String, Object?>) {
    final String base = (paletteSpec['base'] as String?) ?? 'dark';
    palette = _basePalette(base, child(path, 'palette.base'), problems);
    Reader(paletteSpec, child(path, 'palette'), problems)
        .rejectUnknownKeys(<String>{'base', ...paletteRoles});
    Color? role(String name) {
      final Object? value = paletteSpec[name];
      if (value == null) return null;
      final Problems local = Problems();
      checkColour(value, child(path, 'palette.$name'), local);
      // A role may not name another role: `accent: "warning"` is a cycle
      // waiting to be written and buys nothing a hex does not.
      if (value is String && paletteRoles.contains(value)) {
        problems.add(
          child(path, 'palette.$name'),
          'must be a #hex colour; a palette cannot define a role as another '
          'role',
        );
        return null;
      }
      if (!local.isEmpty) {
        for (final SchemaProblem problem in local.found) {
          problems.add(problem.path, problem.message);
        }
        return null;
      }
      return _hexColour(value as String);
    }

    palette = palette.copyWith(
      background: role('background'),
      foreground: role('foreground'),
      muted: role('muted'),
      accent: role('accent'),
      warning: role('warning'),
      surface: role('surface'),
      outline: role('outline'),
    );
  } else if (paletteSpec != null) {
    problems.add(child(path, 'palette'), 'must be a name or an object');
  }

  typography = MotionTypography(
    fontFamily: reader.string('font'),
    scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
  );

  final Object? sizes = json['sizes'];
  if (sizes is Map<String, Object?>) {
    final Reader sizeReader = Reader(sizes, child(path, 'sizes'), problems)
      ..rejectUnknownKeys(<String>{
        'display',
        'headline',
        'title',
        'body',
        'label',
        'caption',
        'statistic',
      });
    double size(String name, double fallback) =>
        sizeReader.plainNumber(name)?.toDouble() ?? fallback;
    typography = MotionTypography(
      fontFamily: typography.fontFamily,
      scale: typography.scale,
      display: size('display', 116),
      headline: size('headline', 58),
      title: size('title', 44),
      body: size('body', 40),
      label: size('label', 30),
      caption: size('caption', 22),
      statistic: size('statistic', 150),
    );
  } else if (sizes != null) {
    problems.add(child(path, 'sizes'), 'must be an object');
  }

  return (palette, typography);
}

MotionPalette _basePalette(String name, String path, Problems problems) {
  switch (name) {
    case 'dark':
      return MotionPalette.dark;
    case 'light':
      return MotionPalette.light;
    default:
      problems.add(path, '"$name" is not a palette; use dark or light');
      return MotionPalette.dark;
  }
}

Color _hexColour(String value) {
  final String digits = value.substring(1);
  final int parsed = int.parse(digits, radix: 16);
  return Color(digits.length == 6 ? 0xFF000000 | parsed : parsed);
}

SceneTransition? _parseTransition(
  Object? json,
  String path,
  Problems problems,
) {
  if (json == null) return null;
  if (json is! Map<String, Object?>) {
    problems.add(path, 'must be an object with a "type"');
    return null;
  }

  final Reader reader = Reader(json, path, problems);
  final String? type = reader.oneOf(
    'type',
    <String>{'none', 'fade', 'slide', 'scale'},
    required: true,
  );

  switch (type) {
    case 'none':
      reader.rejectUnknownKeys(<String>{'type'});
      return const SceneTransition.none();
    case 'fade':
      reader.rejectUnknownKeys(<String>{'type', 'frames'});
      return SceneTransition.fade(
        frames: reader.plainInt('frames') ?? 8,
      );
    case 'slide':
      reader
        ..rejectUnknownKeys(<String>{'type', 'frames', 'x', 'y', 'curve', 'fade'})
        ..oneOf('curve', namedCurves.keys.toSet());
      return SceneTransition.slide(
        frames: reader.plainInt('frames') ?? 12,
        offset: Offset(
          reader.plainNumber('x')?.toDouble() ?? 0,
          reader.plainNumber('y')?.toDouble() ?? 60,
        ),
        curve: namedCurves[json['curve']] ?? Curves.easeOutCubic,
        fade: reader.boolean('fade') ?? true,
      );
    case 'scale':
      reader
        ..rejectUnknownKeys(<String>{'type', 'frames', 'scale', 'curve', 'fade'})
        ..oneOf('curve', namedCurves.keys.toSet());
      return SceneTransition.scale(
        frames: reader.plainInt('frames') ?? 12,
        scale: reader.plainNumber('scale')?.toDouble() ?? 0.94,
        curve: namedCurves[json['curve']] ?? Curves.easeOutCubic,
        fade: reader.boolean('fade') ?? true,
      );
    default:
      return null;
  }
}
