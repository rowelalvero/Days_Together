import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:days_together/features/relationship/presentation/license/painters/watermark_painter.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Shown when no relationship license exists yet, offering to create one.
/// Extracted out of
/// `RelationshipLicenseScreenState._buildFirstTimeWelcomeScreen`
/// (Migration Phase 8).
class FirstTimeLicenseWelcomeScreen extends StatelessWidget {
  const FirstTimeLicenseWelcomeScreen({
    super.key,
    required this.theme,
    required this.onCreatePressed,
  });

  final LoveStoryTheme theme;
  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Relationship License',
          style: AppTypography.cormorant(fontSize: 28, fontWeight: FontWeight.bold, color: theme.textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.watch<ThemeProvider>().currentGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 280,
                    height: 176,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.accentColor.withValues(alpha: 0.3),
                        width: 2.0,
                        style: BorderStyle.solid,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentColor.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CustomPaint(painter: WatermarkPainter()),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 48,
                                color: theme.accentColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'OFFICIAL LOVE LICENSE',
                                style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'No License Found',
                    style: AppTypography.heading(fontSize: 26, fontWeight: FontWeight.bold, color: theme.textColor),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Create your official Relationship License to certify your bond! Fill in your details, draw your signatures, and generate printable & shareable license cards.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(fontSize: 14, fontWeight: FontWeight.w500, color: theme.textColor.withValues(alpha: 0.6), height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: onCreatePressed,
                      icon: const Icon(Icons.add_card_rounded, size: 22),
                      label: Text(
                        'Create License ID',
                        style: AppTypography.body(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
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
