import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/love_chat_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';

class RecentActivityFeed extends StatelessWidget {
  final TimelineProvider timelineProvider;
  final dynamic theme;

  const RecentActivityFeed({
    super.key,
    required this.timelineProvider,
    required this.theme,
  });

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MM/dd').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rp = Provider.of<RelationshipProvider>(context);
    final chatProvider = Provider.of<LoveChatProvider>(context);

    // Map timeline items to activity logs
    final timelineLogs = timelineProvider.timelineItems.map((item) {
      return _ActivityLog(
        title: 'Created shared memory',
        subtitle: '${item.title}: ${item.description}',
        initials: 'CO', // Couple/Co-op
        timestamp: item.date,
      );
    }).toList();

    // Map chat messages to activity logs
    final chatLogs = chatProvider.messages.map((msg) {
      final senderName = msg.senderId == 'you'
          ? (rp.yourName ?? 'Me')
          : (rp.partnerName ?? 'Partner');

      String initials = 'ME';
      if (msg.senderId != 'you') {
        initials = rp.partnerName != null && rp.partnerName!.length >= 2
            ? rp.partnerName!.substring(0, 2).toUpperCase()
            : 'PA';
      } else {
        initials = rp.yourName != null && rp.yourName!.length >= 2
            ? rp.yourName!.substring(0, 2).toUpperCase()
            : 'ME';
      }

      return _ActivityLog(
        title: 'Transmitted chat message',
        subtitle: '$senderName: "${msg.content}"',
        initials: initials,
        timestamp: msg.createdAt,
      );
    }).toList();

    // Combine and sort (newest first)
    final allLogs = [...timelineLogs, ...chatLogs]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    final displayLogs = allLogs.take(5).toList();

    if (displayLogs.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Recent Activities',
                    style: AppTypography.caption(fontSize: 16, fontWeight: FontWeight.w700, color: theme.textColor),
                  ),
                ],
              ),
              Text(
                'LIVE LOGS',
                style: AppTypography.caption(fontSize: 8, fontWeight: FontWeight.w800, color: theme.textColor.withValues(alpha: 0.38)).copyWith(letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Timeline list
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayLogs.length,
            itemBuilder: (context, index) {
              final log = displayLogs[index];
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
                            top: index == 0 ? 25 : 0, // Start line at avatar center
                            bottom: index == displayLogs.length - 1 ? 25 : 0, // End line at avatar center
                            child: Container(
                              width: 1.5,
                              color: Colors.white10,
                            ),
                          ),
                          Positioned(
                            top: 25, // Glowing blue dot aligned with avatar center
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent.withValues(alpha: 0.5),
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
                    // Log details card
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Pink/Rose Initial Badge
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFEC4899), Color(0xFFE11D48)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  log.initials,
                                  style: AppTypography.caption(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                                      Text(
                                        log.title,
                                        style: AppTypography.caption(fontSize: 13, fontWeight: FontWeight.w700, color: theme.textColor),
                                      ),
                                      Text(
                                        _formatRelativeTime(log.timestamp),
                                        style: AppTypography.caption(fontSize: 9, color: theme.textColor.withValues(alpha: 0.3), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    log.subtitle,
                                    style: AppTypography.caption(fontSize: 11, color: theme.textColor.withValues(alpha: 0.54)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shared Co-Lobby Stream',
                style: AppTypography.caption(fontSize: 10, fontWeight: FontWeight.w500, color: theme.textColor.withValues(alpha: 0.3)),
              ),
              Text(
                '${allLogs.length} total',
                style: AppTypography.caption(fontSize: 10, fontWeight: FontWeight.w500, color: theme.textColor.withValues(alpha: 0.3)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityLog {
  final String title;
  final String subtitle;
  final String initials;
  final DateTime timestamp;

  const _ActivityLog({
    required this.title,
    required this.subtitle,
    required this.initials,
    required this.timestamp,
  });
}
