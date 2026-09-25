import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_event.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/company_switched_exception.dart';
import 'package:admin/data/services/request_scope.dart';

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

/// Re-park delay for a row that failed because the network was unavailable.
/// Deliberately flat and budget-neutral — see the `NetworkException` arm in
/// `SyncRepository._attempt`. Long enough not to spin while offline, short
/// enough that the row goes out promptly once connectivity returns (the
/// reconnect / resume / enqueue triggers usually beat it anyway).
const Duration kOfflineRetryDelay = Duration(seconds: 60);

/// How old a failed change is before the Outbox offers to discard it in bulk
/// ([SyncRepository.pruneDeadRows]).
const Duration kOldFailureAge = Duration(days: 90);

/// Server answers after which a write may or may not have been applied: the
/// app threw part-way through (500), or a proxy gave up waiting on an app
/// server that may have finished (502, 504, and Cloudflare's 520 / 524). A
/// 503 — maintenance, or an origin that was never reached — is not here:
/// nothing ran.
const Set<int> kOutcomeUnknownStatuses = {500, 502, 504, 520, 524};

/// The `last_error` of a row the drain parked behind an `unconfirmed` row of
/// the same record — shown in the Outbox, and how Resend and Discard of that
/// row find the ones to re-arm (`OutboxDao.rearmHeldBehind`).
const String kHeldBehindUnconfirmedError =
    'Waiting for an earlier change that may already have been sent';

/// The `last_error` of a row the drain parked because it references a `tmp_`
/// record whose create has not landed yet.
const String kWaitingForReferencedRecordError =
    'Waiting for an unsynced referenced record to sync first';

/// The `last_error` of a `create` the drain refused to send because its record
/// already exists on the server: the server ignores `Idempotency-Key`, so
/// sending it would make the record twice.
const String kAlreadyCreatedError =
    'Already created on the server without these changes — open the record '
    'and save it again to apply them.';

/// Whether [message] — a row's `last_error`, or a save's failure — is
/// [kAlreadyCreatedError].
bool isAlreadyCreatedRejection(String? message) =>
    message == kAlreadyCreatedError;

/// Whether [row] is a `create` of a record that already exists: re-keyed to
/// its real id when an earlier attempt landed, or refused as such. Sending it
/// again can only make the record twice.
bool isCreateOfExistingRecord(OutboxRow row) =>
    row.mutationKind == MutationKind.create.wireName &&
    (!row.entityId.startsWith('tmp_') ||
        isAlreadyCreatedRejection(row.lastError));

