import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/user_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/users_api.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';

/// Drains outbox rows whose `entity_type` is `kUserWireName` (`'user'`).
///
/// Routes by [MutationKind]:
///   * [MutationKind.create] → `POST /api/v1/users`
///   * [MutationKind.update] → `PUT /api/v1/users/{id}` (with body `_action`
///     escape hatch for `connect_oauth` / `disconnect_oauth` /
///     `disconnect_mailer`)
///   * [MutationKind.delete] / [MutationKind.archive] / [MutationKind.restore]
///     → `POST /api/v1/users/bulk` with `{action, ids:[id]}` (password-gated).
///     Users expose **no** per-id `/archive` / `/restore` route and **no**
///     RESTful `DELETE /users/{id}` — the lifecycle ops only exist on `/bulk`
///     (see `UserController::bulk`). Per-id POSTs 404 and park as bogus
///     conflicts, so these must use [BaseEntityApi.bulkActionOne].
///   * [MutationKind.purge] → `POST /api/v1/users/{id}/purge` (hard)
///   * [MutationKind.inviteUser] → `POST /api/v1/users/{id}/invite`
///   * [MutationKind.detachFromCompany] →
///     `DELETE /api/v1/users/{id}/detach_from_company`
///
/// On success, [UserRepository.applyApiResponse] persists the canonical
/// envelope and [AuthRepository.applyUserUpdate] propagates name/email/phone
/// to the topbar / company picker for the auth user (no-op for any other
/// user — the picker only renders the auth user's profile).
class UserSyncDispatcher implements SyncDispatcher {
  UserSyncDispatcher({
    required this.api,
    required this.repo,
    required this.auth,
  });

  final UsersApi api;
  final UserRepository repo;
  final AuthRepository auth;

