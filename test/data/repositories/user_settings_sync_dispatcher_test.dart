import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/repositories/user_settings_sync_dispatcher.dart';
import 'package:admin/data/services/user_settings_api.dart';
import 'package:admin/domain/sync/mutation.dart';

/// First coverage for `UserSettingsSyncDispatcher` — the third of the three
/// dispatchers that bypass `BaseEntitySyncDispatcher`. It drains every
/// list-column preference change (`PUT /company_users/{userId}`).
///
/// The load-bearing case is the **userId fallback**: the server's response
/// doesn't always echo a `user` block, and `user_id` is a non-null column, so
/// without falling back to the locally persisted id the upsert throws
/// `InvalidDataException` and parks the drain. That's a documented past fix
/// with no test until now.
class _RecordingUserSettingsApi implements UserSettingsApi {
  _RecordingUserSettingsApi([this.response]);

  final Map<String, dynamic>? response;
  final List<({String userId, Map<String, dynamic> body, String key})> calls =
      [];

  @override
  Future<Map<String, dynamic>?> update({
    required String userId,
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    calls.add((userId: userId, body: body, key: idempotencyKey));
    return response;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  OutboxRow row({String payload = '{"a":1}'}) => OutboxRow(
    id: 1,
    companyId: 'co',
    entityType: 'user_settings',
    entityId: 'u1',
    mutationKind: MutationKind.update.wireName,
    payload: payload,
    idempotencyKey: 'idk',
    state: 'pending',
    attempts: 0,
    nextAttemptAt: 0,
    createdAt: 0,
    requiresPassword: false,
  );

  Future<_RecordingUserSettingsApi> dispatch({
    Map<String, dynamic>? response,
    String payload = '{"a":1}',
  }) async {
    final api = _RecordingUserSettingsApi(response);
    final dispatcher = UserSettingsSyncDispatcher(
      api: api,
      repo: UserSettingsRepository(db: db),
    );
    await dispatcher.dispatch(
      row: row(payload: payload),
      kind: MutationKind.update,
    );
    return api;
  }

  /// Seeds a DISTINCTIVE payload on purpose. The "writes nothing" tests below
  /// are guarding against the dispatcher clobbering cached settings with an
  /// empty blob — if the seed were `{}` they would pass whether the row was
  /// left alone or overwritten with empty.
  Future<void> seedLocalRow({String userId = 'u1'}) =>
      db.userSettingsDao.upsert(
        UserSettingsCompanion(
          companyId: const Value('co'),
          userId: Value(userId),
          tableColumnsJson: const Value('{"client":["seeded"]}'),
          extraJson: const Value('{"seed":"kept"}'),
          updatedAt: const Value(1),
        ),
      );

  test(
    'PUTs the row payload to the row entity id with its idempotency key',
    () async {
      final api = await dispatch(payload: '{"settings":{"x":1}}');

      expect(api.calls, hasLength(1));
      expect(api.calls.single.userId, 'u1');
      expect(api.calls.single.body, {
        'settings': {'x': 1},
      });
      expect(api.calls.single.key, 'idk');
    },
  );

  test('applies the server response into the local cache', () async {
    await dispatch(
      response: {
        'data': {
          'user': {'id': 'u9'},
          'settings': {
            'table_columns': {
              'client': ['name'],
            },
            'other': 'kept',
          },
        },
      },
    );

    final saved = await db.userSettingsDao.get('co');
    expect(saved, isNotNull);
    expect(saved!.userId, 'u9');
    expect(jsonDecode(saved.tableColumnsJson), {
      'client': ['name'],
    });
    expect(
      jsonDecode(saved.extraJson),
      {'other': 'kept'},
      reason: 'table_columns is split out of the extra blob',
    );
  });

  test('a response with no user block falls back to the locally stored userId '
      'instead of parking the drain', () async {
    await seedLocalRow(userId: 'u1');

    await dispatch(
      response: {
        'data': {
          'settings': {
            'table_columns': {
              'invoice': ['number'],
            },
          },
        },
      },
    );

    final saved = await db.userSettingsDao.get('co');
    expect(saved!.userId, 'u1');
    expect(jsonDecode(saved.tableColumnsJson), {
      'invoice': ['number'],
    });
  });

  test('no user block and no local row → skipped without throwing', () async {
    await dispatch(
      response: {
        'data': {
          'settings': {'table_columns': <String, dynamic>{}},
        },
      },
    );

    expect(await db.userSettingsDao.get('co'), isNull);
  });

  group('responses that carry nothing to apply are ignored', () {
    test('a null response writes nothing', () async {
      await seedLocalRow();
      await dispatch();

      expect(
        jsonDecode((await db.userSettingsDao.get('co'))!.extraJson),
        {'seed': 'kept'},
        reason: 'the cached settings must survive untouched',
      );
    });

    test('a response with no data block writes nothing', () async {
      await seedLocalRow();
      await dispatch(response: {'meta': 'only'});

      expect(
        jsonDecode((await db.userSettingsDao.get('co'))!.extraJson),
        {'seed': 'kept'},
        reason: 'the cached settings must survive untouched',
      );
    });

    test('a response whose settings is not an object writes nothing', () async {
      await seedLocalRow();
      await dispatch(
        response: {
          'data': {'settings': 'nonsense'},
        },
      );

      expect(
        jsonDecode((await db.userSettingsDao.get('co'))!.extraJson),
        {'seed': 'kept'},
        reason: 'the cached settings must survive untouched',
      );
    });
  });

  test(
    'discard hooks are inert — user_settings has no offline create',
    () async {
      await seedLocalRow();
      final dispatcher = UserSettingsSyncDispatcher(
        api: _RecordingUserSettingsApi(),
        repo: UserSettingsRepository(db: db),
      );

      await dispatcher.deleteLocalRecord(companyId: 'co', id: 'u1');
      await dispatcher.clearLocalDirty(companyId: 'co', id: 'u1');

      expect(await db.userSettingsDao.get('co'), isNotNull);
    },
  );
}
