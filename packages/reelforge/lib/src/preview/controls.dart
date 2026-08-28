import 'package:flutter/widgets.dart';

import 'theme.dart';

enum TransportIcon { play, pause, stepBack, stepForward, toStart, toEnd, loop }

/// Transport buttons, drawn rather than imported.
///
/// Keeps the framework's only dependency `flutter/widgets` -- pulling in
/// Material for six glyphs would drag its theming into every preview.
class TransportButton extends StatefulWidget {
  const TransportButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.tooltip,
    this.size = 30,
  });

  final TransportIcon icon;
  final VoidCallback? onPressed;
  final bool active;
  final String? tooltip;
  final double size;

  @override
  State<TransportButton> createState() => _TransportButtonState();
}

class _TransportButtonState extends State<TransportButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Color color = !enabled
        ? PreviewColors.border
        : widget.active
            ? PreviewColors.accent
            : _hovered
                ? PreviewColors.text
                : PreviewColors.textDim;

    return MouseRegion(
      cursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.size + 10,
          height: widget.size,
          child: Center(
            child: CustomPaint(
              size: Size.square(widget.size * 0.5),
              painter: _IconPainter(icon: widget.icon, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter({required this.icon, required this.color});

  final TransportIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..color = color;
    final double w = size.width;
    final double h = size.height;

    switch (icon) {
      case TransportIcon.play:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.15, 0)
            ..lineTo(w, h / 2)
            ..lineTo(w * 0.15, h)
            ..close(),
          paint,
        );
      case TransportIcon.pause:
        canvas.drawRect(Rect.fromLTWH(w * 0.12, 0, w * 0.26, h), paint);
        canvas.drawRect(Rect.fromLTWH(w * 0.62, 0, w * 0.26, h), paint);
      case TransportIcon.stepBack:
        canvas.drawPath(
          Path()
            ..moveTo(w, 0)
            ..lineTo(w * 0.2, h / 2)
            ..lineTo(w, h)
            ..close(),
          paint,
        );
      case TransportIcon.stepForward:
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(w * 0.8, h / 2)
            ..lineTo(0, h)
            ..close(),
          paint,
        );
      case TransportIcon.toStart:
        canvas.drawRect(Rect.fromLTWH(0, 0, w * 0.16, h), paint);
        canvas.drawPath(
          Path()
            ..moveTo(w, 0)
            ..lineTo(w * 0.28, h / 2)
            ..lineTo(w, h)
            ..close(),
          paint,
        );
      case TransportIcon.toEnd:
        canvas.drawRect(Rect.fromLTWH(w * 0.84, 0, w * 0.16, h), paint);
        canvas.drawPath(
          Path()
            ..moveTo(0, 0)
            ..lineTo(w * 0.72, h / 2)
            ..lineTo(0, h)
            ..close(),
          paint,
        );
      case TransportIcon.loop:
        final Paint stroke = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = h * 0.16;
        canvas.drawArc(
          Rect.fromLTWH(0, 0, w, h),
          -2.6,
          5.0,
          false,
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.72, 0)
            ..lineTo(w * 1.02, h * 0.2)
            ..lineTo(w * 0.72, h * 0.4)
            ..close(),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color;
}

/// A small dark pill used for the resolution / fps / zoom readouts.
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.label, this.dim = false});

  final String label;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: PreviewColors.chromeRaised,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: dim ? PreviewText.monoDim : PreviewText.mono,
      ),
    );
  }
}

/// A small labelled button for preview chrome that is not transport control.
class PreviewButton extends StatefulWidget {
  const PreviewButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Draws filled rather than outlined, for the one action a panel is about.
  final bool primary;

  @override
  State<PreviewButton> createState() => _PreviewButtonState();
}

class _PreviewButtonState extends State<PreviewButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    final Color accent =
        enabled ? PreviewColors.accent : PreviewColors.border;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        // Deliberately not an AnimatedContainer. The preview drives the
        // animation clock to composition time while rendering a frame,
        // which would drag any implicit animation in the chrome along.
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: widget.primary
                ? (_hovered && enabled
                    ? accent
                    : accent.withValues(alpha: enabled ? 0.85 : 0.3))
                : (_hovered && enabled
                    ? PreviewColors.border
                    : const Color(0x00000000)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.primary ? accent : PreviewColors.border,
            ),
          ),
          child: Text(
            widget.label,
            style: PreviewText.label.copyWith(
              color: widget.primary
                  ? const Color(0xFFFFFFFF)
                  : (enabled
                      ? PreviewColors.text
                      : PreviewColors.border),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
