import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The "Premium Studio" toggle card on [SettingsTab]. Extracted from its
/// `_buildPremiumGlassCard` (Migration audit item 6).
class PremiumGlassCard extends StatelessWidget {
  const PremiumGlassCard({
    super.key,
    required this.isPremium,
    required this.theme,
    required this.onChanged,
  });

  final bool isPremium;
  final LoveStoryTheme theme;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(4),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.amber.withValues(alpha: 0.15),
          Colors.amber.withValues(alpha: 0.05),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Colors.amber,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
        ),
        title: Text(
          'Premium Studio',
          style: AppTypography.body(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Unlock exclusive liquid glass themes',
          style: AppTypography.caption(
            color: theme.textColor.withValues(alpha: 0.54),
            fontSize: 11,
          ),
        ),
        trailing: Switch.adaptive(
          value: isPremium,
          onChanged: onChanged,
          activeTrackColor: Colors.amber,
        ),
      ),
    );
  }
}
