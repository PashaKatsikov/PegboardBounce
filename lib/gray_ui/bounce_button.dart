import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// Primary action button for the gray shell (Retry / Accept / Skip).
///
/// A fresh design distinct from the game's [GoldButton]: a rounded
/// gold-gradient rectangle with a subtle inner highlight, purple
/// outline and a soft press-shrink reaction.
class BounceButton extends StatefulWidget {
  const BounceButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width,
    this.compact = false,
    this.variant = BounceVariant.primary,
  });

  final String label;
  final VoidCallback onTap;
  final double? width;
  final bool compact;
  final BounceVariant variant;

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

enum BounceVariant { primary, ghost }

class _BounceButtonState extends State<BounceButton> {
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final bool isPrimary = widget.variant == BounceVariant.primary;
    final double vPad = widget.compact ? 12 : 16;
    final double hPad = widget.compact ? 22 : 30;

    final Gradient fill = isPrimary
        ? AppColors.goldGradient
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFF5C36A6),
              Color(0xFF3A1E75),
            ],
          );

    final Color borderColor = isPrimary
        ? const Color(0xFF8B5F14)
        : AppColors.goldLight.withValues(alpha: 0.6);
    final Color textColor =
        isPrimary ? const Color(0xFF3A2200) : AppColors.textLight;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _held = true),
      onTapCancel: () => setState(() => _held = false),
      onTapUp: (_) {
        setState(() => _held = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _held ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: widget.width,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            gradient: fill,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.6),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: (isPrimary
                        ? const Color(0xFFB8862B)
                        : const Color(0xFF20114A))
                    .withValues(alpha: 0.55),
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                offset: const Offset(0, 6),
                blurRadius: 14,
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.label.toUpperCase(),
              style: AppText.label(
                widget.compact ? 15 : 17,
                color: textColor,
              ).copyWith(
                height: 1.0,
                letterSpacing: 1.1,
                shadows: isPrimary
                    ? <Shadow>[
                        const Shadow(
                          color: Color(0x66FFF4CB),
                          offset: Offset(0, 1),
                          blurRadius: 0,
                        ),
                      ]
                    : <Shadow>[
                        const Shadow(
                          color: Colors.black45,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
