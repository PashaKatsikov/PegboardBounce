import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The premium "pegboard" board container: a metallic gold frame around a
/// recessed purple play surface, decorated with gold rivets along the edge.
/// Mirrors the look of the app icon.
class PegboardPanel extends StatelessWidget {
  const PegboardPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    const frame = 12.0;
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.goldGradient,
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(frame),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.panelGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppColors.deepPurple.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 14,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: CustomPaint(
          foregroundPainter: _RivetPainter(),
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _RivetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 12.0;
    const radius = 3.2;

    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );

    // Roughly square rivet spacing along each edge.
    final countX = (rect.width / 46).round().clamp(3, 8);
    final countY = (rect.height / 46).round().clamp(3, 10);

    final positions = <Offset>[];
    for (int i = 0; i <= countX; i++) {
      final x = rect.left + rect.width * i / countX;
      positions.add(Offset(x, rect.top));
      positions.add(Offset(x, rect.bottom));
    }
    for (int j = 1; j < countY; j++) {
      final y = rect.top + rect.height * j / countY;
      positions.add(Offset(rect.left, y));
      positions.add(Offset(rect.right, y));
    }

    for (final p in positions) {
      // Shadow / socket.
      canvas.drawCircle(
        p.translate(0, 0.8),
        radius + 0.6,
        Paint()..color = Colors.black.withValues(alpha: 0.35),
      );
      // Gold rivet with a small highlight.
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.goldLight, AppColors.goldDark],
          ).createShader(Rect.fromCircle(center: p, radius: radius)),
      );
      canvas.drawCircle(
        p.translate(-radius * 0.3, -radius * 0.3),
        radius * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RivetPainter oldDelegate) => false;
}
