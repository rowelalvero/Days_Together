import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The italic story-text card on [MemoryDetailScreen]. Extracted from the
/// screen's `build()` (Migration audit item 6).
class MemoryDescriptionCard extends StatelessWidget {
  const MemoryDescriptionCard({
    super.key,
    required this.description,
    required this.theme,
  });

  final String description;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      borderRadius: 30,
      opacity: 0.08,
      child: Text(
        description,
        style: AppTypography.lora(
          fontSize: 18,
          color: theme.textColor.withValues(alpha: 0.9),
          height: 1.8,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
