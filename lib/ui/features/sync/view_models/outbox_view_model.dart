import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/ui/core/widgets/notify.dart' show formatNotifyError;

final _log = Logger('OutboxViewModel');

/// State for the Outbox screen: the live queue plus the per-row actions.
///
/// Two things here are deliberate, both from invoiceninja/flutter#44 ("Discard
/// doesn't remove the item from view; requires re-entering Outbox"):
///
/// 1. **The Drift watch is subscribed once**, here, not rebuilt inside a
///    `build()`. A `StreamBuilder` handed a fresh `watchAll(...)` on every
///    rebuild cancels and re-subscribes each time, which is the pattern the
///    app already treats as a bug elsewhere (`client_create_dialog.dart`,
///    `billing_doc_sends_tab.dart`, `invoice_detail_screen.dart`).
/// 2. **Discard hides the row immediately** ([_hidden]) instead of waiting for
///    the delete to round-trip through Drift — the tile leaves the list on the
///    tap. The optimistic hide is then *verified*: [discard] re-reads the row
///    and un-hides it if it's still queued, so an action that silently failed
///    can never be papered over. `SyncRepository.discardOutboxRow` has both a
///    silent `row == null` early return and (historically) a branch that could
///    leave the row behind without throwing.
class OutboxViewModel extends ChangeNotifier {
  OutboxViewModel({
    required this.dao,
    required this.sync,
    required this.companyId,
  }) {
    _bind();
  }

  final OutboxDao dao;
  final SyncRepository sync;
  final String companyId;

  StreamSubscription<List<OutboxRow>>? _sub;
  List<OutboxRow> _rows = const [];

  /// Rows the user has just discarded, hidden until the DB agrees they're
  /// gone: [_onRows] drops every id the query no longer returns, and a
  /// discard that didn't take un-hides its row immediately. Ids can outlive
  /// that only when emissions stop entirely (a watch [error]), where the
  /// whole list is stale anyway; the outbox PK is autoincrement, so a
  /// lingering id can never match a different row.
  final Set<int> _hidden = <int>{};

  bool _loaded = false;
  bool _disposed = false;
  String? _error;

  /// Set when the watch itself fails. The screen renders it instead of an
  /// empty queue — a silently-dead subscription behind a loading gate is a
  /// permanently blank screen, which is the trap `GenericListViewModel`
  /// documents at its own `_subscribe`.
  String? get error => _error;

  /// True until the first emission lands. Distinguishes "nothing queued" from
  /// "haven't looked yet", so the screen doesn't flash its empty state on
  /// every entry.
  bool get isLoading => !_loaded;

  List<OutboxRow> get rows => _hidden.isEmpty
      ? _rows
      : _rows.where((r) => !_hidden.contains(r.id)).toList(growable: false);

  void _bind() {
    _sub = dao
        .watchAll(companyId)
        .listen(
          _onRows,
          // A throw inside the watch pipeline must not be swallowed: the
          // subscription would stop delivering with nothing on screen to say so.
          onError: (Object e, StackTrace st) {
            _log.warning('Outbox watch failed', e, st);
            _error = formatNotifyError(e);
            _loaded = true;
            if (!_disposed) notifyListeners();
          },
        );
  }

  /// Re-open the watch — backs the error view's Retry. A `listen` without
  /// `cancelOnError` survives an error on its own (and [_onRows] clears
  /// [error] on the next good emission), so this is for the case where the
  /// stream really did end.
  void rebind() {
    if (_disposed) return;
    unawaited(_sub?.cancel());
    _error = null;
    notifyListeners();
    _bind();
  }

  void _onRows(List<OutboxRow> rows) {
    if (_disposed) return;
    _rows = rows;
    _loaded = true;
    _error = null;
    // Anything the DB has already forgotten no longer needs hiding.
    final live = {for (final row in rows) row.id};
    _hidden.removeWhere((id) => !live.contains(id));
    notifyListeners();
  }

  /// Drop one queued mutation. The row leaves [rows] on the tap; it comes
  /// back (and the caller gets `false` to toast) only if it is still queued
  /// afterwards. The `warning` lands in the diagnostics log, so a failure
  /// that only reproduces on a user's device arrives with evidence.
  ///
  /// The verdict comes from the database, never from the call's outcome, and
  /// that cuts both ways: `discardOutboxRow` silently no-ops when it can't
  /// find the row, and its post-delete cascade can throw *after* the user's
  /// row is already gone — reporting that as a failure would flash the tile
  /// back and toast an error for a discard that worked.
  Future<bool> discard(int id) async {
    _hidden.add(id);
    if (!_disposed) notifyListeners();
    try {
      await sync.discardOutboxRow(id);
    } catch (e, st) {
      _log.warning('Discard failed for outbox row $id', e, st);
    }
    try {
      if (await dao.byId(id) == null) return true;
      _log.warning('Outbox row $id is still queued after discard');
    } catch (e, st) {
      _log.warning('Could not verify the discard of outbox row $id', e, st);
    }
    _hidden.remove(id);
    if (!_disposed) notifyListeners();
    return false;
  }

  /// Re-arm a dead (or backed-off pending) row and kick a drain. No optimistic
  /// state — the row stays put and its state pill flips off the watch stream.
  Future<bool> retry(OutboxRow row) async {
    try {
      // The row can vanish while the menu is open (a drain, or a discard from
      // another surface). `retryDead` is an UPDATE that quietly matches zero
      // rows, so without this the tap would claim "Sync has started".
      if (await dao.byId(row.id) == null) return false;
      await dao.retryDead(
        id: row.id,
        now: DateTime.now().millisecondsSinceEpoch,
      );
      unawaited(sync.drainOnce(companyId: row.companyId));
      return true;
    } catch (e, st) {
      _log.warning('Retry failed for outbox row ${row.id}', e, st);
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
    _sub = null;
    super.dispose();
  }
}
