import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The message text field and send button at the bottom of
/// [LoveChatScreen]. Extracted from its `_buildInputRow` (Migration audit
/// item 6). [controller]'s lifecycle (creation/disposal) stays owned by the
/// screen's State, same as before the extraction.
class ChatInputRow extends StatelessWidget {
  const ChatInputRow({
    super.key,
    required this.controller,
    required this.theme,
    required this.onSend,
  });

  final TextEditingController controller;
  final LoveStoryTheme theme;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Row(
        children: [
          Expanded(
            child: GlassContainer(
              borderRadius: 24,
              opacity: 0.1,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: controller,
                style: AppTypography.body(color: theme.textColor, fontSize: 14),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Write something sweet...',
                  hintStyle: AppTypography.body(
                    color: theme.textColor.withValues(alpha: 0.3),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSend,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: theme.accentColor,
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
