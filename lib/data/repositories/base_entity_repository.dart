import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show protected, visibleForTesting;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart'
    show resolveRelativeFilterTokens;
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/id_remap_dao.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/db/dao/sync_state_dao.dart';
import 'package:admin/data/services/api_exception.dart';

final _log = Logger('BaseEntityRepository');

/// Force-refreshes related entities whose server state changed as a *side
/// effect* of a mutation on a different entity — e.g. adding a payment updates
/// its invoice(s) and client; converting a quote creates an invoice; merging a
/// client moves its children (issue #7 + the stale-sibling sweep). Given the
/// affected entities grouped by [EntityType], the DI-wired implementation
/// force-refetches each via `repoFor(type).refreshByIds`, with an explicit
/// invoice→client cascade (a bank-transaction match knows the invoice, not the
/// client). Injected as `onRelatedEntitiesAffected` on the culprit repos.
typedef RelatedEntitiesRefresher =
    Future<void> Function(
      String companyId,
      Map<EntityType, Set<String>> byType,
    );

/// Shared outbox + id-remap + cursor mechanics. Concrete repositories
/// (`ClientRepository`, `ProductRepository`, ...) extend this with their
/// entity-specific data movement (API → Drift → domain).
///
/// `TDomain` is the clean domain model the UI consumes (`Client`,
/// `Product`, …). `TApi` is the API DTO returned by the server endpoint
/// for this entity (`ClientApi`, `ProductApi`, …). Generics let the sync
/// dispatcher pass typed responses into [applyCreateResponse] /
/// [applyUpdateResponse] without per-entity casts.
///
/// The `is_dirty` flag is local-only — `<Entity>.fromApi(...)` defaults
/// it to `false`, so concrete repos must overlay the row's value when
/// reading from Drift (see `ClientRepository._fromRow`). Without that
/// overlay an unsaved edit looks clean after app restart.
abstract class BaseEntityRepository<TDomain, TApi> {
  BaseEntityRepository({
    required this.db,
    required this.entityType,
    this.uuid = const Uuid(),
    DateTime Function()? now,
    this.onEnqueued,
    Set<MutationKind> requiresPasswordFor = const {},
  }) : _now = now ?? DateTime.now,
       _passwordRequiredKinds = requiresPasswordFor;

  final AppDatabase db;
  final EntityType entityType;
  final Uuid uuid;
  final DateTime Function() _now;
  final Set<MutationKind> _passwordRequiredKinds;

  /// Invoked fire-and-forget after [enqueueMutation] writes an outbox row.
  /// Wired by DI to `SyncRepository.drainOnce` so the row gets drained
  /// immediately when online instead of sitting until the next explicit
  /// trigger (company switch, app resume, etc.). Tests leave it null.
  final void Function(String companyId)? onEnqueued;

  OutboxDao get _outbox => db.outboxDao;
  IdRemapDao get _idRemap => db.idRemapDao;
  SyncStateDao get _syncState => db.syncStateDao;

  /// In-flight + negative-result guards for [ensureLoadedTemplate], so the
  /// N rows referencing the same uncached entity issue one network fetch
  /// and a 404 / deleted id isn't re-fetched on every rebuild this session.
  final Map<String, Future<void>> _ensureInFlight = {};
  final Set<String> _ensureMissing = {};

  /// API path segment in the EntityType registry sense, used by the sync
  /// engine to know which API to call. Concrete repos override.
  String get entityTypeName => entityType.name;

  /// Whether the given mutation requires the user's password (forces the
  /// outbox row's `requiresPassword=true`). Read from the set passed to
  /// the constructor — pass `requiresPasswordFor: const {MutationKind.delete,
  /// MutationKind.purge, ...}` in the concrete repo's `super(...)` call.
  /// Settings-only / read-only entities can omit it (defaults to empty).
  bool requiresPasswordFor(MutationKind kind) =>
      _passwordRequiredKinds.contains(kind);

  /// Resolve `maybeTempId` through `id_remap`. If the id isn't a tmp id (or
  /// no remap exists), the input is returned unchanged. Used by `watch(id)`
  /// so an open detail screen survives a tmp→real swap.
  Future<String> resolveId(String maybeTempId) async {
    if (!maybeTempId.startsWith('tmp_')) return maybeTempId;
    final real = await _idRemap.resolve(
      entityType: entityTypeName,
      tempId: maybeTempId,
    );
    return real ?? maybeTempId;
  }

  /// Enqueue an outbox row. The caller has already written the local
  /// optimistic state to Drift; this just registers the pending sync.
  ///
  /// The drain kick (`onEnqueued`, typically `sync.drainOnce`) is scheduled
  /// on the next event-loop iteration via `Future(() => ...)` so it runs
  /// *after* any `db.transaction(...)` wrapping this call has committed —
  /// otherwise `nextReady`'s SELECT either races the commit or queues
  /// behind the still-open transaction, and the row we just INSERTed sits
  /// at `state=pending, attempts=0` until the next user-driven drain
  /// trigger. `Future.microtask` / `scheduleMicrotask` aren't enough:
  /// microtasks run before timers and can fire while the transaction is
  /// mid-commit.
  ///
  /// The schedule call is wrapped in `Zone.root.run(...)` so the deferred
  /// callback runs in the root zone — without this, a transactional caller
  /// would propagate Drift's `#drift_transaction` zone value into the
  /// timer callback, and the drain's `nextReady` would route through the
  /// now-closed transaction executor and silently return no rows.
  Future<int> enqueueMutation({
    required String companyId,
    required String entityId,
    required MutationKind kind,
    required Map<String, dynamic> payload,
    String? batchId,
  }) async {
    final nowMs = _now().millisecondsSinceEpoch;
    final id = await _outbox.enqueue(
      OutboxCompanion.insert(
        companyId: companyId,
        entityType: entityTypeName,
        entityId: entityId,
        mutationKind: kind.wireName,
        payload: jsonEncode(payload),
        idempotencyKey: uuid.v4(),
        nextAttemptAt: nowMs,
        createdAt: nowMs,
        requiresPassword: requiresPasswordFor(kind)
            ? const Value(true)
            : const Value.absent(),
      ),
    );
    final kick = onEnqueued;
    if (kick != null) {
      // Escape any wrapping db.transaction() zone — see the method doc.
      Zone.root.run(() {
        unawaited(Future(() => kick(companyId)));
      });
    }
    return id;
  }

