import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/user_api_model.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/users_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';

final _log = Logger('UserRepository');

/// Outbox `entity_type` value for the user-record PUT flow. `EntityRegistry`
/// routes rows with this wire name to the user dispatcher.
const String kUserWireName = 'user';

/// Source of truth for the User entity. Powers both:
///  * Auth user flow — single-row reads via [watch], idempotent settings
///    save via [enqueueUpdate] (whole-row collapse across rapid Save taps).
///  * User Management list — page-by-page reads via [watchPage] +
///    [ensurePageLoaded]; CRUD via [create] / [save] / [archive] /
///    [restore] / [delete] / [purge]; non-CRUD actions via [resendEmail]
///    and [detachFromCompany].
class UserRepository extends BaseEntityRepository<User, UserApi> {
  UserRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.user,
         // The user lifecycle ops (create/update/delete/archive/restore/purge)
         // and detach all hit `password_protected` server routes — `POST
         // /users` / `PUT /users/{id}` / `POST /users/bulk` / `POST
         // /users/{id}/purge` / `DELETE /users/{id}/detach_from_company`. Each
         // outbox row must carry `requiresPassword=true` so the drain attaches
         // `X-API-PASSWORD-BASE64` (else the server 412s). archive/restore go
         // through `/users/bulk`, which is gated too — hence included here.
         // inviteUser hits `POST /users/{id}/invite`, also password_protected,
         // so it carries the header too (else a permanent 412 retry loop).
         requiresPasswordFor: const {
           MutationKind.create,
           MutationKind.update,
           MutationKind.delete,
           MutationKind.archive,
           MutationKind.restore,
           MutationKind.purge,
           MutationKind.detachFromCompany,
           MutationKind.inviteUser,
         },
       );

  final UsersApi api;
  final int pageSize;

  @override
  String get entityTypeName => kUserWireName;

  // ── Auth-user-specific reads ────────────────────────────────────────
  // The inherited `watch({companyId, id})` from BaseEntityRepository
  // serves both flows — it watches a single row via the DAO's
  // `watchByCompanyAndId` (wired through `watchByRealId` below).

  /// Stream the users eligible to send mail through the given OAuth provider.
  /// Used by Settings → Email Settings's Gmail / Microsoft picker.
  Stream<List<User>> watchEmailSendingUsers({
    required String companyId,
    required String provider,
  }) {
    final lower = provider.toLowerCase();
    return db.userDao.watchAllForCompany(companyId: companyId).map((rows) {
      return rows
          .map(_fromRow)
          .whereType<User>()
          .where(
            (u) =>
                u.oauthProviderId.toLowerCase() == lower &&
                u.oauthUserToken.isNotEmpty,
          )
          .toList(growable: false);
    });
  }

  /// All users in the company, for the assignee filter picker. Small,
  /// local-only watch (users arrive via `/refresh`) — never paginated.
  Stream<List<User>> watchAllForPicker({required String companyId}) {
    return db.userDao
        .watchAllForCompany(companyId: companyId)
        .map(
          (rows) =>
              rows.map(_fromRow).whereType<User>().toList(growable: false),
        );
  }

  Future<User?> get({required String companyId, required String userId}) async {
    final row = await db.userDao.getByCompanyAndId(
      companyId: companyId,
      id: userId,
    );
    return _fromRow(row);
  }

  /// Persist the user record returned by the server. Public so the sync
  /// dispatcher can apply update responses without reaching into Drift.
  Future<void> applyApiResponse({
    required String companyId,
    required UserApi api,
  }) => _upsertFromApi(companyId: companyId, api: api, isDirty: false);

  /// Seed the local `users` table from the `/login` or `/refresh` envelope's
  /// bundled `data[N].company.users` roster — every user in the company — so
  /// assigned-user ids resolve to display names everywhere without a per-id
  /// `GET /users/{id}` (that endpoint is 412 password-gated).
  ///
  /// Plain upsert-preserving-dirty: a row with a pending local profile edit
  /// (`is_dirty = true`) keeps its outbox-bound payload. Deliberately does NOT
  /// advance the keyset cursor — the User Management list owns its own
  /// paginated `GET /users` sync (server-side owner/auth filtering), and the
  /// embedded roster may be partial for large teams, so it must not
  /// short-circuit that fetch.
  Future<void> applyBundle({
    required String companyId,
    required List<UserApi> bundle,
  }) async {
    final byId = <String, UsersCompanion>{};
    for (final a in bundle) {
      if (a.id.isEmpty) continue;
      byId[a.id] = _apiToCompanion(a, companyId, isDirty: false);
    }
    if (byId.isEmpty) return;
    await db.userDao.upsertAllPreservingDirty(companyId: companyId, byId: byId);
  }

  // ── Auth-user-specific PUT (collapse pending rows per (company, user)) ──

  /// Enqueue an outbox row that PUTs the auth user's own profile.
  /// Collapses pending updates for the same `(companyId, userId)` so a user
  /// spamming Save doesn't pile up duplicate requests.
  Future<void> enqueueUpdate({
    required String companyId,
    required User draft,
    required Map<String, dynamic> body,
    bool requiresPassword = false,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await db.userDao.upsert(
        _domainToCompanion(draft, companyId, isDirty: true),
      );
      final existing = await db.outboxDao.findPendingByEntityId(
        companyId: companyId,
        entityType: entityTypeName,
        entityId: draft.id,
      );
      if (existing != null) {
        await db.outboxDao.updatePayload(
          id: existing.id,
          payload: jsonEncode(body),
        );
      } else {
        await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: companyId,
            entityType: entityTypeName,
            entityId: draft.id,
            mutationKind: MutationKind.update.wireName,
            payload: jsonEncode(body),
            idempotencyKey: uuid.v4(),
            nextAttemptAt: nowMs,
            createdAt: nowMs,
            requiresPassword: Value(requiresPassword),
          ),
        );
      }
    });
    onEnqueued?.call(companyId);
  }

  // ── Management-list reads ───────────────────────────────────────────

  /// Watch the first [loadedPages] pages of company users for the
  /// management list. Excludes the owner and (optionally) the
  /// currently-logged-in user — mirrors React's
  /// `?hideOwnerUsers=true&without=<authId>` filter.
  Stream<List<User>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = 'first_name',
    bool sortAscending = true,
    String? excludeAuthUserId,
  }) {
    assert(loadedPages >= 1);
    return db.userDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          excludeOwner: true,
          excludeIds: excludeAuthUserId == null
              ? const {}
              : <String>{excludeAuthUserId},
        )
        .map(
          (rows) =>
              rows.map(_fromRow).whereType<User>().toList(growable: false),
        );
  }

  /// Live count of non-deleted company users (excluding owner + auth user)
  /// for the sidebar badge / empty-state hint.
  Stream<int> watchCount({required String companyId}) =>
      db.userDao.watchCount(companyId: companyId);

  @override
  Stream<User?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.userDao
      .watchByCompanyAndId(companyId: companyId, id: id)
      .map(_fromRow);

  /// Fetch one page of `/api/v1/users` and upsert into Drift.
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    String? authUserId,
    Set<EntityState> states = const {EntityState.active},
    bool ignoreCursor = false,
  }) {
    return ensurePageLoadedTemplate(
      companyId: companyId,
      page: page,
      pageSize: pageSize,
      search: search,
      states: states,
      ignoreCursor: ignoreCursor,
      staticFilters: <String, String>{
        'include': 'company_user',
        'hideOwnerUsers': 'true',
        if (authUserId != null && authUserId.isNotEmpty) 'without': authUserId,
      },
      listCall: api.list,
      itemsOf: (l) => l.data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId, isDirty: false),
      upsert: (byId) =>
          db.userDao.upsertAllPreservingDirty(companyId: companyId, byId: byId),
    );
  }

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
    while (hasMore) {
      hasMore = await ensurePageLoaded(
        companyId: companyId,
        page: page,
        ignoreCursor: full && page == 1,
        states: EntityState.values.toSet(),
      );
      page++;
      if (page > maxPages) {
        _log.warning(
          'refreshAll hit the $maxPages page safety cap for company $companyId',
        );
        break;
      }
    }
  }

  // ── Mutations ───────────────────────────────────────────────────────

  /// Create a new user offline. Server allocates the real id on the next
  /// online drain; the local row carries `tmp_<uuid>` until then.
  Future<SaveResult<User>> create({
    required String companyId,
    required User draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId, isDirty: true);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.userDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
        payload: _toApiJson(stored),
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  /// Save an existing user (admin "edit other user" flow).
  Future<SaveResult<User>> save({
    required String companyId,
    required User user,
  }) async {
    final stored = user.copyWith(isDirty: true);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.userDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: stored.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: stored.id,
        kind: MutationKind.update,
        payload: _toApiJson(stored),
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  /// `POST /api/v1/users/{id}/invite` — resend the invitation email.
  Future<void> resendEmail({
    required String companyId,
    required String userId,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: userId,
    kind: MutationKind.inviteUser,
    payload: {'id': userId},
  );

  /// `DELETE /api/v1/users/{id}/detach_from_company` — remove the user
  /// from this company. Password-gated.
  Future<void> detachFromCompany({
    required String companyId,
    required String userId,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: userId,
    kind: MutationKind.detachFromCompany,
    payload: {'id': userId},
  );

  // ── Sync engine entry points ────────────────────────────────────────

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.userDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.userDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required UserApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId, isDirty: false),
    upsert: db.userDao.upsert,
    deleteById: (id) => db.userDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required UserApi serverResponse,
  }) async {
    var response = serverResponse;
    // A `/users/bulk` archive/restore echo can omit `company_user` (it's an
    // opt-in include). Don't let that blank the permissions / is_admin
    // columns — carry the last-known company_user forward. `existing.toApi()`
    // reconstructs the full block (permissions + flags + notifications +
    // settings), so the payload's notifications/settings survive too.
    if (response.companyUser == null) {
      final existing = await get(
        companyId: companyId,
        userId: serverResponse.id,
      );
      if (existing != null) {
        response = response.copyWith(companyUser: existing.toApi().companyUser);
      }
    }
    await db.userDao.upsert(
      _apiToCompanion(response, companyId, isDirty: false),
    );
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.userDao
        .watchByCompanyAndId(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.userDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  @override
  Future<void> applyPurgeResponse({
    required String companyId,
    required String id,
  }) async {
    await db.userDao.deleteById(companyId: companyId, id: id);
  }

  /// Sync-engine callback after a successful `detach_from_company` round-trip.
  /// The user record still exists server-side but is no longer linked to
  /// this company — drop the local row so the management list stops
  /// surfacing it.
  Future<void> applyDetachResponse({
    required String companyId,
    required String id,
  }) async {
    await db.userDao.deleteById(companyId: companyId, id: id);
  }

  // Lifecycle filtering uses the shared `BaseEntityRepository.stateQueryParams`
  // (emits the `status` param) — the previous override was identical.

  // ── Conversions ─────────────────────────────────────────────────────

  Future<void> _upsertFromApi({
    required String companyId,
    required UserApi api,
    required bool isDirty,
  }) async {
    await db.userDao.upsert(_apiToCompanion(api, companyId, isDirty: isDirty));
  }

  UsersCompanion _apiToCompanion(
    UserApi a,
    String companyId, {
    required bool isDirty,
  }) {
    final cu = a.companyUser ?? const CompanyUserApi();
    return UsersCompanion.insert(
      id: a.id,
      companyId: companyId,
      firstName: a.firstName,
      lastName: a.lastName,
      email: a.email,
      phone: a.phone,
      languageId: a.languageId,
      signature: a.signature,
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      // Use Value(null) (not Value.absent()) so a restore (server returns
      // archived_at: 0) actually clears the column — otherwise the list's
      // archived filter keeps the row visible after restore.
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      customValue1: Value(a.customValue1),
      customValue2: Value(a.customValue2),
      customValue3: Value(a.customValue3),
      customValue4: Value(a.customValue4),
      permissions: Value(cu.permissions),
      isOwner: Value(cu.isOwner),
      isAdmin: Value(cu.isAdmin),
      isLocked: Value(cu.isLocked),
      isDirty: Value(isDirty),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(a.toJson()),
    );
  }

  UsersCompanion _domainToCompanion(
    User u,
    String companyId, {
    required bool isDirty,
  }) {
    return _apiToCompanion(u.toApi(), companyId, isDirty: isDirty);
  }

  Map<String, dynamic> _toApiJson(User u) => u.toApi().toJson();

  User? _fromRow(UserRow? row) {
    if (row == null) return null;
    UserApi apiUser;
    try {
      final decoded = jsonDecode(row.payload);
      if (decoded is Map<String, dynamic>) {
        apiUser = UserApi.fromJson(decoded);
      } else {
        apiUser = const UserApi();
      }
    } catch (_) {
      apiUser = const UserApi();
    }
    // Overlay the indexed columns onto the typed view so a local edit
    // lands in the UI before the next server round-trip writes the
    // payload back. Permissions / is_admin / is_owner / is_locked also
    // come from the indexed columns so list filters reflect the row
    // state without re-parsing the JSON.
    final cuFromPayload = apiUser.companyUser ?? const CompanyUserApi();
    final overlaid = apiUser.copyWith(
      id: row.id,
      firstName: row.firstName,
      lastName: row.lastName,
      email: row.email,
      phone: row.phone,
      languageId: row.languageId,
      signature: row.signature,
      customValue1: row.customValue1,
      customValue2: row.customValue2,
      customValue3: row.customValue3,
      customValue4: row.customValue4,
      createdAt: row.createdAt,
      archivedAt: row.archivedAt ?? 0,
      isDeleted: row.isDeleted,
      companyUser: cuFromPayload.copyWith(
        permissions: row.permissions,
        isOwner: row.isOwner,
        isAdmin: row.isAdmin,
        isLocked: row.isLocked,
      ),
    );
    // is_dirty is local-only — layer it onto the domain model from the
    // Drift row. Without this, an unsaved edit shows up as clean after
    // app restart.
    return User.fromApi(overlaid).copyWith(isDirty: row.isDirty);
  }
}
