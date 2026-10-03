/// Where a paged ("infinite scroll") list stands: whether the server has
/// more, whether a page is in flight, and whether the last attempt failed.
///
/// Shared by every paged controller (timeline, chat, note-its) so their
/// screens can render the same loading / error / end-of-list footer
/// (`PagedListFooter`).
class PagingStatus {
  const PagingStatus({
    this.hasMore = false,
    this.isLoadingMore = false,
    this.loadMoreFailed = false,
  });

  /// The server may have more rows beyond the loaded window.
  final bool hasMore;

  /// A page request is in flight.
  final bool isLoadingMore;

  /// The last page request failed. Automatic loading pauses until the user
  /// retries, so a failing network is not hammered on every scroll event.
  final bool loadMoreFailed;

  /// Whether reaching the end of the list should fetch the next page now.
  bool get canAutoLoad => hasMore && !isLoadingMore && !loadMoreFailed;

  /// Everything there is has been loaded.
  bool get isExhausted => !hasMore && !loadMoreFailed;

  PagingStatus copyWith({
    bool? hasMore,
    bool? isLoadingMore,
    bool? loadMoreFailed,
  }) {
    return PagingStatus(
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PagingStatus &&
      other.hasMore == hasMore &&
      other.isLoadingMore == isLoadingMore &&
      other.loadMoreFailed == loadMoreFailed;

  @override
  int get hashCode => Object.hash(hasMore, isLoadingMore, loadMoreFailed);
}