  /// Generate a fresh `tmp_<uuid>` id for an offline-created entity.
  String mintTempId() => 'tmp_${uuid.v4()}';

  /// The injected clock (defaults to `DateTime.now`). Exposed for subclasses
  /// that override mutation methods for a bespoke DAO (e.g. [TagRepository]'s
  /// optimistic archive/restore/delete) so they stay deterministic under the
  /// test-injected `now`.
  @protected
  DateTime now() => _now();

  /// Drop any prior `pending` outbox row for this `(company, type, id, kind)`
  /// tuple. Call **inside** the same `db.transaction` that does the
  /// optimistic Drift write + [enqueueMutation], so the new row replaces the
  /// stale one atomically. Used by `create` / `save` to suppress duplicates
  /// when the user retries from a synchronous-when-online inline error — for
  /// CREATE the stale row would otherwise produce a server-side duplicate;
  /// for UPDATE it would waste an HTTP round-trip with stale data. `in_flight`
  /// rows are left alone — their HTTP request may already be landing, so
  /// deleting them would race the dispatcher's `applyCreateResponse`. `dead`
  /// rows are left alone too — the existing `onSaved` cleanup deletes them
  /// after a successful re-save.
  ///
  /// Returns the SAVE-PARAM query carried by the rows it removed, merged
  /// oldest-first. That salvage is load-bearing: the billing repos fold an
  /// action (`mark_sent`, `paid`, `cancel`, `auto_bill`) into an ordinary
  /// `update` row's payload under [kSaveQueryPayloadKey], and this predicate
  /// keys only on `(company, type, id, kind)` — so it cannot tell an
  /// action-bearing save from a plain one. Without carrying the query forward,
  /// an offline "Mark Sent" followed by an offline typo-fix Save silently
  /// dropped the action: the invoice synced with the edit and stayed a draft,
  /// with nothing in the Outbox to show for it. Callers that build a payload
  /// merge this in via [mergeSaveQuery].
  @protected
  Future<Map<String, String>> dedupPendingMutations({
    required String companyId,
    required String entityId,
    required MutationKind kind,
  }) async {
    final superseded = await _outbox.pendingRowsForEntity(
      companyId: companyId,
      entityType: entityTypeName,
      entityId: entityId,
      mutationKind: kind.wireName,
    );
    await _outbox.deletePendingForEntity(
      companyId: companyId,
      entityType: entityTypeName,
      entityId: entityId,
      mutationKind: kind.wireName,
    );
    final carried = <String, String>{};
    for (final row in superseded) {
      carried.addAll(saveQueryOf(row.payload));
    }
    return carried;
  }

  /// The SAVE-PARAM query stored in a raw outbox payload, or empty. Tolerant
  /// of a malformed payload — a salvage step must never break the save it is
  /// trying to protect.
  @protected
  @visibleForTesting
  static Map<String, String> saveQueryOf(String rawPayload) {
    try {
      final decoded = jsonDecode(rawPayload);
      if (decoded is! Map) return const {};
      final q = decoded[kSaveQueryPayloadKey];
      if (q is! Map) return const {};
      return {
        for (final e in q.entries)
          if (e.key is String && e.value != null) e.key as String: '${e.value}',
      };
    } catch (_) {
      return const {};
    }
  }

  /// The save-query this save should send: its [own] if it has one, otherwise
  /// the [carried] one salvaged from the row it supersedes.
  ///
  /// **Deliberately not a union.** Merging by key only disambiguates the *same*
  /// verb; contradictory actions live under *different* keys, so a union keeps
  /// both. On a sent, unpaid invoice `canMarkPaid` and `canCancel` are true at
  /// the same time (`invoice_actions.dart`) and neither flips the local status,
  /// so offline both stay enabled — a union would drain as
  /// `PUT /invoices/{id}?cancel=true&paid=true`, cancelling the invoice AND
  /// recording a payment, with the outcome decided by server param ordering
  /// rather than by the user. `start` / `stop` on a recurring invoice are
  /// exclusive by definition too.
  ///
  /// So: a save that carries its own action states the user's latest intent and
  /// wins outright (which is what the pre-salvage behaviour did, correctly).
  /// The carried query is only for the case this salvage exists to fix — a
  /// PLAIN save superseding an action-bearing one, where dropping it silently
  /// lost an offline Mark Sent.
  ///
  /// Returns null when there is nothing to send, so `_withSaveQuery` skips the
  /// key entirely.
  @protected
  Map<String, String>? mergeSaveQuery(
    Map<String, String> carried,
    Map<String, String>? own,
  ) {
    if (own != null && own.isNotEmpty) return own;
    return carried.isEmpty ? null : carried;
  }

