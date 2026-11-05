import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

/// `TaskDao.watchAnyAssigned` decides whether the phone task list shows its
/// assignee column at all (invoiceninja/flutter#183): company-wide, not the
/// visible rows, and read out of the payload — the table has no
/// `assigned_user_id` column.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> task(
    String id, {
    String company = 'co1',
    String payload = '{}',
    bool deleted = false,
  }) => db.taskDao.upsert(
    TasksCompanion.insert(
      id: id,
      companyId: company,
      updatedAt: 1,
      payload: payload,
      isDeleted: Value(deleted),
    ),
  );

  Future<bool> anyAssigned([String company = 'co1']) =>
      db.taskDao.watchAnyAssigned(companyId: company).first;

  test('false with no tasks, or none assigned', () async {
    expect(await anyAssigned(), isFalse);
    await task('a');
    await task('b', payload: '{"assigned_user_id":""}');
    expect(await anyAssigned(), isFalse);
  });

  test('true once one task is assigned', () async {
    await task('a');
    await task('b', payload: '{"assigned_user_id":"u1"}');
    expect(await anyAssigned(), isTrue);
  });

  test('a deleted task or another company does not count', () async {
    await task('a', payload: '{"assigned_user_id":"u1"}', deleted: true);
    await task('b', company: 'co2', payload: '{"assigned_user_id":"u1"}');
    expect(await anyAssigned(), isFalse);
  });

  test('it follows an assignment as it lands', () async {
    final seen = <bool>[];
    final sub = db.taskDao.watchAnyAssigned(companyId: 'co1').listen(seen.add);
    await task('a');
    await pumpEventQueue();
    await task('a', payload: '{"assigned_user_id":"u1"}');
    await pumpEventQueue();
    await sub.cancel();
    expect(seen.last, isTrue);
    expect(seen.first, isFalse);
  });
}
