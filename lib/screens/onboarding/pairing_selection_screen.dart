import 'package:days_together/screens/onboarding/create_couple_code_screen.dart';
import 'package:days_together/screens/onboarding/join_couple_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:provider/provider.dart';

class PairingSelectionScreen extends StatelessWidget {
  const PairingSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
                ),
                const Spacer(),
                Text(
                  'How would you like to\nbegin your story?',
                  style: AppTypography.cormorant(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Choose a path to connect.',
                  style: AppTypography.spectral(
                    fontSize: 16,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 50),
                _PairingCard(
                  icon: Icons.favorite_rounded,
                  title: "Start Our Story",
                  subtitle: "Generate a connection code to invite your partner.",
                  accentColor: theme.accentColor,
                  textColor: theme.textColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateCoupleCodeScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _PairingCard(
                  icon: Icons.link_rounded,
                  title: "Join My Partner",
                  subtitle: "Enter the connection code shared by your partner.",
                  accentColor: theme.accentColor,
                  textColor: theme.textColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const JoinCoupleCodeScreen(),
                      ),
                    );
                  },
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  const _PairingCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: textColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.body(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.caption(
                      color: textColor.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: textColor.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
