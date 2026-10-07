/// Sum-type for the lifecycle of a single dashboard card's data.
///
/// `idle` — no fetch attempted yet (cold start).
/// `loading` — first fetch in flight; `data` may be `null` (no cache hit) or
///   stale (previous fetch's value, kept so the UI doesn't flash empty).
/// `ready` — last fetch succeeded; `data` holds the canonical value.
/// `error` — last fetch failed; `data` may still hold a prior value.
class AsyncSection<T> {
  const AsyncSection._({required this.status, this.data, this.error});

  const AsyncSection.idle() : this._(status: AsyncStatus.idle);
  const AsyncSection.loading({T? data})
    : this._(status: AsyncStatus.loading, data: data);
  const AsyncSection.ready(T data)
    : this._(status: AsyncStatus.ready, data: data);
  const AsyncSection.error(Object error, {T? data})
    : this._(status: AsyncStatus.error, data: data, error: error);

  final AsyncStatus status;
  final T? data;
  final Object? error;

  bool get isLoading => status == AsyncStatus.loading;
  bool get hasError => status == AsyncStatus.error;
  bool get hasData => data != null;

  AsyncSection<T> withData(T? next) {
    if (next == null) {
      return AsyncSection<T>._(status: status, error: error);
    }
    return AsyncSection<T>._(status: AsyncStatus.ready, data: next);
  }
}

enum AsyncStatus { idle, loading, ready, error }

/// What a single-value section — a figure, the chart — should draw.
///
/// The figures used to format `data ?? zero`, so "not loaded", "failed" and
/// "really nothing" were all `$0.00`. These are the four things a figure can
/// honestly be.
enum ValueSectionState {
  /// No answer yet and nothing has gone wrong — a skeleton, never a zero.
  loading,

  /// The fetch failed and nothing is cached — a dash and a retry.
  failed,

  /// The fetch failed but an earlier answer is still here — shown, and marked
  /// as not current.
  stale,

  /// The latest answer.
  ready,
}

extension ValueSectionStateOf<T> on AsyncSection<T> {
  /// Deliberately not a function of "is a refresh running": a refresh ends a
  /// beat before its cache row reaches the watch stream, and reading that gap
  /// as "finished with nothing" flashed every figure through its failed state
  /// on each load.
  ValueSectionState get valueState {
    if (data == null) {
      return hasError ? ValueSectionState.failed : ValueSectionState.loading;
    }
    return hasError ? ValueSectionState.stale : ValueSectionState.ready;
  }
}

/// What a list card should render for its section — the one ordering every
/// dashboard list surface follows, so "this panel has nothing to show" means
/// the same thing to the card that renders it and to the view model that
/// hides it (invoiceninja/flutter#161). Three hand-written copies of this
/// order had already drifted once: the mobile cards printed "No …" while
/// still loading and after a failed fetch.
enum ListSectionState {
  /// The fetch failed and nothing is cached — show the error and a retry.
  failed,

  /// Nothing has loaded yet — show a skeleton, never "No …".
  loading,

  /// Loaded, and there are no rows — the "No …" state, and the only one
  /// "Hide empty panels" leaves out. An error over a cached `[]` is still
  /// this: the cache already answered.
  empty,

  /// Loaded with rows (possibly stale under an error).
  rows,
}

/// Whether a section's [data] is a loaded, empty list. The single definition
/// both [ListSectionStateOf.listState] and `DashboardViewModel.emptyPanels`
/// use.
bool isLoadedEmpty(List<Object?>? data) => data != null && data.isEmpty;

extension ListSectionStateOf on AsyncSection<List<Object?>> {
  ListSectionState get listState {
    final rows = data;
    if (rows == null) {
      return hasError ? ListSectionState.failed : ListSectionState.loading;
    }
    return isLoadedEmpty(rows) ? ListSectionState.empty : ListSectionState.rows;
  }
}
