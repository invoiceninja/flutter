import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/token_dao.dart';
import 'package:admin/data/models/api/token_api_model.dart';
import 'package:admin/data/models/domain/token.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/tokens_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';

final _log = Logger('TokenRepository');

/// One-shot delivery of a freshly-minted token secret. The repository emits
/// this on [TokenRepository.newSecrets] as soon as [applyCreateResponse]
/// runs for a create that originated from this client (matched by
/// [tempId]). The create screen subscribes once and dismisses on receipt.
class FreshTokenSecret {
  const FreshTokenSecret({required this.tempId, required this.secret});
  final String tempId;
  final String secret;
}

/// Source of truth for API tokens. Bundled on `/refresh?first_load=true`
/// via `tokens_hashed` (server returns masked values there), and also
/// fetched page-by-page via `/api/v1/tokens` when needed.
///
/// On create, the server returns the **raw bearer secret** exactly once;
/// `applyCreateResponse` broadcasts it through [newSecrets] so the
/// create screen can surface a one-time copy dialog. Drift persists only
/// the masked form (see `Token.toApiJson` — `token` is stripped from
/// every outgoing payload).
class TokenRepository extends BaseEntityRepository<Token, TokenApi> {
  TokenRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.token,
         // Server applies `password_protected` to token store/update/destroy
         // (TokenController), so create + update are password-gated up-front,
         // not just delete/purge.
         requiresPasswordFor: const {
           MutationKind.create,
           MutationKind.update,
           MutationKind.delete,
           MutationKind.purge,
         },
       );

  final TokensApi api;
  final int pageSize;

  final _secretsController = StreamController<FreshTokenSecret>.broadcast();

  /// Secrets emitted but not yet shown to the user. The broadcast stream alone
  /// drops a secret minted before any listener subscribed (app cold start) or
  /// while the only listener was between screens; this buffer lets the
  /// always-mounted shell listener drain anything outstanding on (re)mount.
  /// The server never re-returns a raw secret, so losing one is unrecoverable
  /// — hence the buffer. Drained via [takePendingSecrets].
  final List<FreshTokenSecret> _pendingSecrets = <FreshTokenSecret>[];

  /// Fires once per successful create with the **raw** server-minted secret.
  /// Subsequent updates / lists never re-emit — the masked form lives in
  /// Drift and is what the list / detail screens read. A live signal only;
  /// [_pendingSecrets] is the durable source of truth (see [takePendingSecrets]).
  Stream<FreshTokenSecret> get newSecrets => _secretsController.stream;

  /// Return and clear every buffered secret not yet shown. Called by the
  /// single app-wide shell listener on mount and after each broadcast event;
  /// safe because there is exactly one consumer.
  List<FreshTokenSecret> takePendingSecrets() {
    if (_pendingSecrets.isEmpty) return const <FreshTokenSecret>[];
    final out = List<FreshTokenSecret>.of(_pendingSecrets);
    _pendingSecrets.clear();
    return out;
  }

  @override
  String get entityTypeName => 'token';

  Stream<List<Token>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TokenFieldIds.name,
    bool sortAscending = true,
  }) {
    assert(loadedPages >= 1);
    return db.tokenDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<int> watchCount({required String companyId}) =>
      db.tokenDao.watchActiveCount(companyId: companyId);

  @override
  Stream<Token?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.tokenDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Drain the `tokens_hashed` array carried by `/login` and
  /// `/refresh?first_load=true` into the local `tokens` table.
  /// Upserts only — never deletes.
  Future<void> applyBundle({
    required String companyId,
    required List<TokenApi> bundle,
    bool fullSync = true,
  }) => applyBundleUpsertOnly(
    companyId: companyId,
    bundle: bundle,
    wasFullSync: fullSync,
    idOf: (a) => a.id,
    updatedAtOf: (a) => a.updatedAt,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) =>
        db.tokenDao.upsertAllPreservingDirty(companyId: companyId, byId: byId),
  );

  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) => ensurePageLoadedTemplate(
    companyId: companyId,
    page: page,
    pageSize: pageSize,
    search: search,
    states: states,
    extraFilters: extraFilters,
    ignoreCursor: ignoreCursor,
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) =>
        db.tokenDao.upsertAllPreservingDirty(companyId: companyId, byId: byId),
  );

  Future<void> refreshAll({
    required String companyId,
    bool full = false,
  }) async {
    if (full) {
      await db.syncStateDao.reset(
        companyId: companyId,
        entityType: entityTypeName,
      );
    }
    var page = 1;
    var hasMore = true;
    const maxPages = 100;
    final allStates = EntityState.values.toSet();
    while (hasMore) {
      hasMore = await ensurePageLoaded(
        companyId: companyId,
        page: page,
        states: allStates,
        ignoreCursor: full && page == 1,
      );
      page++;
      if (page > maxPages) {
        _log.warning(
          'refreshAll hit the $maxPages page safety cap for company '
          '$companyId — cursor will resume on the next sync trigger.',
        );
        break;
      }
    }
  }

  Future<SaveResult<Token>> create({
    required String companyId,
    required Token draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.tokenDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
        payload: stored.toApiJson(),
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  Future<SaveResult<Token>> save({
    required String companyId,
    required Token token,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(token.id);
    if (resolvedId != token.id) token = token.copyWith(id: resolvedId);

    final companion = _domainToCompanion(token, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.tokenDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: token.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: token.id,
        kind: MutationKind.update,
        payload: token.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: token, outboxRowId: rowId);
  }

  /// This DAO doesn't extend `BaseEntityDao`, so the base's `localDao` hook is
  /// null and the discard-reconciliation clear would be a no-op. Combined with
  /// `upsertAllPreservingDirty` on every refresh path, that pinned a discarded
  /// edit permanently — see [tokenDao.clearDirtyById].
  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => db.tokenDao.clearDirtyById(companyId: companyId, id: id);

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.tokenDao.deleteById(companyId: companyId, id: id);

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required TokenApi serverResponse,
  }) async {
    // Capture the raw secret BEFORE upserting (the companion stores the
    // masked value the server gave us). On a real create response the
    // server returns the unmasked token exactly once — broadcast it so
    // the create screen can dismiss its "waiting for secret…" state.
    final domain = Token.fromApi(serverResponse);
    if (!domain.isMasked && domain.token.isNotEmpty) {
      final secret = FreshTokenSecret(tempId: tempId, secret: domain.token);
      // Buffer first so a listener that isn't subscribed yet (cold start, or
      // the create completed while the user was on another screen) still
      // surfaces it via takePendingSecrets(); the broadcast wakes a live one.
      _pendingSecrets.add(secret);
      _secretsController.add(secret);
    }
    await applyCreateResponseTemplate(
      companyId: companyId,
      tempId: tempId,
      realId: serverResponse.id,
      companion: _apiToCompanion(serverResponse, companyId),
      upsert: db.tokenDao.upsert,
      deleteById: (id) => db.tokenDao.deleteById(companyId: companyId, id: id),
    );
  }

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required TokenApi serverResponse,
  }) async {
    await db.tokenDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.tokenDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.tokenDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  Future<void> dispose() async {
    await _secretsController.close();
  }

  // -------------------- conversions --------------------

  TokensCompanion _apiToCompanion(TokenApi a, String companyId) {
    return TokensCompanion.insert(
      id: a.id,
      companyId: companyId,
      name: Value(a.name),
      userId: Value(a.userId),
      token: Value(a.token),
      isSystem: Value(a.isSystem),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(a.toJson()),
    );
  }

  TokensCompanion _domainToCompanion(
    Token t,
    String companyId, {
    required bool isDirty,
  }) {
    return TokensCompanion.insert(
      id: t.id,
      companyId: companyId,
      name: Value(t.name),
      userId: Value(t.userId),
      token: Value(t.token),
      isSystem: Value(t.isSystem),
      updatedAt: t.updatedAt.millisecondsSinceEpoch ~/ 1000,
      createdAt: Value(t.createdAt.millisecondsSinceEpoch ~/ 1000),
      archivedAt: t.archivedAt == null
          ? const Value.absent()
          : Value(t.archivedAt!.millisecondsSinceEpoch ~/ 1000),
      isDirty: Value(isDirty),
      isDeleted: Value(t.isDeleted),
      payload: jsonEncode(t.toApiJson(preserveTempId: true)),
    );
  }

  Token _fromRow(TokenRow row) {
    final apiJson = jsonDecode(row.payload) as Map<String, dynamic>;
    // Preserve the masked / raw `token` and `user_id` from the dedicated
    // columns — `toApiJson` strips them from `payload` so we'd otherwise
    // lose them on round-trip.
    apiJson['token'] = row.token;
    apiJson['user_id'] = row.userId;
    final api = TokenApi.fromJson(apiJson);
    return Token.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
    );
  }
}
