import 'package:days_together/themes/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/routing/routes.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: themeProvider.currentGradient,
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Pulsing Infinity Logo
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = 1.0 + (_pulseController.value * 0.08);
                  final glowOpacity = 0.15 + (_pulseController.value * 0.2);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.textColor.withValues(alpha: 0.05),
                        border: Border.all(
                          color: theme.textColor.withValues(alpha: 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.accentColor.withValues(alpha: glowOpacity),
                            blurRadius: 40,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.all_inclusive,
                          size: 60,
                          color: theme.accentColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              Text(
                'A dedicated space for the two of you.',
                style: AppTypography.cormorant(
                  fontSize: 26,
                  fontStyle: FontStyle.italic,
                  color: theme.textColor,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your story continues here.',
                style: AppTypography.spectral(
                  fontSize: 18,
                  color: theme.textColor.withValues(alpha: 0.7),
                ).copyWith(letterSpacing: 1.2),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    _buildActionButton(
                      label: 'Begin Your Story',
                      onPressed: () {
                        if (_isNavigating) return;
                        _isNavigating = true;
                        // The custom fade transition moved to
                        // app_router.dart's Routes.auth route (a
                        // CustomTransitionPage), so it still applies here.
                        context.push(Routes.auth).then((_) {
                          if (mounted) _isNavigating = false;
                        });
                      },
                      isPrimary: true,
                      theme: theme,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Made with love for couples.',
                      style: AppTypography.spectral(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: theme.textColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
    required LoveStoryTheme theme,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.button(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ).copyWith(letterSpacing: 1.1),
        ),
      ),
    );
  }
}
