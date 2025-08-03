// widgets/finance_chart.dart
import 'package:flutter/material.dart';

class FinanceChart extends StatelessWidget {
  const FinanceChart({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: ChartPainter(),
        size: const Size.fromHeight(120),
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue[600]!
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Datos de ejemplo para la gráfica (6 meses)
    final points = [
      Offset(0, size.height * 0.6),
      Offset(size.width * 0.15, size.height * 0.3),
      Offset(size.width * 0.3, size.height * 0.5),
      Offset(size.width * 0.45, size.height * 0.4),
      Offset(size.width * 0.6, size.height * 0.7),
      Offset(size.width * 0.75, size.height * 0.2),
      Offset(size.width * 0.9, size.height * 0.45),
      Offset(size.width, size.height * 0.35),
    ];

    // Crear curva suave
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];

      final cp1x = p0.dx + (p1.dx - p0.dx) / 3;
      final cp1y = p0.dy;
      final cp2x = p1.dx - (p1.dx - p0.dx) / 3;
      final cp2y = p1.dy;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p1.dx, p1.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}