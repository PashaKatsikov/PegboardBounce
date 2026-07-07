import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../game/difficulty.dart';

/// A tappable row presenting one difficulty option: its name, board size,
/// pair count and the player's best score for it.
class DifficultyCard extends StatefulWidget {
  const DifficultyCard({
    super.key,
    required this.difficulty,
    required this.best,
    required this.onTap,
  });

  final Difficulty difficulty;
  final int best;
  final VoidCallback onTap;

  @override
  State<DifficultyCard> createState() => _DifficultyCardState();
}

class _DifficultyCardState extends State<DifficultyCard> {
  bool _down = false;

  IconData get _icon => switch (widget.difficulty) {
        Difficulty.easy => Icons.sentiment_satisfied_alt_rounded,
        Difficulty.medium => Icons.bolt_rounded,
        Difficulty.hard => Icons.local_fire_department_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final d = widget.difficulty;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppColors.panelGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldGradient,
                ),
                child: Icon(_icon, color: const Color(0xFF5A3B08), size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.label.toUpperCase(), style: AppText.title(19)),
                    const SizedBox(height: 2),
                    Text(
                      '${d.gridLabel}  \u2022  ${d.pairs} pairs',
                      style: AppText.body(13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: AppColors.goldLight, size: 18),
                  const SizedBox(height: 2),
                  Text('${widget.best}', style: AppText.label(15)),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.goldLight, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
