import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_event.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/services/api_exception.dart';

final _log = Logger('SyncRepository');

/// Exponential backoff for transient failures. After the last entry, one
/// more attempt past the schedule's tail before the row is marked dead.
const List<Duration> kBackoffSchedule = [
  Duration(seconds: 5),
  Duration(seconds: 30),
  Duration(minutes: 2),
  Duration(minutes: 10),
];

/// Total attempts (initial + retries) before a row is marked dead.
const int kMaxAttempts = 5;

/// Terminal state observed by [SyncRepository.awaitRow] for one outbox row.
enum SyncRowOutcome {
  /// Row was successfully drained (server returned 2xx; the row was deleted).
  success,

  /// Row was rejected by the server with a 422 — caller should surface the
  /// returned `fieldErrors` inline on the edit form.
  validationFailed,

  /// Row hit a non-validation failure (5xx, network, dead row with a non-422
  /// status). Caller surfaces [SyncRowResult.message] as a submit-level error
  /// and keeps the form open.
  serverError,

  /// [SyncRepository.awaitRow] hit its caller-supplied timeout while the row
  /// was still pending / in-flight. Caller pops the form optimistically and
  /// lets the outbox keep draining in the background.
  timeout,
}

/// Result of [SyncRepository.awaitRow]. [fieldErrors] is populated only for
/// [SyncRowOutcome.validationFailed]; [message] / [statusCode] are surfaced
/// on transient and validation failures so the form can show an error.
class SyncRowResult {
  const SyncRowResult({
    required this.outcome,
    this.fieldErrors = const <String, List<String>>{},
    this.message,
    this.statusCode,
  });

  final SyncRowOutcome outcome;
  final Map<String, List<String>> fieldErrors;
  final String? message;
  final int? statusCode;
}

