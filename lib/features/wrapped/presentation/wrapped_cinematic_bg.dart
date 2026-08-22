import 'package:flutter/material.dart';

/// Animated fullscreen gradient background — each page sends its own gradient.
/// Uses [AnimatedContainer] for smooth cross-page color transitions.
class WrappedCinematicBg extends StatelessWidget {
  final List<Color> colors;
  final Widget child;

  const WrappedCinematicBg({
    super.key,
    required this.colors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: child,
    );
  }
}

/// Per-page background gradient definitions.
class WrappedGradients {
  static const welcome = [Color(0xFF1a0033), Color(0xFF3d0066), Color(0xFF1a0033)];
  static const days    = [Color(0xFF0d1b2a), Color(0xFF1b2838), Color(0xFF0d1b2a)];
  static const growth  = [Color(0xFF0f2027), Color(0xFF203a43), Color(0xFF2c5364)];
  static const memories= [Color(0xFF1a0533), Color(0xFF2d0b4e), Color(0xFF1a0533)];
  static const notes   = [Color(0xFF200122), Color(0xFF6f0000), Color(0xFF200122)];
  static const bucket  = [Color(0xFF004d40), Color(0xFF00695c), Color(0xFF004d40)];
  static const mood    = [Color(0xFF1a237e), Color(0xFF283593), Color(0xFF1a237e)];
  static const calendar= [Color(0xFF880e4f), Color(0xFFad1457), Color(0xFF880e4f)];
  static const capsule = [Color(0xFF0d3b5e), Color(0xFF1565c0), Color(0xFF0d3b5e)];
  static const stats   = [Color(0xFF212121), Color(0xFF37474f), Color(0xFF212121)];
  static const milestones=[Color(0xFF4a148c), Color(0xFF6a1b9a), Color(0xFF4a148c)];
  static const featured = [Color(0xFF1c1c2e), Color(0xFF2d2d44), Color(0xFF1c1c2e)];
  static const letter  = [Color(0xFF1b1b2f), Color(0xFF2c2c54), Color(0xFF1b1b2f)];
  static const finale  = [Color(0xFF0a0a1a), Color(0xFF1a0033), Color(0xFF0a0a1a)];

  static List<List<Color>> get all => [
    welcome, days, growth, memories, notes,
    bucket, mood, calendar, capsule, stats,
    milestones, featured, letter, finale,
  ];
}
