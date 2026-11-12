// A new payment for a client defaults to the type of that client's last
// manual payment (invoiceninja/flutter#191, docs/payment-types.md). This pins
// which payment counts as "last".

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

void main() {
  late AppDatabase db;
  const co = 'co1';

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> payment(
    String id, {
    String companyId = co,
    String clientId = 'c1',
    required String typeId,
    required String date,
    int createdAt = 1,
    bool isManual = true,
    bool isDeleted = false,
    bool isDirty = false,
  }) => db
      .into(db.payments)
      .insert(
        PaymentsCompanion.insert(
          id: id,
          companyId: companyId,
          updatedAt: 1,
          payload: '{}',
          clientId: Value(clientId),
          typeId: Value(typeId),
          date: Value(date),
          createdAt: Value(createdAt),
          isManual: Value(isManual),
          isDeleted: Value(isDeleted),
          isDirty: Value(isDirty),
        ),
      );

  Future<String?> latest({String clientId = 'c1'}) => db.paymentDao
      .latestManualTypeForClient(companyId: co, clientId: clientId);

  test('the most recent payment date wins', () async {
    await payment('p1', typeId: '1', date: '2026-10-01');
    await payment('p2', typeId: '6', date: '2026-11-01');
    await payment('p3', typeId: '2', date: '2026-09-01', createdAt: 99);
    expect(await latest(), '6');
  });

  test('on the same day, created_at breaks the tie', () async {
    await payment('p1', typeId: '1', date: '2026-11-01', createdAt: 5);
    await payment('p2', typeId: '6', date: '2026-11-01', createdAt: 9);
    expect(await latest(), '6');
  });

  // An offline create has created_at 0, so it would otherwise lose the tie
  // to every synced payment of the same day.
  test('on the same day, an unsynced payment wins', () async {
    await payment('p1', typeId: '1', date: '2026-11-01', createdAt: 9);
    await payment(
      'tmp_1',
      typeId: '6',
      date: '2026-11-01',
      createdAt: 0,
      isDirty: true,
    );
    expect(await latest(), '6');
  });

  test('skips online, deleted, blank, "0" and Credit payments', () async {
    await payment('p1', typeId: '1', date: '2026-01-01');
    await payment('p2', typeId: '5', date: '2026-11-01', isManual: false);
    await payment('p3', typeId: '6', date: '2026-11-02', isDeleted: true);
    await payment('p4', typeId: '', date: '2026-11-03');
    await payment('p5', typeId: '0', date: '2026-11-04');
    await payment('p6', typeId: '32', date: '2026-11-05');
    expect(await latest(), '1');
  });

  test('is scoped to the client and the company', () async {
    await payment('p1', typeId: '1', date: '2026-01-01');
    await payment('p2', typeId: '6', date: '2026-11-01', clientId: 'c2');
    await payment('p3', typeId: '7', date: '2026-11-02', companyId: 'co2');
    expect(await latest(), '1');
    expect(await latest(clientId: 'c3'), isNull);
  });
}
