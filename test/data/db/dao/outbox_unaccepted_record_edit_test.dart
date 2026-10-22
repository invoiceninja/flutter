import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/sync/mutation.dart';

/// `watchHasUnacceptedRecordEdit` gates the client-portal QR code: a value
/// the server has not accepted must not be printed. Every state counts —
/// `dead` too, because a rejected edit keeps its value in the local row —
/// and a document upload or a comment does not, since it writes no field.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> seed({
    String state = 'pending',
    String entityId = 'co',
    MutationKind kind = MutationKind.update,
    Map<String, dynamic> payload = const {'subdomain': 'acme'},
  }) => db.outboxDao.enqueue(
    OutboxCompanion.insert(
      companyId: 'co',
      entityType: 'company',
      entityId: entityId,
      mutationKind: kind.wireName,
      payload: jsonEncode(payload),
      idempotencyKey: 'k-$state-$entityId-${kind.wireName}-${payload.length}',
      nextAttemptAt: 0,
      createdAt: 0,
      state: Value(state),
    ),
  );

  Future<bool> unaccepted() => db.outboxDao
      .watchHasUnacceptedRecordEdit(
        companyId: 'co',
        entityType: 'company',
        entityId: 'co',
      )
      .first;

  test('no row: accepted', () async {
    expect(await unaccepted(), isFalse);
  });

  for (final state in ['pending', 'in_flight', 'unconfirmed', 'dead']) {
    test('a $state edit is not accepted yet', () async {
      await seed(state: state);
      expect(await unaccepted(), isTrue);
    });
  }

  test('a document upload or a comment writes no field', () async {
    await seed(payload: {'_action': 'upload_document', 'local_path': '/x'});
    await seed(kind: MutationKind.addComment, payload: {'comment': 'hi'});
    expect(await unaccepted(), isFalse);
  });

  test("another record's edit does not count", () async {
    await seed(entityId: 'other');
    expect(await unaccepted(), isFalse);
  });

  test('emits again when the row leaves the outbox', () async {
    final id = await seed();
    final stream = db.outboxDao.watchHasUnacceptedRecordEdit(
      companyId: 'co',
      entityType: 'company',
      entityId: 'co',
    );
    final seen = <bool>[];
    final sub = stream.listen(seen.add);
    await pumpEventQueue();
    await db.outboxDao.deleteRow(id);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [true, false]);
  });
}
