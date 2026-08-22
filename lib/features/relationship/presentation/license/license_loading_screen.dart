import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// The animated "generating your license" loading screen shown after
/// submitting the creation form. Extracted out of
/// `RelationshipLicenseScreenState._buildLoadingScreen` (Migration
/// Phase 8).
class LicenseLoadingScreen extends StatelessWidget {
  const LicenseLoadingScreen({
    super.key,
    required this.theme,
    required this.loadingMessage,
    required this.loadingStep,
  });

  final LoveStoryTheme theme;
  final String loadingMessage;

  /// Only used as the `AnimatedSwitcher`'s `ValueKey`, to trigger the
  /// transition on each step -- the actual text to show is
  /// [loadingMessage].
  final int loadingStep;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.watch<ThemeProvider>().currentGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                      strokeWidth: 3.5,
                    ),
                  ),
                  Icon(
                    Icons.favorite_rounded,
                    color: theme.accentColor,
                    size: 38,
                  ),
                ],
              ),
              const SizedBox(height: 48),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  loadingMessage,
                  key: ValueKey<int>(loadingStep),
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textColor),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  backgroundColor: theme.textColor.withValues(alpha: 0.1),
                  color: theme.accentColor,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
