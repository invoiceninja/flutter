import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/tables/outbox_table.dart';
import 'package:admin/domain/sync/mutation.dart';

part 'outbox_dao.g.dart';

/// `state` values: `pending | in_flight | dead`.
enum OutboxState { pending, inFlight, dead }

@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  Future<int> enqueue(OutboxCompanion row) => into(outbox).insert(row);

  /// One-shot row fetch by id. Used by sync-bound UI (e.g. Danger Zone delete)
  /// to inspect a row's terminal state immediately after [drainOnce] returns.
  Future<OutboxRow?> byId(int id) =>
      (select(outbox)..where((o) => o.id.equals(id))).getSingleOrNull();

  /// One-shot count of non-`dead` rows for [companyId]. The picker uses this
  /// to decide whether a company switch needs a "you have unsaved changes"
  /// confirmation; the streaming variant below feeds badges that refresh
  /// continuously.
  ///
  /// Counts `in_flight` alongside `pending`: a row mid-attempt at the moment
  /// a logout/switch guard reads this is still the user's unsynced work — if
  /// the attempt fails it re-parks as pending, and a guard that saw 0 would
  /// already have wiped it. (Badges use [watchPendingCount], unaffected.)
  Future<int> pendingCountForCompany(String companyId) async {
    final count = outbox.id.count();
    final q = selectOnly(outbox)
      ..addColumns([count])
      ..where(
        outbox.companyId.equals(companyId) & outbox.state.isNotValue('dead'),
      );
    final row = await q.getSingle();
    return row.read(count) ?? 0;
  }

  /// Distinct company ids holding any non-`dead` (pending or in_flight)
  /// outbox row. The full-logout / idle-timeout guards read this instead of
  /// `session.companies`: the wipe destroys EVERY company's rows, and the
  /// outbox is the ground truth for unsynced work — a company that vanished
  /// from the session envelope (e.g. one tolerantly-skipped malformed row on
  /// refresh) still counts here.
  Future<List<String>> companiesWithActiveRows() async {
    final q = selectOnly(outbox, distinct: true)
      ..addColumns([outbox.companyId])
      ..where(outbox.state.isNotValue('dead'));
    final rows = await q.get();
    return [
      for (final row in rows)
        if (row.read(outbox.companyId) case final String id) id,
    ];
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

  Future<void> markInFlight(int id) =>
      (update(outbox)..where((o) => o.id.equals(id))).write(
        const OutboxCompanion(state: Value('in_flight')),
      );

  /// Re-arm rows orphaned in `in_flight` — left there when a drain was
  /// interrupted (process death) between [markInFlight] and the catch handler
  /// that would have rescheduled or killed them. Sets them back to `pending`
  /// so [nextReady] sees them again. `SyncRepository` calls this at the top of
  /// each drain pass; safe because `drainOnce` is single-flight per company, so
  /// at drain-start no `in_flight` row for [companyId] is a live request.
  /// Returns the number of rows recovered.
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

  /// Snapshot of `pending` rows for [companyId] (excludes `dead` and
  /// `in_flight`) — same predicate as [deletePendingForCompany], but
  /// returns the rows so a caller can apply per-row discard logic. Used by
  /// `SyncRepository.discardPendingFor`.
  /// True when any non-terminal (`pending` or `in_flight`) row exists for
  /// [companyId] + [entityType]. `in_flight` matters: a refresh that lands
  /// while the row's HTTP attempt is mid-send must still treat the local
  /// edit as in charge — the attempt may fail and re-park as pending.
  Future<bool> hasActiveRowsFor({
    required String companyId,
    required String entityType,
  }) async {
    final q = select(outbox)
      ..where(
        (o) =>
            o.companyId.equals(companyId) &
            o.entityType.equals(entityType) &
            (o.state.equals('pending') | o.state.equals('in_flight')),
      )
      ..limit(1);
    return (await q.getSingleOrNull()) != null;
  }

  /// Like [hasActiveRowsFor] but scoped to a single [entityId]. The discard
  /// reconciliation uses it to decide whether clearing a local record's
  /// `is_dirty` is safe — only when NO other pending/in_flight outbox row
  /// for that exact record remains (else clearing would un-protect a still-
  /// queued edit from the next server refresh).
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
            (o.state.equals('pending') | o.state.equals('in_flight')),
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

  /// Newest `dead` row for the given entity (if any). The edit form calls
  /// this on open so it can replay 422 field errors against the form.
  Future<OutboxRow?> findDeadForEntity({
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
            o.state.equals('dead'),
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
  Future<void> retryDead({required int id, required int now}) =>
      (update(outbox)..where((o) => o.id.equals(id))).write(
        OutboxCompanion(
          state: const Value('pending'),
          attempts: const Value(0),
          nextAttemptAt: Value(now),
        ),
      );

  /// Delete `dead` rows whose `created_at` is older than [olderThanMs].
  /// Returns the number of rows removed.
  ///
  /// Dead rows hold the full mutation payload (PII, sometimes payment / tax
  /// fields) and are otherwise never cleaned up — the user has to discard
  /// them one by one from the Outbox UI. Auto-pruning bounds how long the
  /// data sits on disk in the (currently unencrypted) Drift DB.
  Future<int> pruneDead({required int olderThanMs}) =>
      (delete(outbox)..where(
            (o) =>
                o.state.equals('dead') &
                o.createdAt.isSmallerThanValue(olderThanMs),
          ))
          .go();

  /// Snapshot of rows that aren't on the happy path: `dead`, `in_flight`,
  /// or `pending` whose `next_attempt_at` is parked more than 24 h out (the
  /// 409 / password-required / 1-year-park cases in [SyncRepository]).
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
            (o.state.equals('dead') |
                o.state.equals('in_flight') |
                (o.state.equals('pending') &
                    o.nextAttemptAt.isBiggerThanValue(parkedThreshold))),
      )
      ..orderBy([(o) => OrderingTerm(expression: o.id)]);
    return q.get();
  }

  /// Rewrite tmp ids inside payloads of pending AND dead rows once a
  /// `create` lands and produces a real id. The repository / sync engine
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
                  (o.state.equals('pending') | o.state.equals('dead')) &
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
      // budget). DEAD rows keep their state and scheduling untouched — a
      // dead dependent heals its payload for a manual Retry but must stay
      // dead (see the dead-row test in outbox_dao_test).
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
