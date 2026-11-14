import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Exact geometric "E" with rightward chevron middle bar on the Edged violet-to-blue gradient.
class EdgedLogo extends StatelessWidget {
  final double size;
  final double borderRadius;

  const EdgedLogo({
    super.key,
    this.size = 76,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandPurpleMid.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _EdgedLogoPainter(),
      ),
    );
  }
}

class _EdgedLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Coordinates mapped from 512x512 appiconfg.svg
    final sx = size.width / 512.0;
    final sy = size.height / 512.0;

    // Vertical stem: (108, 106, 68, 300)
    canvas.drawRect(
      Rect.fromLTWH(108 * sx, 106 * sy, 68 * sx, 300 * sy),
      paint,
    );
    // Top horizontal bar: (108, 106, 244, 66)
    canvas.drawRect(
      Rect.fromLTWH(108 * sx, 106 * sy, 244 * sx, 66 * sy),
      paint,
    );
    // Middle bar — chevron pointing right
    final chevron = Path()
      ..moveTo(108 * sx, 222 * sy)
      ..lineTo(312 * sx, 222 * sy)
      ..lineTo(404 * sx, 256 * sy)
      ..lineTo(312 * sx, 290 * sy)
      ..lineTo(108 * sx, 290 * sy)
      ..close();
    canvas.drawPath(chevron, paint);

    // Bottom horizontal bar: (108, 340, 244, 66)
    canvas.drawRect(
      Rect.fromLTWH(108 * sx, 340 * sy, 244 * sx, 66 * sy),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
