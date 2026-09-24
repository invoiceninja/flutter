import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/local_data_disposer.dart';

/// Every wipe of local data goes through [LocalDataDisposer], which says why
/// and logs what went — the first thing to look for when a user says their
/// changes vanished.
void main() {
  late AppDatabase db;
  late LocalDataDisposer disposer;
  late List<LogRecord> logged;
  late StreamSubscription<LogRecord> sub;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    disposer = LocalDataDisposer(db);
    logged = [];
    Logger.root.level = Level.ALL;
    sub = Logger.root.onRecord.listen(logged.add);
  });
  tearDown(() async {
    await sub.cancel();
    await db.close();
  });

  Future<void> queue(String companyId, String state) => db.outboxDao.enqueue(
    OutboxCompanion.insert(
      companyId: companyId,
      entityType: 'client',
      entityId: 'c',
      mutationKind: 'update',
      payload: '{}',
      idempotencyKey: '$companyId-$state',
      nextAttemptAt: 0,
      createdAt: 0,
      state: Value(state),
    ),
  );

  test('wipeCompany takes that company\'s rows only, and logs what went '
      'and why', () async {
    await queue('co1', 'pending');
    await queue('co1', 'dead');
    await queue('co2', 'pending');

    await disposer.wipeCompany('co1', DisposalReason.companyGoneOnServer);

    final left = await db.select(db.outbox).get();
    expect(left.map((r) => r.companyId), ['co2']);
    final warning = logged.singleWhere(
      (r) => r.loggerName == 'LocalDataDisposer',
    );
    expect(warning.level, Level.WARNING);
    expect(warning.message, contains('companyGoneOnServer'));
    expect(warning.message, contains('co1'));
    expect(warning.message, contains('pending: 1'));
    expect(warning.message, contains('dead: 1'));
  });

  test('wipeAll takes everything but the device\'s own preferences', () async {
    await queue('co1', 'unconfirmed');
    await queue('co2', 'pending');
    final prefs = DevicePrefsStore(db);
    await prefs.write(DevicePrefKeys.themeMode, 'dark');
    await prefs.write(DevicePrefKeys.tasksView, 'kanban');
    // Written by a newer build: its scope is unknown here, so it goes — the
    // safe answer when the next person to sign in may be someone else.
    await db.devicePrefsDao.put('from_a_newer_build', 'x', now: 1);
    await db.devicePrefsDao.put(kPrefsCarriedFromNavState, '1', now: 1);
    await prefs.load();

    await LocalDataDisposer(
      db,
      prefs: prefs,
    ).wipeAll(DisposalReason.identityChanged);

    expect(await db.select(db.outbox).get(), isEmpty);
    expect((await db.devicePrefsDao.readAll()).keys, {
      DevicePrefKeys.themeMode.name,
      kPrefsCarriedFromNavState,
    });
    expect(prefs.read(DevicePrefKeys.themeMode), 'dark');
    expect(prefs.read(DevicePrefKeys.tasksView), isNull);
    expect(
      logged.last.message,
      allOf(contains('identityChanged'), contains('unconfirmed: 1')),
    );
  });
}
