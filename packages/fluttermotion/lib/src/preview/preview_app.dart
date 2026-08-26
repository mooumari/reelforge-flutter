import 'package:flutter/widgets.dart';

import '../composition.dart';
import 'player.dart';
import 'theme.dart';

/// Entry point for a preview app.
///
/// ```dart
/// // lib/main.dart
/// void main() => previewMain(<Composition>[myPromo]);
/// ```
///
/// Then `flutter run -d macos` and scrub. Hot reload applies to compositions
/// like any other Flutter code -- edit a widget, save, and the frame you are
/// parked on redraws immediately.
///
/// [projectPath] is the root a video clip's `src` is resolved against. It
/// defaults to the working directory, which is the project root under
/// `flutter run`.
void previewMain(List<Composition> compositions, {String? projectPath}) {
  runApp(FlutterMotionPreview(
    compositions: compositions,
    projectPath: projectPath,
  ));
}

class FlutterMotionPreview extends StatefulWidget {
  const FlutterMotionPreview({
    super.key,
    required this.compositions,
    this.projectPath,
  });

  final List<Composition> compositions;

  /// Root that a clip's `src` is resolved against.
  final String? projectPath;

  @override
  State<FlutterMotionPreview> createState() => _FlutterMotionPreviewState();
}

class _FlutterMotionPreviewState extends State<FlutterMotionPreview> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery.fromView(
        view: View.of(context),
        child: DefaultTextStyle(
          style: PreviewText.label,
          child: ColoredBox(
            color: PreviewColors.background,
            child: widget.compositions.isEmpty
                ? const _Empty()
                : _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    // Hot reload can remove the composition currently being viewed.
    final int index = _selected.clamp(0, widget.compositions.length - 1);
    final Composition composition = widget.compositions[index];

    return Row(
      children: <Widget>[
        if (widget.compositions.length > 1)
          _Sidebar(
            compositions: widget.compositions,
            selected: index,
            onSelect: (int i) => setState(() => _selected = i),
          ),
        Expanded(
          child: CompositionPlayer(
            projectPath: widget.projectPath,
            // Rebuild player state from scratch when switching compositions,
            // rather than carrying a playhead across different durations.
            key: ValueKey<String>(composition.id),
            composition: composition,
          ),
        ),
      ],
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.compositions,
    required this.selected,
    required this.onSelect,
  });

  final List<Composition> compositions;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: PreviewColors.chrome,
        border: Border(right: BorderSide(color: PreviewColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Text('COMPOSITIONS',
                style: TextStyle(
                  fontSize: 10,
                  color: PreviewColors.textDim,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                )),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: compositions.length,
              itemBuilder: (BuildContext context, int i) => _SidebarItem(
                composition: compositions[i],
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.composition,
    required this.selected,
    required this.onTap,
  });

  final Composition composition;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Composition c = widget.composition;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: widget.selected
                ? PreviewColors.accentDim
                : _hovered
                    ? PreviewColors.chromeRaised
                    : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                c.id,
                style: PreviewText.label.copyWith(
                  color: widget.selected
                      ? PreviewColors.text
                      : PreviewColors.text.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${c.width}x${c.height}  ·  '
                '${(c.durationInFrames / c.fps).toStringAsFixed(1)}s',
                style: PreviewText.monoDim.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No compositions passed to previewMain().',
        style: PreviewText.dim,
      ),
    );
  }
}
