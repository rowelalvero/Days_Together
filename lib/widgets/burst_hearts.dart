import 'dart:math';
import 'package:flutter/material.dart';

class BurstHeartsWidget extends StatefulWidget {
  final VoidCallback? onComplete;

  const BurstHeartsWidget({super.key, this.onComplete});

  @override
  State<BurstHeartsWidget> createState() => _BurstHeartsWidgetState();
}

class _BurstHeartsWidgetState extends State<BurstHeartsWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_HeartParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Generate 12 heart particles with random starting trajectories
    for (int i = 0; i < 12; i++) {
      _particles.add(
        _HeartParticle(
          x: 0.5 + (_random.nextDouble() - 0.5) * 0.4, // Centered horizontally
          y: 0.8, // Rise from bottom
          dx: (_random.nextDouble() - 0.5) * 0.3,
          dy: -0.4 - _random.nextDouble() * 0.4,
          size: 16 + _random.nextDouble() * 20,
          opacity: 0.8 + _random.nextDouble() * 0.2,
          color: Colors.pinkAccent.withValues(
            alpha: 0.6 + _random.nextDouble() * 0.4,
          ),
        ),
      );
    }

    _controller.forward().then((_) {
      if (widget.onComplete != null) widget.onComplete!();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Stack(
          children: _particles.map((p) {
            final x = p.x + p.dx * progress;
            final y = p.y + p.dy * progress;
            final opacity = (p.opacity * (1.0 - progress)).clamp(0.0, 1.0);
            final scale = 0.5 + progress * 0.5;

            return Positioned(
              left: MediaQuery.of(context).size.width * x - (p.size / 2),
              top: MediaQuery.of(context).size.height * y - (p.size / 2),
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Icon(
                    Icons.favorite_rounded,
                    color: p.color,
                    size: p.size,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _HeartParticle {
  final double x;
  final double y;
  final double dx;
  final double dy;
  final double size;
  final double opacity;
  final Color color;

  const _HeartParticle({
    required this.x,
    required this.y,
    required this.dx,
    required this.dy,
    required this.size,
    required this.opacity,
    required this.color,
  });
}
