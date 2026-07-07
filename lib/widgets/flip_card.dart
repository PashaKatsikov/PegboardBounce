import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A 3D Y-axis flip between a [back] (cover) and [front] (revealed) widget.
/// Driven purely by the [showFront] flag so parents can stay declarative.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.showFront,
    required this.front,
    required this.back,
    this.duration = const Duration(milliseconds: 340),
  });

  final bool showFront;
  final Widget front;
  final Widget back;
  final Duration duration;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.showFront ? 1.0 : 0.0,
  );

  late final Animation<double> _anim =
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showFront != oldWidget.showFront) {
      if (widget.showFront) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final value = _anim.value; // 0 = back, 1 = front
        final angle = value * math.pi;
        final showingFront = angle > math.pi / 2;

        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateY(angle);

        Widget child;
        if (showingFront) {
          // Counter-rotate so the front isn't mirrored.
          child = Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..rotateY(math.pi),
            child: widget.front,
          );
        } else {
          child = widget.back;
        }

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: child,
        );
      },
    );
  }
}
