import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/design_api_model.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// `watchAll` is the pickers' list and leaves archived designs out. Until
/// `watchArchived` nothing listed them, so an archived design could never be
/// found again to restore.
void main() {
  late AppDatabase db;
  late DesignRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DesignRepository(db: db, api: _FakeDesignsApi());
    await repo.applyBundle(
      companyId: 'co1',
      bundle: const [
        DesignApi(id: 'live', name: 'Live', isCustom: true, updatedAt: 3),
        DesignApi(
          id: 'old-b',
          name: 'beta (old)',
          isCustom: true,
          archivedAt: 1700000000,
          updatedAt: 3,
        ),
        DesignApi(
          id: 'old-a',
          name: 'Alpha (old)',
          isCustom: true,
          archivedAt: 1700000000,
          updatedAt: 3,
        ),
        DesignApi(
          id: 'gone',
          name: 'Deleted',
          isCustom: true,
          archivedAt: 1700000000,
          isDeleted: true,
          updatedAt: 3,
        ),
      ],
    );
    await repo.applyBundle(
      companyId: 'co2',
      bundle: const [
        DesignApi(
          id: 'other',
          name: 'Other company',
          isCustom: true,
          archivedAt: 1700000000,
          updatedAt: 3,
        ),
      ],
    );
  });

  tearDown(() async => db.close());

  test(
    'the archived designs of this company, by name; never a deleted one',
    () async {
      final archived = await repo.watchArchived(companyId: 'co1').first;
      expect([for (final d in archived) d.id], ['old-a', 'old-b']);
      expect(archived.every((d) => d.archivedAt != null), isTrue);
    },
  );

  test('a name is taken whatever became of its design', () async {
    // The server's uniqueness rule counts archived and deleted designs.
    expect(await repo.knownNames(companyId: 'co1'), {
      'Live',
      'beta (old)',
      'Alpha (old)',
      'Deleted',
    });
    expect(await repo.knownNames(companyId: 'co2'), {'Other company'});
  });

  test('and they stay out of the active list', () async {
    final active = await repo.watchAll(companyId: 'co1').first;
    expect([for (final d in active) d.id], ['live']);
  });
}
