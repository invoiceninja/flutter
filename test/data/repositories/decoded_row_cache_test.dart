import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/domain/entity_state.dart';

/// Every Drift change re-emits each mounted list's whole window, and every row
/// in it used to be decoded again from its JSON payload on the UI isolate —
/// ~50 ms for one edit with ten pages of invoices loaded
/// (`invoices.list_deep_scroll`, docs/performance-tracking.md). A repository
/// now decodes each distinct row once (`BaseEntityRepository.decodeRow`).
///
/// Pinned: an unchanged row comes back as the same instance; a changed row —
/// any column — is decoded fresh and shows the change; a record keeps one
/// entry, not one per version; logout drops the cache (decoded records are
/// user data); and the cache is bounded.
class _Api implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  const co = 'co';
  late AppDatabase db;
  late InvoiceRepository repo;

  setUp(() {
    db = AppDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    repo = InvoiceRepository(
      db: db,
      api: _Api(),
      settings: SettingsRepository(db: db),
    );
  });
  tearDown(() => db.close());

  Future<void> seed(int count) async {
    for (var i = 0; i < count; i++) {
      await repo.applyUpdateResponse(
        companyId: co,
        serverResponse: InvoiceApi(
          id: 'inv_$i',
          number: '${10000 + i}',
          publicNotes: 'Invoice $i',
          updatedAt: 1700000000 + i,
        ),
      );
    }
  }

  test('an unchanged row is decoded once', () async {
    await seed(5);
    final first = await repo.watchPage(companyId: co).first;
    final second = await repo.watchPage(companyId: co).first;
    expect(second, hasLength(5));
    for (var i = 0; i < 5; i++) {
      expect(second[i], same(first[i]));
    }
  });

  test('a changed row is decoded fresh, and its neighbours are not', () async {
    await seed(5);
    final before = await repo.watchPage(companyId: co).first;
    final edited = before.firstWhere((i) => i.id == 'inv_2');
    await repo.save(
      companyId: co,
      invoice: edited.copyWith(privateNotes: 'changed'),
    );

    final after = await repo.watchPage(companyId: co).first;
    final now = after.firstWhere((i) => i.id == 'inv_2');
    expect(now, isNot(same(edited)));
    expect(now.privateNotes, 'changed');
    expect(now.isDirty, isTrue);
    for (final invoice in after.where((i) => i.id != 'inv_2')) {
      expect(invoice, same(before.firstWhere((b) => b.id == invoice.id)));
    }
  });

  test('a change to a column alone is decoded fresh too', () async {
    await seed(3);
    final before = await repo.watchPage(companyId: co).first;
    final target = before.first;
    // Archiving writes the column only; the payload is untouched.
    await db.invoiceDao.setArchived(
      companyId: co,
      id: target.id,
      atEpochSeconds: 1700000500,
    );
    final archived = await repo
        .watchPage(companyId: co, states: const {EntityState.archived})
        .first;
    final now = archived.single;
    expect(now, isNot(same(target)));
    expect(now.archivedAt, isNotNull);
  });

  test(
    'an edited record replaces its entry — one version per record',
    () async {
      await seed(5);
      await repo.watchPage(companyId: co).first;
      expect(repo.decodedRowCount, 5);
      final edited = (await repo.watchPage(companyId: co).first).first;
      await repo.save(
        companyId: co,
        invoice: edited.copyWith(privateNotes: 'again'),
      );
      await repo.watchPage(companyId: co).first;
      expect(
        repo.decodedRowCount,
        5,
        reason: 'the old version of the edited record must not linger',
      );
    },
  );

  test('logout drops the decoded rows with the peek seeds', () async {
    await seed(3);
    final before = await repo.watchPage(companyId: co).first;
    repo.clearPeekCache();
    final after = await repo.watchPage(companyId: co).first;
    for (var i = 0; i < 3; i++) {
      expect(after[i], isNot(same(before[i])));
      expect(after[i], before[i]);
    }
  });

  test('the cache keeps the most recently decoded rows', () async {
    const limit = BaseEntityRepository.decodedRowCacheLimit;
    const pages = limit ~/ 50 + 1;
    await seed(pages * 50);
    // Newest number first, so the window's first row is decoded first and
    // is the one a full cache evicts.
    final all = await repo.watchPage(companyId: co, loadedPages: pages).first;
    expect(all, hasLength(pages * 50));

    final newestDecoded = await repo
        .watchByRealId(companyId: co, id: all.last.id)
        .first;
    expect(newestDecoded, same(all.last));
    final oldestDecoded = await repo
        .watchByRealId(companyId: co, id: all.first.id)
        .first;
    expect(oldestDecoded, isNot(same(all.first)));
    expect(oldestDecoded, all.first);
  });
}
