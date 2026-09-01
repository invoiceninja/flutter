import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final _log = Logger('GenericDetailViewModel');

/// Read-only entity-detail ViewModel. Subscribes to a repo watch stream and
/// exposes the latest value through [item]. Anything that mutates the row —
/// a synced edit, a server refresh, an `applyDeleteResponse` — propagates to
/// the UI here.
///
/// Two ways to use it:
///
///  * **Plain entities** — instantiate directly (or via a typedef alias) and
///    pass the watch stream to [GenericDetailViewModel.bound]. The default
///    for an entity with no screen-specific derived state.
///
///  * **Entities with derived state** — subclass and add entity-specific
///    getters; the subclass constructor still forwards the watch stream to
///    [bindStream]. `ClientDetailViewModel` is the reference.
class GenericDetailViewModel<T> extends ChangeNotifier {
  GenericDetailViewModel();

  /// Subscribe the VM to [stream]. Equivalent to `GenericDetailViewModel()
  /// ..bindStream(stream)` — exists so screens can express the wiring as one
  /// expression in `initState`.
  GenericDetailViewModel.bound(Stream<T?> stream) {
    bindStream(stream);
  }

  T? _item;
  T? get item => _item;

  bool _isResolving = true;
  bool get isResolving => _isResolving;

  StreamSubscription<T?>? _sub;

  /// Mirrors [GenericListViewModel]'s guard. `dispose()` cancels [_sub], but a
  /// Drift watch event already dispatched before the cancel can still invoke
  /// the listener — and `notifyListeners()` on a disposed `ChangeNotifier`
  /// throws "was used after being disposed". Subclasses that add their own
  /// async derived-state work should consult [isDisposed] before notifying.
  bool _disposed = false;
  bool get isDisposed => _disposed;

  /// Subscribe to [stream]. Replaces any prior subscription. Each emission
  /// updates [item] and clears [isResolving].
  ///
  /// A throw inside the watch pipeline (e.g. `_fromRow` failing to map a
  /// newly-shaped row) must NOT be swallowed — mirrors the `onError` on
  /// `GenericListViewModel`'s page subscription, for a sharper reason here:
  /// [isResolving] is what bounds the detail pane's first-frame seed
  /// (`EntityDetailScaffold._resolveItem`). Left true forever, the pane would
  /// keep painting a plausible, fully-populated record from the list snapshot
  /// that never updates for the rest of the session, with the actions row and
  /// the `e` shortcut operating on that frozen object. A silent wrong-data
  /// state is worse than the stuck spinner this used to produce, so clear the
  /// flag and let the empty state through.
  @protected
  void bindStream(Stream<T?> stream) {
    _sub?.cancel();
    _isResolving = true;
    _sub = stream.listen(
      (value) {
        _item = value;
        _isResolving = false;
        notifyListeners();
      },
      onError: (Object e, StackTrace st) {
        _log.warning('detail watch stream failed', e, st);
        _isResolving = false;
        notifyListeners();
      },
    );
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
