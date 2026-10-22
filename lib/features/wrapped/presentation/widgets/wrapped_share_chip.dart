import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';

/// One stat pill (e.g. "365 Days") on [WrappedShareCard]. Extracted from
/// [WrappedPageFinale]'s `_shareChip` method (Migration audit item 6).
class WrappedShareChip extends StatelessWidget {
  const WrappedShareChip({super.key, required this.text, required this.emoji});

  final String text;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: AppTypography.body(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
