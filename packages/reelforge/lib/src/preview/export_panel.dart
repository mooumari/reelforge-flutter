import 'package:flutter/widgets.dart';

import '../export/exporter.dart';
import 'controls.dart';
import 'theme.dart';

/// Shows what an in-app export is doing, over the canvas.
///
/// Exporting is the one thing in the preview that takes real time, so it gets
/// real feedback: how far along, how long is left, and a way out.
class ExportPanel extends StatelessWidget {
  const ExportPanel({
    super.key,
    required this.progress,
    required this.result,
    required this.error,
    required this.onCancel,
    required this.onDismiss,
  });

  final ExportProgress? progress;
  final ExportResult? result;
  final String? error;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;

  bool get _visible => progress != null || result != null || error != null;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xCC08080C),
        child: Center(
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: PreviewColors.chrome,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: PreviewColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _body(),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    if (error != null) {
      return <Widget>[
        const Text('Export failed', style: PreviewText.label),
        const SizedBox(height: 8),
        Text(error!, style: PreviewText.dim),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: PreviewButton(label: 'Close', onPressed: onDismiss),
        ),
      ];
    }

    if (result != null) {
      final ExportResult r = result!;
      final double seconds = r.elapsed.inMilliseconds / 1000;
      return <Widget>[
        const Text('Exported', style: PreviewText.label),
        const SizedBox(height: 8),
        Text(r.outputPath, style: PreviewText.monoDim),
        const SizedBox(height: 6),
        Text(
          '${r.frames} frames  ${r.width}x${r.height}  '
          'in ${seconds.toStringAsFixed(2)}s',
          style: PreviewText.dim,
        ),
        for (final String warning in r.warnings) ...<Widget>[
          const SizedBox(height: 8),
          Text(warning, style: PreviewText.dim),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: PreviewButton(
              label: 'Done', onPressed: onDismiss, primary: true),
        ),
      ];
    }

    final ExportProgress p = progress!;
    final Duration? left = p.remaining;
    return <Widget>[
      const Text('Exporting', style: PreviewText.label),
      const SizedBox(height: 12),
      _Bar(fraction: p.fraction),
      const SizedBox(height: 8),
      Text(
        '${p.frame} / ${p.totalFrames} frames'
        '${left == null ? '' : '   ~${left.inSeconds}s left'}',
        style: PreviewText.monoDim,
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerRight,
        child: PreviewButton(label: 'Cancel', onPressed: onCancel),
      ),
    ];
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Stack(
          children: <Widget>[
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: PreviewColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Container(
              height: 6,
              width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: PreviewColors.accent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        );
      },
    );
  }
}
