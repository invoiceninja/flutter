import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/repositories/user_settings_sync_dispatcher.dart';
import 'package:admin/data/repositories/user_sync_dispatcher.dart';
import 'package:admin/data/services/user_settings_api.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';

/// `company_user.react_settings` — the blob the dashboard syncs through. The
/// server REPLACES it on a write and React owns most of it, so every test here
/// is about not wiping a key this app didn't set.
class _RecordingApi implements UserSettingsApi {
  final calls = <({String userId, Map<String, dynamic> body})>[];

  @override
  Future<void> updatePreferences({
    required String userId,
    required Map<String, dynamic> reactSettings,
    required String idempotencyKey,
  }) async => calls.add((userId: userId, body: reactSettings));

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late UserSettingsRepository repo;
  const companyId = 'co1';

  Future<void> seedRow({String? reactSettingsJson}) =>
      db.userSettingsDao.upsert(
        UserSettingsCompanion(
          companyId: const Value(companyId),
          userId: const Value('u1'),
          updatedAt: const Value(0),
          reactSettingsJson: Value(reactSettingsJson),
        ),
      );

  Future<List<OutboxRow>> rows() => db.select(db.outbox).get();

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = UserSettingsRepository(db: db);
  });
  tearDown(() async => db.close());

  test('a patch before the blob was captured writes nothing anywhere — it '
      'would send only our keys and wipe React\'s', () async {
    await seedRow();
    final changed = await repo.patchReactSettings(
      companyId: companyId,
      patch: {'dashboard_fields': <String>[]},
    );
    expect(changed, isFalse);
    expect(await repo.getReactSettings(companyId), isNull);
    expect(await rows(), isEmpty);
  });

  test('a patch sets dotted paths, keeps React\'s keys, and queues only the '
      'patch', () async {
    await seedRow(
      reactSettingsJson: jsonEncode({
        'show_pdf_preview': true,
        'preferences': {
          'dashboard_charts': {'range': 'last7'},
        },
      }),
    );
    await repo.patchReactSettings(
      companyId: companyId,
      patch: {'preferences.dashboard_charts.default_view': 'week'},
    );
    expect(await repo.getReactSettings(companyId), {
      'show_pdf_preview': true,
      'preferences': {
        'dashboard_charts': {'range': 'last7', 'default_view': 'week'},
      },
    });
    final queued = await rows();
    expect(queued, hasLength(1));
    expect(queued.single.entityType, kUserPreferencesWireName);
    expect(queued.single.entityId, 'u1');
    expect(reactSettingsPatchOf(queued.single.payload), {
      'preferences.dashboard_charts.default_view': 'week',
    });
  });

  test('an unchanged patch queues nothing; rapid patches collapse into one '
      'row carrying both', () async {
    await seedRow(
      reactSettingsJson: '{"dashboard_fields":["a|current|sum|money|0"]}',
    );
    expect(
      await repo.patchReactSettings(
        companyId: companyId,
        patch: {
          'dashboard_fields': ['a|current|sum|money|0'],
        },
      ),
      isFalse,
    );
    expect(await rows(), isEmpty);

    await repo.patchReactSettings(
      companyId: companyId,
      patch: {'dashboard_fields': <String>[]},
    );
    await repo.patchReactSettings(
      companyId: companyId,
      patch: {
        'flutter_dashboard': {'panels': <String>[]},
      },
    );
    final queued = await rows();
    expect(queued, hasLength(1));
    expect(reactSettingsPatchOf(queued.single.payload).keys, {
      'dashboard_fields',
      'flutter_dashboard',
    });
  });

  test('a /refresh capture lays a queued patch over the server blob, so the '
      'change does not revert and React\'s newer keys still land', () async {
    await seedRow(reactSettingsJson: '{}');
    await repo.patchReactSettings(
      companyId: companyId,
      patch: {
        'dashboard_fields': <String>['x|current|sum|money|0'],
      },
    );
    await applyServerReactSettings(
      db,
      companyId: companyId,
      server: {'show_pdf_preview': false, 'dashboard_fields': <String>[]},
      nowMs: 1,
    );
    expect(await repo.getReactSettings(companyId), {
      'show_pdf_preview': false,
      'dashboard_fields': ['x|current|sum|money|0'],
    });
  });

  test('a capture with nothing queued stores the server blob as is', () async {
    await seedRow();
    await applyServerReactSettings(
      db,
      companyId: companyId,
      server: {'show_pdf_preview': true},
      nowMs: 1,
    );
    expect(await repo.getReactSettings(companyId), {'show_pdf_preview': true});
  });

  test('the dispatcher sends the freshest local blob with the patch over it '
      'to the preferences route', () async {
    await seedRow(reactSettingsJson: '{}');
    await repo.patchReactSettings(
      companyId: companyId,
      patch: {
        'flutter_dashboard': {
          'chart_series': ['invoices'],
        },
      },
    );
    // React changed something since; a refresh brought it in.
    await applyServerReactSettings(
      db,
      companyId: companyId,
      server: {'dark_mode': true},
      nowMs: 2,
    );
    final api = _RecordingApi();
    final row = (await rows()).single;
    await UserSettingsSyncDispatcher(
      api: api,
      repo: repo,
    ).dispatch(row: row, kind: MutationKind.update);
    expect(api.calls.single.userId, 'u1');
    expect(api.calls.single.body, {
      'dark_mode': true,
      'flutter_dashboard': {
        'chart_series': ['invoices'],
      },
    });
  });

  test(
    'the dispatcher sends nothing when the blob is no longer known',
    () async {
      await seedRow(reactSettingsJson: '{}');
      await repo.patchReactSettings(
        companyId: companyId,
        patch: {'dashboard_fields': <String>[]},
      );
      final row = (await rows()).single;
      await db.userSettingsDao.deleteFor(companyId);
      final api = _RecordingApi();
      await UserSettingsSyncDispatcher(
        api: api,
        repo: repo,
      ).dispatch(row: row, kind: MutationKind.update);
      expect(api.calls, isEmpty);
    },
  );

  test('applyReactSettingsPatch: a null removes, a non-map on the way is '
      'replaced, and the base is not mutated', () {
    final base = <String, dynamic>{
      'a': 1,
      'preferences': 'oops',
      'keep': {'x': 1},
    };
    final out = applyReactSettingsPatch(base, {
      'a': null,
      'preferences.dashboard_charts.default_view': 'day',
    });
    expect(out, {
      'preferences': {
        'dashboard_charts': {'default_view': 'day'},
      },
      'keep': {'x': 1},
    });
    expect(base['a'], 1);
  });

  group('discarding a preferences row', () {
    Future<void> enqueueUserEdit({required String state}) async {
      await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: companyId,
          entityType: kUserWireName,
          entityId: 'u1',
          mutationKind: MutationKind.update.wireName,
          payload: '{}',
          idempotencyKey: 'k-$state',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );
      await db.customStatement('UPDATE outbox SET state = ?', [state]);
    }

    CompositeUserDispatcher composite(_RecordingDispatcher user) =>
        CompositeUserDispatcher(
          userSettings: _RecordingDispatcher(),
          user: user,
          outbox: db.outboxDao,
        );

    for (final state in ['pending', 'dead']) {
      test('leaves the dirty flag of a $state profile edit alone', () async {
        await enqueueUserEdit(state: state);
        final user = _RecordingDispatcher();
        await composite(user).clearLocalDirty(companyId: companyId, id: 'u1');
        expect(user.cleared, isEmpty);
      });
    }

    test('still clears it when no profile edit is waiting', () async {
      final user = _RecordingDispatcher();
      await composite(user).clearLocalDirty(companyId: companyId, id: 'u1');
      expect(user.cleared, ['u1']);
    });
  });

  group('login model', () {
    Map<String, dynamic> uc(Object? react) => {
      'company': {'id': 'c'},
      'account': {'id': 'a'},
      'react_settings': ?react,
    };

    test('reads the object, takes PHP\'s [] as empty, and anything else — or '
        'no key — as unknown', () {
      expect(UserCompanyApi.fromJson(uc({'dark_mode': true})).reactSettings, {
        'dark_mode': true,
      });
      expect(UserCompanyApi.fromJson(uc(<Object>[])).reactSettings, isEmpty);
      expect(UserCompanyApi.fromJson(uc('x')).reactSettings, isNull);
      expect(UserCompanyApi.fromJson(uc(null)).reactSettings, isNull);
    });
  });
}

class _RecordingDispatcher implements SyncDispatcher {
  final cleared = <String>[];

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async => cleared.add(id);

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
