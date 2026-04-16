import 'package:flutter/material.dart';

/// Уникальная иконка «Телепатия» — две волны мысли, сходящиеся к центру.
/// Символизирует ментальную связь. В центре — фокус связи.
class TelepathyIcon extends StatelessWidget {
  final double size;
  final Color? color;
  final bool filled;

  const TelepathyIcon({
    super.key,
    this.size = 24,
    this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? IconTheme.of(context).color ?? Colors.grey;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TelepathyIconPainter(color: effectiveColor, filled: filled),
      ),
    );
  }
}

class _TelepathyIconPainter extends CustomPainter {
  final Color color;
  final bool filled;

  _TelepathyIconPainter({required this.color, required this.filled});

  @override
  void paint(Canvas canvas, Size size) {
    // Толщина штриха как у Material Icons (~2dp для 24dp)
    final strokeW = size.width * 0.083;
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = filled ? strokeW * 1.4 : strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final cx = w / 2;
    final cy = w / 2;
    final r = w * 0.4;

    // Две дуги — в стиле Material Icons (контуры, скруглённые концы)
    final left = Path();
    left.moveTo(cx - r * 0.5, cy - r * 0.55);
    left.cubicTo(
      cx - r * 1.06, cy - r * 0.15,
      cx - r * 1.06, cy + r * 0.15,
      cx - r * 0.5, cy + r * 0.55,
    );
    canvas.drawPath(left, strokePaint);

    final right = Path();
    right.moveTo(cx + r * 0.5, cy + r * 0.55);
    right.cubicTo(
      cx + r * 1.06, cy + r * 0.15,
      cx + r * 1.06, cy - r * 0.15,
      cx + r * 0.5, cy - r * 0.55,
    );
    canvas.drawPath(right, strokePaint);

    // Центр: outline — контур круга, filled — заливка (как у chat_bubble/phone)
    if (filled) {
      canvas.drawCircle(Offset(cx, cy), w * 0.065, fillPaint);
    } else {
      canvas.drawCircle(Offset(cx, cy), w * 0.065, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TelepathyIconPainter oldDelegate) =>
      color != oldDelegate.color || filled != oldDelegate.filled;
}
