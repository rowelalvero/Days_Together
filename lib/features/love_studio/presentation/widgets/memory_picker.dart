import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/shared/models/timeline_model.dart';
import 'package:days_together/shared/widgets/paged_list_footer.dart';

/// The memory picker on [AILoveLetterScreen]: shows the chosen memory and
/// opens [MemoryPickerSheet] to change it.
///
/// It used to be a `DropdownButton` over the loaded memories. The timeline
/// now loads a page at a time, and a dropdown can't fetch more as it
/// scrolls, so older memories were unreachable; the sheet pages them in.
class MemoryPicker extends StatelessWidget {
  const MemoryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.theme,
  });

  final TimelineItemData? selected;
  final ValueChanged<String> onChanged;
  final LoveStoryTheme theme;

  Future<void> _open(BuildContext context) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MemoryPickerSheet(selectedId: selected?.id, theme: theme),
    );
    if (id != null) onChanged(id);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: theme.textColor.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
        ),
        child: InkWell(
          key: const ValueKey('memory-picker-field'),
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (selected != null) ...[
                  Text(selected!.mood, style: AppTypography.body(fontSize: 20)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    selected?.title ?? 'Choose a memory',
                    style: AppTypography.body(color: theme.textColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, color: theme.textColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Every memory, paged in as the user scrolls (the timeline's own window,
/// so nothing is fetched twice). Pops with the chosen memory's id.
class MemoryPickerSheet extends ConsumerWidget {
  const MemoryPickerSheet({
    super.key,
    required this.selectedId,
    required this.theme,
  });

  final String? selectedId;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(timelineControllerProvider);
    final controller = ref.read(timelineControllerProvider.notifier);
    final memories = state.items;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (state.paging.canAutoLoad && isNearScrollEnd(n.metrics)) {
              controller.loadMore();
            }
            return false;
          },
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 12),
            // Header + memories + footer.
            itemCount: memories.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
                  child: Text(
                    'Choose a memory',
                    style: AppTypography.heading(
                      color: theme.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }
              if (index == memories.length + 1) {
                return PagedListFooter(
                  status: state.paging,
                  onRetry: controller.retryLoad,
                  color: theme.textColor,
                );
              }
              final m = memories[index - 1];
              final isSelected = m.id == selectedId;
              return ListTile(
                key: ValueKey('memory-picker-${m.id}'),
                leading: Text(m.mood, style: AppTypography.body(fontSize: 20)),
                title: Text(
                  m.title,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_rounded, color: theme.accentColor)
                    : null,
                onTap: () => Navigator.pop(context, m.id),
              );
            },
          ),
        );
      },
    );
  }
}
