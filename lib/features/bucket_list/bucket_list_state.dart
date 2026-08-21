import 'package:days_together/models/bucket_list_model.dart';

/// State for `BucketListController` (Phase 6a of the architecture
/// migration) -- a direct Riverpod port of `BucketListProvider`'s
/// `_items`/`_isLoading` fields.
class BucketListState {
  final List<BucketListItem> items;
  final bool isLoading;

  const BucketListState({this.items = const [], this.isLoading = true});

  BucketListState copyWith({List<BucketListItem>? items, bool? isLoading}) {
    return BucketListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  int get totalItems => items.length;
  int get completedItems => items.where((i) => i.isCompleted).length;
  double get progress => totalItems == 0 ? 0 : completedItems / totalItems;
}
