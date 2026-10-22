import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The bottom sheet opened by long-pressing a message on [LoveChatScreen],
/// currently offering only "Delete Message". Extracted from the screen's
/// `_showActions` (Migration audit item 6).
///
/// Shown directly as a `showModalBottomSheet` builder, matching this app's
/// other sheets -- no `.show()` static helper.
class ChatMessageActionsSheet extends StatelessWidget {
  const ChatMessageActionsSheet({super.key, required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 24,
      opacity: 0.15,
      blur: 20,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              title: Text(
                'Delete Message',
                style: AppTypography.body(color: Colors.redAccent),
              ),
              onTap: () {
                onDelete();
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
