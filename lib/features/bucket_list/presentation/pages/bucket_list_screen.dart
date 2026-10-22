import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';

import 'package:days_together/features/bucket_list/bucket_list_controller.dart';
import 'package:days_together/features/bucket_list/domain/entities/bucket_list_model.dart';
import 'package:days_together/features/bucket_list/presentation/sheets/add_bucket_item_sheet.dart';
import 'package:days_together/features/bucket_list/presentation/widgets/bucket_list_app_bar.dart';
import 'package:days_together/features/bucket_list/presentation/widgets/bucket_list_empty_state.dart';
import 'package:days_together/features/bucket_list/presentation/widgets/bucket_list_progress_card.dart';
import 'package:days_together/features/bucket_list/presentation/widgets/bucket_list_reorderable_view.dart';
import 'package:days_together/features/theme/theme_controller.dart';

/// The couple's shared bucket list: a progress summary and a drag-to-reorder
/// list of adventures, each completable, editable, and deletable.
///
/// Its `_buildX` methods and inline `_showAddItemSheet` were extracted into
/// focused widgets under `presentation/widgets/` and `presentation/sheets/`
/// (Migration audit item 6) -- this class now only owns the confetti
/// celebration played when an item is completed.
class BucketListScreen extends ConsumerStatefulWidget {
  const BucketListScreen({super.key});

  @override
  ConsumerState<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends ConsumerState<BucketListScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _showAddItemSheet(BuildContext context, {BucketListItem? existingItem}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddBucketItemSheet(existingItem: existingItem),
    );
  }

  void _toggleItem(BucketListItem item) {
    ref.read(bucketListControllerProvider.notifier).toggleItem(item.id);
    if (!item.isCompleted) {
      _confettiController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final theme = themeState.currentLoveTheme;
    final bucketState = ref.watch(bucketListControllerProvider);
    final bucketNotifier = ref.read(bucketListControllerProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: themeState.currentGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                BucketListAppBar(theme: theme),
                BucketListProgressCard(state: bucketState, theme: theme),
                Expanded(
                  child: bucketState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : bucketState.items.isEmpty
                      ? BucketListEmptyState(theme: theme)
                      : BucketListReorderableView(
                          state: bucketState,
                          notifier: bucketNotifier,
                          theme: theme,
                          onToggleItem: _toggleItem,
                          onEditItem: (item) =>
                              _showAddItemSheet(context, existingItem: item),
                        ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Colors.pink,
                Colors.red,
                Colors.orange,
                Colors.amber,
                Colors.lightBlue,
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemSheet(context),
        backgroundColor: theme.accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
