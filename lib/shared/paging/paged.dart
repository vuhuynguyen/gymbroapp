import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One page fetched from a paged endpoint: the page's [items] and the server's reported [total].
class PageResult<T> {
  const PageResult(this.items, this.total);
  final List<T> items;
  final int total;
}

/// Accumulated state of an infinite-scroll list — every page loaded so far, flattened into [items].
class PagedData<T> {
  const PagedData({
    this.items = const [],
    this.page = 0,
    this.total = 0,
    this.loadingMore = false,
  });

  final List<T> items;
  final int page;
  final int total;

  /// A `loadMore` is in flight (drives the list footer spinner).
  final bool loadingMore;

  /// More pages remain on the server.
  bool get hasMore => items.length < total;

  PagedData<T> copyWith({
    List<T>? items,
    int? page,
    int? total,
    bool? loadingMore,
  }) =>
      PagedData(
        items: items ?? this.items,
        page: page ?? this.page,
        total: total ?? this.total,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

/// Base notifier for an infinite-scroll list. Loads page 1 on build; [loadMore] appends the next page
/// (guarded so over-eager scroll callbacks are harmless), [refresh] restarts from page 1. Subclasses only
/// implement [fetch]. The state mirrors `FutureProvider`'s `AsyncValue`, so screens keep using `.when`.
abstract class PagedNotifier<T>
    extends AutoDisposeNotifier<AsyncValue<PagedData<T>>> {
  /// Page size requested from the server. Override per list as needed.
  int get pageSize => 20;

  /// Fetch one page (1-based). Return the page's items and the server's total count.
  Future<PageResult<T>> fetch(int page, int pageSize);

  @override
  AsyncValue<PagedData<T>> build() {
    // Fire-and-forget: the first state mutation happens only after the await in [_loadFirst], so we never
    // set state synchronously during build.
    _loadFirst();
    return const AsyncValue.loading();
  }

  Future<void> _loadFirst() async {
    try {
      final r = await fetch(1, pageSize);
      state = AsyncData(PagedData(items: r.items, page: 1, total: r.total));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || !cur.hasMore || cur.loadingMore) return;
    state = AsyncData(cur.copyWith(loadingMore: true));
    try {
      final r = await fetch(cur.page + 1, pageSize);
      state = AsyncData(cur.copyWith(
        items: [...cur.items, ...r.items],
        page: cur.page + 1,
        total: r.total,
        loadingMore: false,
      ));
    } catch (_) {
      // Keep what we already have; a transient next-page failure shouldn't blow away the list.
      state = AsyncData(cur.copyWith(loadingMore: false));
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _loadFirst();
  }
}

/// Wraps a scrollable and invokes [onLoadMore] once the user scrolls within [threshold] px of the bottom.
/// Pair with a [PagedNotifier] whose `loadMore` is idempotent, so repeated edge notifications are no-ops.
class InfiniteScroll extends StatelessWidget {
  const InfiniteScroll({
    required this.onLoadMore,
    required this.child,
    this.threshold = 320,
    super.key,
  });

  final VoidCallback onLoadMore;
  final Widget child;
  final double threshold;

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.axis == Axis.vertical &&
              n.metrics.pixels >= n.metrics.maxScrollExtent - threshold) {
            onLoadMore();
          }
          return false;
        },
        child: child,
      );
}

/// List/scroll footer for an infinite list: a centered spinner while [loadingMore], otherwise nothing.
class PagingFooter extends StatelessWidget {
  const PagingFooter({required this.loadingMore, super.key});
  final bool loadingMore;

  @override
  Widget build(BuildContext context) => loadingMore
      ? const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4)),
          ),
        )
      : const SizedBox.shrink();
}
