import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/contacts_sync/contacts_sync_types.dart';

final _log = Logger('ContactsSyncController');

/// In-flight state of a contacts-sync pass. `companyId == null` means idle.
@immutable
class ContactsSyncProgress {
  const ContactsSyncProgress.idle() : companyId = null, done = 0, total = 0;

  const ContactsSyncProgress.running({
    required this.companyId,
    this.done = 0,
    this.total = 0,
  });

  final String? companyId;
  final int done;
  final int total;

  bool get isRunning => companyId != null;

  bool isRunningFor(String id) => companyId == id;
}

/// Owns the device-local "sync contacts to this device" preference and the
/// single-flight guard around a pass.
///
/// Persists to `nav_state.contacts_sync_json` — same single-row device-local
/// pattern as [ConfirmActionsController] — and copies [ResyncController]'s
/// single-flight discipline, because the same pass is reachable from three
/// places (the settings button, the Sync pass hook, and the first-enable
/// flow) and two concurrent reconciles would fight over the same address book.
///
/// A [ChangeNotifier] rather than a `ValueNotifier` because it holds a small
/// collection of state (toggle, scope, per-company last-run, progress), which
/// is the convention the other controllers follow.
class ContactsSyncController extends ChangeNotifier
    implements ContactsSyncGroupStore {
  ContactsSyncController({
    required AppDatabase db,
    required ContactsSyncEngine engine,
    DateTime Function()? now,
  }) : _db = db,
       _engine = engine,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final ContactsSyncEngine _engine;
  final DateTime Function() _now;

  bool _enabled = false;
  ContactsSyncScope _scope = ContactsSyncScope.all;
  final Map<String, int> _lastRunAt = {};

  /// companyId -> device address-book group id. The ownership record that keeps
  /// two companies from sharing a group; see [ContactsSyncGroupStore].
  final Map<String, String> _groupIds = {};
  ContactsSyncProgress _progress = const ContactsSyncProgress.idle();
  final Map<String, ContactsSyncSummary> _lastSummary = {};

  Future<ContactsSyncSummary>? _inFlight;
  bool _cancelled = false;

  bool get enabled => _enabled;
  ContactsSyncScope get scope => _scope;
  ContactsSyncProgress get progress => _progress;
  bool get isRunning => _progress.isRunning;

  /// The most recent pass's result **for [companyId]**, so the settings card
  /// can explain a permission failure or a no-label degradation instead of just
  /// going quiet. Keyed by company: a result from the company you were in five
  /// minutes ago must not be presented as this one's.
  ContactsSyncSummary? lastSummaryFor(String companyId) =>
      _lastSummary[companyId];

  /// Epoch millis of the last successful pass for [companyId], or null if it
  /// has never run here. Also what decides `isFirstRun` (and therefore whether
  /// the pass forces a full client re-download).
  int? lastRunAt(String companyId) => _lastRunAt[companyId];

  bool hasRunFor(String companyId) => _lastRunAt.containsKey(companyId);

  Future<void> restore() async {
    final row = await _db.navStateDao.current();
    final raw = row?.contactsSyncJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _enabled = json['enabled'] == true;
      _scope = ContactsSyncScope.fromId(json['scope'] as String?);
      _lastRunAt
        ..clear()
        ..addAll({
          for (final e in (json['lastRun'] as Map? ?? const {}).entries)
            if (e.value is int) e.key as String: e.value as int,
        });
      _groupIds
        ..clear()
        ..addAll({
          for (final e in (json['groupIds'] as Map? ?? const {}).entries)
            if (e.value is String && (e.value as String).isNotEmpty)
              e.key as String: e.value as String,
        });
      notifyListeners();
    } catch (e, st) {
      // A corrupt blob must not wedge the app at boot; the feature simply
      // starts from off and the user can switch it back on.
      _log.warning('could not restore the contacts-sync preference', e, st);
    }
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    await _persist();
  }

  Future<void> setScope(ContactsSyncScope value) async {
    if (_scope == value) return;
    _scope = value;
    notifyListeners();
    await _persist();
  }

  /// The card count for the pre-flight dialog. Refreshes clients first — the
  /// number has to be trustworthy or the dialog is worse than not showing one
  /// (see [ContactsSyncEngine.previewCardCount]). Slow on a large account, so
  /// callers should show progress.
  Future<int> previewCardCount(String companyId) => _engine.previewCardCount(
    companyId: companyId,
    scope: _scope,
    refreshClients: true,
  );

  /// Start a pass for [companyId], or attach to the one already running.
  ///
  /// Never throws: the engine folds every failure into the returned summary.
  ///
  /// [refreshClients] is false where the caller already refreshed — the Sync
  /// pass hook, and the first-enable flow whose pre-flight count just did a
  /// full pull. Getting it wrong costs a redundant full download of the whole
  /// client list, not correctness.
  Future<ContactsSyncSummary> run(
    String companyId, {
    bool refreshClients = true,
  }) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    // Claim the slot *synchronously*, before any engine code can run — the same
    // shape (and for the same reason) as `ResyncController.run`: assigning the
    // future directly would leave a window where an engine that throws before
    // its first suspension clears `_inFlight` in its `finally`, only for the
    // assignment to put it straight back and wedge the controller as busy.
    final completer = Completer<ContactsSyncSummary>();
    _inFlight = completer.future;
    _cancelled = false;
    _progress = ContactsSyncProgress.running(companyId: companyId);
    notifyListeners();

    unawaited(
      _run(companyId, refreshClients: refreshClients).then((summary) {
        try {
          _inFlight = null;
          _cancelled = false;
          _progress = const ContactsSyncProgress.idle();
          _lastSummary[companyId] = summary;
          notifyListeners();
        } finally {
          // Completion must not depend on the UI: `notifyListeners` above can
          // throw past Flutter's guard, and an uncompleted completer would hang
          // every caller forever with nothing surfaced.
          completer.complete(summary);
        }
      }),
    );
    return completer.future;
  }

  /// Ask the in-flight pass to stop at the next chunk boundary. Wired to
  /// logout (which wipes the database this pass is writing to) and to the user
  /// switching the feature off mid-run. No-op when idle.
  void cancel() {
    if (_inFlight != null) _cancelled = true;
  }

  Future<ContactsSyncSummary> _run(
    String companyId, {
    required bool refreshClients,
  }) async {
    final summary = await _engine.run(
      companyId: companyId,
      scope: _scope,
      isFirstRun: !hasRunFor(companyId),
      refreshClients: refreshClients,
      isCancelled: () => _cancelled,
      onProgress: (done, total) {
        if (_cancelled) return;
        _progress = ContactsSyncProgress.running(
          companyId: companyId,
          done: done,
          total: total,
        );
        notifyListeners();
      },
    );
    // Only a pass that actually reconciled sets the high-water mark. Stamping
    // it after a permission failure would make the next run a delta refresh
    // against a cache that was never fully downloaded.
    if (summary.outcome == ContactsSyncOutcome.ok) {
      _lastRunAt[companyId] = _now().millisecondsSinceEpoch;
      await _persist();
    }
    return summary;
  }

  /// Delete every card this install wrote for [companyId] and forget it.
  Future<void> removeAll(String companyId) async {
    await _engine.removeAll(companyId: companyId);
    _lastRunAt.remove(companyId);
    _lastSummary.remove(companyId);
    // The engine normally clears this itself as it deletes the label, making
    // this a no-op. It is repeated here so the controller's own bookkeeping is
    // complete regardless: the engine swallows its failures, so a delete that
    // died mid-way would otherwise leave an id behind pointing at a group that
    // may no longer exist.
    _groupIds.remove(companyId);
    notifyListeners();
    await _persist();
  }

  /// Delete the cards for **every** company this install has synced.
  ///
  /// Wired to `AuthRepository.onBeforeDataWipe`: logout wipes the link table,
  /// so anything left behind at that point is stranded on the device forever —
  /// a former user's whole client list sitting in the address book.
  Future<void> removeAllCompanies() async {
    // Cancel *and wait*. `cancel()` is cooperative and returns immediately, so
    // without the await a pass mid-flight would keep creating device contacts
    // after the removal below had already deleted them — and `_db.wipe()`, a
    // moment later, destroys the link table that recorded them. Those cards
    // would sit in a signed-out user's address book with nothing left that
    // knows they exist, which is the exact leak this method exists to close.
    // Bounded by one chunk, since that's where the pass polls the flag.
    cancel();
    await _inFlight;
    List<String> companies;
    try {
      companies = await _engine.companiesWithSyncedContacts();
    } catch (e, st) {
      _log.warning('could not list companies with synced contacts', e, st);
      return;
    }
    for (final companyId in companies) {
      await _engine.removeAll(companyId: companyId);
    }
    _lastRunAt.clear();
    _lastSummary.clear();
    _groupIds.clear();
    // Deliberately not persisted: this runs immediately before `_db.wipe()`,
    // which empties `nav_state` along with everything else, so the write would
    // be thrown away anyway. (Each `removeAll` above does persist, via the
    // group store — same fate, and not worth a special case to avoid.)
    // In-memory state is cleared so a re-login on the same process starts
    // clean.
  }

  // --- ContactsSyncGroupStore ---------------------------------------------
  //
  // The controller is the store because it already owns the blob these ids live
  // in. `ContactsSyncService` holds it behind a getter to break the cycle: the
  // service is constructed as an argument to this controller.

  @override
  String? syncedGroupId(String companyId) => _groupIds[companyId];

  @override
  bool groupIsClaimedByOther(
    String groupId, {
    required String exceptCompanyId,
  }) => _groupIds.entries.any(
    (e) => e.key != exceptCompanyId && e.value == groupId,
  );

  @override
  Future<void> setSyncedGroupId(String companyId, String? groupId) async {
    final existing = _groupIds[companyId];
    if (existing == groupId) return;
    if (groupId == null || groupId.isEmpty) {
      _groupIds.remove(companyId);
    } else {
      _groupIds[companyId] = groupId;
    }
    // Deliberately no `notifyListeners`: this is bookkeeping no surface renders,
    // and a pass resolves its group mid-flight — a rebuild there would churn the
    // settings card for nothing.
    await _persist();
  }

  Future<void> _persist() async {
    // Optimistic, like every other device-local controller: a failed write
    // never rolls back the in-memory value — the user keeps the state they
    // chose until the next launch.
    try {
      await _db.navStateDao.saveContactsSync(
        json: jsonEncode({
          'enabled': _enabled,
          'scope': _scope.id,
          'lastRun': _lastRunAt,
          'groupIds': _groupIds,
        }),
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      _log.warning('could not persist the contacts-sync preference', e, st);
    }
  }
}
