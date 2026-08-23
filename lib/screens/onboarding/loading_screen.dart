import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _timeoutTimer;
  bool _showRetry = false;
  bool _isOffline = false;

  static const _timeoutDuration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _checkConnectivity();
    _startTimeout();
  }

  void _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      if (!isOnline && mounted) {
        setState(() {
          _isOffline = true;
          _showRetry = true;
        });
      }
    } catch (_) {
      // Connectivity check failed — let timeout handle it
    }
  }

  void _startTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(_timeoutDuration, () {
      if (mounted && !context.read<CoupleSession>().isInitialized) {
        setState(() => _showRetry = true);
      }
    });
  }

  void _handleRetry() {
    setState(() {
      _showRetry = false;
      _isOffline = false;
    });

    // Force re-initialization by reading the session
    // The session's auth listener will re-fire on reconnect
    final session = context.read<CoupleSession>();
    if (!session.isInitialized) {
      // Mark as initialized to allow the user through if still stuck
      // The auth listener will correct state once connectivity returns
      session.forceInitialized();
    }

    _startTimeout();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
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
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: themeProvider.currentGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: Tween<double>(begin: 0.9, end: 1.1).animate(
                  CurvedAnimation(
                    parent: _pulseController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: theme.accentColor,
                  size: 80,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isOffline
                    ? 'You appear to be offline'
                    : 'A little magic is loading...',
                style: AppTypography.spectral(
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  color: theme.textColor,
                ),
              ),

              // Retry / Continue CTA that appears after timeout or offline detection
              AnimatedSize(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: _showRetry
                    ? Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isOffline
                                  ? 'Check your connection and try again.'
                                  : 'Taking longer than expected...',
                              style: AppTypography.body(
                                fontSize: 13,
                                color: theme.textColor.withValues(alpha: 0.5),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: 200,
                              child: ElevatedButton(
                                onPressed: _handleRetry,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.accentColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 0,
                                ),
                                child: Text(
                                  _isOffline ? 'Retry' : 'Continue Anyway',
                                  style: AppTypography.body(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