/// Whether [row] is a `create` that a newer create of the same record, also
/// in [queue], replaced — the fixed re-save from its edit form. Sending it
/// first would put its stale content on the server, and the fix would then
/// be refused as a create of an existing record.
bool isReplacedCreate(OutboxRow row, Iterable<OutboxRow> queue) =>
    row.mutationKind == MutationKind.create.wireName &&
    queue.any(
      (o) =>
          o.id > row.id &&
          o.companyId == row.companyId &&
          o.entityType == row.entityType &&
          o.entityId == row.entityId &&
          o.mutationKind == MutationKind.create.wireName,
    );

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

  /// The row — or an earlier change to the same record it is queued behind —
  /// may already have reached the server, and nothing sends it until the user
  /// checks and chooses Send again or Discard ([OutboxState.unconfirmed]).
  /// [SyncRowResult.unconfirmedRowId] names the row that needs them.
  unconfirmed,
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
    this.unconfirmedRowId,
    this.unconfirmedMutationKind,
  });

  final SyncRowOutcome outcome;
  final Map<String, List<String>> fieldErrors;
  final String? message;
  final int? statusCode;

  /// For [SyncRowOutcome.unconfirmed]: the `unconfirmed` row — the awaited
  /// one, or the earlier one holding it back — and its `mutation_kind`.
  final int? unconfirmedRowId;
  final String? unconfirmedMutationKind;
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

  /// The company whose token outbound requests are currently carrying —
  /// `auth.credentials.value?.companyId`, wired by DI. Null (tests, or before
  /// credentials exist) disables the check.
  ///
  /// `ApiClient` builds every request from a live credentials notifier and has
  /// no notion of which company a drain pass is for, so a pass that outlives a
  /// company switch dispatches the OLD company's mutations under the NEW
  /// company's token. The server then can't find those ids, answers 400 "No
  /// query results", and the row parks a year as a bogus conflict whose only
  /// forward option hard-deletes a local record that is alive on the server.
  String? Function()? activeCompanyId;

  /// The device's connectivity, wired by DI (`ConnectivityWatcher.isOnline`)
  /// on web only; null means "assume online". Read just before each attempt
  /// so a transport failure after the device reported no connectivity is
  /// filed as "never sent" ([RequestScope.offlineBeforeSend]) — which only
  /// web's `ApiClient` consults, its body probe being blind. It classifies —
  /// it never skips the attempt, so a platform that misreports "offline"
  /// can't stall the outbox.
  Future<bool> Function()? isOnline;

  /// Re-fetches one record from the server into Drift, dirty-preserving —
  /// wired by DI to the entity repository's `refreshByIds`; null (tests)
  /// skips it. Run once a row whose write landed has been settled without its
  /// reply ([_settleCommitted]), so the local copy converges on what the
  /// server now holds.
  Future<void> Function(String companyId, EntityType type, String id)?
  refreshRecord;

  /// Re-fetches the newest page of one entity's list — wired by DI to its
  /// first-page prefetcher; null (tests) skips it. A record the server
  /// created leads that page, which is what [recheck] needs for a create.
  Future<void> Function(String companyId, EntityType type)? refreshNewest;

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

  /// Holds taken by [holdDrains] and not yet released.
  int _holds = 0;

  /// Start no pass until [releaseDrains], and stop a running one at its next
  /// row — without waiting for it, unlike [cancel]: a prompt must not stall on
  /// a request already on the wire. Holds nest, so one flow's release doesn't
  /// lift another's. The sign-out review takes one, so a reconnect's drain
  /// can't send the changes the user has just chosen to discard.
  void holdDrains() {
    _holds++;
    _cancelRequested = true;
  }

  /// Release one [holdDrains].
  void releaseDrains() {
    if (_holds > 0) _holds--;
  }

  /// Count of non-`dead` outbox rows for [companyId]. Wraps the DAO so the
  /// UI shell doesn't reach into the database layer directly.
  Future<int> pendingCountFor(String companyId) =>
      db.outboxDao.pendingCountForCompany(companyId);

  /// How many of [companyId]'s pending rows wait on another change — held
  /// behind one that may already have gone through, or parked until a record
  /// they reference syncs — rather than on the network. No drain sends them
  /// until the user deals with that change.
  Future<int> pendingWaitingOnAnotherCount(String companyId) =>
      db.outboxDao.countPendingParkedWith(
        companyId: companyId,
        errors: const [
          kHeldBehindUnconfirmedError,
          kWaitingForReferencedRecordError,
        ],
      );

  /// Distinct company ids with any non-`dead` outbox row — the ground truth
  /// the full-logout / idle-timeout guards check (see
  /// `OutboxDao.companiesWithActiveRows` for why this beats
  /// `session.companies`).
  Future<List<String>> companiesWithActiveRows() =>
      db.outboxDao.companiesWithActiveRows();

  /// True when ANY company still holds unsynced outbox rows — the predicate
  /// every involuntary session-end must consult before choosing a destructive
  /// logout. `AuthRepository.logout(data: LocalDataPolicy.destroy)`
  /// wipes the whole Drift database, outbox included, so ending a session
  /// without this check silently destroys the user's offline edits (CLAUDE.md:
  /// "never silently drops user data").
  ///
  /// A non-active company's pending rows count just as much as the active
  /// one's — the wipe is global. So do `dead` rows: a rejected edit waits in
  /// the Outbox (and in its dirty local row) for the user to fix and retry,
  /// and a wipe destroys it just as surely as a pending one. Fast local read
  /// only (no network drain), so it's safe on the security-lock and 401
  /// paths. **Errs toward preserving** on any error: keeping data that could
  /// have been dropped is recoverable, dropping data that should have been
  /// kept is not.
  Future<bool> hasUnsyncedWork() async {
    try {
      return (await db.outboxDao.companiesWithUnsyncedRows()).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  /// Count of rows that need the user — `dead` and `unconfirmed` — across
  /// every company: the changes a full logout would delete that "Sync first"
  /// can't send. Surfaced by the sign-out prompt, whose pending count
  /// deliberately leaves them out.
  Future<int> attentionCountEverywhere() => db.outboxDao.attentionCountAll();

  /// The companies, in order, holding a change that waits on the user.
  Future<List<String>> companiesWithAttentionRows() =>
      db.outboxDao.companiesWithAttentionRows();

  /// Discard [id] as an edit form's "Discard failed save" means it: that save
  /// and the older failed saves of the same record it replaced. Those go
  /// FIRST, so [discardOutboxRow]'s dirty reconcile can release the record —
  /// kept, one of them held its dirty flag, and the record went on showing
  /// the discarded content, shielded from refresh. A never-synced record's
  /// own failed create stays when a later edit is discarded: it is the
  /// record. The Outbox's Discard still takes one row, via
  /// [discardOutboxRow].
  Future<bool> discardFailedSave(int id) async {
    final row = await db.outboxDao.byId(id);
    if (row == null) return false;
    final kind = MutationKind.tryParse(row.mutationKind);
    if ((kind == MutationKind.create || kind == MutationKind.update) &&
        row.state != 'in_flight') {
      await db.outboxDao.deleteOlderDeadSaves(
        companyId: row.companyId,
        entityType: row.entityType,
        entityId: row.entityId,
        beforeId: row.id,
        includeCreates: !row.entityId.startsWith('tmp_'),
      );
    }
    return discardOutboxRow(id);
  }

  /// Drop the failed save [id], and the older failed saves of the same record,
  /// once a newer save of it has gone through: their payloads are stale. Only a `dead` create / update is
  /// superseded by a save — anything else on the record (a rejected email,
  /// a payment) is separate work the save did not replace, and stays.
  ///
  /// And only a create supersedes a failed create that has not landed (still
  /// under its `tmp_` id): an edit of that record saves an update, which waits
  /// behind the create and can't send before it — dropping the create
  /// stranded the record, the update then dying as referencing a discarded
  /// one. A failed create under a real id is stale like any failed save.
  /// Returns whether a row was dropped.
  Future<bool> supersedeDeadSave(int id) async {
    final row = await db.outboxDao.byId(id);
    if (row == null || row.state != 'dead') return false;
    final kind = MutationKind.tryParse(row.mutationKind);
    if (kind != MutationKind.create && kind != MutationKind.update) {
      return false;
    }
    if (kind == MutationKind.create && row.entityId.startsWith('tmp_')) {
      final newest = await db.outboxDao.findNewestCreateForEntity(
        companyId: row.companyId,
        entityType: row.entityType,
        entityId: row.entityId,
      );
      if (newest == null || newest.id <= row.id) return false;
    }
    // The older failed saves are staler still — as in [discardFailedSave].
    // Kept, the oldest one's error came back on the next open, and an Outbox
    // Retry would have put its content over the save that just went through.
    // A never-synced record's failed create stays unless a create replaced it.
    await db.outboxDao.deleteOlderDeadSaves(
      companyId: row.companyId,
      entityType: row.entityType,
      entityId: row.entityId,
      beforeId: row.id,
      includeCreates:
          kind == MutationKind.create || !row.entityId.startsWith('tmp_'),
    );
    await db.outboxDao.deleteRow(id);
    return true;
  }

  /// Fetch what `unconfirmed` [row] may have changed, so the user can see
  /// whether it went through before choosing Send again or Discard: for a
  /// create, the newest page of its list (a record the server made would lead
  /// it); for anything else, the record itself. Best-effort — never throws.
  Future<void> recheck(OutboxRow row) async {
    final handlers = registry.byWireName(row.entityType);
    if (handlers == null) return;
    try {
      if (row.mutationKind == MutationKind.create.wireName) {
        await refreshNewest?.call(row.companyId, handlers.type);
      } else if (!row.entityId.startsWith('_')) {
        await refreshRecord?.call(row.companyId, handlers.type, row.entityId);
      }
    } catch (e) {
      _log.fine('Re-checking ${row.entityType} ${row.entityId} failed: $e');
    }
  }

  /// The user checked an `unconfirmed` row and chose to send it again — the
  /// Outbox screen's Send again, or the edit form's. It goes back in line with
  /// a fresh budget and the same idempotency key, and a drain is kicked.
  /// Returns whether the row was still `unconfirmed` to move.
  Future<bool> resendUnconfirmed(int id) async {
    final row = await db.outboxDao.byId(id);
    if (row == null) return false;
    final moved = await db.outboxDao.resendUnconfirmed(
      id: id,
      now: _now().millisecondsSinceEpoch,
    );
    if (moved) {
      // The saves held behind it go in the same pass, after it.
      await _rearmHeldBehind(row);
      unawaited(drainOnce(companyId: row.companyId));
    }
    return moved;
  }

  /// Make the rows the drain parked behind unconfirmed [row] due now, once it
  /// is back in line or gone — they wait on nothing else. Only those rows:
  /// matched by the error the drain parked them with.
  Future<void> _rearmHeldBehind(OutboxRow row) => db.outboxDao.rearmHeldBehind(
    companyId: row.companyId,
    entityType: row.entityType,
    entityId: row.entityId,
    afterId: row.id,
    heldError: kHeldBehindUnconfirmedError,
    now: _now().millisecondsSinceEpoch,
  );

  /// Discard one outbox row. If it's a never-synced offline `create`
  /// (`tmp_` id, no `id_remap` entry yet) the orphaned local Drift record
  /// is also hard-deleted — with no outbox row it could never reach the
  /// server, so it would otherwise linger forever as a ghost. An
  /// `unconfirmed` create goes the same way, but what was made offline
  /// against it is kept, dead: the record may exist on the server after all
  /// ([_ParentGone.discardedUnconfirmed]). A row that's
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
    if (!await _discardTakesRecord(row)) {
      await db.outboxDao.deleteRow(id);
      await _reconcileDiscardedDirty(row);
      if (row.state == 'unconfirmed') {
        await _rearmHeldBehind(row);
        // What it held goes now, as after a Resend — for the active company
        // only: another one's drain can't send, and would surface its events
        // here.
        if (_isActive(row.companyId)) {
          unawaited(drainOnce(companyId: row.companyId));
        }
      }
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
    // whole offline subtree — unless the create may already have reached the
    // server: then the parent may well exist there, and the offline work
    // pointing at it is kept for the user to re-point once it arrives.
    await _failTmpDependents(
      row.companyId,
      row.entityId,
      row.state == 'unconfirmed'
          ? _ParentGone.discardedUnconfirmed
          : _ParentGone.discarded,
    );
    return localDeleted;
  }

  /// Whether discarding [row] deletes a record the server never saw from this
  /// device, with the unsynced records made for it — so a form asks first,
  /// as the Outbox's Discard does. Not for a create that may already have
  /// reached the server: it goes too, but what was made for it is kept for
  /// the user to re-point, and "never saved" would be untrue.
  Future<bool> discardDeletesUnsyncedRecord(OutboxRow row) async =>
      row.state != 'unconfirmed' && await _discardTakesRecord(row);

  /// Whether [discardOutboxRow] takes [row]'s record with it — the create of
  /// a record the server never saw (the ghost path). Not while another
  /// attempt at the same create is on the wire — a re-save queued while it
  /// was in flight — which may still make the record: then the row goes
  /// alone, and the in-flight one, the local record and what was made
  /// against it stay for that attempt's landing, or failure, to settle.
  Future<bool> _discardTakesRecord(OutboxRow row) async {
    if (MutationKind.tryParse(row.mutationKind) != MutationKind.create ||
        !row.entityId.startsWith('tmp_') ||
        await db.idRemapDao.resolve(
              entityType: row.entityType,
              tempId: row.entityId,
            ) !=
            null) {
      return false;
    }
    return !(await db.outboxDao.inFlightRowsForCompany(row.companyId)).any(
      (r) =>
          r.id != row.id &&
          r.entityType == row.entityType &&
          r.entityId == row.entityId,
    );
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
  /// [_ParentGone.discarded] = the parent was a never-synced ghost the user
  /// discarded. A dependent that is ITSELF a ghost create can never sync
  /// either, so it's removed wholesale (local record + all its outbox rows)
  /// and we recurse into ITS tmp id (catching e.g. a payment created against
  /// an offline invoice created against the discarded client). A non-ghost
  /// dependent (an update/action on a real entity that merely referenced the
  /// tmp) is marked dead.
  ///
  /// [_ParentGone.failed] = the parent's CREATE died (422). Dependents are
  /// marked dead (kept, not deleted) — the user may fix + retry the parent,
  /// and `rewriteTempIdInPayloads` (which covers dead rows) then heals their
  /// refs for a manual Retry. Recursion marks deeper levels dead too.
  ///
  /// [_ParentGone.discardedUnconfirmed] = the user discarded a create that
  /// may already have reached the server. Nothing depending on it is deleted
  /// — the parent may exist there, and the invoice made offline for it is the
  /// user's work. Dependents are marked dead, saying so, as for a failure.
  ///
  /// Terminates: every branch removes the row from the `pending` set
  /// (`markDead` flips state, ghost-delete removes it) and
  /// `pendingRowsReferencing` is pending-only, so the still-pending set
  /// strictly shrinks each step (also breaks any hypothetical reference
  /// cycle).
  Future<void> _failTmpDependents(
    String companyId,
    String parentTmpId,
    _ParentGone why,
  ) async {
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
      if (why == _ParentGone.discarded && isGhostDep) {
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
        await _failTmpDependents(companyId, dep.entityId, why);
      } else {
        // Said only for the active company: another company's rows are in
        // its own Outbox, and the shell's View opens this one's.
        await _markDead(dep, why.message, null, announce: _isActive(companyId));
        // Recurse into a dead create's OWN tmp dependents (deeper levels).
        // The `!= parentTmpId` guard skips a same-entity update keyed to the
        // parent's tmp id (already handled above), so we never re-query the
        // same needle.
        if (MutationKind.tryParse(dep.mutationKind) == MutationKind.create &&
            dep.entityId.startsWith('tmp_') &&
            dep.entityId != parentTmpId) {
          await _failTmpDependents(
            companyId,
            dep.entityId,
            // A level down, the record referenced is this dependent — dead
            // now, not one that may exist on the server.
            why == _ParentGone.discardedUnconfirmed ? _ParentGone.failed : why,
          );
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
      final encoded = jsonEncode(payload);
      // Parked on the tag, it waits on nothing now: due at once, as a row
      // whose reference resolved is. Left parked, it sat out its minute while
      // a form awaiting it reported "The server rejected this save".
      if (dep.lastError == kWaitingForReferencedRecordError) {
        await db.outboxDao.replacePayloadAndRearm(id: dep.id, payload: encoded);
      } else {
        await db.outboxDao.updatePayload(id: dep.id, payload: encoded);
      }
    }
  }

  /// Delete [companyId]'s dead outbox rows older than [ttl] — every
  /// company's when null — releasing each one's optimistic `is_dirty` flag on
  /// the way out. The Outbox screen's "Discard them" on its old-failures
  /// notice; it used to run unattended at every launch, deleting failed
  /// changes nobody had decided to give up (CLAUDE.md § Sync: unsynced work is
  /// destroyed only with the user's confirmation).
  ///
  /// The delete alone used to live in `OutboxDao`, which cannot reach the
  /// registry — so it ran as a bare `DELETE` with no reconciliation, and that
  /// orphaned the flag. `_releaseDeadLifecycleDirty` deliberately keeps
  /// `is_dirty` set for a dead create/update (the local row is the user's
  /// unsaved work, offered back by `SaveFailedBanner` + Retry), and
  /// `upsertAllPreservingDirty` skips every dirty id on every fetch,
  /// `refreshAll` and bundle apply. Once the row explaining the flag was
  /// pruned, the record was frozen at its stale local value for the life of the
  /// install — permanently `unsynced` in the list, with nothing left to retry
  /// from.
  ///
  /// The local record is deliberately LEFT IN PLACE, including a never-synced
  /// `tmp_` create's phantom: the user chose to drop old failed CHANGES, not
  /// the records they were made to — `discardOutboxRow` is the gesture that
  /// ghost-deletes one.
  Future<int> pruneDeadRows({
    String? companyId,
    Duration ttl = kOldFailureAge,
  }) async {
    final cutoff = _now().subtract(ttl).millisecondsSinceEpoch;
    final doomed = await db.outboxDao.deadRowsOlderThan(
      olderThanMs: cutoff,
      companyId: companyId,
    );
    if (doomed.isEmpty) return 0;
    final removed = await db.outboxDao.pruneDead(
      olderThanMs: cutoff,
      companyId: companyId,
    );
    // Delete first, reconcile second: `_reconcileDiscardedDirty` probes for a
    // surviving edit row for the same entity, and its doc requires the row
    // being abandoned to be gone already so it cannot match itself.
    for (final row in doomed) {
      try {
        await _reconcileDiscardedDirty(row);
      } catch (e, st) {
        _log.warning(
          'Failed to release is_dirty for a pruned '
          '${row.entityType}/${row.entityId}',
          e,
          st,
        );
      }
    }
    return removed;
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
  ///   * [SyncRowOutcome.unconfirmed] — the row went `unconfirmed`, or it is
  ///     queued behind an `unconfirmed` row for the same record, which no
  ///     drain sends until the user decides. Returned at once rather than
  ///     after [timeout]: waiting cannot change it.
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
        if (row.state == 'unconfirmed') {
          return SyncRowResult(
            outcome: SyncRowOutcome.unconfirmed,
            message: row.lastError,
            statusCode: row.lastStatusCode,
            unconfirmedRowId: row.id,
            unconfirmedMutationKind: row.mutationKind,
          );
        }
        if (row.state == 'pending') {
          final ahead = await db.outboxDao.unconfirmedRowAhead(
            companyId: row.companyId,
            entityType: row.entityType,
            entityId: row.entityId,
            beforeId: row.id,
          );
          if (ahead != null) {
            return SyncRowResult(
              outcome: SyncRowOutcome.unconfirmed,
              message: ahead.lastError,
              statusCode: ahead.lastStatusCode,
              unconfirmedRowId: ahead.id,
              unconfirmedMutationKind: ahead.mutationKind,
            );
          }
        }
        final nowMs = _now().millisecondsSinceEpoch;
        // Not when the tmp_ guard parked it behind a parent create still on
        // its way: nothing was sent, and it goes the moment the parent lands
        // (rewriteTempIdInPayloads re-arms it) — so keep waiting, into the
        // timeout's "saving in background" if need be. Reported as a failure,
        // it read "The server rejected this save". A parent that is dead or may
        // already have gone through waits for the user, and so does the save
        // behind it, so that is still reported. A dispatched row never carries
        // an unresolved token (the drain heals or defers first), so every real
        // backoff still lands here.
        if (row.state == 'pending' &&
            row.nextAttemptAt > nowMs &&
            !await _waitsOnLandingParent(row)) {
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
    if (_cancelled || _holds > 0) return Future<int>.value(0);
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

  /// Settle rows orphaned `in_flight` by a prior interrupted pass (app killed /
  /// process death between `markInFlight` and the catch handler). `nextReady`
  /// only selects `pending`, so without this an orphaned row is invisible
  /// forever. Safe at drain start: `drainOnce` is single-flight per company
  /// and rows are processed sequentially, so no `in_flight` row for this
  /// company is a live request.
  ///
  /// Re-arming is not harmless for everything — the server ignores
  /// `Idempotency-Key`, so re-sending an attempt that landed does it twice.
  /// A `create` is the one kind that leaves durable proof: the `id_remap`
  /// entry is written in the same transaction that applies the server's
  /// response (`recordCreateSuccess`), and the outbox row is deleted in a
  /// separate statement after it. A create whose tmp id already maps died in
  /// that gap — it is delivered, and re-sending it re-created the record.
  /// Any other row whose replay would repeat its effect
  /// (`DeliverySafety.nonIdempotent`) may or may not have landed, so it waits
  /// for the user as `unconfirmed`. The rest are re-armed as before.
  ///
  /// Only the rows read here are settled — the set is fixed at pass start,
  /// where the blanket reset this replaced used to run.
  Future<void> _recoverOrphanedInFlight(String companyId) async {
    final orphans = await db.outboxDao.inFlightRowsForCompany(companyId);
    if (orphans.isEmpty) return;
    final rearm = <int>[];
    for (final row in orphans) {
      if (row.mutationKind == MutationKind.create.wireName &&
          row.entityId.startsWith('tmp_') &&
          await db.idRemapDao.resolveAnyType(row.entityId) != null) {
        _log.warning(
          'Outbox row ${row.id} (${row.entityType} create ${row.entityId}) '
          'was left in flight after its response was applied; retiring it '
          'instead of re-sending a duplicate',
        );
        await db.outboxDao.deleteRow(row.id);
        continue;
      }
      final kind = MutationKind.tryParse(row.mutationKind);
      if (kind != null && !_autoResendable(row, kind)) {
        await _markUnconfirmed(
          row,
          'The app stopped while this was being sent',
          null,
        );
        continue;
      }
      rearm.add(row.id);
    }
    await db.outboxDao.resetInFlightRows(rearm);
  }

  Future<int> _drainOnceImpl(String companyId) async {
    await _recoverOrphanedInFlight(companyId);
    final nowMs = _now().millisecondsSinceEpoch;
    final rows = await db.outboxDao.nextReady(companyId: companyId, now: nowMs);
    var successes = 0;
    // Per-entity ordering. See `OutboxDao.hasEarlierActiveRowForEntity` for
    // the lost-update this prevents and why parked rows are excluded.
    //
    // A per-pass Set is NOT enough on its own: `nextReady` only returns rows
    // that are DUE, so the row we most need to wait for — one that just failed
    // and re-parked — is absent from the snapshot entirely. The set still earns
    // its keep for a row that fails *within* this pass and is re-parked into
    // the future by it, which the SQL query above (run before that happened)
    // could not see either. A row this pass KILLS is deliberately not added —
    // see the dead-row note at the bottom of the loop.
    final blockedEntities = <(String, String)>{};
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
      // An earlier row for this same record didn't land in this pass — see
      // [blockedEntities]. Dispatching this one now would apply mutations out
      // of order.
      //
      // Except for the create of a record that has never reached the server:
      // every other change to it references its temp id, so it waits for a
      // create to land and can never go first. Held behind one — an archive
      // queued after the first create failed, then the fixed record saved
      // again — the create never went, and neither did the archive. Only an
      // earlier create of the record holds it back.
      final entityKey = (row.entityType, row.entityId);
      final createsNewRecord =
          MutationKind.tryParse(row.mutationKind) == MutationKind.create &&
          row.entityId.startsWith('tmp_');
      if (!createsNewRecord && blockedEntities.contains(entityKey)) continue;
      if (await db.outboxDao.hasEarlierActiveRowForEntity(
        companyId: companyId,
        entityType: row.entityType,
        entityId: row.entityId,
        beforeId: row.id,
        now: _now().millisecondsSinceEpoch,
        onlyCreates: createsNewRecord,
      )) {
        // An older mutation for this record is still going to be sent. Held
        // behind an `unconfirmed` one, this row waits on the user for as long
        // as they take — so it vacates the `nextReady` window, as the tmp_
        // deferral below does, rather than coming back in every snapshot and,
        // with enough like it, starving everything queued after. Budget-
        // neutral, and `awaitRow` still reports the hold: its
        // `unconfirmedRowAhead` check runs before it looks at the schedule.
        final ahead = await db.outboxDao.unconfirmedRowAhead(
          companyId: companyId,
          entityType: row.entityType,
          entityId: row.entityId,
          beforeId: row.id,
        );
        if (ahead != null) {
          await db.outboxDao.scheduleRetry(
            id: row.id,
            attempts: row.attempts,
            nextAttemptAt:
                _now().millisecondsSinceEpoch +
                const Duration(minutes: 1).inMilliseconds,
            error: kHeldBehindUnconfirmedError,
          );
        }
        continue;
      }
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
          // Deliberately NOT blocked: a dead row will never be sent, so it
          // imposes no ordering constraint on later rows for the same record.
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
          error: kWaitingForReferencedRecordError,
        );
        blockedEntities.add(entityKey);
        continue;
      }
      // The active company changed under this pass (a switch, or the 401
      // rollback re-activating the previous company). Dispatching now would
      // send this row under another workspace's token. Leave it `pending` and
      // stop the pass — `drainOnce` is per company, so the right pass will
      // pick these up.
      final live = activeCompanyId?.call();
      if (live != null && live != companyId) {
        // Expected on any company switch with queued rows — not a fault.
        _log.fine(
          'Halting the drain for $companyId: $live is now the active company',
        );
        break;
      }
      final dispatched = await _attempt(current);
      if (dispatched) {
        successes++;
      } else {
        // Latch only on a row that will still be SENT. `_attempt` also returns
        // false when it just killed the row (`_markDead` — a permanent 4xx, a
        // cancelled password sheet, an exhausted budget), and a row that can
        // never go out imposes no ordering on anything queued behind it.
        // Blocking there deferred every later edit of that record by a whole
        // pass, for as long as the dead row sat in the outbox — and it made
        // this set STRICTER than the SQL barrier above, which already ignores
        // `dead`. Two gates that disagree about the same question is the shape
        // to avoid.
        //
        // The synthetic ids (`_sort`, `_bulk`) deliberately still latch. They
        // name no single record, so the barrier cannot tell an ordered pair
        // (two reorders of one list — genuinely last-write-wins) from an
        // independent one (`convertMatched` and `unlinkTransaction` over
        // disjoint transaction ids). Over-blocking costs one pass;
        // under-blocking costs a lost update on bank data.
        //
        // Nor on a document upload, which the SQL barrier likewise lets hold
        // nothing back ([isDocumentUploadRow]): it writes no field of the
        // record, so nothing queued behind it can be applied out of order.
        final after = await db.outboxDao.byId(current.id);
        if (after != null &&
            after.state != 'dead' &&
            !isDocumentUploadRow(
              mutationKind: after.mutationKind,
              payload: after.payload,
            )) {
          blockedEntities.add(entityKey);
        }
      }
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

  /// Whether [row] is parked only behind `tmp_` records that will land
  /// without the user ([_parentLands]), so it sends once they do. False for a
  /// row with no such reference, and for one whose parent — or a record that
  /// parent refers to — waits on the user.
  Future<bool> _waitsOnLandingParent(OutboxRow row) async {
    final tokens = _unresolvedTempRefTokens(row);
    if (tokens.isEmpty) return false;
    final visited = <String>{};
    for (final token in tokens) {
      if (!await _parentLands(row.companyId, token, visited, 0)) return false;
    }
    return true;
  }

  /// Whether `tmp_` record [token] lands without the user: it has landed
  /// already, its create is in flight, or its create is queued with nothing
  /// ahead of it that waits on the user and the records it refers to land
  /// too. Bounded by [depth] and [visited]; what it can't tell reads as
  /// landing, the answer from before it looked past the first level.
  Future<bool> _parentLands(
    String companyId,
    String token,
    Set<String> visited,
    int depth,
  ) async {
    final create = await db.outboxDao.liveCreateRowFor(
      companyId: companyId,
      entityId: token,
    );
    if (create == null) {
      // No create on its way: landed, or waiting on the user. A parent that
      // landed after the child was read has its `id_remap` entry — written in
      // the transaction that re-arms the child, before its own outbox row is
      // deleted — so its row can already be gone.
      return await db.idRemapDao.resolveAnyType(token) != null;
    }
    if (create.state == 'in_flight') return true;
    if (depth >= 4 || !visited.add(token)) return true;
    final ahead = await db.outboxDao.unconfirmedRowAhead(
      companyId: companyId,
      entityType: create.entityType,
      entityId: create.entityId,
      beforeId: create.id,
    );
    if (ahead != null) return false;
    for (final next in _unresolvedTempRefTokens(create)) {
      if (!await _parentLands(companyId, next, visited, depth + 1)) {
        return false;
      }
    }
    return true;
  }

  /// [isOnline], degrading every failure to "online" — only a positive
  /// "no connectivity" reading may classify a failure as unsent.
  Future<bool> _probablyOnline() async {
    final probe = isOnline;
    if (probe == null) return true;
    try {
      return await probe();
    } catch (_) {
      return true;
    }
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
    // A create for a record that already exists would make it twice (the
    // server ignores Idempotency-Key). Its id stops being a `tmp_` one only
    // when an earlier attempt landed and re-keyed it, and a tmp id maps only
    // once one did: a second create queued while the first was in flight, a
    // Retry of a failed create re-keyed that way, a password revival.
    if (kind == MutationKind.create &&
        (!row.entityId.startsWith('tmp_') ||
            await db.idRemapDao.resolveAnyType(row.entityId) != null)) {
      _log.warning(
        'Not sending ${row.entityType} create ${row.id}: '
        '${row.entityId} already exists on the server',
      );
      await _markDead(row, kAlreadyCreatedError, null);
      return false;
    }

    if (!await db.outboxDao.markInFlight(row.id)) {
      _log.fine('Not sending ${row.entityType} ${row.id}: no longer pending');
      return false;
    }
    // Every request the dispatch makes is bound to this row's company, and
    // the scope records whether a write has committed — see `RequestScope`.
    final scope = RequestScope(
      row.companyId,
      sourceRowId: row.id,
      sourceEntityType: row.entityType,
      sourceEntityId: row.entityId,
    )..offlineBeforeSend = !await _probablyOnline();
    try {
      await scope.run(() => handlers.dispatcher.dispatch(row: row, kind: kind));
      await db.outboxDao.deleteRow(row.id);
      return true;
    } catch (e, st) {
      // Settled by what reached the server before the exception says what
      // failed: once a write has committed, nothing that goes wrong after it
      // may send the row again.
      if (scope.committed) return _settleCommitted(row, kind, e, st);
      return _settleFailed(row, handlers, kind, scope, e, st);
    }
  }

  /// The server accepted this row's write, and something after it failed —
  /// decoding the reply, the client-too-old header, a follow-up read,
  /// applying the response, a company switch before the follow-up. No
  /// handler makes a second write, so the change is done and a re-send would
  /// repeat it (the server ignores `Idempotency-Key`): the row is deleted, the
  /// record's dirty flag released and the record re-fetched, so the local
  /// copy converges on what the server now holds. These used to be retried —
  /// a 2xx carrying the client-too-old header re-sent the write every hour.
  ///
  /// Except a create whose reply never reached `applyCreateResponse`: the
  /// server holds the record under an id this device never learned. A re-send
  /// duplicates it, and deleting the row strands the local copy and
  /// everything queued against its temp id, so it waits for the user as
  /// `unconfirmed`.
  Future<bool> _settleCommitted(
    OutboxRow row,
    MutationKind kind,
    Object error,
    StackTrace stackTrace,
  ) async {
    _log.warning(
      'Row ${row.id} (${row.entityType} ${row.mutationKind}) reached the '
      'server; what failed after it does not undo that',
      error,
      stackTrace,
    );
    if (kind == MutationKind.create &&
        row.entityId.startsWith('tmp_') &&
        await db.idRemapDao.resolveAnyType(row.entityId) == null) {
      await _markUnconfirmed(
        row,
        'The server accepted this, but its reply was lost: '
        '${_messageOf(error)}',
        null,
      );
      return false;
    }
    await db.outboxDao.deleteRow(row.id);
    await _reconcileDiscardedDirty(row);
    final handlers = registry.byWireName(row.entityType);
    final refresh = refreshRecord;
    // `_sort` / `_bulk` name no single record to re-fetch.
    if (handlers != null && refresh != null && !row.entityId.startsWith('_')) {
      try {
        await refresh(row.companyId, handlers.type, row.entityId);
      } catch (e) {
        _log.fine('Re-fetching ${row.entityType} ${row.entityId} failed: $e');
      }
    }
    return true;
  }

  /// A row whose attempt failed with nothing committed: routed by the
  /// exception, as it always was — except that a failure after a write went
  /// out with no answer (a dropped connection, a 500 / 502 / 504, an
  /// unclassified throw) leaves the outcome unknown, and a row whose replay
  /// would repeat its effect then waits for the user as `unconfirmed` instead
  /// of being retried ([_unknownOutcome]).
  Future<bool> _settleFailed(
    OutboxRow row,
    EntityHandlers handlers,
    MutationKind kind,
    RequestScope scope,
    Object error,
    StackTrace stackTrace,
  ) async {
    try {
      Error.throwWithStackTrace(error, stackTrace);
    } on CompanySwitchedException catch (e) {
      // Nothing was sent under the wrong token (a switch after a committed
      // write is [_settleCommitted]'s). Put the row back exactly as
      // it was — budget untouched, due now — for its own company's drain;
      // the live-company check ends this pass at the next row.
      _log.fine('Row ${row.id} re-queued: $e');
      await db.outboxDao.scheduleRetry(
        id: row.id,
        attempts: row.attempts,
        nextAttemptAt: _now().millisecondsSinceEpoch,
        error: row.lastError ?? '',
        statusCode: row.lastStatusCode,
      );
      return false;
    } on ValidationException catch (e) {
      _log.info('422 on ${row.entityType}/${row.entityId}: ${e.message}');
      // Marks dead directly rather than via `_markDead` because the failure
      // surface here is `ValidationFailedEvent` (field-keyed, routed to the
      // edit form), not `DeadEvent` — and the row carries `field_errors_json`.
      // The two reconciliation steps `_markDead` performs still have to run, or
      // a 422 death silently skips them; see each for what it protects.
      await db.outboxDao.markDead(
        id: row.id,
        error: e.message,
        statusCode: 422,
        fieldErrorsJson: e.fieldErrors.isEmpty
            ? null
            : jsonEncode(e.fieldErrors),
      );
      await _clearReorderDirty(row);
      await _releaseDeadLifecycleDirty(row);
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
          await _failTmpDependents(
            row.companyId,
            row.entityId,
            _ParentGone.failed,
          );
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
    } on RequestNotSentException catch (e) {
      // Provably never reached the server — see the next arm for why a lost
      // connection is re-parked rather than counted against the budget.
      await db.outboxDao.scheduleRetry(
        id: row.id,
        attempts: row.attempts,
        nextAttemptAt:
            _now().millisecondsSinceEpoch + kOfflineRetryDelay.inMilliseconds,
        error: e.message,
        statusCode: null,
      );
      return false;
    } on NetworkException catch (e) {
      if (_unknownOutcome(row, kind, scope)) {
        await _markUnconfirmed(row, e.message, null);
        return false;
      }
      // Offline (or an unreachable host) is "wait for an external condition",
      // not a reason to dead-letter the user's work — the same reasoning the
      // 429 / 401 / client-too-old arms above already apply by re-parking with
      // `attempts: row.attempts`. This one used to burn the budget instead, so
      // a user working offline in the foreground lost every queued mutation to
      // `dead` in about 25 minutes (one attempt per 5-minute refresh tick, plus
      // every resume and connectivity flap — nothing gates the drain on
      // connectivity). A later sign-out then wiped those payloads with NO
      // prompt at all, because `pendingCountForCompany` and
      // `companiesWithActiveRows` both exclude `dead`.
      //
      // The delay is an explicit constant, NOT `_retryWithBackoff`: with
      // `attempts` frozen that helper would index `kBackoffSchedule[0]` = 5s
      // forever, turning an offline session into a 5-second retry loop.
      //
      // Trade: a permanently misconfigured host now retries indefinitely rather
      // than dying, and a network failure no longer raises a `DeadEvent` toast.
      // The Outbox screen shows these rows as pending with their `lastError`.
      await db.outboxDao.scheduleRetry(
        id: row.id,
        attempts: row.attempts,
        nextAttemptAt:
            _now().millisecondsSinceEpoch + kOfflineRetryDelay.inMilliseconds,
        error: e.message,
        statusCode: null,
      );
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
      } else if (kOutcomeUnknownStatuses.contains(e.statusCode) &&
          _unknownOutcome(row, kind, scope)) {
        await _markUnconfirmed(row, e.message, e.statusCode);
      } else {
        await _retryWithBackoff(row, e.message, e.statusCode);
      }
      return false;
    } on ClientTooOldException catch (e) {
      // The header is read before the status, so the status is judged here:
      // a 500 that also carries it is still a write whose outcome is unknown
      // (the ServerException arm's rule), which a blind hourly retry would
      // repeat for as long as the app stayed out of date.
      final code = e.statusCode;
      if (code != null &&
          kOutcomeUnknownStatuses.contains(code) &&
          _unknownOutcome(row, kind, scope)) {
        await _markUnconfirmed(
          row,
          'Client too old: needs ${e.minRequiredVersion}',
          code,
        );
        return false;
      }
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
      if (_unknownOutcome(row, kind, scope)) {
        await _markUnconfirmed(row, e.toString(), null);
        return false;
      }
      await _retryWithBackoff(row, e.toString(), null);
      return false;
    }
  }

  /// Whether this failed attempt may have changed the server AND re-sending
  /// [row] could change it again: a write went out with no answer
  /// ([RequestScope.writeSent] without [RequestScope.committed] — a failure
  /// before any write, such as a follow-up read or a throw before the
  /// request, proves nothing was changed), and the row's replay is not
  /// harmless ([deliverySafetyFor]). Such a row waits for the user as
  /// `unconfirmed`; everything else keeps its old retry.
  bool _unknownOutcome(OutboxRow row, MutationKind kind, RequestScope scope) =>
      scope.writeSent && !scope.committed && !_autoResendable(row, kind);

  bool _autoResendable(OutboxRow row, MutationKind kind) {
    Object? payload;
    try {
      payload = jsonDecode(row.payload);
    } catch (_) {
      // Undecodable — judged on the kind alone.
    }
    return deliverySafetyFor(kind, payload).autoResendable;
  }

  static String _messageOf(Object error) =>
      error is ApiException ? error.message : error.toString();

  /// Park [row] as `unconfirmed` ([OutboxState]) and tell the shell. No
  /// dirty-flag reconciliation, unlike [_markDead]: the change may have
  /// landed, or may still be sent again, so the local copy stays the user's.
  Future<void> _markUnconfirmed(OutboxRow row, String error, int? code) async {
    _log.warning(
      'Row ${row.id} (${row.entityType} ${row.mutationKind} ${row.entityId}) '
      'may have reached the server; holding it for the user: $error',
    );
    await db.outboxDao.markUnconfirmed(
      id: row.id,
      error: error,
      statusCode: code,
    );
    final handlers = registry.byWireName(row.entityType);
    if (handlers != null) {
      _events.add(
        UnconfirmedEvent(
          entityType: handlers.type,
          entityId: row.entityId,
          message: error,
          handledByCaller: _callerDisplayedRows.contains(row.id),
        ),
      );
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
    if (stillActive) return;
    // "The user abandoned it" holds when the discarded row IS this entity's
    // edit. It does not when the row is some *other* mutation keyed to the same
    // entity — and `add_comment` is exactly that: `ClientRepository.addComment`
    // enqueues under `entity_type: 'client'`, `entity_id: <client id>`. So
    // discarding a queued comment used to clear a **dead** edit's `is_dirty`
    // (invisible to `hasActiveRowsForEntity`, which matches only `pending` /
    // `in_flight`), `upsertAllPreservingDirty` would stop skipping the id, and
    // the next refresh would overwrite the edit the `SaveFailedBanner` is still
    // asking the user to retry. Same guard, same reason, as
    // [_releaseDeadLifecycleDirty] — see its doc.
    //
    // Unconditional because the caller **deletes the row before calling this**,
    // so the probe can never match the row being discarded: discarding an
    // entity's only (dead) edit still clears, as it always did.
    final hasPendingEdit = await db.outboxDao.hasEditRowForEntity(
      companyId: row.companyId,
      entityType: row.entityType,
      entityId: row.entityId,
    );
    if (hasPendingEdit) return;
    await registry
        .byWireName(row.entityType)
        ?.dispatcher
        .clearLocalDirty(companyId: row.companyId, id: row.entityId);
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
    //
    // `whereType`, not `cast`: `cast` is a lazy view that throws on the first
    // non-String element, and this runs inside `_markDead`, *after* the row is
    // already dead — a throw there would skip the DeadEvent (so no failure
    // toast) and leave the dirty flags set, which is the exact silent
    // "every refresh is dropped for these rows" state this method exists to
    // prevent. Skipping a junk element degrades instead.
    final ids = <String>{};
    final taskIds = payload['task_ids'];
    if (taskIds is Map) {
      for (final list in taskIds.values) {
        if (list is List) ids.addAll(list.whereType<String>());
      }
    }
    if (payload['status_ids'] is List) {
      ids.addAll((payload['status_ids'] as List).whereType<String>());
    }
    if (payload['all_ids'] is List) {
      ids.addAll((payload['all_ids'] as List).whereType<String>());
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

  /// Release the optimistic `is_dirty` flag left by a mutation that has died
  /// permanently and is NOT the entity's own `create` / `update`.
  ///
  /// The name is historical: it started as the three lifecycle verbs (delete /
  /// archive / restore) and now covers every kind but those two — see the
  /// enumeration note in the body for the `bulk_update` case that forced the
  /// widening.
  ///
  /// Those three flip the local row before the server has agreed —
  /// `delete()` writes `is_deleted=true, is_dirty=true`, `archive()` writes
  /// `archived_at`. If the row then dies (the user cancels the password sheet
  /// on a delete, or an OAuth-only account has no password to give, or any
  /// permanent 4xx), nothing used to undo that: `upsertAllPreservingDirty`
  /// skips dirty ids on every page fetch, `refreshAll` and bundle apply, so the
  /// record stayed invisible locally and refresh-frozen **forever** while the
  /// server still had it, live. Clearing the flag lets the next refresh restore
  /// server truth — the same contract [_reconcileDiscardedDirty] gives a
  /// discarded row.
  ///
  /// Deliberately NOT applied to `update`/`create`: a dead edit's local row is
  /// where the user's unsaved work lives, and the edit screen re-opens onto it
  /// with a `SaveFailedBanner` + Retry. Clearing dirty there would let the next
  /// refresh clobber the very edit the user is being asked to retry. Discard is
  /// different — there the user has explicitly abandoned *the row being
  /// discarded*, which is why [_reconcileDiscardedDirty] clears every kind.
  /// (It carries the same `hasEditRowForEntity` guard as this method, because
  /// "abandoned" says nothing about a *different* mutation on the same entity —
  /// discarding a queued comment must not release a dead edit's flag.)
  ///
  /// Guarded per-id like its sibling: an id that still has another pending row
  /// keeps its flag so that separate edit stays protected.
  Future<void> _releaseDeadLifecycleDirty(OutboxRow row) async {
    final kind = MutationKind.tryParse(row.mutationKind);
    // Every kind EXCEPT create/update releases. It used to enumerate the three
    // lifecycle verbs, which left `bulk_update` falling through both this and
    // `_clearReorderDirty`: a bulk column edit writes `is_dirty = true` on every
    // selected row, so one permanently-rejected row stayed frozen against
    // `upsertAllPreservingDirty` forever — rendering the value the server
    // refused as authoritative, with no way back short of finding the dead row
    // in the Outbox and discarding it. An inverted test is the safer shape:
    // a new optimistic non-edit writer is covered on the day it ships.
    //
    // create/update stay excluded for the reason in the doc above: their local
    // row is where the user's unsaved work lives, and the edit screen reopens
    // onto it with a `SaveFailedBanner` + Retry.
    if (kind == null ||
        kind == MutationKind.create ||
        kind == MutationKind.update) {
      return;
    }
    // `reorder` is already owned by [_clearReorderDirty], which BOTH callers
    // run immediately before this one, and which knows how to walk the
    // reordered ids. A reorder row's `entityId` is the synthetic `_sort`
    // sentinel, so falling through here only spends a dispatcher round-trip
    // clearing a record that does not exist. [_reconcileDiscardedDirty] hands
    // reorder off the same way.
    if (kind == MutationKind.reorder) return;
    final stillActive = await db.outboxDao.hasActiveRowsForEntity(
      companyId: row.companyId,
      entityType: row.entityType,
      entityId: row.entityId,
    );
    if (stillActive) return;
    // `hasActiveRowsForEntity` matches only `pending` / `in_flight`, so a
    // **dead** edit is invisible to it — and a dead edit is exactly what the
    // doc above says must keep its flag. Reachable: an edit 422s (row dead,
    // local row dirty, `SaveFailedBanner` + Retry on the form), the user then
    // archives the same record, and that archive dies too. Without this check
    // the archive's death would clear the flag, `upsertAllPreservingDirty`
    // would stop skipping the id, and the next refresh would overwrite the
    // edit the user is being asked to retry.
    final hasPendingEdit = await db.outboxDao.hasEditRowForEntity(
      companyId: row.companyId,
      entityType: row.entityType,
      entityId: row.entityId,
    );
    if (hasPendingEdit) return;
    await registry
        .byWireName(row.entityType)
        ?.dispatcher
        .clearLocalDirty(companyId: row.companyId, id: row.entityId);
  }

  /// Whether [companyId] is the company in view — every company is, until
  /// the app wires [activeCompanyId].
  bool _isActive(String companyId) =>
      (activeCompanyId?.call() ?? companyId) == companyId;

  Future<void> _markDead(
    OutboxRow row,
    String error,
    int? code, {
    bool announce = true,
  }) async {
    await db.outboxDao.markDead(id: row.id, error: error, statusCode: code);
    // A permanently-failed reorder must release its optimistic dirty flags so
    // future refreshes can restore the server's ordering (see below).
    await _clearReorderDirty(row);
    await _releaseDeadLifecycleDirty(row);
    final handlers = registry.byWireName(row.entityType);
    if (announce && handlers != null) {
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

/// Why a `tmp_` parent's dependents can no longer go out as queued
/// (`SyncRepository._failTmpDependents`), and what the dead ones say.
enum _ParentGone {
  failed('References a record that could not be saved'),
  discarded('References a discarded unsynced record'),
  discardedUnconfirmed(
    'References a record that may already exist on the server — choose it '
    'again, then retry',
  );

  const _ParentGone(this.message);

  final String message;
}