/// Long-running consumer of the outbox. Drains rows in FIFO order per
/// `(company, entity_type)`, dispatches them via the [EntityRegistry], and
/// emits typed [SyncEvent]s for the UI shell to react to.
///
/// In M1 we expose [drainOnce] for direct invocation; the long-running
/// scheduling (connectivity, foreground-resume, due-time timers) is wired
/// up in `app/di.dart` once `AuthRepository` lands in M1.8.
class SyncRepository {
  SyncRepository({
    required this.db,
    required this.registry,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase db;
  final EntityRegistry registry;
  final DateTime Function() _now;

  final StreamController<SyncEvent> _events =
      StreamController<SyncEvent>.broadcast();

  Stream<SyncEvent> get events => _events.stream;

  /// Drains currently in flight, keyed by `companyId`. A second
  /// [drainOnce] call for the same company while a drain is running
  /// returns the existing future instead of starting a parallel one —
  /// otherwise the five auto-drain triggers (onEnqueued, connectivity,
  /// lifecycle, auth, dialog flush) would double-dispatch rows because
  /// `nextReady` filters by `state='pending'` only AFTER `markInFlight`
  /// is awaited. The Idempotency-Key header makes double-dispatch
  /// server-safe, but it's still wasted work we'd rather not do.
  final Map<String, Future<int>> _inFlight = {};

  /// Signal checked between outbox rows. [cancel] sets it; [drainOnce]
  /// clears it on entry so the next drain starts fresh.
  bool _cancelRequested = false;

  /// Sticky cancellation latch, distinct from the per-pass [_cancelRequested].
  /// Set by [cancel] and cleared only by [resume], so no new pass can start
  /// behind a logout's back between `cancel()` returning and the Drift wipe.
  bool _cancelled = false;

  /// Outbox rows whose caller is synchronously surfacing the failure itself
  /// (an open edit form via [awaitRow], or any `awaitRow(callerWillDisplayFailure:
  /// true)` caller). [_markDead] tags such rows' [DeadEvent] with
  /// `handledByCaller: true` so the shell shows the error inline rather than
  /// popping a duplicate modal. A row drops out of the set the moment its
  /// `awaitRow` returns, so a *later* background death (e.g. after the form's
  /// online-save timeout popped the screen) is correctly treated as unhandled
  /// and does surface a modal.
  final Set<int> _callerDisplayedRows = {};

  Future<void> dispose() => _events.close();

  /// Stop a running [drainOnce] (between rows — an in-flight HTTP request is
  /// allowed to settle so the server's view doesn't diverge from ours) and
  /// await the iteration. Safe to call when no drain is active.
  ///
  /// Used by [AuthRepository.logout] so the local DB wipe doesn't race a
  /// pending mutation that's still using the soon-to-be-revoked credentials.
  Future<void> cancel() async {
    // Latch, not a one-shot flag. Awaiting a snapshot of `_inFlight` was not
    // enough: any `drainOnce` that landed during the await (a connectivity
    // flap — the listener only checks `auth.session`, which logout clears
    // AFTER this hook — or `awaitRow`'s poll) cleared `_cancelRequested` and
    // registered a new future the snapshot didn't cover. cancel() then
    // returned while a fresh pass was still dispatching, and logout wiped
    // Drift underneath it.
    _cancelled = true;
    _cancelRequested = true;
    // Drop queued trailing re-drains: logout relies on cancel() meaning "no
    // drain is running once this returns" before it wipes Drift — a
    // re-drain auto-kicked from a completing pass would start a NEW pass
    // behind logout's back and race the wipe with stale-credential writes.
    _redrainRequested.clear();
    // Loop until the map is empty rather than awaiting one snapshot: a pass
    // that was already mid-flight when the latch flipped still has to settle,
    // and awaiting it can yield. No new pass can be added while `_cancelled`
    // is set, so this terminates.
    while (_inFlight.isNotEmpty) {
      // Snapshot before awaiting — entries clean themselves up via the
      // `whenComplete` hook in [drainOnce], which would mutate the map
      // while we iterate.
      final pending = _inFlight.values.toList(growable: false);
      for (final f in pending) {
        try {
          await f;
        } catch (_) {
          // Errors are reported via events on the SyncEvent stream; here we
          // only care that the iteration has settled.
        }
      }
    }
  }

  /// Release the [cancel] latch so drains can run again. Called when a company
  /// is activated (login / restore / switch) — `onActiveCompanyChanged` fires
  /// only on an actual change and `logout()` re-arms it, so a re-login always
  /// reaches here. Deliberately NOT called from the per-mutation drain kick: a
  /// write landing mid-logout must not restart the engine.
  void resume() {
    _cancelled = false;
  }

  /// Count of non-`dead` outbox rows for [companyId]. Wraps the DAO so the
  /// UI shell doesn't reach into the database layer directly.
  Future<int> pendingCountFor(String companyId) =>
      db.outboxDao.pendingCountForCompany(companyId);

  /// Distinct company ids with any non-`dead` outbox row — the ground truth
  /// the full-logout / idle-timeout guards check (see
  /// `OutboxDao.companiesWithActiveRows` for why this beats
  /// `session.companies`).
  Future<List<String>> companiesWithActiveRows() =>
      db.outboxDao.companiesWithActiveRows();

  /// True when ANY company still holds unsynced outbox rows — the predicate
  /// every involuntary session-end must consult before choosing a destructive
  /// logout. `AuthRepository.logout()`'s default (`preserveLocalData: false`)
  /// wipes the whole Drift database, outbox included, so ending a session
  /// without this check silently destroys the user's offline edits (CLAUDE.md:
  /// "never silently drops user data").
  ///
  /// A non-active company's pending rows count just as much as the active
  /// one's — the wipe is global. Fast local read only (no network drain), so
  /// it's safe on the security-lock and 401 paths. **Errs toward preserving**
  /// on any error: keeping data that could have been dropped is recoverable,
  /// dropping data that should have been kept is not.
  Future<bool> hasUnsyncedWork() async {
    try {
      return (await companiesWithActiveRows()).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  /// Discard one outbox row. If it's a never-synced offline `create`
  /// (`tmp_` id, no `id_remap` entry yet) the orphaned local Drift record
  /// is also hard-deleted — with no outbox row it could never reach the
  /// server, so it would otherwise linger forever as a ghost. A row that's
  /// currently `in_flight` only has its outbox row dropped: its network
  /// attempt may be landing concurrently and would re-create the local row
  /// + write an `id_remap`, so ghost-deleting it would race that (TOCTOU).
  ///
  /// Returns `true` when the ghost path was taken **and** the local record is
  /// confirmed gone, so a caller showing that entity can navigate away. A
  /// ghost discard whose local delete failed still drops the outbox rows but
  /// returns `false` — the record is still on screen, so don't pop it.
  Future<bool> discardOutboxRow(int id) async {
    final row = await db.outboxDao.byId(id);
    if (row == null) return false;
    if (row.state == 'in_flight') {
      await db.outboxDao.deleteRow(id);
      // Reconcile the optimistic is_dirty flag on an in_flight UPDATE/reorder:
      // if the attempt then fails, its scheduleRetry/markDead no-op on the
      // now-deleted row, so without this the abandoned edit would render as
      // authoritative forever. A success leg would clear the flag anyway, so
      // clearing it now is safe. Creates are left untouched — we do NOT
      // ghost-delete an in_flight create (its request may still be landing and
      // would re-create the record, TOCTOU), and a create has no server row to
      // refresh from, so its flag is moot.
      if (MutationKind.tryParse(row.mutationKind) != MutationKind.create) {
        await _reconcileDiscardedDirty(row);
      }
      return false;
    }
    final isGhostCreate =
        MutationKind.tryParse(row.mutationKind) == MutationKind.create &&
        row.entityId.startsWith('tmp_') &&
        await db.idRemapDao.resolve(
              entityType: row.entityType,
              tempId: row.entityId,
            ) ==
            null;
    if (!isGhostCreate) {
      await db.outboxDao.deleteRow(id);
      await _reconcileDiscardedDirty(row);
      return false;
    }
    // Never synced: drop the ghost local row, then every outbox row for
    // that tmp entity (queued follow-up update/delete rows are meaningless
    // once the entity is gone). `deleteAllForEntity` also removes `row`.
    // The local delete stays FIRST — an orphaned local record with no outbox
    // row could never reach the server (see this method's doc) — but it can
    // no longer veto the discard; see [_deleteGhostRecord].
    final localDeleted = await _deleteGhostRecord(
      companyId: row.companyId,
      entityType: row.entityType,
      entityId: row.entityId,
    );
    await db.outboxDao.deleteAllForEntity(
      companyId: row.companyId,
      entityType: row.entityType,
      entityId: row.entityId,
    );
    // Rows that REFERENCE the ghost in their payload (e.g. an invoice
    // created offline against this unsynced client) can never succeed —
    // there is no parent left to mint a real id, so the drain's
    // tmp_-dependency guard would defer them forever (also blocking the
    // logout/switch "Sync first" pending check). Recursively resolve the
    // whole offline subtree.
    await _failTmpDependents(row.companyId, row.entityId, discard: true);
    return localDeleted;
  }

  /// Hard-delete a never-synced ghost's local record, best effort.
  ///
  /// Returns whether the record is actually gone. A failure is logged and
  /// swallowed **on purpose**: the caller must still drop the outbox rows,
  /// because a discard the user asked for can't be vetoed by cleanup — a
  /// throw here used to abandon the whole discard, leaving the row queued
  /// with no feedback at all (the symptom reported in
  /// invoiceninja/flutter#44, though never confirmed as that report's cause).
  /// It can fail on a DAO/DB error, or on a repo that hasn't overridden
  /// `BaseEntityRepository.deleteLocalById`, which throws by default.
  /// WARNING lands in the diagnostics log, so the next report names the
  /// entity instead of leaving us guessing.
  Future<bool> _deleteGhostRecord({
    required String companyId,
    required String entityType,
    required String entityId,
  }) async {
    try {
      await registry
          .byWireName(entityType)
          ?.dispatcher
          .deleteLocalRecord(companyId: companyId, id: entityId);
      return true;
    } catch (e, st) {
      _log.warning(
        'discardOutboxRow: local ghost delete failed for '
        '$entityType/$entityId — dropping the outbox row anyway',
        e,
        st,
      );
      return false;
    }
  }

  /// Resolve outbox rows that reference an unsynced (`tmp_`) entity that has
  /// just become terminal — discarded or dead — so a dependent's tmp ref
  /// can't strand it forever (the drain's tmp_-dependency guard would defer
  /// such a row every 60s indefinitely, and it would keep `pendingCountFor`
  /// above zero so "Sync first" on logout/switch could never settle).
  ///
  /// [discard] true = the parent was a never-synced ghost the user discarded.
  /// A dependent that is ITSELF a ghost create can never sync either, so it's
  /// removed wholesale (local record + all its outbox rows) and we recurse
  /// into ITS tmp id (catching e.g. a payment created against an offline
  /// invoice created against the discarded client). A non-ghost dependent
  /// (an update/action on a real entity that merely referenced the tmp) is
  /// marked dead.
  ///
  /// [discard] false = the parent's CREATE died (422). Dependents are marked
  /// dead (kept, not deleted) — the user may fix + retry the parent, and
  /// `rewriteTempIdInPayloads` (which covers dead rows) then heals their refs
  /// for a manual Retry. Recursion marks deeper levels dead too.
  ///
  /// Terminates: every branch removes the row from the `pending` set
  /// (`markDead` flips state, ghost-delete removes it) and
  /// `pendingRowsReferencing` is pending-only, so the still-pending set
  /// strictly shrinks each step (also breaks any hypothetical reference
  /// cycle).
  Future<void> _failTmpDependents(
    String companyId,
    String parentTmpId, {
    required bool discard,
  }) async {
    if (!parentTmpId.startsWith('tmp_')) return;
    final deps = await db.outboxDao.pendingRowsReferencing(
      companyId: companyId,
      needle: parentTmpId,
    );
    for (final dep in deps) {
      final isGhostDep =
          MutationKind.tryParse(dep.mutationKind) == MutationKind.create &&
          dep.entityId.startsWith('tmp_') &&
          await db.idRemapDao.resolve(
                entityType: dep.entityType,
                tempId: dep.entityId,
              ) ==
              null;
      if (discard && isGhostDep) {
        // Same best-effort rule as the primary row — and it matters more
        // here: this cleanup runs *after* the user's row was deleted, so a
        // throw would reject a discard that already succeeded.
        await _deleteGhostRecord(
          companyId: companyId,
          entityType: dep.entityType,
          entityId: dep.entityId,
        );
        await db.outboxDao.deleteAllForEntity(
          companyId: companyId,
          entityType: dep.entityType,
          entityId: dep.entityId,
        );
        await _failTmpDependents(companyId, dep.entityId, discard: true);
      } else {
        await _markDead(
          dep,
          discard
              ? 'References a discarded unsynced record'
              : 'References a record that could not be saved',
          null,
        );
        // Recurse into a dead create's OWN tmp dependents (deeper levels).
        // The `!= parentTmpId` guard skips a same-entity update keyed to the
        // parent's tmp id (already handled above), so we never re-query the
        // same needle.
        if (MutationKind.tryParse(dep.mutationKind) == MutationKind.create &&
            dep.entityId.startsWith('tmp_') &&
            dep.entityId != parentTmpId) {
          await _failTmpDependents(companyId, dep.entityId, discard: discard);
        }
      }
    }
  }

  /// A tag CREATE 422'd (typically a name colliding with a tag
  /// archived/deleted on another device that our cache hadn't reconciled —
  /// the local picker suppresses known collisions, see M1). Unlike a generic
  /// failed parent, a dead tag must NOT kill every task/project that referenced
  /// it: strip the dead tmp tag id from each dependent's full-set `tags`
  /// payload and leave the row pending, so the parent save still drains with
  /// its remaining tags (the server's `tags` is a full-replace, so dropping one
  /// id is safe — matches React). The dependent's local row reconciles its
  /// stale tag id on the parent's own update response. (M1)
  Future<void> _stripFailedTagFromDependents(
    String companyId,
    String tagTmpId,
  ) async {
    final deps = await db.outboxDao.pendingRowsReferencing(
      companyId: companyId,
      needle: tagTmpId,
    );
    for (final dep in deps) {
      Map<String, dynamic> payload;
      try {
        payload = jsonDecode(dep.payload) as Map<String, dynamic>;
      } catch (_) {
        continue; // unexpected shape — leave for the generic fail path
      }
      final tags = payload['tags'];
      if (tags is! List) {
        // No `tags` list to strip. The remaining rows referencing the dead tag
        // are the tag's OWN follow-ups — an offline rename (update payload
        // embeds the tmp id) or an archive/restore/delete keyed to it. The
        // create is dead, so the tmp id will never resolve and these can never
        // succeed; mark them dead (mirroring _failTmpDependents) instead of
        // leaving them for the tmp-dependency guard to defer +1 min forever.
        await _markDead(
          dep,
          'References a record that could not be saved',
          null,
        );
        continue;
      }
      final cleaned = [
        for (final t in tags)
          if (t != tagTmpId) t,
      ];
      if (cleaned.length == tags.length) continue; // nothing to strip
      payload['tags'] = cleaned;
      await db.outboxDao.updatePayload(
        id: dep.id,
        payload: jsonEncode(payload),
      );
    }
  }

  /// Discard every `pending` outbox row for [companyId] — the "Discard"
  /// branch of the confirm-before-switch / logout dialog and the 409
  /// "discard mine" path. Each row routes through [discardOutboxRow] so a
  /// never-synced offline `create` also removes its orphaned local record;
  /// non-ghost rows behave exactly as the old blanket delete (dead /
  /// in_flight rows are untouched, matching `deletePendingForCompany`).
  ///
  /// Deliberate asymmetry with [pendingCountFor] (which also counts
  /// `in_flight`): an in-flight row's HTTP attempt is already on the wire and
  /// can't be unsent, and deleting its row would race the response applier —
  /// so the guard COUNTS it (never silently proceed past unsynced work) while
  /// Discard leaves it to settle (success = synced anyway; failure re-parks
  /// it pending, where the guard's re-check still catches it).
  Future<void> discardPendingFor(String companyId) async {
    final rows = await db.outboxDao.pendingRowsForCompany(companyId);
    for (final row in rows) {
      await discardOutboxRow(row.id);
    }
  }

  /// Discard every `pending` outbox row for one entity — the conflict sheet's
  /// "discard my changes" path (both variants). Scoped to the conflicted
  /// record: the parked row itself plus any queued follow-up mutations for
  /// the same entity. (This used to route through [discardPendingFor],
  /// which destroyed the *whole company's* pending queue — including
  /// unrelated offline creates, which were also ghost-deleted locally.)
  /// [entityType] is the outbox wire name (`OutboxRow.entityType`).
  Future<void> discardPendingForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
  }) async {
    final rows = await db.outboxDao.pendingRowsForCompany(companyId);
    for (final row in rows) {
      if (row.entityType != entityType || row.entityId != entityId) continue;
      await discardOutboxRow(row.id);
    }
  }

  /// Synchronous-ish entry point for the shell: drain whatever is due now
  /// for [companyId]. Returns the number of rows successfully dispatched.
  /// Errors propagate so the caller can show a SnackBar.
  Future<int> flushNow({required String companyId}) =>
      drainOnce(companyId: companyId);

  /// Wait for one specific outbox row to reach a terminal state, kicking the
  /// drain as needed so the row actually gets dispatched. Used by
  /// `GenericEditViewModel.save()` when the device is online to flip the form
  /// into a synchronous UX: a 422 lands inline on the still-open form
  /// instead of via the dead-row banner after the route popped.
  ///
  /// The poll loop (default 200 ms) is the contract; events are nice-to-have.
  /// On every tick where the row is still `pending` and due, [drainOnce] is
  /// re-kicked — the single-flight `_inFlight` guard makes that idempotent.
  /// This closes the drain race where a prior in-flight drain snapshotted
  /// `nextReady` before our row was enqueued and finished without seeing it.
  ///
  /// Returns:
  ///   * [SyncRowOutcome.success] — row was deleted (server 2xx).
  ///   * [SyncRowOutcome.validationFailed] — row is `dead` with status 422.
  ///   * [SyncRowOutcome.serverError] — row is `dead` with a non-422 status,
  ///     or row is `pending` with a future `nextAttemptAt` (a backoff was
  ///     scheduled; surface the `lastError`).
  ///   * [SyncRowOutcome.timeout] — [timeout] elapsed with the row still
  ///     pending or in_flight; caller should fall back to background sync.
  Future<SyncRowResult> awaitRow({
    required int rowId,
    required String companyId,
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 200),
    bool callerWillDisplayFailure = true,
  }) async {
    // Use a real wall-clock Stopwatch for the deadline — the injected `_now`
    // is fixed in unit tests (deterministic backoff math) so checking it
    // would never trip the timeout branch. The poll loop's `Future.delayed`
    // is already real-wall-time, so this just matches what the user actually
    // experiences.
    final stopwatch = Stopwatch()..start();
    // Claim the row so a death observed while we're actively polling is shown
    // by *this* caller (inline on the form / at the tap site) rather than also
    // by a duplicate shell modal. Released in the `finally` the instant we
    // return, so a *later* background death (e.g. after the online-save timeout
    // popped the screen) is treated as unhandled and does surface a modal.
    if (callerWillDisplayFailure) _callerDisplayedRows.add(rowId);
    // Kick the drain right away so an idle company starts processing without
    // waiting for the first poll. Subsequent kicks happen inside the loop.
    unawaited(drainOnce(companyId: companyId));
    try {
      while (true) {
        final row = await db.outboxDao.byId(rowId);
        if (row == null) {
          return const SyncRowResult(outcome: SyncRowOutcome.success);
        }
        if (row.state == 'dead') {
          if (row.lastStatusCode == 422) {
            return SyncRowResult(
              outcome: SyncRowOutcome.validationFailed,
              fieldErrors: _decodeFieldErrors(row.fieldErrorsJson),
              message: row.lastError,
              statusCode: row.lastStatusCode,
            );
          }
          return SyncRowResult(
            outcome: SyncRowOutcome.serverError,
            message: row.lastError ?? 'Save failed',
            statusCode: row.lastStatusCode,
          );
        }
        final nowMs = _now().millisecondsSinceEpoch;
        if (row.state == 'pending' && row.nextAttemptAt > nowMs) {
          // A retry has been scheduled into the future — this is a transient
          // server/network failure. Surface inline; the outbox will keep
          // retrying in the background per its backoff if the user navigates
          // away, but for now the form stays open with the error.
          return SyncRowResult(
            outcome: SyncRowOutcome.serverError,
            message: row.lastError ?? 'Connection lost',
            statusCode: row.lastStatusCode,
          );
        }
        if (stopwatch.elapsed >= timeout) {
          return const SyncRowResult(outcome: SyncRowOutcome.timeout);
        }
        // Pending and due, or in_flight. Re-kick drainOnce — if a prior drain
        // missed this row (it snapshotted nextReady before our enqueue), the
        // next pass picks it up. If a drain is already running, single-flight
        // makes this a no-op.
        if (row.state == 'pending') {
          unawaited(drainOnce(companyId: companyId));
        }
        await Future<void>.delayed(pollInterval);
      }
    } finally {
      _callerDisplayedRows.remove(rowId);
    }
  }

  Map<String, List<String>> _decodeFieldErrors(String? json) {
    if (json == null || json.isEmpty) return const <String, List<String>>{};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(
            k.toString(),
            v is List ? v.map((e) => e.toString()).toList() : <String>[],
          ),
        );
      }
    } catch (_) {}
    return const <String, List<String>>{};
  }

  /// Drain all due `pending` rows for [companyId] in one pass. Returns the
  /// number of rows successfully dispatched (200-class result). Stops early
  /// if [cancel] is invoked mid-iteration.
  ///
  /// Single-flight per company: a second call while a drain is already
  /// running for the same company returns the existing future instead of
  /// starting a parallel one.
  /// Companies whose `drainOnce` kick was absorbed by the single-flight
  /// guard while a pass was already running — each gets one trailing
  /// re-drain when that pass completes (see the guard comment below).
  final Set<String> _redrainRequested = <String>{};

  Future<int> drainOnce({required String companyId}) {
    // Cancelled (logout in progress, or completed and not yet re-activated) —
    // starting a pass here would dispatch under soon-to-be-revoked credentials
    // and race the Drift wipe. See [cancel] / [resume].
    if (_cancelled) return Future<int>.value(0);
    final existing = _inFlight[companyId];
    if (existing != null) {
      // A kick landed mid-pass. The row that triggered it isn't in the
      // running pass's `nextReady` snapshot, so returning the in-progress
      // future alone would swallow it — on desktop (app stays resumed,
      // connectivity stable) nothing else re-kicks for days and the
      // mutation sits pending while the user believes they're synced.
      // Flag a trailing re-drain instead. Deliberately a flag and not a
      // blanket "re-check nextReady after every pass": rows skipped by the
      // tmp_-dependency guard stay pending AND due, so a blanket re-check
      // would spin on them.
      _redrainRequested.add(companyId);
      return existing;
    }
    _cancelRequested = false;
    final future = _drainOnceImpl(companyId);
    _inFlight[companyId] = future;
    // Use `whenComplete` so the slot is cleared whether the drain succeeded
    // or threw. The `identical` guard protects against a hypothetical
    // re-entrant overwrite (none today, but cheap insurance). The trailing
    // `.catchError` silences THIS derived future only — `whenComplete`
    // re-propagates the pass's error onto its own (unlistened) return
    // future, which would otherwise surface as an unhandled async error;
    // callers awaiting `drainOnce` still see the error on the original.
    unawaited(
      future
          .whenComplete(() {
            if (identical(_inFlight[companyId], future)) {
              _inFlight.remove(companyId);
            }
            if (!_cancelRequested && _redrainRequested.remove(companyId)) {
              // Best-effort: the app (or a test) may be tearing down by the
              // time the trailing pass starts — a failure must not surface as
              // an unhandled async error; the row stays pending for the next
              // trigger. The `_cancelRequested` check keeps a cancel()-then-
              // wipe sequence (logout) from racing a freshly kicked pass.
              unawaited(
                drainOnce(companyId: companyId).catchError((Object e) {
                  _log.fine('trailing re-drain failed: $e');
                  return 0;
                }),
              );
            }
          })
          .catchError((Object _) => 0),
    );
    return future;
  }

  /// Re-arm parked password-required rows for [companyId], then kick a drain.
  /// Called by the shell's password sheet after the user enters their password
  /// so the just-parked mutation retries immediately instead of waiting out
  /// its +1 min park (see the `PasswordRequiredException` handler).
  Future<void> retryPasswordRows({required String companyId}) async {
    await db.outboxDao.readyPasswordRows(
      companyId: companyId,
      now: _now().millisecondsSinceEpoch,
    );
    await drainOnce(companyId: companyId);
  }

  Future<int> _drainOnceImpl(String companyId) async {
    // Re-arm rows orphaned in `in_flight` by a prior interrupted pass (app
    // killed / process death between `markInFlight` and the catch handler).
    // `nextReady` only selects `pending`, so without this an orphaned row is
    // invisible forever. Safe here: `drainOnce` is single-flight per company
    // and rows are processed sequentially, so at drain-start no `in_flight`
    // row for this company is a live request — and the idempotency key makes a
    // re-send harmless regardless.
    await db.outboxDao.resetInFlightForCompany(companyId);
    final nowMs = _now().millisecondsSinceEpoch;
    final rows = await db.outboxDao.nextReady(companyId: companyId, now: nowMs);
    var successes = 0;
    for (final snapshot in rows) {
      if (_cancelRequested) break;
      // Re-read the row immediately before dispatch. An earlier CREATE in THIS
      // same pass may have remapped a tmp_ id -> real id inside this row's
      // payload/entityId (OutboxDao.rewriteTempIdInPayloads runs from
      // applyCreateResponse). Our `nextReady` snapshot predates that write, so
      // dispatching it as-is would send the stale tmp_ id — e.g. an offline
      // create + edit drained together would `PUT /invoices/tmp_xxx` -> entity
      // missing and park the edit as a bogus conflict. byId() returns the
      // post-remap row.
      final row = await db.outboxDao.byId(snapshot.id);
      if (row == null) continue; // deleted / superseded mid-pass
      // No longer pending? An earlier row in THIS pass may have turned this
      // one terminal — e.g. a parent create's 422 cascaded `_failTmpDependents`
      // and marked this dependent dead. Skip it; otherwise the tmp_-ref
      // branch below would `scheduleRetry` it straight back to `pending`.
      if (row.state != 'pending') continue;
      var current = row;
      // Materialized once per row (the token scan regexes the full payload
      // JSON — potentially tens of KB for invoices), refreshed only after a
      // successful heal rewrote the row.
      var tmpTokens = _unresolvedTempRefTokens(current);
      if (tmpTokens.isNotEmpty) {
        // Before deferring, try to heal: a referenced tmp_ entity may have
        // ALREADY synced. rewriteTempIdInPayloads (the create-success healer)
        // only rewrites rows that exist AT create-success time, so a row
        // enqueued AFTER its dependency synced is never touched by it — e.g.
        // an inline-created tag whose tiny create round-tripped and was
        // deleted while the user was still filling the task form, then the
        // task is saved carrying the now-dead tmp_ tag id. id_remap mappings
        // are permanent, so resolve each tmp_ token there and rewrite the
        // ones that map; only genuinely-unresolved tokens defer the row.
        final healed = await _healResolvedTempRefs(current);
        if (healed != null) {
          current = healed;
          tmpTokens = _unresolvedTempRefTokens(current);
        }
      }
      if (tmpTokens.isNotEmpty) {
        // Dead-end check first: a token the heal above could not resolve (no
        // permanent id_remap) AND with no create outbox row in ANY state can
        // never heal — its parent create was discarded (ghost-discard deletes
        // the rows; id_remap only exists once a create SUCCEEDS). Deferring
        // such a row forever turns the Outbox screen's Retry into an immortal
        // zombie that also pins pendingCountFor > 0, wedging "Sync first"
        // logout. A parent create that merely failed / parked / died still
        // EXISTS as a row, so every recoverable chain keeps deferring below.
        var orphaned = false;
        for (final token in tmpTokens) {
          final parentExists = await db.outboxDao.hasCreateRowFor(
            companyId: current.companyId,
            entityId: token,
          );
          if (!parentExists) {
            orphaned = true;
            break;
          }
        }
        if (orphaned) {
          await _markDead(
            current,
            'References a discarded unsynced record',
            null,
          );
          continue;
        }
        // Still references a not-yet-created entity — its parent create didn't
        // produce a real id (it failed earlier in this pass, is parked, or is
        // dead). Dispatching anyway sends the tmp_ id to the server: a
        // PUT/DELETE on `/<entity>/tmp_x` comes back entity-missing and parks
        // this row as a bogus year-long "conflict" (with a misleading
        // resolution dialog), and a
        // create carrying e.g. `client_id: tmp_x` dies on a 422. Leave it
        // pending: when the parent create eventually lands,
        // rewriteTempIdInPayloads heals the reference and the next drain
        // sends it.
        _log.info(
          'Skipping outbox row ${current.id}'
          ' (${current.entityType}/${current.entityId}):'
          ' unresolved tmp_ reference awaiting its parent create',
        );
        // Vacate the nextReady window (a 50-row snapshot): a skipped row
        // left due-and-pending forever would pin the window and starve
        // every row queued behind it once skips accumulate. A short defer
        // (attempts unchanged) keeps it cheap — when the parent create
        // lands, rewriteTempIdInPayloads heals the reference and the row
        // dispatches on a pass within the defer window.
        await db.outboxDao.scheduleRetry(
          id: current.id,
          attempts: current.attempts,
          nextAttemptAt:
              _now().millisecondsSinceEpoch +
              const Duration(minutes: 1).inMilliseconds,
          error: 'Waiting for an unsynced referenced record to sync first',
        );
        continue;
      }
      final dispatched = await _attempt(current);
      if (dispatched) successes++;
    }
    return successes;
  }

  /// Heal any `tmp_` tokens in [row] (entityId + payload) that ALREADY have an
  /// `id_remap` mapping, rewriting them to the real id in the database.
  /// Returns the re-read row when anything changed, else `null`.
  ///
  /// Covers the "referenced entity synced before this row was enqueued"
  /// ordering that `rewriteTempIdInPayloads` (create-success-time only) can't:
  /// e.g. an inline-created tag whose create round-tripped and was deleted
  /// before the dependent task/project row existed. The tag's id_remap entry
  /// outlives its outbox row, so we resolve through it here. Tokens with no
  /// mapping yet are left in place (the row defers as before, then heals via
  /// rewriteTempIdInPayloads when that create lands — the offline ordering).
  Future<OutboxRow?> _healResolvedTempRefs(OutboxRow row) async {
    final isCreate =
        MutationKind.tryParse(row.mutationKind) == MutationKind.create;
    final tokens = <String>{};
    if (!isCreate && row.entityId.startsWith('tmp_')) tokens.add(row.entityId);
    for (final m in _tempIdPattern.allMatches(row.payload)) {
      final t = m.group(0)!;
      if (isCreate && t == row.entityId) continue; // a create's own tmp id
      tokens.add(t);
    }
    var changed = false;
    for (final tempId in tokens) {
      final realId = await db.idRemapDao.resolveAnyType(tempId);
      if (realId == null) continue;
      // tmp_ ids are globally unique, so this rewrites the token wherever it
      // appears across the company's pending/dead rows (and re-arms the
      // deferred row) — the same primitive the create-success path uses.
      // NOTE: `entityType` here is the CARRIER row's type, which may differ
      // from the token's owning entity (e.g. a `tmp_` tag id inside a `client`
      // row's payload). That's fine ONLY because rewriteTempIdInPayloads
      // matches purely by `(companyId, state, token)` and ignores entityType —
      // the heal is intentionally type-agnostic. If that DAO query ever starts
      // scoping by entityType, this call must pass the token's own type (or a
      // wildcard). Covered by the cross-type case in sync_repository_test
      // (a `tag` id_remap healed inside a `client` row).
      await db.outboxDao.rewriteTempIdInPayloads(
        companyId: row.companyId,
        entityType: row.entityType,
        tempId: tempId,
        realId: realId,
      );
      changed = true;
    }
    if (!changed) return null;
    return db.outboxDao.byId(row.id);
  }

  /// Matches ids minted by `BaseEntityRepository.mintTempId()`
  /// (`tmp_<uuid-v4>`). Strict on the full UUID shape so user-typed text
  /// that merely starts with "tmp_" can never flag a payload.
  static final RegExp _tempIdPattern = RegExp(
    r'tmp_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
  );

  /// The `tmp_` tokens in [row] that still reference a not-yet-created
  /// entity — its own entityId (for non-creates) plus every payload token
  /// other than a create's own id (`toApiJson(preserveTempId: true)`
  /// legitimately embeds the row's own tmp_ id in its create payload).
  Set<String> _unresolvedTempRefTokens(OutboxRow row) {
    final isCreate =
        MutationKind.tryParse(row.mutationKind) == MutationKind.create;
    final tokens = <String>{};
    if (!isCreate && row.entityId.startsWith('tmp_')) tokens.add(row.entityId);
    for (final m in _tempIdPattern.allMatches(row.payload)) {
      final t = m.group(0)!;
      if (isCreate && t == row.entityId) continue;
      tokens.add(t);
    }
    return tokens;
  }

  Future<bool> _attempt(OutboxRow row) async {
    final handlers = registry.byWireName(row.entityType);
    if (handlers == null) {
      _log.warning('No registry entry for ${row.entityType}; marking dead.');
      await _markDead(row, 'No dispatcher for entity type', null);
      return false;
    }
    final kind = MutationKind.tryParse(row.mutationKind);
    if (kind == null) {
      // Open-ended actions (e.g. `action:send_email`) aren't part of M1;
      // when M2 introduces them, this branch will route to a dedicated
      // action handler. For now, fail closed.
      _log.warning('Unknown mutation kind ${row.mutationKind}; marking dead.');
      await _markDead(row, 'Unknown mutation kind', null);
      return false;
    }

    await db.outboxDao.markInFlight(row.id);
    try {
      await handlers.dispatcher.dispatch(row: row, kind: kind);
      await db.outboxDao.deleteRow(row.id);
      return true;
    } on ValidationException catch (e) {
      _log.info('422 on ${row.entityType}/${row.entityId}: ${e.message}');
      await db.outboxDao.markDead(
        id: row.id,
        error: e.message,
        statusCode: 422,
        fieldErrorsJson: e.fieldErrors.isEmpty
            ? null
            : jsonEncode(e.fieldErrors),
      );
      _events.add(
        ValidationFailedEvent(
          entityType: _entityTypeFrom(handlers.type),
          entityId: row.entityId,
          fieldErrors: e.fieldErrors,
          message: e.message,
        ),
      );
      // A failed tmp_ CREATE strands every dependent that referenced it —
      // their tmp ref can never be rewritten now (rewrite only fires on a
      // create SUCCESS), so the drain's tmp_-dependency guard would defer
      // them forever and "Sync first" could never settle. Mark them dead
      // (kept, retryable once the parent is fixed); recursion covers deeper
      // levels.
      if (MutationKind.tryParse(row.mutationKind) == MutationKind.create &&
          row.entityId.startsWith('tmp_')) {
        if (row.entityType == 'tag') {
          // A failed tag create must not kill the task/project that referenced
          // it — strip the dead tmp tag id from their payloads so they still
          // save with their remaining tags, instead of marking them dead (M1).
          await _stripFailedTagFromDependents(row.companyId, row.entityId);
        } else {
          await _failTmpDependents(row.companyId, row.entityId, discard: false);
        }
      }
      return false;
    } on RecordDeletedException catch (e) {
      // The row still exists server-side but is soft-deleted (`is_deleted`),
      // and the server says so in plain words: "Restore the record to enable
      // editing". Retrying is futile, so mark dead like any permanent 4xx —
      // but the failure surface reads `statusCode == 400` + this message and
      // offers **Restore**, which is the one action that unblocks the save.
      //
      // NOTE: must precede the ServerException catch — RecordDeletedException
      // is a subtype of it. Archived records never land here: the server's
      // guard is `is_deleted` only, so an archived edit succeeds (200).
      _log.info(
        'Record deleted server-side on ${row.entityType}/${row.entityId}: '
        '${e.message}',
      );
      await _markDead(row, e.message, e.statusCode);
      return false;
    } on NotFoundException catch (e) {
      // The entity is gone server-side (Invoice Ninja reports this as HTTP 400
      // `"No query results for model …"`, not 404 — see
      // `ApiClient._raiseFromResponse`) while we held this pending edit, so
      // there's nothing left to update. (The same signal on a DELETE is
      // swallowed upstream by the dispatcher as idempotent success.) Re-sending
      // would fail forever, so park it (1-year safety valve, same as 409) and
      // emit a deleted-server-side ConflictEvent — the sheet offers
      // discard-locally only (the only escape; "use my changes" would re-park).
      // NOTE: must precede the ConflictException catch — NotFoundException is a
      // subtype of it.
      _log.info(
        'Entity missing on ${row.entityType}/${row.entityId}: deleted '
        'server-side, parking as a conflict',
      );
      await db.outboxDao.scheduleRetry(
        id: row.id,
        attempts: row.attempts,
        nextAttemptAt:
            _now().millisecondsSinceEpoch +
            const Duration(days: 365).inMilliseconds,
        error: e.message,
        statusCode: 400,
      );
      _events.add(
        ConflictEvent(
          entityType: handlers.type,
          entityId: row.entityId,
          companyId: row.companyId,
          message: e.message,
          wireEntityType: row.entityType,
          statusCode: 400,
          outboxRowId: row.id,
          isDeletedServerSide: true,
        ),
      );
      return false;
    } on ConflictException catch (e) {
      _log.info('409 on ${row.entityType}/${row.entityId}: ${e.message}');
      // Leave the row pending but parked far in the future. Auto-retrying
      // a 409 just re-hits the same conflict; the user has to resolve it
      // via the ConflictResolutionSheet, which either re-enqueues a fresh
      // mutation (and discards this row) or discards this row outright.
      // The 1-year delay is a safety valve in case the UI never resolves;
      // we don't want a stuck row to silently burn API quota.
      await db.outboxDao.scheduleRetry(
        id: row.id,
        attempts: row.attempts,
        nextAttemptAt:
            _now().millisecondsSinceEpoch +
            const Duration(days: 365).inMilliseconds,
        error: e.message,
        statusCode: 409,
      );
      _events.add(
        ConflictEvent(
          entityType: handlers.type,
          entityId: row.entityId,
          companyId: row.companyId,
          message: e.message,
          wireEntityType: row.entityType,
          statusCode: 409,
          outboxRowId: row.id,
        ),
      );
      return false;
    } on PlanRequiredException catch (e) {
      _log.info(
        'Plan upgrade required for ${row.entityType}/${row.entityId}: '
        '${e.message}',
      );
      // No amount of retrying upgrades the account. Mark dead so the
      // user sees the failure in the outbox screen and resolves it by
      // upgrading + re-enqueuing or discarding the row.
      await _markDead(row, e.message, 402);
      return false;
    } on PasswordRequiredException {
      _log.info('Password required for ${row.entityType}/${row.entityId}');
      // The server gates this mutation behind a password (e.g. a plain user
      // PUT). Upgrade the row so that once the user enters their password the
      // retry attaches X-API-PASSWORD-BASE64 — the dispatcher forwards
      // `row.requiresPassword`, and `api_client.mutate` only reads the cache
      // when it's true. Without this, a row enqueued with
      // requiresPassword=false would 412 forever.
      await db.outboxDao.updateRequiresPassword(id: row.id, value: true);
      // Count the failure like any other 4xx. This path used to re-park at
      // +1 min with `attempts: row.attempts` — never incremented — so the row
      // could never reach `kMaxAttempts` and every drain trigger (the 5-min
      // refresh tick, app resume, connectivity, any new enqueue) re-emitted
      // the event below and reopened the sheet. A user who cancelled, or who
      // mistyped (the sheet does no server-side validation, so a wrong
      // password is cached and 412s here), got that modal every few minutes
      // forever with no terminal state. Now it backs off and dies into the
      // Outbox screen like any other permanent failure — and
      // `readyPasswordRows` resurrects it if a password arrives later.
      final isFirstPark = row.attempts == 0;
      await _retryWithBackoff(row, 'Password required', 412);
      // Prompt ONCE per row. Re-emitting on every retry is what made a cancel
      // mean "ask again in five minutes" instead of "leave me alone"; the
      // death path (DeadEvent → failure toast → Outbox) is the visible
      // fallback for a row the user never unlocked.
      if (isFirstPark) {
        _events.add(
          PasswordRequiredEvent(
            entityType: handlers.type,
            entityId: row.entityId,
          ),
        );
      }
      return false;
    } on RateLimitedException catch (e) {
      final delay = e.retryAfter ?? const Duration(seconds: 30);
      await db.outboxDao.scheduleRetry(
        id: row.id,
        attempts: row.attempts,
        nextAttemptAt: _now().millisecondsSinceEpoch + delay.inMilliseconds,
        error: e.message,
        statusCode: 429,
      );
      return false;
    } on UnauthorizedException {
      // Auth layer is already handling logout — leave the row, it will
      // resume after re-login.
      await db.outboxDao.scheduleRetry(
        id: row.id,
        attempts: row.attempts,
        nextAttemptAt:
            _now().millisecondsSinceEpoch +
            const Duration(minutes: 1).inMilliseconds,
        error: 'Unauthorized',
        statusCode: 401,
      );
      return false;
    } on NetworkException catch (e) {
      await _retryWithBackoff(row, e.message, null);
      return false;
    } on ServerException catch (e) {
      // 4xx client errors are permanent: the identical request will keep
      // failing, so don't burn the full retry budget (≈13 min of backoff)
      // before the user hears about it — mark dead immediately so a `DeadEvent`
      // fires on the first attempt. 5xx (and anything else) stays on transient
      // backoff. The 4xx with dedicated resolution UI (401/403/412/409/422/
      // 429/402, plus the entity-missing and record-deleted flavors of 400) are
      // all caught above; only genuinely-permanent codes reach here — including
      // a bare **404**, which on this server means we built a bad URL/verb
      // ("Route does not exist" / "Method not supported for this route"), not
      // that the entity vanished.
      if (e.statusCode >= 400 && e.statusCode < 500) {
        await _markDead(row, e.message, e.statusCode);
      } else {
        await _retryWithBackoff(row, e.message, e.statusCode);
      }
      return false;
    } on ClientTooOldException catch (e) {
      // The UI surfaces a "please update" screen elsewhere; sync stops.
      await db.outboxDao.scheduleRetry(
        id: row.id,
        attempts: row.attempts,
        nextAttemptAt:
            _now().millisecondsSinceEpoch +
            const Duration(hours: 1).inMilliseconds,
        error: 'Client too old: needs ${e.minRequiredVersion}',
        statusCode: null,
      );
      return false;
    } on Object catch (e, st) {
      // Catch-all: anything not matched above (DemoModeException, a future
      // exception type, a non-API throw from inside a customAction) routes
      // to backoff. Without this, an unhandled throw leaves the row in
      // `in_flight` forever — `nextReady` only picks up `pending`, so the
      // row is invisible to subsequent drains.
      _log.warning(
        'Unhandled exception on ${row.entityType}/${row.entityId}',
        e,
        st,
      );
      await _retryWithBackoff(row, e.toString(), null);
      return false;
    }
  }

  Future<void> _retryWithBackoff(OutboxRow row, String error, int? code) async {
    final nextAttempt = row.attempts + 1;
    if (nextAttempt >= kMaxAttempts) {
      await _markDead(row, error, code);
      return;
    }
    // `nextAttempt` is the count of attempts including this one (1, 2, 3, …);
    // the schedule is the wait BEFORE attempt N+1, so index by `nextAttempt - 1`
    // — first failure (nextAttempt=1) uses kBackoffSchedule[0] = 5s, etc.
    final delay =
        kBackoffSchedule[(nextAttempt - 1).clamp(
          0,
          kBackoffSchedule.length - 1,
        )];
    await db.outboxDao.scheduleRetry(
      id: row.id,
      attempts: nextAttempt,
      nextAttemptAt: _now().millisecondsSinceEpoch + delay.inMilliseconds,
      error: error,
      statusCode: code,
    );
  }

  /// After a discarded row is removed from the outbox, release the optimistic
  /// `is_dirty` flag its mutation set so a later refresh can restore server
  /// truth — otherwise the abandoned edit renders as authoritative forever
  /// (`upsertAllPreservingDirty` skips dirty rows). Reorder rows clear the
  /// payload's ids (their entityId is the synthetic `_sort`); every other row
  /// clears its own entityId. Guarded per-id: an id that still has ANOTHER
  /// pending row keeps its flag so that separate edit stays protected.
  Future<void> _reconcileDiscardedDirty(OutboxRow row) async {
    if (MutationKind.tryParse(row.mutationKind) == MutationKind.reorder) {
      await _clearReorderDirty(row);
      return;
    }
    final stillActive = await db.outboxDao.hasActiveRowsForEntity(
      companyId: row.companyId,
      entityType: row.entityType,
      entityId: row.entityId,
    );
    if (!stillActive) {
      await registry
          .byWireName(row.entityType)
          ?.dispatcher
          .clearLocalDirty(companyId: row.companyId, id: row.entityId);
    }
  }

  /// Clear the optimistic `is_dirty` flag on every row a reorder touched, once
  /// that reorder terminates without success (dead or discarded).
  ///
  /// A reorder marks EVERY reordered row `is_dirty=true` but enqueues a single
  /// synthetic `_sort` outbox row, so the normal entityId-keyed clear can't
  /// reach them (its entityId is `_sort`, which matches no entity row). The
  /// success handler clears them (`clearDirtyForReorder`); this covers the
  /// failure paths. Without it those rows stay `is_dirty=true` forever and
  /// `upsertAllPreservingDirty` silently drops every inbound server refresh for
  /// them. Only clears an id that has no OTHER pending row, so a genuine
  /// separate edit stays protected.
  Future<void> _clearReorderDirty(OutboxRow row) async {
    if (MutationKind.tryParse(row.mutationKind) != MutationKind.reorder) return;
    final dispatcher = registry.byWireName(row.entityType)?.dispatcher;
    if (dispatcher == null) return;
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(row.payload) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    // Task reorder carries `{status_ids, task_ids: {statusId: [taskId…]}}`;
    // task-status reorder carries `{status, all_ids: [statusId…]}`. Collect the
    // reordered ids from whichever shape is present.
    final ids = <String>{};
    final taskIds = payload['task_ids'];
    if (taskIds is Map) {
      for (final list in taskIds.values) {
        if (list is List) ids.addAll(list.cast<String>());
      }
    }
    if (payload['status_ids'] is List) {
      ids.addAll((payload['status_ids'] as List).cast<String>());
    }
    if (payload['all_ids'] is List) {
      ids.addAll((payload['all_ids'] as List).cast<String>());
    }
    for (final affectedId in ids) {
      final stillActive = await db.outboxDao.hasActiveRowsForEntity(
        companyId: row.companyId,
        entityType: row.entityType,
        entityId: affectedId,
      );
      if (!stillActive) {
        await dispatcher.clearLocalDirty(
          companyId: row.companyId,
          id: affectedId,
        );
      }
    }
  }

  Future<void> _markDead(OutboxRow row, String error, int? code) async {
    await db.outboxDao.markDead(id: row.id, error: error, statusCode: code);
    // A permanently-failed reorder must release its optimistic dirty flags so
    // future refreshes can restore the server's ordering (see below).
    await _clearReorderDirty(row);
    final handlers = registry.byWireName(row.entityType);
    if (handlers != null) {
      _events.add(
        DeadEvent(
          entityType: handlers.type,
          entityId: row.entityId,
          message: error,
          statusCode: code,
          handledByCaller: _callerDisplayedRows.contains(row.id),
        ),
      );
    }
  }

  EntityType _entityTypeFrom(EntityType t) => t;
}
