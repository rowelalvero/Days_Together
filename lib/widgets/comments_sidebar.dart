import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/widgets/glass_container.dart';

class CommentsSidebar extends StatefulWidget {
  final TimelineItemData item;

  const CommentsSidebar({super.key, required this.item});

  static void show(BuildContext context, TimelineItemData item) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CommentsSidebar',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return CommentsSidebar(item: item);
      },
      transitionBuilder: (context, anim, secondaryAnim, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );
  }

  @override
  State<CommentsSidebar> createState() => _CommentsSidebarState();
}

class _CommentsSidebarState extends State<CommentsSidebar> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submitComment(TimelineProvider provider, String authorName) {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    provider.addCommentToItem(widget.item.id, text, authorName);
    _commentController.clear();

    // Scroll to bottom after comment added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final rp = context.watch<RelationshipProvider>();
    final tp = context.watch<TimelineProvider>();

    // Get current item to reflect real-time updates
    final currentItem = tp.timelineItems.firstWhere(
      (i) => i.id == widget.item.id,
      orElse: () => widget.item,
    );

    // Sort comments: pinned first, then by date
    final sortedComments = List<CommentData>.from(currentItem.comments)
      ..sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return a.date.compareTo(b.date);
      });

    final yourName = rp.yourName ?? 'Me';

    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.85,
        heightFactor: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border(
              left: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: GlassContainer(
              borderRadius: 0,
              padding: EdgeInsets.zero,
              opacity: 0.18,
              blur: 25,
              child: SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: theme.accentColor,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sidebar Chat',
                              style: AppTypography.bodyLarge(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textColor,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Colors.white10, height: 1),

                    // Comments List
                    Expanded(
                      child: sortedComments.isEmpty
                          ? _buildEmptyState(theme)
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: sortedComments.length,
                              itemBuilder: (context, index) {
                                final comment = sortedComments[index];
                                final isMe = comment.authorName == yourName;
                                return _buildCommentBubble(context, comment, isMe, theme, tp);
                              },
                            ),
                    ),

                    const Divider(color: Colors.white10, height: 1),

                    // Input Row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: GlassContainer(
                              borderRadius: 24,
                              opacity: 0.1,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: TextField(
                                controller: _commentController,
                                style: AppTypography.body(color: theme.textColor, fontSize: 14),
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: 'Write a cute reply...',
                                  hintStyle: AppTypography.body(color: Colors.white30, fontSize: 14),
                                  border: InputBorder.none,
                                ),
                                onSubmitted: (_) => _submitComment(tp, yourName),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _submitComment(tp, yourName),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: theme.accentColor,
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCommentBubble(
    BuildContext context,
    CommentData comment,
    bool isMe,
    dynamic theme,
    TimelineProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (comment.isPinned) ...[
                Icon(Icons.push_pin_rounded, color: theme.accentColor, size: 11),
                const SizedBox(width: 4),
              ],
              Text(
                comment.authorName,
                style: AppTypography.bodyLarge(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: comment.isPinned ? theme.accentColor : Colors.white70,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('MM/dd h:mm a').format(comment.date),
                style: AppTypography.caption(fontSize: 10, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onLongPress: () => _showCommentActions(context, comment, provider, theme),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: comment.isPinned
                    ? theme.accentColor.withValues(alpha: 0.25)
                    : (isMe
                        ? theme.accentColor.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: Border.all(
                  color: comment.isPinned
                      ? theme.accentColor.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Text(
                comment.content,
                style: AppTypography.body(color: theme.textColor, fontSize: 13.5, height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCommentActions(
    BuildContext context,
    CommentData comment,
    TimelineProvider provider,
    dynamic theme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        borderRadius: 24,
        opacity: 0.15,
        blur: 20,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  comment.isPinned ? Icons.pin_end_rounded : Icons.push_pin_rounded,
                  color: theme.accentColor,
                ),
                title: Text(
                  comment.isPinned ? 'Unpin Conversation' : 'Pin to Top',
                  style: AppTypography.body(color: theme.textColor),
                ),
                onTap: () {
                  provider.togglePinComment(widget.item.id, comment.id);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text(
                  'Delete Comment',
                  style: AppTypography.body(color: Colors.redAccent),
                ),
                onTap: () {
                  provider.deleteCommentFromItem(widget.item.id, comment.id);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(dynamic theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: Colors.white24,
            size: 40,
          ),
          const SizedBox(height: 16),
          Text(
            'No conversations yet.',
            style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            'Pin a cute memory conversation here!',
            style: AppTypography.bodyMedium(color: theme.accentColor.withValues(alpha: 0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
