import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
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

  test('wipeAll takes everything', () async {
    await queue('co1', 'unconfirmed');
    await queue('co2', 'pending');

    await disposer.wipeAll(DisposalReason.identityChanged);

    expect(await db.select(db.outbox).get(), isEmpty);
    expect(
      logged.last.message,
      allOf(contains('identityChanged'), contains('unconfirmed: 1')),
    );
  });
}
