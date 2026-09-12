import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/app/shell/widgets/feature_bullet.dart';

/// The "Love Studio Premium" paywall bottom sheet, opened from
/// [StudioTab]. Extracted from its `_showPremiumPaywall` (Migration audit
/// item 6) -- [onUnlock] performs the actual `setPremium(true)` write,
/// which stays on the tab since it's a state mutation, not rendering.
///
/// Shown directly as a `showModalBottomSheet` builder, matching this app's
/// other sheets -- no `.show()` static helper.
class PremiumPaywallSheet extends StatelessWidget {
  const PremiumPaywallSheet({
    super.key,
    required this.theme,
    required this.onUnlock,
  });

  final LoveStoryTheme theme;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.textColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '✨ Love Studio Premium',
            style: AppTypography.heading(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Unlock the full magic of AI and digital connection.',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              color: theme.textColor.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          FeatureBullet(
            icon: Icons.edit_note_rounded,
            title: 'AI Love Letter Generator',
            desc: 'Create poetic love letters from your timeline memories.',
            theme: theme,
          ),
          FeatureBullet(
            icon: Icons.insights_rounded,
            title: 'Deep Relationship Insights',
            desc:
                'Get fun stats, relationship analysis & compatibility scores.',
            theme: theme,
          ),
          FeatureBullet(
            icon: Icons.alarm_on_rounded,
            title: 'Unlimited Future Time Capsules',
            desc: 'Write to your future selves with no date restrictions.',
            theme: theme,
          ),
          FeatureBullet(
            icon: Icons.palette_rounded,
            title: 'Exclusive App Themes',
            desc: 'Access premium romantic and celestial color palettes.',
            theme: theme,
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () {
                onUnlock();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✨ Welcome to Love Studio Premium!'),
                    backgroundColor: Colors.pinkAccent,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Unlock Premium — \$0.00 (Free Test)',
                style: AppTypography.button(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'This is a local demo. Toggling is completely free.',
            style: AppTypography.caption(
              color: theme.textColor.withValues(alpha: 0.3),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
