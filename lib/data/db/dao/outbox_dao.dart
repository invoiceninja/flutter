import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/tables/outbox_table.dart';
import 'package:admin/domain/sync/mutation.dart';

part 'outbox_dao.g.dart';

/// `state` values: `pending | in_flight | unconfirmed | dead`.
///
/// `pending` and `in_flight` are **active**: the drain sends them on its own.
/// `unconfirmed` and `dead` **need the user**: `dead` was refused (or ran out
/// of retries); `unconfirmed` is a non-idempotent change whose attempt may
/// have reached the server — the connection dropped after sending, a 5xx, the
/// app died mid-request — so re-sending it could do it twice. It waits for
/// the user to check and then Send again or Discard, and meanwhile holds back
/// later changes to the same record ([hasEarlierActiveRowForEntity]).
enum OutboxState { pending, inFlight, unconfirmed, dead }

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  Future<int> enqueue(OutboxCompanion row) => into(outbox).insert(row);

  /// One-shot row fetch by id. Used by sync-bound UI (e.g. Danger Zone delete)
  /// to inspect a row's terminal state immediately after [drainOnce] returns.
  Future<OutboxRow?> byId(int id) =>
      (select(outbox)..where((o) => o.id.equals(id))).getSingleOrNull();

  /// One-shot count of active (`pending` / `in_flight`) rows for
  /// [companyId] — what "Sync first" can send. The picker uses this to decide
  /// whether a company switch needs a "you have unsaved changes"
  /// confirmation; the streaming variant below feeds badges that refresh
  /// continuously.
  ///
  /// Counts `in_flight` alongside `pending`: a row mid-attempt at the moment
  /// a logout/switch guard reads this is still the user's unsynced work — if
  /// the attempt fails it re-parks as pending, and a guard that saw 0 would
  /// already have wiped it. (Badges use [watchPendingCount], unaffected.)
  /// `unconfirmed` is left out with `dead`: no drain sends it, so counting it
  /// here would leave "Sync first" waiting forever. [attentionCountAll]
  /// counts both.
  Future<int> pendingCountForCompany(String companyId) async {
    final count = outbox.id.count();
    final q = selectOnly(outbox)
      ..addColumns([count])
      ..where(
        outbox.companyId.equals(companyId) &
            outbox.state.isIn(const ['pending', 'in_flight']),
      );
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  /// How many of [companyId]'s `pending` rows the drain parked with one of
  /// [errors] as their `last_error` — rows that wait on another change rather
  /// than on the network, so a drain can't send them.
  Future<int> countPendingParkedWith({
    required String companyId,
    required List<String> errors,
  }) async {
    final count = outbox.id.count();
    final q = selectOnly(outbox)
      ..addColumns([count])
      ..where(
        outbox.companyId.equals(companyId) &
            outbox.state.equals('pending') &
            outbox.lastError.isIn(errors),
      );
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  /// Distinct company ids, in order, holding a row that waits on the user —
  /// `dead` or `unconfirmed`: what the sign-out review counts everywhere.
  Future<List<String>> companiesWithAttentionRows() async {
    final q = selectOnly(outbox, distinct: true)
      ..addColumns([outbox.companyId])
      ..where(outbox.state.isIn(const ['dead', 'unconfirmed']))
      ..orderBy([OrderingTerm(expression: outbox.companyId)]);
    final rows = await q.get();
    return [for (final r in rows) r.read(outbox.companyId)!];
  }

  /// Distinct company ids holding any active (`pending` / `in_flight`)
  /// outbox row. The full-logout / idle-timeout guards read this instead of
  /// `session.companies`: the wipe destroys EVERY company's rows, and the
  /// outbox is the ground truth for unsynced work — a company that vanished
  /// from the session envelope (e.g. one tolerantly-skipped malformed row on
  /// refresh) still counts here.
  Future<List<String>> companiesWithActiveRows() async {
    final q = selectOnly(outbox, distinct: true)
      ..addColumns([outbox.companyId])
      ..where(outbox.state.isIn(const ['pending', 'in_flight']));
    final rows = await q.get();
    return [
      for (final row in rows)
        if (row.read(outbox.companyId) case final String id) id,
    ];
  }

  /// Distinct company ids holding outbox rows in ANY state — `dead` included.
  ///
  /// The question a destructive logout has to ask. [companiesWithActiveRows]
  /// leaves `dead` out because the sign-out prompt's "Sync first" can't send
  /// them, but a full logout wipes them all the same — together with the
  /// dirty local rows that hold the user's rejected edit, which the edit form
  /// reopens onto for a fix-and-retry. A failed change is still the user's
  /// unsynced work.
  Future<List<String>> companiesWithUnsyncedRows() async {
    final q = selectOnly(outbox, distinct: true)
      ..addColumns([outbox.companyId]);
    final rows = await q.get();
    return [
      for (final row in rows)
        if (row.read(outbox.companyId) case final String id) id,
    ];
  }

  /// One-shot count of rows that need the user — `dead` and `unconfirmed` —
  /// across every company: what a full logout would delete that the sign-out
  /// prompt's pending count doesn't show.
  Future<int> attentionCountAll() async {
    final count = outbox.id.count();
    final q = selectOnly(outbox)
      ..addColumns([count])
      ..where(outbox.state.isIn(const ['dead', 'unconfirmed']));
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  /// True when the outbox holds any row at all, in any state, for any
  /// company. The cheapest "is there unsynced work anywhere" probe, for
  /// callers that hold only the database (`AuthRepository.restore`).
  Future<bool> hasAnyRows() async {
    final q = selectOnly(outbox)
      ..addColumns([outbox.id])
      ..limit(1);
    return (await q.getSingleOrNull()) != null;
  }

  /// True when a `create` outbox row for [entityId] exists in ANY state —
  /// pending, in_flight, or dead. The tmp-ref defer branch uses this to
  /// distinguish "parent create still around (recoverable — keep deferring)"
  /// from "parent create discarded (the reference can never heal — dead-end
  /// the dependent)". Any-state is load-bearing: a dead-but-retryable create
  /// must keep its dependents alive.
  Future<bool> hasCreateRowFor({
    required String companyId,
    required String entityId,
  }) async {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityId.equals(entityId) &
            o.mutationKind.equals(MutationKind.create.wireName),
      )
      ..limit(1);
    return (await q.get()).isNotEmpty;
  }

  /// The `create` row of record [entityId] still on its way — the one on the
  /// wire, else the newest `pending` — or null when its create is `dead` or
  /// `unconfirmed` (waiting on the user), has landed, or never was.
  /// `SyncRepository.awaitRow` uses it to tell a save that sends once its
  /// parent lands from one that waits on the user first. The one on the wire
  /// wins: the record lands with it, whatever a newer attempt queued behind
  /// it refers to.
  Future<OutboxRow?> liveCreateRowFor({
    required String companyId,
    required String entityId,
  }) {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityId.equals(entityId) &
            o.mutationKind.equals(MutationKind.create.wireName) &
            o.state.isIn(const ['pending', 'in_flight']),
      )
      ..orderBy([
        (o) => OrderingTerm(
          expression: o.state.equals('in_flight'),
          mode: OrderingMode.desc,
        ),
        (o) => OrderingTerm(expression: o.id, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return q.getSingleOrNull();
  }

  /// Delete every `pending` row for [companyId] in one statement. The
  /// "Discard" flows now route through [pendingRowsForCompany] +
  /// `SyncRepository.discardOutboxRow` (so ghost creates also drop their
  /// local record); this stays as the equivalent bulk primitive.
  Future<int> deletePendingForCompany(String companyId) =>
      (delete(outbox)..where(
            (o) => o.companyId.equals(companyId) & o.state.equals('pending'),
          ))
          .go();

  Stream<int> watchPendingCount({required String companyId}) {
    final count = outbox.id.count();
    final q = selectOnly(outbox)
      ..addColumns([count])
      ..where(
        outbox.companyId.equals(companyId) & outbox.state.equals('pending'),
      );
    return q.map((row) => row.read(count) ?? 0).watchSingle();
  }

  Stream<int> watchDeadCount({required String companyId}) {
    final count = outbox.id.count();
    final q = selectOnly(outbox)
      ..addColumns([count])
      ..where(outbox.companyId.equals(companyId) & outbox.state.equals('dead'));
    return q.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Live count of rows that need the user — `dead` and `unconfirmed` — for
  /// [companyId]. The sidebar's Outbox badge adds it to [watchPendingCount].
  Stream<int> watchAttentionCount({required String companyId}) {
    final count = outbox.id.count();
    final q = selectOnly(outbox)
      ..addColumns([count])
      ..where(
        outbox.companyId.equals(companyId) &
            outbox.state.isIn(const ['dead', 'unconfirmed']),
      );
    return q.map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<List<OutboxRow>> nextReady({
    required String companyId,
    required int now,
    int limit = 50,
  }) {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.state.equals('pending') &
            o.nextAttemptAt.isSmallerOrEqualValue(now),
      )
      ..orderBy([(o) => OrderingTerm(expression: o.id)])
      ..limit(limit);
    return q.get();
  }

  /// [isDocumentUploadRow], in SQL — keep the two in step.
  Expression<bool> _isDocumentUpload($OutboxTable o) =>
      o.mutationKind.equals(MutationKind.documentUpload.wireName) |
      (o.mutationKind.equals(MutationKind.update.wireName) &
          o.payload.contains(kUploadDocumentActionJson));

  /// Whether an EARLIER row for the same record is still going to be sent.
  ///
  /// The outbox has no per-entity ordering guarantee: `nextReady` is id-ordered
  /// but only returns rows that are due, so a row re-parked into the future
  /// drops out of the snapshot while a *later* row for the same record stays in
  /// it. That let mutation N+1 be applied before N, and N then overwrote it on
  /// its retry — the classic lost update:
  ///
  ///   save v1 -> row1 hangs, the form times out and pops "saving in
  ///   background" -> user saves v2 (dedup leaves the in_flight row1 alone) ->
  ///   row1 fails and re-parks -> row2 succeeds -> row1 retries and PUTs v1
  ///   over it, on the server and locally. No dead row, no toast, no event.
  ///
  /// "Still going to be sent" deliberately EXCLUDES a row parked beyond
  /// [parkedHorizon]: a 409 conflict and the entity-missing 400 both re-park a
  /// row `pending` at `now + 365 days` while it waits for the user to resolve
  /// it. Blocking on those would starve the record for a year — far worse than
  /// the reordering. Same horizon [staleRowsForCompany] uses to call a row
  /// parked.
  ///
  /// An `unconfirmed` row DOES block, parked or not: the user's Send again
  /// puts it back in line, and a later full-record PUT sent ahead of it would
  /// then be overwritten by the older one — the same lost update. The save
  /// held behind it says why ([unconfirmedRowAhead]).
  ///
  /// A document upload never blocks ([isDocumentUploadRow]): it writes no
  /// field of the record, so it can cause no lost update.
  ///
  /// [onlyCreates] counts earlier creates alone — for the create of a record
  /// that has never reached the server, whose every other earlier change
  /// waits for a create of it to land and so can never go first.
  Future<bool> hasEarlierActiveRowForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    required int beforeId,
    required int now,
    Duration parkedHorizon = const Duration(days: 1),
    bool onlyCreates = false,
  }) async {
    final horizon = now + parkedHorizon.inMilliseconds;
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.entityId.equals(entityId) &
            o.id.isSmallerThanValue(beforeId) &
            _isDocumentUpload(o).not() &
            (onlyCreates
                ? o.mutationKind.equals(MutationKind.create.wireName)
                : const Constant(true)) &
            (o.state.isIn(const ['in_flight', 'unconfirmed']) |
                (o.state.equals('pending') &
                    o.nextAttemptAt.isSmallerOrEqualValue(horizon))),
      )
      ..limit(1);
    return (await q.getSingleOrNull()) != null;
  }

  /// Make due now — error cleared — the `pending` rows of one record newer than
  /// [afterId] that the drain parked behind an `unconfirmed` row with
  /// [heldError], once that row is resent or discarded: they wait on nothing
  /// else. Matched by the error so a row in its own backoff keeps it.
  Future<int> rearmHeldBehind({
    required String companyId,
    required String entityType,
    required String entityId,
    required int afterId,
    required String heldError,
    required int now,
  }) =>
      (update(outbox)..where(
            (o) =>
                o.companyId.equals(companyId) &
                o.entityType.equals(entityType) &
                o.entityId.equals(entityId) &
                o.id.isBiggerThanValue(afterId) &
                o.state.equals('pending') &
                o.lastError.equals(heldError),
          ))
          .write(
            OutboxCompanion(
              nextAttemptAt: Value(now),
              lastError: const Value(null),
            ),
          );

  /// The newest `unconfirmed` row for the same record that is older than row
  /// [beforeId] — the one holding that row back
  /// ([hasEarlierActiveRowForEntity]). Null when nothing is.
  Future<OutboxRow?> unconfirmedRowAhead({
    required String companyId,
    required String entityType,
    required String entityId,
    required int beforeId,
  }) {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.entityId.equals(entityId) &
            o.id.isSmallerThanValue(beforeId) &
            o.state.equals('unconfirmed') &
            _isDocumentUpload(o).not(),
      )
      ..orderBy([
        (o) => OrderingTerm(expression: o.id, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return q.getSingleOrNull();
  }

  /// Find an existing `pending` row for [companyId] + [entityType] so the
  /// caller can collapse rapid edits of an idempotent mutation (e.g. user
  /// settings) into one outbox row instead of N.
  Future<OutboxRow?> findPending({
    required String companyId,
    required String entityType,
  }) {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.state.equals('pending'),
      )
      ..orderBy([(o) => OrderingTerm(expression: o.id)])
      ..limit(1);
    return q.getSingleOrNull();
  }

  /// Per-entity variant of [findPending]. Use when the caller needs to
  /// collapse rapid edits of *one* row instead of any pending row of the
  /// same type — e.g. the User Management edit screen saving user X
  /// shouldn't collapse a pending edit to user Y.
  Future<OutboxRow?> findPendingByEntityId({
    required String companyId,
    required String entityType,
    required String entityId,
    String mutationKind = 'update',
  }) {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.entityId.equals(entityId) &
            o.mutationKind.equals(mutationKind) &
            o.state.equals('pending'),
      )
      ..orderBy([(o) => OrderingTerm(expression: o.id)])
      ..limit(1);
    return q.getSingleOrNull();
  }

  /// Overwrite the payload of an existing outbox row (idempotency key stays
  /// the same — server treats a retry with a fresher payload as equivalent
  /// to the original).
  Future<void> updatePayload({required int id, required String payload}) =>
      (update(outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion(payload: Value(payload)),
      );

  /// Replace a `pending` row's payload and make it due now, its error and
  /// status cleared — for a row whose wait has just ended with the reference
  /// it was parked on stripped out. The same re-arm [rewriteTempIdInPayloads]
  /// gives a row whose reference resolved.
  Future<void> replacePayloadAndRearm({
    required int id,
    required String payload,
  }) =>
      (update(
        outbox,
      )..where((o) => o.id.equals(id) & o.state.equals('pending'))).write(
        OutboxCompanion(
          payload: Value(payload),
          nextAttemptAt: const Value(0),
          lastError: const Value(null),
          lastStatusCode: const Value(null),
        ),
      );

  /// Claim `pending` row [id] for dispatch. Whether it was still pending —
  /// a Discard, or a save that replaced it, can land between the drain's
  /// re-read and this write, and a row that is gone or no longer pending must
  /// not be sent.
  Future<bool> markInFlight(int id) async =>
      await (update(outbox)
            ..where((o) => o.id.equals(id) & o.state.equals('pending')))
          .write(const OutboxCompanion(state: Value('in_flight'))) ==
      1;

  /// Re-arm rows orphaned in `in_flight` — left there when a drain was
  /// interrupted (process death) between [markInFlight] and the catch handler
  /// that would have rescheduled or killed them. Sets them back to `pending`
  /// so [nextReady] sees them again. `SyncRepository` calls this at the top of
  /// each drain pass; safe because `drainOnce` is single-flight per company, so
  /// at drain-start no `in_flight` row for [companyId] is a live request.
  /// Returns the number of rows recovered.
  /// Rows left `in_flight` for [companyId] — at drain start these are
  /// orphans of an interrupted pass (`SyncRepository._recoverOrphanedInFlight`).
  Future<List<OutboxRow>> inFlightRowsForCompany(String companyId) =>
      (select(outbox)..where(
            (o) => o.companyId.equals(companyId) & o.state.equals('in_flight'),
          ))
          .get();

  /// Re-arm exactly [ids] (those still `in_flight`) back to `pending`. The
  /// drain settles the orphans it READ at pass start rather than every
  /// `in_flight` row at the moment of the write — see
  /// `SyncRepository._recoverOrphanedInFlight`.
  Future<int> resetInFlightRows(List<int> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (update(outbox)
          ..where((o) => o.id.isIn(ids) & o.state.equals('in_flight')))
        .write(const OutboxCompanion(state: Value('pending')));
  }

  Future<int> resetInFlightForCompany(String companyId) =>
      (update(outbox)..where(
            (o) => o.companyId.equals(companyId) & o.state.equals('in_flight'),
          ))
          .write(const OutboxCompanion(state: Value('pending')));

  Future<void> deleteRow(int id) =>
      (delete(outbox)..where((o) => o.id.equals(id))).go();

  /// Delete every outbox row (any state) for one entity. Used when a
  /// never-synced offline `create` is discarded: queued follow-up
  /// update/delete/action rows against the same `tmp_` id are meaningless
  /// once the entity is gone, so they go with it.
  Future<int> deleteAllForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
  }) =>
      (delete(outbox)..where(
            (o) =>
                o.companyId.equals(companyId) &
                o.entityType.equals(entityType) &
                o.entityId.equals(entityId),
          ))
          .go();

  /// Drop only `pending` rows for the given tuple. Used by repo `create` /
  /// `save` to suppress duplicates when the user retries from a synchronous-
  /// when-online inline error: a previously-enqueued pending row would still
  /// be queued (and for CREATE would cause a server-side duplicate when both
  /// rows eventually drain). `in_flight` rows are left alone — their HTTP
  /// request may already be landing, so deleting them would race the
  /// dispatcher's `applyCreateResponse`. `dead` rows are left alone too —
  /// the existing `onSaved` cleanup deletes them after a successful re-save.
  Future<int> deletePendingForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    required String mutationKind,
  }) =>
      (delete(outbox)..where(
            (o) =>
                o.companyId.equals(companyId) &
                o.entityType.equals(entityType) &
                o.entityId.equals(entityId) &
                o.mutationKind.equals(mutationKind) &
                o.state.equals('pending'),
          ))
          .go();

  /// The `pending` rows [deletePendingForEntity] would remove, in id order.
  ///
  /// Exists so a caller can salvage anything the superseding row would
  /// otherwise destroy — specifically a SAVE-PARAM action folded into an
  /// earlier save's payload (`__save_query`), which the dedup predicate can't
  /// see because it keys only on `(company, type, id, kind)`.
  Future<List<OutboxRow>> pendingRowsForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    required String mutationKind,
  }) =>
      (select(outbox)
            ..where(
              (o) =>
                  o.companyId.equals(companyId) &
                  o.entityType.equals(entityType) &
                  o.entityId.equals(entityId) &
                  o.mutationKind.equals(mutationKind) &
                  o.state.equals('pending'),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.id)]))
          .get();

  /// True when a `create` or `update` row for [entityId] exists in **any**
  /// state — including `dead`.
  ///
  /// A dead edit is still the user's unsaved work: the edit screen re-opens
  /// onto the local row with a `SaveFailedBanner` + Retry, so its `is_dirty`
  /// flag must keep protecting it from the next refresh. [hasActiveRowsForEntity]
  /// can't answer this — it matches only `pending` / `in_flight`.
  ///
  /// [afterRowId] narrows it to rows NEWER than that one — what a server copy
  /// applied while dispatching row [afterRowId] must not overwrite
  /// (`BaseEntityRepository.hasNewerLocalEdit`).
  ///
  /// A document upload is no edit ([isDocumentUploadRow]): the company's is an
  /// `update` row, and counting it kept every refresh of the company — Check's
  /// included — from landing while an upload waited.
  Future<bool> hasEditRowForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    int? afterRowId,
  }) async {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.entityId.equals(entityId) &
            o.mutationKind.isIn([
              MutationKind.create.wireName,
              MutationKind.update.wireName,
            ]) &
            _isDocumentUpload(o).not() &
            (afterRowId == null
                ? const Constant(true)
                : o.id.isBiggerThanValue(afterRowId)),
      )
      ..limit(1);
    return (await q.getSingleOrNull()) != null;
  }

  /// Snapshot of `pending` rows for [companyId] (excludes `dead` and
  /// `in_flight`) — same predicate as [deletePendingForCompany], but
  /// returns the rows so a caller can apply per-row discard logic. Used by
  /// `SyncRepository.discardPendingFor`.
  /// True when any non-terminal (`pending`, `in_flight` or `unconfirmed`)
  /// row exists for [companyId] + [entityType]. `in_flight` matters: a
  /// refresh that lands while the row's HTTP attempt is mid-send must still
  /// treat the local edit as in charge — the attempt may fail and re-park as
  /// pending. `unconfirmed` for the same reason: the user may send it again.
  /// A document upload is no local edit of the table's columns
  /// ([isDocumentUploadRow]) — counting one withheld the company's columns
  /// from `/refresh` for as long as an upload waited.
  Future<bool> hasActiveRowsFor({
    required String companyId,
    required String entityType,
  }) async {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.state.isIn(const ['pending', 'in_flight', 'unconfirmed']) &
            _isDocumentUpload(o).not(),
      )
      ..limit(1);
    return (await q.getSingleOrNull()) != null;
  }

  /// Like [hasActiveRowsFor] but scoped to a single [entityId]. The discard
  /// reconciliation uses it to decide whether clearing a local record's
  /// `is_dirty` is safe — only when NO other pending/in_flight outbox row
  /// for that exact record remains (else clearing would un-protect a still-
  /// queued edit from the next server refresh). An `unconfirmed` row counts:
  /// the user may still send it again. A document upload does not
  /// ([isDocumentUploadRow]): it writes nothing locally and sets no flag, so it
  /// has none to protect — and an unconfirmed one waits on the user, which
  /// kept a discarded edit's flag, and its stale value, indefinitely.
  Future<bool> hasActiveRowsForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
  }) async {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.entityId.equals(entityId) &
            o.state.isIn(const ['pending', 'in_flight', 'unconfirmed']) &
            _isDocumentUpload(o).not(),
      )
      ..limit(1);
    return (await q.getSingleOrNull()) != null;
  }

  /// Pending rows whose payload embeds [needle] — the ghost-discard path
  /// uses this to find dependents that reference a discarded tmp_ entity.
  Future<List<OutboxRow>> pendingRowsReferencing({
    required String companyId,
    required String needle,
  }) =>
      (select(outbox)..where(
            (o) =>
                o.companyId.equals(companyId) &
                o.state.equals('pending') &
                o.payload.contains(needle),
          ))
          .get();

  Future<List<OutboxRow>> pendingRowsForCompany(String companyId) =>
      (select(outbox)..where(
            (o) => o.companyId.equals(companyId) & o.state.equals('pending'),
          ))
          .get();

  Future<void> scheduleRetry({
    required int id,
    required int attempts,
    required int nextAttemptAt,
    required String error,
    int? statusCode,
  }) => (update(outbox)..where((o) => o.id.equals(id))).write(
    OutboxCompanion(
      state: const Value('pending'),
      nextAttemptAt: Value(nextAttemptAt),
      attempts: Value(attempts),
      lastError: Value(error),
      lastStatusCode: Value(statusCode),
    ),
  );

  /// Flip an outbox row's `requires_password` flag. The drain loop calls this
  /// when the server answers a no-password mutation with 412, so the
  /// post-prompt retry attaches `X-API-PASSWORD-BASE64` (the dispatcher
  /// forwards `row.requiresPassword`).
  Future<void> updateRequiresPassword({required int id, required bool value}) =>
      (update(outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion(requiresPassword: Value(value)),
      );

  /// Re-arm every password-required row for a company so the next [nextReady]
  /// returns it immediately. Called right after the user enters their password
  /// (cache now warm) — without it the rows sit on their park until an
  /// unrelated drain trigger fires.
  ///
  /// Covers two states:
  ///  * `pending` — just un-park it. `attempts` is deliberately PRESERVED so a
  ///    repeatedly-wrong password still walks the backoff and eventually dies
  ///    instead of looping forever.
  ///  * `dead` **with a 412** — a password-gated row that exhausted its
  ///    attempts while the user was away. Resurrect it with a fresh budget:
  ///    the user has just supplied a password, which is exactly the input that
  ///    was missing. Without this branch the terminal state is a trap — the
  ///    row can only be revived by hunting down the Outbox screen's Retry.
  ///    Scoped to 412 so an unrelated dead row (422, 5xx) stays dead.
  Future<void> readyPasswordRows({
    required String companyId,
    required int now,
  }) async {
    await (update(outbox)..where(
          (o) =>
              o.companyId.equals(companyId) &
              o.state.equals('pending') &
              o.requiresPassword.equals(true),
        ))
        .write(OutboxCompanion(nextAttemptAt: Value(now)));
    await (update(outbox)..where(
          (o) =>
              o.companyId.equals(companyId) &
              o.state.equals('dead') &
              o.requiresPassword.equals(true) &
              o.lastStatusCode.equals(412),
        ))
        .write(
          OutboxCompanion(
            state: const Value('pending'),
            attempts: const Value(0),
            nextAttemptAt: Value(now),
          ),
        );
  }

  /// Park row [id] as `unconfirmed`: its attempt may have reached the server
  /// and a re-send could do it twice, so no drain sends it until the user
  /// chooses ([resendUnconfirmed], or a discard). [OutboxState] has the rest.
  Future<void> markUnconfirmed({
    required int id,
    required String error,
    int? statusCode,
  }) => (update(outbox)..where((o) => o.id.equals(id))).write(
    OutboxCompanion(
      state: const Value('unconfirmed'),
      lastError: Value(error),
      lastStatusCode: Value(statusCode),
    ),
  );

  /// The user checked row [id] and chose to send it again: back in line with
  /// a fresh budget, keeping its payload and idempotency key. Only an
  /// `unconfirmed` row moves; returns whether one did.
  Future<bool> resendUnconfirmed({required int id, required int now}) async {
    final moved =
        await (update(
          outbox,
        )..where((o) => o.id.equals(id) & o.state.equals('unconfirmed'))).write(
          OutboxCompanion(
            state: const Value('pending'),
            attempts: const Value(0),
            nextAttemptAt: Value(now),
          ),
        );
    return moved > 0;
  }

  Future<void> markDead({
    required int id,
    required String error,
    int? statusCode,
    String? fieldErrorsJson,
  }) => (update(outbox)..where((o) => o.id.equals(id))).write(
    OutboxCompanion(
      state: const Value('dead'),
      lastError: Value(error),
      lastStatusCode: Value(statusCode),
      fieldErrorsJson: Value(fieldErrorsJson),
    ),
  );

  /// Stream of non-`dead` rows for one specific entity. Drives the
  /// optimistic "syncing…" entries in the client Activity tab; can be
  /// scoped to a single [kind] (e.g. only `addComment` rows) when the
  /// caller only cares about a particular flavor of mutation.
  ///
  /// Includes `pending` and `in_flight` rows so a row that's mid-send still
  /// shows up; excludes `dead` rows so a 422-failed comment doesn't linger
  /// in the tab (the user will see it on the Outbox screen instead).
  ///
  /// That trade was made when the only consumer was the 14th of 14 tabs. It is
  /// louder now: a rejected comment also leaves the Comments card high on the
  /// detail body, and if it was the only one the card collapses — so the user
  /// sees their note appear and then vanish, with the `DeadEvent` toast as the
  /// only signal. Accepted for now (the text survives on the Outbox screen);
  /// the fix is a `watchDeadForEntity` sibling feeding a Retry/Discard row.
  Stream<List<OutboxRow>> watchPendingForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
    MutationKind? kind,
  }) {
    final wireKind = kind?.wireName;
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.entityId.equals(entityId) &
            o.state.isNotValue('dead') &
            (wireKind == null
                ? const Constant(true)
                : o.mutationKind.equals(wireKind)),
      )
      ..orderBy([(o) => OrderingTerm(expression: o.id)]);
    return q.watch().distinctRows();
  }

  /// Stream of every outbox row for [companyId], newest first. Drives the
  /// Outbox screen. Includes `pending`, `in_flight`, and `dead` rows so the
  /// user sees the full mutation queue, not just the failures.
  Stream<List<OutboxRow>> watchAll(String companyId) {
    final q = select(outbox)
      ..where((o) => o.companyId.equals(companyId))
      ..orderBy([
        (o) => OrderingTerm(expression: o.createdAt, mode: OrderingMode.desc),
      ]);
    return q.watch().distinctRows();
  }

  /// Newest `unconfirmed` row for the given entity (if any), any mutation
  /// kind. The edit form calls this on open: a save of the record queues
  /// behind it ([hasEarlierActiveRowForEntity]), so the form says so up
  /// front instead of letting the next save wait on it silently.
  Future<OutboxRow?> findUnconfirmedForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
  }) {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.entityId.equals(entityId) &
            o.state.equals('unconfirmed') &
            // Holds nothing back, so the form has nothing to wait on.
            _isDocumentUpload(o).not(),
      )
      ..orderBy([
        (o) => OrderingTerm(expression: o.id, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return q.getSingleOrNull();
  }

  /// Newest `dead` save of the given entity — its own `create` / `update` —
  /// if any. The edit form calls this on open so it can replay 422 field
  /// errors against the form, and after a successful re-save to drop the
  /// failed attempt it replaced (`SyncRepository.supersedeDeadSave`).
  ///
  /// Saves only. Any failed row for the record used to match — a rejected
  /// email or payment on the same invoice included — so the form opened on
  /// that row's error as if the save had failed, and the next successful
  /// save deleted it: unrelated user work, gone without a word.
  Future<OutboxRow?> findDeadSaveForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
  }) {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.entityId.equals(entityId) &
            o.state.equals('dead') &
            o.mutationKind.isIn([
              MutationKind.create.wireName,
              MutationKind.update.wireName,
            ]),
      )
      ..orderBy([
        (o) => OrderingTerm(expression: o.id, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return q.getSingleOrNull();
  }

  /// Newest `create` row of the given record, in any state, if any.
  Future<OutboxRow?> findNewestCreateForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
  }) {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.entityId.equals(entityId) &
            o.mutationKind.equals(MutationKind.create.wireName),
      )
      ..orderBy([
        (o) => OrderingTerm(expression: o.id, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return q.getSingleOrNull();
  }

  /// Newest row for the given entity that a "Discard failed save" tap may
  /// legitimately abandon: the entity's own `create` / `update`, in state
  /// `dead`, `unconfirmed` **or** `pending`.
  ///
  /// [findDeadSaveForEntity] is not enough for that surface. `SaveFailedBanner`
  /// renders off `submitError`, and only a **422** kills the row — a 5xx or a
  /// lost connection leaves it `pending` with backoff, so the banner is up
  /// while no dead row exists. Falling back to the dead-only query there
  /// found nothing, `clearFailedSync()` ran alone, the banner vanished and the
  /// queued row went on to apply the write the user had just discarded.
  ///
  /// Two exclusions are load-bearing:
  ///
  ///  * **`in_flight` is excluded.** `SyncRepository.discardOutboxRow` deletes
  ///    an in-flight row while leaving its request on the wire — right for the
  ///    Outbox screen's explicit Discard, and exactly the lie this surface
  ///    exists to avoid. The banner outlives the attempt either way: the row
  ///    re-parks as `pending` on failure, or succeeds and clears the form.
  ///  * **Only `create` / `update` kinds.** A discard abandons the ROW, not the
  ///    ENTITY (CLAUDE.md § Sync). A queued `add_comment`, `email` or
  ///    `mark_sent` on the same record is unrelated user work and must survive
  ///    a discard of the save — the same distinction `hasEditRowForEntity`
  ///    draws for the dirty-flag reconcile.
  Future<OutboxRow?> findDiscardableForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
  }) {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            o.entityId.equals(entityId) &
            o.state.isIn(const ['dead', 'unconfirmed', 'pending']) &
            o.mutationKind.isIn([
              MutationKind.create.wireName,
              MutationKind.update.wireName,
            ]),
      )
      ..orderBy([
        (o) => OrderingTerm(expression: o.id, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return q.getSingleOrNull();
  }

  /// Re-arm a `dead` row for immediate retry. Resets `attempts` and
  /// `nextAttemptAt` so the next [drainOnce] picks it up; preserves
  /// `idempotency_key`, `payload`, and `field_errors_json` so the server
  /// sees the same request and the UI can still surface the prior errors
  /// if the retry fails again.
  ///
  /// Only a `dead` row, or a `pending` one waiting out its backoff: the
  /// Outbox menu that asked can be stale, and a row that went `unconfirmed`
  /// meanwhile may already have reached the server — only Resend, which asks
  /// first, may send it again. Returns whether a row was re-armed.
  Future<bool> retryDead({required int id, required int now}) async =>
      await (update(outbox)..where(
            (o) => o.id.equals(id) & o.state.isIn(const ['dead', 'pending']),
          ))
          .write(
            OutboxCompanion(
              state: const Value('pending'),
              attempts: const Value(0),
              nextAttemptAt: Value(now),
            ),
          ) >
      0;

  /// Delete `dead` rows whose `created_at` is older than [olderThanMs].
  /// Returns the number of rows removed.
  ///
  /// Dead rows hold the full mutation payload (PII, sometimes payment / tax
  /// fields) and are otherwise never cleaned up — the user has to discard
  /// them one by one from the Outbox UI. Auto-pruning bounds how long the
  /// data sits on disk in the (currently unencrypted) Drift DB.
  /// The dead rows [SyncRepository.pruneDeadRows] is about to delete, so it can
  /// reconcile each one's `is_dirty` flag before the row that explains it is
  /// gone. Read-only; the delete is still [pruneDead].
  Future<List<OutboxRow>> deadRowsOlderThan({
    required int olderThanMs,
    String? companyId,
  }) =>
      (select(outbox)..where(
            (o) =>
                o.state.equals('dead') &
                o.createdAt.isSmallerThanValue(olderThanMs) &
                (companyId == null
                    ? const Constant(true)
                    : o.companyId.equals(companyId)),
          ))
          .get();

  Future<int> pruneDead({required int olderThanMs, String? companyId}) =>
      (delete(outbox)..where(
            (o) =>
                o.state.equals('dead') &
                o.createdAt.isSmallerThanValue(olderThanMs) &
                (companyId == null
                    ? const Constant(true)
                    : o.companyId.equals(companyId)),
          ))
          .go();

  /// Snapshot of rows that aren't on the happy path: `dead`, `unconfirmed`,
  /// `in_flight`, or `pending` whose `next_attempt_at` is parked more than
  /// 24 h out (the 409 / password-required / 1-year-park cases in
  /// [SyncRepository]).
  ///
  /// Used by the debug-only diagnostics log on the System Logs screen. The
  /// drain-loop path keeps using [nextReady]; this query is read-only.
  Future<List<OutboxRow>> staleRowsForCompany({
    required String companyId,
    required int now,
  }) {
    final parkedThreshold = now + Duration.millisecondsPerDay;
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            (o.state.isIn(const ['dead', 'unconfirmed', 'in_flight']) |
                (o.state.equals('pending') &
                    o.nextAttemptAt.isBiggerThanValue(parkedThreshold))),
      )
      ..orderBy([(o) => OrderingTerm(expression: o.id)]);
    return q.get();
  }

  /// Delete the record's failed saves older than [beforeId]: its `dead`
  /// `update` rows, and its `dead` `create` rows too when [includeCreates] —
  /// never a document upload, which writes no field. A save that replaced
  /// them, or a discard of that save, leaves them stale.
  Future<int> deleteOlderDeadSaves({
    required String companyId,
    required String entityType,
    required String entityId,
    required int beforeId,
    required bool includeCreates,
  }) =>
      (delete(outbox)..where(
            (o) =>
                o.companyId.equals(companyId) &
                o.entityType.equals(entityType) &
                o.entityId.equals(entityId) &
                o.mutationKind.isIn([
                  MutationKind.update.wireName,
                  if (includeCreates) MutationKind.create.wireName,
                ]) &
                _isDocumentUpload(o).not() &
                o.state.equals('dead') &
                o.id.isSmallerThanValue(beforeId),
          ))
          .go();

  /// The failed saves [deleteOlderDeadSaves] would remove with
  /// `includeCreates: true` once a create of the record lands, in id order —
  /// so the create can salvage the SAVE-PARAM action one of them carried
  /// (`BaseEntityRepository.dedupPendingMutations`).
  Future<List<OutboxRow>> deadSavesForEntity({
    required String companyId,
    required String entityType,
    required String entityId,
  }) =>
      (select(outbox)
            ..where(
              (o) =>
                  o.companyId.equals(companyId) &
                  o.entityType.equals(entityType) &
                  o.entityId.equals(entityId) &
                  o.mutationKind.isIn([
                    MutationKind.update.wireName,
                    MutationKind.create.wireName,
                  ]) &
                  _isDocumentUpload(o).not() &
                  o.state.equals('dead'),
            )
            ..orderBy([(o) => OrderingTerm.asc(o.id)]))
          .get();

  /// Rewrite tmp ids inside payloads of pending, unconfirmed AND dead rows
  /// once a `create` lands and produces a real id. The repository / sync engine
  /// calls this in the same transaction as inserting into `id_remap`.
  ///
  /// Dead rows are included so a dependent mutation that died while the
  /// parent create was still unsynced (e.g. an invoice create whose
  /// `client_id: tmp_x` 422'd) heals once the parent finally lands —
  /// otherwise the Outbox screen's Retry re-sends the stale tmp_ id and
  /// fails identically forever. `in_flight` rows stay untouched: their
  /// network attempt may be landing concurrently (TOCTOU).
  Future<void> rewriteTempIdInPayloads({
    required String companyId,
    required String entityType,
    required String tempId,
    required String realId,
  }) async {
    final rows =
        await (select(outbox)..where(
              (o) =>
                  o.companyId.equals(companyId) &
                  o.state.isIn(const ['pending', 'unconfirmed', 'dead']) &
                  (o.payload.contains(tempId) | o.entityId.equals(tempId)),
            ))
            .get();
    for (final row in rows) {
      final newPayload = row.payload.replaceAll(tempId, realId);
      final newEntityId = row.entityId == tempId ? realId : row.entityId;
      // A PENDING row that was deferred by the drain's tmp_-dependency guard
      // (nextAttemptAt parked +60s, lastError set) is now healed — make it
      // immediately eligible so the very next `nextReady` picks it up,
      // instead of waiting out the stale defer. Without this, a "Sync first"
      // logout drains the parent, heals the dependent, but the dependent
      // stays parked and `pendingCountFor` still counts it → logout cancels
      // on a chain that's actually fine. `attempts` is deliberately NOT
      // reset (a row failing for a real reason must still exhaust its retry
      // budget). DEAD and UNCONFIRMED rows keep their state and scheduling
      // untouched — they heal their payload for the user's Retry / Send
      // again but must not start sending on their own (see the dead-row
      // test in outbox_dao_test).
      final reArm = row.state == 'pending';
      await (update(outbox)..where((o) => o.id.equals(row.id))).write(
        OutboxCompanion(
          payload: Value(newPayload),
          entityId: Value(newEntityId),
          nextAttemptAt: reArm ? const Value(0) : const Value.absent(),
          lastError: reArm ? const Value(null) : const Value.absent(),
          lastStatusCode: reArm ? const Value(null) : const Value.absent(),
        ),
      );
    }
  }
}
