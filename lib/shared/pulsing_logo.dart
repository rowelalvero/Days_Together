import 'package:flutter/material.dart';

class PulsingLogo extends StatefulWidget {
  final double size;
  final Color? color;

  const PulsingLogo({
    super.key,
    this.size = 80,
    this.color,
  });

  @override
  State<PulsingLogo> createState() => _PulsingLogoState();
}

class _PulsingLogoState extends State<PulsingLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 4, end: 16).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoColor = widget.color ?? Colors.pinkAccent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: logoColor.withValues(alpha: 0.3),
                  blurRadius: _glowAnimation.value,
                  spreadRadius: _glowAnimation.value / 2,
                ),
              ],
            ),
            child: Icon(
              Icons.all_inclusive_rounded, // Infinity symbol representing eternal love
              size: widget.size,
              color: logoColor,
            ),
          ),
        );
      },
    );
  }
}
