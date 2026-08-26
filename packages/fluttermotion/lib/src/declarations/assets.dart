import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'manifest.dart';

/// Images that have been fully decoded and are safe to paint synchronously.
///
/// The whole point: a composition must never wait on an image mid-render. If
/// frame 12 could show a placeholder on one run and the photo on the next, the
/// render is not deterministic.
class ResolvedImages extends InheritedWidget {
  const ResolvedImages({
    super.key,
    required this.images,
    required super.child,
  });

  final Map<ImageProvider<Object>, ui.Image> images;

  static ResolvedImages? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ResolvedImages>();

  ui.Image? operator [](ImageProvider<Object> provider) => images[provider];

  @override
  bool updateShouldNotify(ResolvedImages oldWidget) =>
      !identical(images, oldWidget.images);
}

/// Decodes every declared image up front.
abstract final class ImagePreloader {
  static Future<Map<ImageProvider<Object>, ui.Image>> resolveAll(
    Iterable<ImageDeclaration> declarations,
  ) async {
    final Map<ImageProvider<Object>, ui.Image> resolved =
        <ImageProvider<Object>, ui.Image>{};
    for (final ImageDeclaration declaration in declarations) {
      resolved[declaration.provider] = await resolve(declaration);
    }
    return resolved;
  }

  static Future<ui.Image> resolve(ImageDeclaration declaration) {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    final ImageStream stream =
        declaration.provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;

    listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (!completer.isCompleted) completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stack) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError(
              'Could not load ${declaration.debugLabel}: $error\n'
              'Every image a composition uses must resolve before rendering '
              'starts, otherwise frames would differ between runs.',
            ),
            stack,
          );
        }
        stream.removeListener(listener);
      },
    );

    stream.addListener(listener);
    return completer.future;
  }
}
