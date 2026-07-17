import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/services/credits_api.dart';
import 'package:admin/domain/entity_type.dart';

class _FakeCreditsApi implements CreditsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  final calls = <Map<EntityType, Set<String>>>[];

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    calls.clear();
  });
  tearDown(() async => db.close());

  CreditRepository makeRepo() => CreditRepository(
    db: db,
    api: _FakeCreditsApi(),
    onRelatedEntitiesAffected: (companyId, byType) async =>
        calls.add({for (final e in byType.entries) e.key: e.value}),
  );

  test(
    'deleting a credit refreshes its client (credit-balance / '
    'paid_to_date reverse server-side) — not just the flag flip (#32)',
    () async {
      final repo = makeRepo();
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'cr1',
        serverResponse: const CreditApi(id: 'cr1', clientId: 'c1'),
      );
      calls.clear(); // drop the seed's own refresh

      await repo.applyDeleteResponse(companyId: 'co', id: 'cr1');

      expect(calls, hasLength(1));
      expect(calls.single[EntityType.client], {'c1'});
    },
  );
}