  /// Archive a row: flip the local Drift row optimistically (`archived_at`
  /// now, `is_dirty=true`) AND enqueue the mutation, in one transaction — so
  /// offline the row leaves the active list immediately instead of sitting
  /// there with no feedback (users would otherwise re-tap → duplicate
  /// mutations). The dispatcher hits `DELETE /entity/{id}?action=archive` on
  /// drain and `applyUpdateResponse` reconciles the row. The optimistic flip
  /// is gated on [localDao] (BaseEntityDao entities); bespoke-DAO entities
  /// fall back to enqueue-only (see [localDao]). `is_dirty=true` keeps a
  /// `/refresh` from clobbering the flip before sync.
  Future<void> archive({required String companyId, required String id}) async {
    await db.transaction(() async {
      await localDao?.setArchived(
        companyId: companyId,
        id: id,
        atEpochSeconds: _now().millisecondsSinceEpoch ~/ 1000,
      );
      await enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.archive,
        payload: {'id': id},
      );
    });
  }

  /// Restore a row: optimistically clear archived/deleted flags (the inverse
  /// of both [archive] and [delete]) + enqueue, in one transaction. See
  /// [archive].
  Future<void> restore({required String companyId, required String id}) async {
    await db.transaction(() async {
      await localDao?.markRestored(companyId: companyId, id: id);
      await enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.restore,
        payload: {'id': id},
      );
    });
  }

  /// Delete a row: optimistically soft-delete the local row (`is_deleted=true`,
  /// `is_dirty=true`) + enqueue, in one transaction (see [archive]).
  /// Password-gated for entities that opted into it via the constructor's
  /// `requiresPasswordFor:` set — the outbox row gets `requiresPassword=true`
  /// and the sync engine prompts via `ConfirmPasswordSheet`. (Invoice Ninja
  /// delete is a soft-delete; [purge] is the irreversible hard delete.)
  Future<void> delete({required String companyId, required String id}) async {
    await db.transaction(() async {
      await localDao?.markDeletedDirty(companyId: companyId, id: id);
      await enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.delete,
        payload: {'id': id},
      );
    });
  }

  /// Enqueue a `purge` mutation. Irreversible — the dispatcher hard-deletes
  /// the local row via `applyPurgeResponse` after the server confirms.
  /// Password-gated for entities that opted in.
  Future<void> purge({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.purge,
        payload: {'id': id},
      );

  /// Called by the sync engine after a successful `create` round-trip:
  /// remember the temp → real id remap and rewrite any pending outbox
  /// payloads that referenced the temp id.
  Future<void> recordCreateSuccess({
    required String companyId,
    required String tempId,
    required String realId,
  }) async {
    if (tempId == realId) return;
    final nowMs = _now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await _idRemap.remember(
        entityType: entityTypeName,
        tempId: tempId,
        realId: realId,
        now: nowMs,
      );
      await _outbox.rewriteTempIdInPayloads(
        companyId: companyId,
        entityType: entityTypeName,
        tempId: tempId,
        realId: realId,
      );
    });
  }

  /// Shared shape for `applyCreateResponse` implementations. Mirrors the
  /// three-step contract every CRUD repo (Client / Product / Task / …) shares:
  ///   1. Upsert the new row under the real id (via the [upsert] callback).
  ///   2. Delete the tmp row (if `realId != tempId`) via [deleteById].
  ///   3. Call [recordCreateSuccess] so the id-remap is recorded and pending
  ///      outbox payloads referencing the tmp id are rewritten.
  ///
  /// All three steps run inside a single transaction. Concrete repos call
  /// this from their [applyCreateResponse] override, supplying the typed
  /// dao calls and the per-entity `_apiToCompanion` projection.
  @protected
  Future<void> applyCreateResponseTemplate<TCompanion>({
    required String companyId,
    required String tempId,
    required String realId,
    required TCompanion companion,
    required Future<void> Function(TCompanion) upsert,
    required Future<void> Function(String id) deleteById,
  }) async {
    await db.transaction(() async {
      await upsert(companion);
      if (realId != tempId) {
        await deleteById(tempId);
      }
      await recordCreateSuccess(
        companyId: companyId,
        tempId: tempId,
        realId: realId,
      );
    });
  }

  /// Sync engine entry point for "the server accepted our `create` and
  /// returned the real entity." Concrete repos override and:
  ///   1. Upsert the new row under the real id.
  ///   2. Delete the tmp row (if `realId != tempId`).
  ///   3. Call [recordCreateSuccess] to remap and rewrite pending payloads.
  /// All three steps run inside a single transaction.
  ///
  /// Settings-only entities (e.g. company) that have no create flow can
  /// leave this as the default — the dispatcher never calls it.
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required TApi serverResponse,
  }) => throw UnsupportedError(
    '$runtimeType does not support create — entity $entityTypeName is '
    'settings-only or read-only.',
  );

  /// Sync engine entry point for "the server accepted our `update` /
  /// `archive` / `restore` and returned the canonical entity." Concrete
  /// repos upsert the row with `is_dirty=false`.
  Future<void> applyUpdateResponse({
    required String companyId,
    required TApi serverResponse,
  }) => throw UnsupportedError(
    '$runtimeType does not implement applyUpdateResponse — every CRUD '
    'entity must override this.',
  );

  /// Sync engine entry point for "the server accepted our `delete`."
  /// Concrete repos mark the local row as `is_deleted=true` so the list
  /// hides it immediately, without waiting for a pull-to-refresh.
  ///
  /// Settings-only entities that have no delete flow can leave this as
  /// the default — the dispatcher never calls it.
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) => throw UnsupportedError(
    '$runtimeType does not support delete — entity $entityTypeName is '
    'settings-only or read-only.',
  );

  /// Sync engine entry point for "the server accepted our `purge`."
  /// Concrete repos hard-delete the local row — purge is irreversible
  /// and the server has forgotten the entity, so the local copy should
  /// be gone too (not just flagged `is_deleted=true` the way
  /// [applyDeleteResponse] does).
  ///
  /// Entities that haven't wired purge can leave this as the default —
  /// the dispatcher only reaches here when an outbox row of kind
  /// [MutationKind.purge] exists, which their UI can't enqueue today.
  Future<void> applyPurgeResponse({
    required String companyId,
    required String id,
  }) => throw UnsupportedError(
    '$runtimeType does not support purge — entity $entityTypeName has '
    'not wired the purge flow.',
  );

  /// Hard-delete the local Drift row for [id] without enqueuing any server
  /// mutation. Called when a never-synced offline `create` is discarded from
  /// the outbox (see `SyncRepository.discardOutboxRow`): the `tmp_` row would
  /// otherwise linger forever as a ghost with no outbox row to ever sync it.
  ///
  /// Concrete CRUD repos override with the one-line DAO call (the same
  /// `deleteById` they already pass into [applyCreateResponseTemplate]).
  /// Settings-only / create-less entities (e.g. company) leave this as the
  /// default — they can never produce a `tmp_` ghost create, so the discard
  /// path never reaches here for them.
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => throw UnsupportedError(
    '$runtimeType does not support deleteLocalById — entity $entityTypeName '
    'is settings-only or has no offline create flow.',
  );

  /// The entity's Drift DAO, used only by the generic [clearLocalDirty]
  /// reconciliation below. Entities whose DAO extends [BaseEntityDao]
  /// override this with their one-liner (`db.xDao`); the bespoke-DAO
  /// entities (bundled / settings lists whose DAO extends `DatabaseAccessor`
  /// directly — tax rates, gateways, payment terms, tokens, webhooks,
  /// schedules, designs, task statuses, expense categories, payment links,
  /// bank accounts/transactions, transaction rules) leave it null.
  ///
  /// Those entities therefore override [clearLocalDirty] themselves. They must:
  /// the "they're refreshed wholesale so a stale dirty flag is harmless"
  /// reasoning that used to live here was **false** — every one of them writes
  /// `is_dirty = true` on optimistic create/save AND refreshes through
  /// `upsertAllPreservingDirty`, which *skips dirty rows*. A row left dirty
  /// after the user discards its edit is skipped by every later bundle and
  /// paged refresh, so the abandoned value is shown as authoritative until the
  /// database is wiped.
  ///
  /// Additive — does not replace the per-entity [deleteLocalById] override.
  /// (The sibling gap — no optimistic `setArchived` / `markRestored` /
  /// `markDeletedDirty` for these entities — IS benign, because it sets no
  /// `is_dirty`; see the note on [archive].)
  @protected
  BaseEntityDao<dynamic, dynamic>? get localDao => null;

  /// Clear the local record's `is_dirty` flag — the discard-reconciliation
  /// hook (see `SyncRepository.discardOutboxRow`). No-op when the entity has
  /// no DAO (`localDao == null`). The SyncRepository gates the call on "no
  /// other active outbox row for this entity", so this never un-protects a
  /// still-queued edit.
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async => localDao?.clearDirtyById(companyId: companyId, id: id);

  /// Translate the requested UI [EntityState]s into server query params for
  /// the list endpoint, e.g. `{'status': 'archived,deleted'}`.
  ///
  /// Lifecycle (active/archived/deleted) is the Invoice Ninja **`status`**
  /// param (`QueryFilters::status` — `deleted_at` / `is_deleted`), inherited
  /// by every list entity. It is **not** `client_status` (that param is the
  /// per-entity *computed* business status: invoice unpaid/overdue, quote
  /// expired, payment completed, …). Sending lifecycle on `client_status`
  /// (the old behaviour) silently no-op'd archived/deleted views and
  /// collided with the quote/payment status filters.
  ///
  /// Empty or all-states → no constraint, which on the server means **every**
  /// lifecycle state comes back, not just active: `QueryFilters::status('')`
  /// returns the builder untouched. That is what makes `refreshAll`'s
  /// all-states sweep pull the archived/deleted tail into the local cache.
  /// (`status=active,archived,deleted` would be an equivalent no-op.)
  /// Concrete repos should not override this.
  @protected
  Map<String, String> stateQueryParams(Set<EntityState> states) {
    if (states.isEmpty || states.containsAll(EntityState.values)) {
      return const {};
    }
    final names = states.map((s) => s.serverName).toList()..sort();
    return {'status': names.join(',')};
  }

  /// Watch a single row by a *real* (non-tmp) id, mapping Drift rows to the
  /// domain model. Concrete repos implement this with their DAO and the
  /// private `_fromRow` overlay that re-applies local-only flags like
  /// `is_dirty`. Called by [watch] and [watchByTempId].
  @protected
  Stream<TDomain?> watchByRealId({
    required String companyId,
    required String id,
  });

  /// Watch a single row by id. The id may be a tmp id; we transparently
  /// resolve through `id_remap` so an open detail screen survives the swap
  /// the sync engine makes after a successful create — even when the swap
  /// happens **while** the screen is open.
  Stream<TDomain?> watch({required String companyId, required String id}) {
    if (!id.startsWith('tmp_')) {
      return watchByRealId(companyId: companyId, id: id);
    }
    return watchByTempId(companyId: companyId, tempId: id);
  }

  /// Drift's `watchById(tempId)` goes blank when the sync engine deletes the
  /// tmp row mid-swap. To keep the detail screen alive, we listen to
  /// `id_remap` in parallel and re-subscribe to the new id when it lands.
  @protected
  Stream<TDomain?> watchByTempId({
    required String companyId,
    required String tempId,
  }) {
    final controller = StreamController<TDomain?>();
    StreamSubscription<TDomain?>? rowSub;
    StreamSubscription<String?>? remapSub;
    String? currentId;

    void subscribeToRow(String resolved) {
      if (resolved == currentId) return;
      currentId = resolved;
      rowSub?.cancel();
      rowSub = watchByRealId(
        companyId: companyId,
        id: resolved,
      ).listen(controller.add, onError: controller.addError);
    }

    controller.onListen = () async {
      final initial = await resolveId(tempId);
      subscribeToRow(initial);
      remapSub = _idRemap
          .watchRealId(entityType: entityTypeName, tempId: tempId)
          .listen((realId) {
            if (realId != null) subscribeToRow(realId);
          });
    };
    controller.onCancel = () async {
      await rowSub?.cancel();
      await remapSub?.cancel();
    };

    return controller.stream;
  }

  /// Advance the keyset cursor after upserting a page.
  Future<void> advanceCursor({
    required String companyId,
    required int updatedAt,
    required String id,
    bool wasFullSync = false,
  }) {
    return _syncState.writeCursor(
      companyId: companyId,
      entityType: entityTypeName,
      updatedAt: updatedAt,
      id: id,
      now: _now().millisecondsSinceEpoch,
      wasFullSync: wasFullSync,
    );
  }

  /// Whether a just-fetched page implies more rows are reachable.
  ///
  /// Shared by [ensurePageLoadedTemplate] and by the repos that hand-roll their
  /// own `ensurePageLoaded` body, so the rule can't drift between them again.
  ///
  /// [cursorApplied] must mean a REAL watermark went out on the request, not
  /// merely that a cursor object was read: `SyncStateDao.read` returns an
  /// empty `SyncCursor` (never null) when nothing is stored, and the request
  /// then sends `sinceUpdatedAt: null` — so a cold first load is unnarrowed and
  /// must conclude normally. Pass `cursor?.isEmpty == false`.
  ///
  /// The subtlety is the keyset cursor. A page-1 fetch that applied it returned
  /// only the `updated_at >= W` **delta**, not a true first page — so a short
  /// (or empty) result means "the delta window is exhausted", NOT "end of
  /// list". Concluding `false` there latched `hasMore = false`, which
  /// hard-gates `loadMore()`, so every warm-session filter/sort change capped
  /// the list at one page while rows 51+ sat unreachable in the local cache.
  /// Defer the decision to the next page, which drops the cursor (`page > 1`)
  /// and reads true offset rows. A cold page 1 (no cursor) concludes normally
  /// from the row count.
  @protected
  @visibleForTesting
  bool hasMoreAfterPage({
    required int rowCount,
    required bool cursorApplied,
    required int pageSize,
  }) {
    if (cursorApplied) return true;
    return rowCount >= pageSize;
  }

  /// Whether this fetch is a NARROWED VIEW of the entity — a slice — rather
  /// than a canonical page of the whole list.
  ///
  /// One predicate, two consumers, so the cursor READ gate and the cursor
  /// ADVANCE gate can never disagree again (they did: the read gate ignored
  /// `extraFilters` / `states` while the advance gate honoured both, which is
  /// flutter#32):
  ///
  ///  * **READ** ([shouldReadCursor]) — a narrowed page-1 fetch must NOT apply
  ///    the `updated_at >=` keyset cursor. The server ANDs the watermark onto
  ///    the filter, so a cursor'd filtered fetch returns only rows in the slice
  ///    that changed since the last sync and silently misses older,
  ///    not-recently-edited matches. Worse, after a full resync the watermark
  ///    is ~now, so a filtered page 1 comes back empty and the list renders a
  ///    false "No records found". This is verbatim the reasoning the SEARCH
  ///    gate has always had — it applies to any filter.
  ///  * **ADVANCE** ([shouldAdvanceCursor]) — a narrowed page's `data.last` is
  ///    a high-water mark for that SLICE, not for the entity.
  ///    `SyncStateDao.writeCursor` is last-write-wins with no max guard, so
  ///    advancing from it walks the shared watermark past rows the filter
  ///    excluded, and the next unfiltered delta never fetches them.
  ///
  /// The narrowing dimensions:
  ///
  ///  * **parent scope** (a client's Invoices tab, a bank account's
  ///    Transactions tab).
  ///  * **an active search**.
  ///  * **any user filter** with a non-empty value set in `extraFilters`.
  ///  * **a `states` set that narrows away from the list's baseline.** Two
  ///    shapes are baselines and are NOT narrowing: the default `{active}`
  ///    (long-standing behaviour — the archived/deleted tail is swept by
  ///    `refreshAll`), and any set [stateQueryParams] sends nothing for (empty,
  ///    or all of `EntityState.values` — the widest possible fetch, which is
  ///    what `refreshAll` sends and what stamps `lastFullSyncAt`). Anything in
  ///    between, e.g. `{archived}` from the status chip, is a slice.
  ///
  /// `staticFilters` is deliberately NOT considered: those are per-repo
  /// constants, and the ones that do narrow the row set (e.g. `active_banks` on
  /// bank transactions) are constant for that repo's list, so they can't skew
  /// the watermark relative to its own baseline.
  @protected
  @visibleForTesting
  bool isNarrowedFetch({
    required bool hasParentScope,
    required bool isSearchScoped,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
  }) {
    if (hasParentScope || isSearchScoped) return true;
    if (extraFilters.values.any((v) => v.isNotEmpty)) return true;
    if (stateQueryParams(states).isEmpty) return false;
    return !(states.length == 1 && states.contains(EntityState.active));
  }

  /// Whether this fetch may APPLY the shared `(companyId, entityType)` keyset
  /// cursor. Page 1 of an un-narrowed fetch only — see [isNarrowedFetch] for
  /// why, and note the `page > 1` exclusion: the server applies the cursor as a
  /// plain `updated_at >=` WHERE filter on top of offset paging (default order
  /// `id DESC` — see CLAUDE.md § Sync), so letting it leak into page >= 2 turns
  /// "browse the full list" into "browse only recently-changed rows" — page 2
  /// is mostly the same ~50 rows page 1 already returned → near-empty →
  /// `hasMore = false`. That silently capped pagination, search, and even a
  /// forced full resync at roughly one page for any organically-grown account.
  ///
  /// Pure, so it unit-tests against [shouldAdvanceCursor] for symmetry;
  /// [readCursorIfEligible] is the form repos actually call.
  @protected
  @visibleForTesting
  bool shouldReadCursor({
    required bool ignoreCursor,
    required int page,
    required bool hasParentScope,
    required bool isSearchScoped,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
  }) {
    if (ignoreCursor || page > 1) return false;
    return !isNarrowedFetch(
      hasParentScope: hasParentScope,
      isSearchScoped: isSearchScoped,
      states: states,
      extraFilters: extraFilters,
    );
  }

  /// Read the shared keyset cursor when this fetch is entitled to it, else
  /// null. The single call every `ensurePageLoaded` body uses — including the
  /// six repos that hand-roll their own — so the gate expression exists in
  /// exactly one place.
  ///
  /// Pass the `extraFilters` map **after** [resolveRelativeFilterTokens], the
  /// same one handed to [shouldAdvanceCursor].
  @protected
  Future<SyncCursor?> readCursorIfEligible({
    required String companyId,
    required bool ignoreCursor,
    required int page,
    required bool hasParentScope,
    required bool isSearchScoped,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
  }) async {
    if (!shouldReadCursor(
      ignoreCursor: ignoreCursor,
      page: page,
      hasParentScope: hasParentScope,
      isSearchScoped: isSearchScoped,
      states: states,
      extraFilters: extraFilters,
    )) {
      return null;
    }
    return _syncState.read(companyId: companyId, entityType: entityTypeName);
  }

  /// Whether this page's `data.last` may advance the shared
  /// `(companyId, entityType)` keyset cursor.
  ///
  /// Only an UNSCOPED, UNFILTERED page 1 may — see [isNarrowedFetch], which
  /// this shares with the cursor READ gate. The `page != 1` exclusion is its
  /// own: under `id DESC` deeper pages carry OLDER rows, so last-write-wins
  /// would walk the watermark backwards.
  @protected
  @visibleForTesting
  bool shouldAdvanceCursor({
    required int page,
    required bool hasParentScope,
    required bool isSearchScoped,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
  }) {
    if (page != 1) return false;
    return !isNarrowedFetch(
      hasParentScope: hasParentScope,
      isSearchScoped: isSearchScoped,
      states: states,
      extraFilters: extraFilters,
    );
  }

  /// Shared shape for `ensurePageLoaded` across every paginated repo (CRUD
  /// + bundled). Encodes the contract every list-fetching repo has shared
  /// independently:
  ///   1. Read cursor (or skip when `ignoreCursor`).
  ///   2. Merge `stateQueryParams(states)` + per-call [staticFilters] + the
  ///      open-ended [extraFilters] map (each set comma-joined, keys sorted
  ///      deterministically) into a flat `Map<String, String>`.
  ///   3. Call [listCall] with cursor + filters.
  ///   4. Empty page → return false (no more rows).
  ///   5. Upsert via [upsert] with `{id → companion}` projected via [idOf] +
  ///      [toCompanion].
  ///   6. Advance the cursor when the server returned a non-null
  ///      `(cursorUpdatedAt, cursorId)`. `wasFullSync` mirrors the
  ///      established convention: true only when this call ignored the
  ///      cursor AND we're on page 1 (a fresh full-sync sweep).
  ///   7. Return `apiRows.length >= pageSize` — more pages remain when the
  ///      server filled the page.
  ///
  /// [listCall] accepts the typed `*Api.list` tear-off directly (the
  /// signature matches `BaseEntityApi.list`). [itemsOf] projects the inner
  /// array out of the `*ListApi` wrapper (typically `(l) => l.data`). The
  /// extra `TList` generic lets call sites pass `api.list` without a
  /// wrapping closure.
  @protected
  Future<bool> ensurePageLoadedTemplate<TList, TItem, TCompanion>({
    required String companyId,
    required int page,
    required int pageSize,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    Map<String, String> staticFilters = const {},
    bool ignoreCursor = false,
    bool excludeDeletedClients = false,
    required Future<({TList data, int? cursorUpdatedAt, String? cursorId})>
    Function({
      required int page,
      int perPage,
      String? search,
      int? sinceUpdatedAt,
      String? sinceId,
      Map<String, String> filters,
    })
    listCall,
    required List<TItem> Function(TList) itemsOf,
    required String Function(TItem) idOf,
    required TCompanion Function(TItem) toCompanion,
    required Future<void> Function(Map<String, TCompanion> byId) upsert,
  }) async {
    // Rolling `rel:` tokens must be resolved to absolute values before
    // they hit the wire — the server never sees a relative token.
    final resolvedExtra = resolveRelativeFilterTokens(extraFilters);
    // A fetch scoped to a parent record — an embedded detail tab, or a
    // standalone list the user has filtered to one parent — is a filtered VIEW,
    // not a canonical full-entity sync. Two distinct scope checks below:
    //
    //  * `hasClientScope` (client only) gates the `without_deleted_clients`
    //    suppression so a deleted client's own detail tabs still fetch (React
    //    parity). Client-specific, so it stays narrow.
    //
    //  * `hasParentScope` (client OR vendor OR bank-integration) gates the
    //    shared `(companyId, entityType)` keyset cursor — neither read nor
    //    advanced for a scoped fetch. The scoped page's `data.last` is not a
    //    valid global high-water mark: reading it would make the scoped list
    //    under-fetch, and advancing it would corrupt the *unscoped* list's
    //    delta sync (e.g. opening a client's Invoices tab or a bank account's
    //    Transactions tab skipping the standalone list forward). A scoped fetch
    //    offset-paginates its narrowed view from page 1 instead. These are the
    //    server-narrowing scope params embedded lists thread; `project_id` is
    //    intentionally absent — project-embedded lists scope only the LOCAL
    //    watch, never the server fetch, so their cursor advance stays correct.
    final hasClientScope =
        resolvedExtra.containsKey('client_id') ||
        resolvedExtra.containsKey('client_ids');
    final hasParentScope =
        hasClientScope ||
        resolvedExtra.containsKey('vendor_id') ||
        resolvedExtra.containsKey('bank_integration_ids');

    // The cursor is a PAGE-1, UNSCOPED, UN-NARROWED delta probe only — see
    // `isNarrowedFetch` / `shouldReadCursor` for the full rationale, shared
    // with the ADVANCE gate below so the two can't disagree.
    final isSearchScoped = search != null && search.isNotEmpty;
    final cursor = await readCursorIfEligible(
      companyId: companyId,
      ignoreCursor: ignoreCursor,
      page: page,
      hasParentScope: hasParentScope,
      isSearchScoped: isSearchScoped,
      states: states,
      extraFilters: resolvedExtra,
    );

    final filters = <String, String>{
      ...stateQueryParams(states),
      ...staticFilters,
      if (excludeDeletedClients && !hasClientScope)
        'without_deleted_clients': 'true',
      for (final entry in resolvedExtra.entries)
        if (entry.value.isNotEmpty)
          entry.key: (entry.value.toList()..sort()).join(','),
    };

    final result = await listCall(
      page: page,
      perPage: pageSize,
      search: search,
      sinceUpdatedAt: cursor?.updatedAt,
      sinceId: cursor?.id,
      filters: filters,
    );

    final apiRows = itemsOf(result.data);
    if (apiRows.isEmpty) {
      return hasMoreAfterPage(
        rowCount: 0,
        cursorApplied: cursor?.isEmpty == false,
        pageSize: pageSize,
      );
    }

    // Server-refresh: skip ids whose existing local row has is_dirty=true,
    // so a paged refresh doesn't clobber the user's pending offline edit.
    await upsert({for (final a in apiRows) idOf(a): toCompanion(a)});

    // Only an unscoped, un-narrowed page 1 may move the global watermark —
    // same `isNarrowedFetch` predicate the cursor READ above is gated on.
    if (shouldAdvanceCursor(
          page: page,
          hasParentScope: hasParentScope,
          isSearchScoped: isSearchScoped,
          states: states,
          extraFilters: resolvedExtra,
        ) &&
        result.cursorUpdatedAt != null &&
        result.cursorId != null) {
      await advanceCursor(
        companyId: companyId,
        updatedAt: result.cursorUpdatedAt!,
        id: result.cursorId!,
        wasFullSync: ignoreCursor,
      );
    }

    // A page-1 fetch that applied the keyset cursor returned only the
    // `updated_at >= W` DELTA (rows changed since the last sync), not a true
    // first page — so a partial result means "the delta window is exhausted",
    // NOT "end of list". Latching hasMore=false here permanently capped
    // warm-session lists at one page: rows 51+ sit in the local cache but the
    // Drift watch window (`LIMIT pageSize * loadedPages`) never widens because
    // loadMore() is hard-gated on hasMore. Defer the has-more decision to the
    // next page, which drops the cursor (see the `page > 1` guard above) and
    // reads true offset rows. A cold page 1 (no cursor) still concludes
    // normally from the row count.
    return hasMoreAfterPage(
      rowCount: apiRows.length,
      cursorApplied: cursor?.isEmpty == false,
      pageSize: pageSize,
    );
  }

  /// Lazily hydrate a single referenced row into Drift on a cache miss —
  /// e.g. a `*NameLabel` watch yielded null because the vendor an expense
  /// references isn't on the prefetched first page. Network-fetch by id
  /// via [fetch] (`api.get`), then upsert via the **same** projection the
  /// repo's `ensurePageLoaded` uses ([idOf] + [toCompanion] + [upsert]).
  ///
  /// Safe to call from many rows / every rebuild: short-circuits when the
  /// row is already cached, coalesces concurrent calls for the same id,
  /// skips empty / `tmp_` (local-only) ids, and negative-caches ids the
  /// server reports as gone (`NotFoundException` / 404) so a deleted/unknown
  /// reference doesn't hammer the network. A *transient* failure
  /// (network down, 5xx, rate-limit, stale 401) is NOT negative-cached — the
  /// id stays eligible so the next rebuild retries once connectivity
  /// recovers, instead of showing a raw id for the rest of the session. This
  /// is a read-only hydrate — no outbox / `is_dirty` semantics.
  @protected
  Future<void> ensureLoadedTemplate<TItem, TCompanion>({
    required String companyId,
    required String id,
    required Future<TItem> Function(String id) fetch,
    required String Function(TItem) idOf,
    required TCompanion Function(TItem) toCompanion,
    required Future<void> Function(Map<String, TCompanion> byId) upsert,
  }) {
    if (id.isEmpty || id.startsWith('tmp_') || _ensureMissing.contains(id)) {
      return Future<void>.value();
    }
    return _ensureInFlight[id] ??= () async {
      try {
        final cached = await watch(companyId: companyId, id: id).first;
        if (cached != null) return;
        final item = await fetch(id);
        await upsert({idOf(item): toCompanion(item)});
      } on NotFoundException {
        // Genuinely gone server-side (404) — negative-cache so a deleted /
        // unknown reference isn't re-fetched on every rebuild this session.
        _ensureMissing.add(id);
      } catch (_) {
        // Transient failure (NetworkException / 5xx ServerException /
        // RateLimitedException / stale 401): leave the id eligible so the
        // next rebuild retries once the network recovers, rather than
        // pinning the *NameLabel to a raw id for the rest of the session.
      } finally {
        // `remove` returns the in-flight future itself; awaiting it here
        // would deadlock, so explicitly mark it unawaited.
        unawaited(_ensureInFlight.remove(id));
      }
    }();
  }

  /// Force-refetch [ids] from the server and upsert them into Drift,
  /// **dirty-preserving**, even when already cached — the non-cache-gated
  /// sibling of [ensureLoadedTemplate]. Converges a sibling entity that a
  /// mutation on *another* entity changed server-side (issue #7 + the
  /// stale-sibling sweep). Runs **inside the outbox drain**, so every per-id
  /// fetch **swallows all errors**: a thrown exception here would be
  /// mis-attributed to the already-succeeded mutation by the drain's typed
  /// error handling (404 → bogus conflict, 422 → dead, …). A missed refresh
  /// self-heals on the next full resync. Returns the successfully-fetched items
  /// so callers can derive further ids (e.g. an invoice's `clientId`). Skips
  /// empty/`tmp_` ids.
  @protected
  Future<List<TItem>> refreshByIdsTemplate<TItem, TCompanion>({
    required String companyId,
    required Iterable<String> ids,
    required Future<TItem> Function(String id) fetch,
    required String Function(TItem) idOf,
    required TCompanion Function(TItem) toCompanion,
    required Future<void> Function(Map<String, TCompanion> byId) upsert,
  }) async {
    final realIds = ids
        .where((id) => id.isNotEmpty && !id.startsWith('tmp_'))
        .toSet();
    if (realIds.isEmpty) return const [];
    final fetched = <TItem>[];
    final byId = <String, TCompanion>{};
    await Future.wait(
      realIds.map((id) async {
        try {
          final item = await fetch(id);
          fetched.add(item);
          byId[idOf(item)] = toCompanion(item);
        } catch (e) {
          _log.warning(
            'refreshByIds: failed to refetch $entityTypeName $id: $e',
          );
        }
      }),
    );
    if (byId.isNotEmpty) await upsert(byId);
    return fetched;
  }

  /// Force-refetch [ids] and upsert them dirty-preserving. Default is a no-op —
  /// settings/bundled repos aren't fetched by id this way; every list repo
  /// overrides this via [refreshByIdsTemplate]. Reached generically through the
  /// DI `repoFor(EntityType)` map by [RelatedEntitiesRefresher].
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {}

  /// Shared shape for bundled-entity `applyBundle` implementations. Encodes
  /// the contract every bundled repo (task_statuses, payment_terms,
  /// company_gateways, tax_rates, expense_categories, designs, payment_links)
  /// shares:
  ///   1. Empty bundle → no-op (preserves the existing cursor).
  ///   2. Project each API item to a Drift companion via [toCompanion].
  ///   3. Inside one transaction: invoke [upsert] with the projected map,
  ///      then advance the keyset cursor to the bundle's max `updated_at`
  ///      and the corresponding id.
  ///
  /// [wasFullSync] (default true — login / forced / first refresh) marks the
  /// cursor as a complete snapshot so a later `ensurePageLoaded`
  /// short-circuits its first page fetch. On a *delta* refresh
  /// (`current_company=true`, `wasFullSync: false`) the bundle is **partial**:
  ///   * the cursor is advanced but **not** marked full (so pagination still
  ///     back-fills rows the delta didn't carry), and
  ///   * it is never *regressed* — a delta whose max `updated_at` is behind
  ///     the cursor we already hold leaves the cursor untouched (the upsert
  ///     still runs, so archived/deleted flags from the delta still land).
  ///
  /// Soft-delete note: this is upsert-only and never deletes. A delta returns
  /// archived/deleted rows with their flags set; bundled-entity `watchAll`
  /// DAOs already filter `archived_at`/`is_deleted`, so display stays correct
  /// while tombstones accumulate locally — matching legacy admin-portal
  /// behavior (it keeps them too, filtered by `isActive`). If local growth
  /// ever matters, prune in a separate maintenance pass, never here.
  ///
  /// Why a callback for [upsert] instead of a DAO reference: bundled DAOs
  /// disagree on the upsert signature today — most take `(companyId:, byId:
  /// {String: Companion})` and use `upsertAllPreservingDirty` so pending
  /// offline edits survive a refresh, while a couple take a flat companion
  /// list via plain `upsertAll`. Pass-through preserves the existing
  /// per-entity choice without forcing alignment here.
  @protected
  Future<void> applyBundleUpsertOnly<TItem, TCompanion>({
    required String companyId,
    required List<TItem> bundle,
    required String Function(TItem) idOf,
    required int Function(TItem) updatedAtOf,
    required TCompanion Function(TItem) toCompanion,
    required Future<void> Function(Map<String, TCompanion> byId) upsert,
    bool wasFullSync = true,
  }) async {
    if (bundle.isEmpty) return;
    final byId = <String, TCompanion>{
      for (final a in bundle) idOf(a): toCompanion(a),
    };
    var maxUpdatedAt = 0;
    String? lastId;
    for (final a in bundle) {
      final updatedAt = updatedAtOf(a);
      if (updatedAt > maxUpdatedAt) {
        maxUpdatedAt = updatedAt;
        lastId = idOf(a);
      }
    }
    await db.transaction(() async {
      // Always upsert (preserving dirty) — even when we skip the cursor
      // write below, the rows (incl. archived/deleted flags) must land.
      await upsert(byId);
      if (lastId == null) return;
      if (wasFullSync) {
        await advanceCursor(
          companyId: companyId,
          updatedAt: maxUpdatedAt,
          id: lastId,
          wasFullSync: true,
        );
        return;
      }
      // Delta: never claim a full sync, and only advance the keyset cursor
      // on a *strictly greater* `updatedAt`. At an equal timestamp the
      // delta's `lastId` is arbitrary (just the last row in the partial
      // bundle); moving the cursor to `(T, thatId)` could push it sideways
      // past rows at `(T, id ≤ thatId)` that the delta didn't carry, which a
      // later keyset `ensurePageLoaded` would then skip. Leaving the cursor
      // is safe — the rows were already upserted above; worst case is one
      // cheap idempotent re-fetch, never a skip. The server's
      // `updated_at >= T-buffer` window is complete, so a strictly-greater
      // max is a legitimate forward move.
      final existing = await _syncState.read(
        companyId: companyId,
        entityType: entityTypeName,
      );
      if (maxUpdatedAt <= (existing.updatedAt ?? 0)) return;
      await advanceCursor(
        companyId: companyId,
        updatedAt: maxUpdatedAt,
        id: lastId,
        wasFullSync: false,
      );
    });
  }
}
