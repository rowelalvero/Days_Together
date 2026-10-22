import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/bucket_list/bucket_list_state.dart';
import 'package:days_together/features/bucket_list/domain/entities/bucket_list_model.dart';
import 'package:days_together/features/bucket_list/presentation/widgets/bucket_list_item_tile.dart';

/// The drag-to-reorder list of adventures on [BucketListScreen]. Extracted
/// from its `_buildListView` (Migration audit item 6).
class BucketListReorderableView extends StatelessWidget {
  const BucketListReorderableView({
    super.key,
    required this.state,
    required this.notifier,
    required this.theme,
    required this.onToggleItem,
    required this.onEditItem,
  });

  final BucketListState state;
  final BucketListController notifier;
  final LoveStoryTheme theme;
  final ValueChanged<BucketListItem> onToggleItem;
  final ValueChanged<BucketListItem> onEditItem;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(canvasColor: Colors.transparent),
      child: ReorderableListView.builder(
        itemCount: state.items.length,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        onReorder: notifier.reorderItems,
        itemBuilder: (context, index) {
          final item = state.items[index];
          return BucketListItemTile(
            key: ValueKey(item.id),
            item: item,
            theme: theme,
            onToggle: () => onToggleItem(item),
            onEdit: () => onEditItem(item),
            onDelete: () => notifier.deleteItem(item.id),
          );
        },
      ),
    );
  }
}
