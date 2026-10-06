import 'package:flutter/material.dart';

import '../theme/motify_theme.dart';

/// Section heading in code-comment style: `// steps_today`.
class TerminalLabel extends StatelessWidget {
  final String text;
  const TerminalLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        '// $text',
        style: const TextStyle(
          color: MotifyColors.textDim,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      );
}

/// A terminal cursor that blinks after a piece of text.
class BlinkingCursor extends StatefulWidget {
  final TextStyle? style;
  const BlinkingCursor({super.key, this.style});

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (_, child) => Opacity(opacity: _controller.value < 0.5 ? 1 : 0, child: child),
        child: Text('_', style: widget.style),
      );
}

/// Bracketed status tag, e.g. `[LOCKED]`.
class StatusTag extends StatelessWidget {
  final String text;
  final Color color;
  const StatusTag(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          border: Border.all(color: color.withValues(alpha: 0.6)),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      );
}

/// Progress drawn as discrete segments, like a terminal loading bar.
class SegmentedProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final int segments;
  final double height;

  const SegmentedProgressBar({
    super.key,
    required this.value,
    this.color = MotifyColors.neon,
    this.segments = 24,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final filled = (value.clamp(0.0, 1.0) * segments).round();
    return Row(
      children: [
        for (var i = 0; i < segments; i++)
          Expanded(
            child: Container(
              height: height,
              margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 2),
              decoration: BoxDecoration(
                color: i < filled ? color : MotifyColors.panelHighest,
                boxShadow: i < filled
                    ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6)]
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// Faint grid behind a screen's content, fading out towards the bottom.
class GridBackground extends StatelessWidget {
  final Widget child;
  const GridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: _GridPainter())),
          ),
          child,
        ],
      );
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  static const _spacing = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          MotifyColors.neon.withValues(alpha: 0.07),
          MotifyColors.neon.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += _spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += _spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
