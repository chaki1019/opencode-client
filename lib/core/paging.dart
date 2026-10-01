import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/opencode_client.dart';

/// Items loaded so far from a cursor-paginated endpoint.
class PagedItems<T> {
  const PagedItems({
    required this.items,
    this.nextCursor,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<T> items;
  final String? nextCursor;
  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => nextCursor != null;

  PagedItems<T> copyWith({
    List<T>? items,
    String? Function()? nextCursor,
    bool? isLoadingMore,
    Object? Function()? loadMoreError,
  }) => PagedItems(
    items: items ?? this.items,
    nextCursor: nextCursor != null ? nextCursor() : this.nextCursor,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: loadMoreError != null ? loadMoreError() : this.loadMoreError,
  );
}

/// Loads the first page in [build] and further pages via [loadMore].
/// Subclasses decide where newer pages go with [merge].
abstract class PagedNotifier<T> extends AsyncNotifier<PagedItems<T>> {
  Future<Page<T>> fetch(String? cursor);

  List<T> merge(List<T> current, List<T> page);

  @override
  Future<PagedItems<T>> build() async {
    final page = await fetch(null);
    return PagedItems(items: page.items, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, loadMoreError: () => null),
    );
    try {
      final page = await fetch(current.nextCursor);
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(
          items: merge(current.items, page.items),
          nextCursor: () => page.nextCursor,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: () => e),
      );
    }
  }
}
