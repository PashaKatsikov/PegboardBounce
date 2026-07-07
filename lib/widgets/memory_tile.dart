import 'package:flutter/material.dart';

import '../core/app_assets.dart';
import '../core/app_theme.dart';
import '../game/game_controller.dart';
import 'flip_card.dart';

/// A single board cell: a recessed socket that flips between the "?" cover and
/// a coloured ball. Matched balls get a soft celebratory glow.
class MemoryTile extends StatelessWidget {
  const MemoryTile({
    super.key,
    required this.colorIndex,
    required this.status,
    required this.onTap,
  });

  final int colorIndex;
  final TileStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final faceUp = status != TileStatus.hidden;
    final matched = status == TileStatus.matched;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            alignment: Alignment.center,
            children: [
              _socket(),
              FlipCard(
                showFront: faceUp,
                back: _cover(),
                front: _ball(matched),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socket() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.15),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 4,
            spreadRadius: -1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _cover() {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Image.asset(AppAssets.question, fit: BoxFit.contain),
    );
  }

  Widget _ball(bool matched) {
    final assetIndex = AppAssets.usableBallIndices[
        colorIndex % AppAssets.usableBallIndices.length];
    final ball = Padding(
      padding: const EdgeInsets.all(4),
      child: Image.asset(AppAssets.ball(assetIndex), fit: BoxFit.contain),
    );

    if (!matched) return ball;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.goldLight.withValues(alpha: 0.55),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ball,
    );
  }
}