  // Reached by (a) a discarded ghost create — UserRepository.create mints
  // tmp_ ids, so the offline-create flow is real — and (b) the 404-conflict
  // "deleted on the server" discard, where the orphaned local row must go.
  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) => repo.deleteLocalById(companyId: companyId, id: id);

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) => repo.clearLocalDirty(companyId: companyId, id: id);

  @override
  Future<void> dispatch({
    required OutboxRow row,
    required MutationKind kind,
  }) async {
    final body = row.payload.isEmpty
        ? const <String, dynamic>{}
        : jsonDecode(row.payload) as Map<String, dynamic>;

    switch (kind) {
      case MutationKind.update:
        final action = body['_action'] as String?;
        final UserApi response;
        switch (action) {
          case 'connect_oauth':
            response = await api.connectOauth(
              provider: body['provider'] as String? ?? '',
              accessToken: body['access_token'] as String? ?? '',
              idempotencyKey: row.idempotencyKey,
              requiresPassword: row.requiresPassword,
            );
          case 'disconnect_oauth':
            response = await api.disconnectOauth(
              id: row.entityId,
              idempotencyKey: row.idempotencyKey,
              requiresPassword: row.requiresPassword,
            );
          case 'disconnect_mailer':
            response = await api.disconnectMailer(
              id: row.entityId,
              idempotencyKey: row.idempotencyKey,
              requiresPassword: row.requiresPassword,
            );
          default:
            response = await api.updateAuthUser(
              id: row.entityId,
              body: body,
              idempotencyKey: row.idempotencyKey,
              requiresPassword: row.requiresPassword,
            );
        }
        await repo.applyApiResponse(companyId: row.companyId, api: response);
        auth.applyUserUpdate(response);

      case MutationKind.create:
        // `?include=company_user` so the echoed user carries its permissions /
        // is_admin block — `company_user` is an opt-in include server-side, and
        // applyCreateResponse (no carry-forward, unlike applyUpdateResponse)
        // would otherwise blank those columns until the next refresh.
        final item = await api.create(
          payload: body,
          idempotencyKey: row.idempotencyKey,
          query: const {'include': 'company_user'},
          requiresPassword: row.requiresPassword,
        );
        await repo.applyCreateResponse(
          companyId: row.companyId,
          tempId: row.entityId,
          serverResponse: item.data,
        );

      case MutationKind.delete:
        // Users have no RESTful `DELETE /users/{id}` — the delete lifecycle op
        // lives only on `POST /users/bulk` (password-gated). Route through
        // bulkActionOne; the server echoes the soft-deleted user but we only
        // need to mark the local row deleted.
        try {
          await api.bulkActionOne(
            id: row.entityId,
            action: 'delete',
            idempotencyKey: row.idempotencyKey,
            requiresPassword: row.requiresPassword,
          );
        } on NotFoundException {
          // Already gone server-side — idempotent success (see the generic
          // BaseEntitySyncDispatcher for the rationale).
        }
        await repo.applyDeleteResponse(
          companyId: row.companyId,
          id: row.entityId,
        );

      case MutationKind.archive:
        // `?include=company_user` so the echoed user keeps its permissions /
        // is_admin block — `company_user` is an opt-in include server-side,
        // and applyUpdateResponse would otherwise blank those columns.
        final item = await api.bulkActionOne(
          id: row.entityId,
          action: 'archive',
          idempotencyKey: row.idempotencyKey,
          query: const {'include': 'company_user'},
          requiresPassword: row.requiresPassword,
        );
        if (item != null) {
          await repo.applyUpdateResponse(
            companyId: row.companyId,
            serverResponse: item.data,
          );
        } else {
          // The bulk action drained successfully but returned no entity — the
          // server's re-query found zero rows for the id (purged from another
          // device). `UserController::bulk` answers HTTP 200 `{"data":[]}` in
          // that case, so this row counts as a success and disappears from the
          // outbox. The optimistic flip left the local row `is_dirty=true`, and
          // without this it stays dirty forever: every `/refresh` skips it
          // (`auth_repository` `if (existingUser?.isDirty == true) continue;`)
          // and so does every `GET /users` page, leaving a user shown as
          // Archived that no longer exists. The generic
          // `BaseEntitySyncDispatcher` has had this branch all along; this
          // hand-rolled dispatcher did not.
          await repo.clearLocalDirty(
            companyId: row.companyId,
            id: row.entityId,
          );
        }

      case MutationKind.restore:
        final item = await api.bulkActionOne(
          id: row.entityId,
          action: 'restore',
          idempotencyKey: row.idempotencyKey,
          query: const {'include': 'company_user'},
          requiresPassword: row.requiresPassword,
        );
        if (item != null) {
          await repo.applyUpdateResponse(
            companyId: row.companyId,
            serverResponse: item.data,
          );
        } else {
          // The bulk action drained successfully but returned no entity — the
          // server's re-query found zero rows for the id (purged from another
          // device). `UserController::bulk` answers HTTP 200 `{"data":[]}` in
          // that case, so this row counts as a success and disappears from the
          // outbox. The optimistic flip left the local row `is_dirty=true`, and
          // without this it stays dirty forever: every `/refresh` skips it
          // (`auth_repository` `if (existingUser?.isDirty == true) continue;`)
          // and so does every `GET /users` page, leaving a user shown as
          // still Archived when the restore never landed. The generic
          // `BaseEntitySyncDispatcher` has had this branch all along; this
          // hand-rolled dispatcher did not.
          await repo.clearLocalDirty(
            companyId: row.companyId,
            id: row.entityId,
          );
        }

      case MutationKind.purge:
        try {
          await api.action(
            id: row.entityId,
            action: 'purge',
            idempotencyKey: row.idempotencyKey,
            requiresPassword: row.requiresPassword,
          );
        } on NotFoundException {
          // Already gone server-side — idempotent success (see the generic
          // BaseEntitySyncDispatcher for the rationale).
        }
        await repo.applyPurgeResponse(
          companyId: row.companyId,
          id: row.entityId,
        );

      case MutationKind.inviteUser:
        // `/users/{id}/invite` is password_protected — forward the flag so the
        // header is attached (the outbox row carries requiresPassword=true).
        await api.resendEmail(
          id: row.entityId,
          idempotencyKey: row.idempotencyKey,
          requiresPassword: row.requiresPassword,
        );

      case MutationKind.detachFromCompany:
        await api.detachFromCompany(
          id: row.entityId,
          idempotencyKey: row.idempotencyKey,
          requiresPassword: row.requiresPassword,
        );
        await repo.applyDetachResponse(
          companyId: row.companyId,
          id: row.entityId,
        );

      // Kinds that don't apply to users — reaching here is a wiring bug.
      // ignore: no_default_cases
      default:
        throw StateError(
          'UserSyncDispatcher received unsupported kind ${kind.wireName}',
        );
    }
  }
}

/// Composite dispatcher under `EntityType.user`. Routes outbox rows by their
/// `entity_type` wire name to the right sub-dispatcher:
///   * `'user_settings'` → the per-(user, company) settings PUT to
///     `/company_users/{id}` (existing flow, [userSettings]).
///   * `'user'` → the full-user PUT / disconnect / management flows on
///     `/users/{id}` (existing + new flow, [user]).
class CompositeUserDispatcher implements SyncDispatcher {
  CompositeUserDispatcher({required this.userSettings, required this.user});

  final SyncDispatcher userSettings;
  final SyncDispatcher user;

  // The wire name isn't known here, so fan out to both. The user_settings
  // child is a keyed-by-company no-op for arbitrary user ids; the user child
  // hard-deletes the local users row (ghost-create discard + 404-conflict
  // "deleted on the server" cleanup).
  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) async {
    await userSettings.deleteLocalRecord(companyId: companyId, id: id);
    await user.deleteLocalRecord(companyId: companyId, id: id);
  }

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async {
    await userSettings.clearLocalDirty(companyId: companyId, id: id);
    await user.clearLocalDirty(companyId: companyId, id: id);
  }

  @override
  Future<void> dispatch({required OutboxRow row, required MutationKind kind}) {
    switch (row.entityType) {
      case kUserSettingsWireName:
        return userSettings.dispatch(row: row, kind: kind);
      case kUserWireName:
        return user.dispatch(row: row, kind: kind);
      default:
        throw StateError(
          'CompositeUserDispatcher: unknown wire name "${row.entityType}"',
        );
    }
  }
}
