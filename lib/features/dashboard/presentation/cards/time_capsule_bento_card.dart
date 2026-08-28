import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/features/love_studio/time_capsule_controller.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card for the Time Capsule / Future Letters on the dashboard.
/// Displays sealed lockbox countdown and unlock date alerts.
class TimeCapsuleBentoCard extends StatelessWidget {
  final LoveStoryTheme theme;

  const TimeCapsuleBentoCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final lockedCapsules = ref.watch(timeCapsuleControllerProvider).lockedCapsules;
        final hasCapsules = lockedCapsules.isNotEmpty;

        final latestLockedMessage = hasCapsules
            ? lockedCapsules.first.message
            : 'No sealed capsules yet';

        final openDate = hasCapsules ? lockedCapsules.first.openDate : null;

        String countdownText = '--d --h --m';
        if (openDate != null) {
          final duration = openDate.difference(DateTime.now());
          if (duration.isNegative) {
            countdownText = 'Ready to open!';
          } else {
            final days = duration.inDays;
            final hours = duration.inHours % 24;
            final minutes = duration.inMinutes % 60;
            countdownText = '${days}d ${hours}h ${minutes}m';
          }
        }

        final sealedCount = lockedCapsules.length;

        return InkWell(
          onTap: () => context.push(Routes.timeCapsule),
          borderRadius: BorderRadius.circular(24),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'FUTURE LETTERS',
                        style: AppTypography.cardCategory(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: theme.accentColor,
                        ).copyWith(letterSpacing: 0.5),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.hourglass_empty_rounded,
                          color: theme.accentColor,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Time Capsules',
                  style: AppTypography.title(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: !hasCapsules
                      ? Container(
                          height: 100,
                          alignment: Alignment.center,
                          child: Text(
                            'Write a letter to your future selves. Seal it today, and unlock a beautiful memory later! ✉️',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyMedium(
                              fontSize: 12,
                              color: theme.textColor.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    latestLockedMessage,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.heading(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.accentColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'SEALED',
                                    style: AppTypography.bodyMono(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: theme.accentColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 1,
                              color: theme.textColor.withValues(alpha: 0.05),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      color: theme.accentColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'REMAINING:',
                                      style: AppTypography.captionMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: theme.textColor.withValues(alpha: 0.35),
                                      ).copyWith(letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                                Text(
                                  countdownText,
                                  style: AppTypography.bodyMono(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: theme.accentColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$sealedCount Sealed Lockboxes',
                      style: AppTypography.button(
                        fontSize: 10.5,
                        color: theme.textColor.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Launch Capsule',
                          style: AppTypography.button(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: theme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: theme.accentColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
