import 'package:days_together/themes/theme_manager.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerState, ConsumerStatefulWidget;
import 'package:go_router/go_router.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:days_together/shared/glass_container.dart';

// Providers & Models
import 'package:days_together/features/dashboard/recent_activity_controller.dart';
import 'package:days_together/models/local_activity_model.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/calendar/calendar_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/love_studio/time_capsule_controller.dart';
import 'package:days_together/features/vault/vault_controller.dart';
import 'package:days_together/features/scrapbook/noteit_controller.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_controller.dart';

import 'package:days_together/routing/routes.dart';
// LoveStoryScreen.of(context)?.setIndex(...) below is tab-switching inside
// the already-mounted shell, not screen navigation -- deliberately out of
// go_router's scope (ADR-007); every other case now resolves to a Routes
// constant instead of a screen import.
import 'package:days_together/screens/love_story_screen.dart';

class RecentActivityFeed extends ConsumerStatefulWidget {
  final LoveStoryTheme theme;

  const RecentActivityFeed({
    super.key,
    required this.theme,
  });

  @override
  ConsumerState<RecentActivityFeed> createState() => _RecentActivityFeedState();
}

class _RecentActivityFeedState extends ConsumerState<RecentActivityFeed> {
  Timer? _relativeTimeTimer;

  @override
  void initState() {
    super.initState();
    // Refresh relative timestamps every 30 seconds
    _relativeTimeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _relativeTimeTimer?.cancel();
    super.dispose();
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      final hrs = difference.inHours;
      return '$hrs ${hrs == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }

  Color _featureColor(String feature) {
    switch (feature) {
      case 'chat':
        return const Color(0xFF6366F1); // Indigo
      case 'doodle_notes':
      case 'love_notes':
        return const Color(0xFFF59E0B); // Amber
      case 'timeline':
        return const Color(0xFF8B5CF6); // Purple
      case 'bucket_list':
        return const Color(0xFF14B8A6); // Teal
      case 'calendar':
        return const Color(0xFF3B82F6); // Blue
      case 'time_capsule':
        return const Color(0xFFF97316); // Orange
      case 'vault':
        return const Color(0xFF64748B); // Slate
      case 'topic_cards':
        return const Color(0xFFEC4899); // Pink
      case 'gifts':
        return const Color(0xFFEF4444); // Red
      case 'love_meter':
        return const Color(0xFFE11D48); // Rose
      case 'relationship_profile':
        return const Color(0xFFFF69B4); // Hot Pink
      default:
        return const Color(0xFF6366F1);
    }
  }

  void _navigateToFeature(BuildContext context, LocalActivity activity) {
    final route = activity.route;
    final referenceId = activity.referenceId;

    if (route == null) return;

    bool exists = true;
    String? targetRoute;

    switch (route) {
      case 'bucket_list':
        if (referenceId != null && activity.activityType != 'deleted') {
          final bucketState = ref.read(bucketListControllerProvider);
          exists = bucketState.items.any((i) => i.id == referenceId);
        }
        targetRoute = Routes.bucketList;
        break;
      case 'calendar':
        if (referenceId != null && activity.activityType != 'deleted') {
          final calendarState = ref.read(calendarControllerProvider);
          exists = calendarState.events.any((e) => e.id == referenceId);
        }
        targetRoute = Routes.calendar;
        break;
      case 'timeline':
        if (referenceId != null && activity.activityType != 'deleted') {
          final timelineState = ref.read(timelineControllerProvider);
          exists = timelineState.items.any((i) => i.id == referenceId);
        }
        if (exists) {
          LoveStoryScreen.of(context)?.setIndex(1); // Story/Timeline Tab
          return;
        }
        break;
      case 'time_capsule':
        if (referenceId != null && activity.activityType != 'deleted') {
          final capsuleState = ref.read(timeCapsuleControllerProvider);
          exists = capsuleState.capsules.any((c) => c.id == referenceId);
        }
        targetRoute = Routes.timeCapsule;
        break;
      case 'vault':
        if (referenceId != null && activity.activityType != 'deleted') {
          final vaultState = ref.read(vaultControllerProvider);
          exists = vaultState.visibleItems.any((i) => i.id == referenceId);
        }
        targetRoute = Routes.vault;
        break;
      case 'love_notes':
      case 'doodle_notes':
        if (referenceId != null && activity.activityType != 'deleted') {
          final noteitState = ref.read(noteitControllerProvider);
          exists = noteitState.visibleNotes.any((n) => n.id == referenceId);
        }
        targetRoute = Routes.notes;
        break;
      case 'topic_cards':
        targetRoute = Routes.topicCards;
        break;
      case 'gifts':
        if (referenceId != null && activity.activityType != 'deleted') {
          final giftState = ref.read(giftReminderControllerProvider);
          exists = giftState.reminders.any((r) => r.id == referenceId);
        }
        targetRoute = Routes.gifts;
        break;
      case 'relationship_profile':
        targetRoute = Routes.license;
        break;
      case 'chat':
        targetRoute = Routes.chat;
        break;
    }

    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The selected item no longer exists. Opening section...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    if (targetRoute != null) {
      context.push(targetRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final activityState = ref.watch(recentActivityControllerProvider);
    final allActivities = activityState.activities;
    final displayActivities = allActivities.take(6).toList();

    if (activityState.isLoading && allActivities.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme, 0),
            const SizedBox(height: 24),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(theme.textColor.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (displayActivities.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 28,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(theme, 0),
            const SizedBox(height: 24),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    const Text(
                      '✨',
                      style: TextStyle(fontSize: 28),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your story is just beginning',
                      style: AppTypography.body(
                        fontSize: 13,
                        color: theme.textColor.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Activities will appear here as you use the app',
                      style: AppTypography.caption(
                        fontSize: 11,
                        color: theme.textColor.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(theme, allActivities.length),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayActivities.length,
            itemBuilder: (context, index) {
              final activity = displayActivities[index];
              return _buildActivityRow(theme, activity, index, displayActivities.length);
            },
          ),
          Divider(color: theme.textColor.withValues(alpha: 0.1), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Local Activity Timeline',
                style: AppTypography.caption(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: theme.textColor.withValues(alpha: 0.3),
                ),
              ),
              Text(
                '${allActivities.length} total',
                style: AppTypography.caption(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: theme.textColor.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LoveStoryTheme theme, int totalCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: theme.accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Recent Activities',
              style: AppTypography.body(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.textColor,
              ),
            ),
          ],
        ),
        Text(
          'TIMELINE',
          style: AppTypography.caption(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: theme.textColor.withValues(alpha: 0.38),
          ).copyWith(letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildActivityRow(LoveStoryTheme theme, LocalActivity activity, int index, int totalCount) {
    final featureColor = _featureColor(activity.route ?? '');
    final icon = activity.icon;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline vertical line track
          SizedBox(
            width: 24,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: index == 0 ? 25 : 0,
                  bottom: index == totalCount - 1 ? 25 : 0,
                  child: Container(
                    width: 1.5,
                    color: theme.textColor.withValues(alpha: 0.1),
                  ),
                ),
                Positioned(
                  top: 25,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: featureColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: featureColor.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Log details card (wrapped in InkWell for interactivity)
          Expanded(
            child: InkWell(
              onTap: () => _navigateToFeature(context, activity),
              borderRadius: BorderRadius.circular(16),
              splashColor: featureColor.withValues(alpha: 0.1),
              highlightColor: featureColor.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Icon badge
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            featureColor,
                            featureColor.withValues(alpha: 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          icon,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Log textual info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  activity.title,
                                  style: AppTypography.body(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: theme.textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatRelativeTime(activity.timestamp),
                                style: AppTypography.caption(
                                  fontSize: 9,
                                  color: theme.textColor.withValues(alpha: 0.3),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (activity.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              activity.description,
                              style: AppTypography.bodyMedium(
                                fontSize: 11,
                                color: theme.textColor.withValues(alpha: 0.54),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
