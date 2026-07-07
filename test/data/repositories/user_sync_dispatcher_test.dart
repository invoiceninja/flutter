import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/user_api_model.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/repositories/user_sync_dispatcher.dart';
import 'package:admin/data/services/users_api.dart';
import 'package:admin/domain/sync/mutation.dart';

/// Regression guard for the launch bug where user archive/restore/delete were
/// dispatched to per-id routes (`POST /users/{id}/archive`, `DELETE
/// /users/{id}`) that don't exist server-side. Users expose these lifecycle
/// ops ONLY via `POST /users/bulk` (password-gated). The recording fake throws
/// on any per-id `action()` / `delete()`, so a regression fails loudly.
///
/// Also guards two pre-launch fixes:
///   * `create` must send `?include=company_user` so the new user's permissions
///     / is_admin aren't blanked locally (the create response is opt-in).
///   * `inviteUser` must forward `requiresPassword` so the password-gated
///     `/users/{id}/invite` route doesn't 412-loop.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  OutboxRow rowFor(MutationKind kind) => OutboxRow(
    id: 1,
    companyId: 'co',
    entityType: 'user',
    entityId: 'u1',
    mutationKind: kind.wireName,
    payload: '{}',
    idempotencyKey: 'idk',
    state: 'pending',
    attempts: 0,
    nextAttemptAt: 0,
    createdAt: 0,
    requiresPassword: true,
  );

  Future<_RecordingUsersApi> dispatch(MutationKind kind) async {
    final api = _RecordingUsersApi();
    final repo = UserRepository(db: db, api: api);
    final dispatcher = UserSyncDispatcher(
      api: api,
      repo: repo,
      auth: _FakeAuth(),
    );
    await dispatcher.dispatch(row: rowFor(kind), kind: kind);
    return api;
  }

  test(
    'archive → POST /users/bulk with include=company_user + password',
    () async {
      final api = await dispatch(MutationKind.archive);
      expect(api.bulkCalls, hasLength(1));
      expect(api.bulkCalls.single.action, 'archive');
      expect(api.bulkCalls.single.id, 'u1');
      expect(api.bulkCalls.single.requiresPassword, isTrue);
      expect(api.bulkCalls.single.query, {'include': 'company_user'});
    },
  );

  test('restore → POST /users/bulk with password', () async {
    final api = await dispatch(MutationKind.restore);
    expect(api.bulkCalls.single.action, 'restore');
    expect(api.bulkCalls.single.requiresPassword, isTrue);
  });

  test(
    'delete → POST /users/bulk (no RESTful per-id DELETE for users)',
    () async {
      final api = await dispatch(MutationKind.delete);
      expect(api.bulkCalls.single.action, 'delete');
      expect(api.bulkCalls.single.requiresPassword, isTrue);
    },
  );

  test('create → POST /users with include=company_user + password, and the '
      'echoed company_user lands on the local row (not blanked)', () async {
    final api = _RecordingUsersApi();
    final repo = UserRepository(db: db, api: api);
    final dispatcher = UserSyncDispatcher(
      api: api,
      repo: repo,
      auth: _FakeAuth(),
    );
    await dispatcher.dispatch(
      row: rowFor(MutationKind.create),
      kind: MutationKind.create,
    );
    expect(api.createCalls, hasLength(1));
    expect(api.createCalls.single.query, {'include': 'company_user'});
    expect(api.createCalls.single.requiresPassword, isTrue);
    // The whole point of the include: the new user keeps its role locally.
    final user = await repo.get(companyId: 'co', userId: 'u1');
    expect(user, isNotNull);
    expect(user!.companyUser.isAdmin, isTrue);
    expect(user.companyUser.permissions, 'create_all');
  });

  test('inviteUser → POST /users/{id}/invite forwards the password', () async {
    final api = await dispatch(MutationKind.inviteUser);
    expect(api.inviteCalls, hasLength(1));
    expect(api.inviteCalls.single.id, 'u1');
    expect(api.inviteCalls.single.requiresPassword, isTrue);
  });

  test(
    'deleteLocalRecord removes the local users row — the ghost-create '
    'discard and the 404 "deleted on the server" cleanup both route here '
    '(a no-op left a phantom tmp_ user in User Management forever)',
    () async {
      final api = _RecordingUsersApi();
      final repo = UserRepository(db: db, api: api);
      final dispatcher = UserSyncDispatcher(
        api: api,
        repo: repo,
        auth: _FakeAuth(),
      );
      final created = await repo.create(
        companyId: 'co',
        draft: const User(firstName: 'Ghost'),
      );
      final id = created.entity.id;
      expect(await repo.get(companyId: 'co', userId: id), isNotNull);

      await dispatcher.deleteLocalRecord(companyId: 'co', id: id);

      expect(await repo.get(companyId: 'co', userId: id), isNull);
    },
  );
}

class _RecordingUsersApi implements UsersApi {
  final List<
    ({
      String action,
      String id,
      bool requiresPassword,
      Map<String, String>? query,
    })
  >
  bulkCalls = [];

  final List<({Map<String, String>? query, bool requiresPassword})>
  createCalls = [];
  final List<({String id, bool requiresPassword})> inviteCalls = [];

  @override
  Future<UserItemApi?> bulkActionOne({
    required String id,
    required String action,
    required String idempotencyKey,
    Map<String, dynamic>? extra,
    Map<String, String>? query,
    bool requiresPassword = false,
  }) async {
    bulkCalls.add((
      action: action,
      id: id,
      requiresPassword: requiresPassword,
      query: query,
    ));
    return UserItemApi(
      data: UserApi(
        id: id,
        firstName: 'X',
        email: 'x@example.com',
        updatedAt: 1700000000,
        companyUser: const CompanyUserApi(
          permissions: 'view_client',
          isAdmin: false,
        ),
      ),
    );
  }

  @override
  Future<UserItemApi> create({
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    bool requiresPassword = false,
    Map<String, String>? query,
  }) async {
    createCalls.add((query: query, requiresPassword: requiresPassword));
    // Mirror the server's opt-in transformer: `company_user` is echoed back
    // ONLY when `?include=company_user` is requested. This makes the persisted-
    // permissions assertion a real regression guard — drop the dispatcher's
    // `query:` and the new user lands with blank permissions, failing the test.
    final includeCompanyUser = query?['include'] == 'company_user';
    return UserItemApi(
      data: UserApi(
        id: 'u1',
        firstName: 'New',
        email: 'new@example.com',
        updatedAt: 1700000000,
        companyUser: includeCompanyUser
            ? const CompanyUserApi(permissions: 'create_all', isAdmin: true)
            : null,
      ),
    );
  }

  @override
  Future<void> resendEmail({
    required String id,
    required String idempotencyKey,
    bool requiresPassword = false,
  }) async {
    inviteCalls.add((id: id, requiresPassword: requiresPassword));
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Unexpected ${invocation.memberName} — user archive/restore/delete must '
    'route through bulkActionOne (POST /users/bulk), not per-id action()/'
    'delete().',
  );
}

class _FakeAuth implements AuthRepository {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
