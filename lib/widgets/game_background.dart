import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Full-bleed background image with a subtle vertical scrim so foreground
/// UI (HUD, board, buttons) always stays readable.
class GameBackground extends StatelessWidget {
  const GameBackground({
    super.key,
    required this.image,
    required this.child,
    this.scrim = 0.35,
  });

  final String image;
  final Widget child;
  final double scrim;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.screenGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(image, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: scrim + 0.1),
                  Colors.black.withValues(alpha: scrim * 0.4),
                  Colors.black.withValues(alpha: scrim + 0.15),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
