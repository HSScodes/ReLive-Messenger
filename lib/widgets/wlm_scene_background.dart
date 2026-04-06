import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Recreates the default WLM 2009 "blue sky with light rays" scene background.
///
/// In the original WLM, this was a photographic scene from sceneres.dll.
/// Since the asset isn't available, this widget faithfully recreates the look
/// using gradients and a custom painter for the soft light rays.
class WlmSceneBackground extends StatelessWidget {
  const WlmSceneBackground({super.key, this.height = 200});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Base sky gradient
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5EB3E4), // deeper sky blue at top
                  Color(0xFF8CCBEF), // mid sky blue
                  Color(0xFFB4DDF5), // lighter blue
                  Color(0xFFD6ECF9), // very light blue at bottom
                ],
                stops: [0.0, 0.3, 0.65, 1.0],
              ),
            ),
          ),
          // Soft light rays from bottom-left
          CustomPaint(
            painter: _LightRaysPainter(),
          ),
          // Cloud-like soft overlay at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: height * 0.45,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.15),
                    Colors.white.withValues(alpha: 0.30),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightRaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.15, size.height * 1.1);

    // Draw several soft white rays fanning out from bottom-left
    const rayCount = 7;
    const baseAngle = -math.pi / 2.6;
    const spread = math.pi / 3.5;

    for (int i = 0; i < rayCount; i++) {
      final t = i / (rayCount - 1);
      final angle = baseAngle + spread * t;
      final rayLength = size.width * 1.6;

      final endPoint = Offset(
        origin.dx + rayLength * math.cos(angle),
        origin.dy + rayLength * math.sin(angle),
      );

      // Each ray is a thin gradient line
      final opacity = 0.06 + 0.04 * math.sin(t * math.pi);
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromPoints(origin, endPoint))
        ..strokeWidth = 18 + 14 * t
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(origin, endPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
