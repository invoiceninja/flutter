import 'package:flutter/widgets.dart';

/// A [StreamBuilder] that owns its subscription across parent rebuilds.
///
/// Reach for this instead of `StreamBuilder(stream: repo.watchX(...))` whenever
/// the stream is a Drift watch created from `build()`. Every repo `watch*`
/// returns a **fresh** stream per call, so a stream built inline gets a new
/// identity on every parent rebuild, and `StreamBuilder.didUpdateWidget` tears
/// the subscription down and re-subscribes.
///
/// **This does not stop a blank, and nothing here should be reached for as if
/// it did.** On a stream swap `StreamBuilder.afterDisconnected` returns
/// `current.inState(ConnectionState.none)`, and `AsyncSnapshot.inState`
/// preserves `data`, `error` and `stackTrace` verbatim —
/// `AsyncSnapshot.nothing()` is only ever produced by `initial()`, i.e. first
/// mount. `sidebar_counters_section.dart` says the same thing next to its own
/// hoisted stream. **The cost is churn, not a visible blink.**
///
/// The churn is what matters: a fresh DB query and subscription per widget per
/// rebuild. Worst in the master-detail pane, which rebuilds on every VM notify
/// and on every frame of the pane's full-screen grow/shrink — the width lerp
/// re-runs each descendant `LayoutBuilder`, so that is per frame.
///
/// Generalises three hand-rolled hoists that already existed:
/// `_BadgePreviewState._ensureStream`, `PartyMoneyCell._ensureStream`, and the
/// sidebar's `_cachedBadge`.
///
/// Not for a per-cell id→name resolver (`ClientNameLabel`, `EntityTagsView`,
/// …): drift keys active query streams by SQL+variables, so N rows of a column
/// already share one underlying query, and those files document the per-cell
/// `StreamBuilder` as deliberate.
///
/// [create] runs on the first build and re-runs only when [cacheKey] changes.
/// The key is required rather than inferred from [create] because a closure is
/// rebuilt every frame and its identity is therefore useless; pass the values
/// the stream is derived from, e.g. `(companyId, invoice.clientId)`.
class WatchBuilder<T> extends StatefulWidget {
  const WatchBuilder({
    super.key,
    required this.cacheKey,
    required this.create,
    required this.builder,
    this.initialData,
  });

  /// Everything [create] closes over that decides *which* stream this is.
  /// Records compare by value, so a tuple is the usual shape.
  final Object? cacheKey;

  final Stream<T> Function() create;
  final AsyncWidgetBuilder<T> builder;
  final T? initialData;

  @override
  State<WatchBuilder<T>> createState() => _WatchBuilderState<T>();
}

class _WatchBuilderState<T> extends State<WatchBuilder<T>> {
  late Stream<T> _stream = widget.create();

  @override
  void didUpdateWidget(WatchBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cacheKey != widget.cacheKey) _stream = widget.create();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: _stream,
    initialData: widget.initialData,
    builder: widget.builder,
  );
}
