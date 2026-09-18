// Completeness guard for the `/refresh` delta top-up (invoiceninja/flutter#170).
//
// The server's `refreshResponse()` parses the full `first_load` include set
// unconditionally, so every delta refresh already carries each browsable entity
// filtered to `updated_at >= <watermark>`. v2 discarded all of it, which is why
// a long-lived session showed days-old data — the shell is a
// `StatefulShellRoute.indexedStack`, so a mounted list VM never re-fetches.
//
// The applier set is hand-maintained (WiredEntities.refreshDeltaAppliers). This
// asserts it covers every workspace-sidebar (SidebarSection.top) entity, so a
// future list entity can't silently ship stale-forever. The failure mode is
// invisible otherwise: no crash, no log — just a list that never updates.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';

import '../ui/features/shell/_shell_test_helpers.dart';

void main() {
  testWidgets('a /refresh delta tops up every workspace-sidebar list entity', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

    final browsable = fixture.services.entityRegistry.sidebarTop
        .map((h) => h.type)
        .toSet();

    // Non-vacuous: if the registry ever returned nothing, the difference below
    // would be trivially empty and this guard would silently stop guarding.
    expect(browsable, isNotEmpty);
    expect(
      browsable.difference(fixture.services.refreshDeltaEntityTypes),
      isEmpty,
      reason:
          'every workspace-sidebar list entity must be topped up by a /refresh '
          'delta — add the missing entity to refreshDeltaAppliers in '
          'services_entity_wiring.dart',
    );

    fixture.services.recentlyViewed.dispose();
  });

  // The staleness guard in `applyRefreshDeltaTemplate` is powered by the DAO's
  // `updatedAtAmong`, which returns `const {}` when `updatedAtColumn` is left
  // unbound. That degrades silently to the un-guarded behaviour — an echoed
  // save could then be reverted by an in-flight delta — so pin the binding.
  test('every BaseEntityDao topped up from a delta binds updatedAtColumn', () {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final unbound = <String>[
      for (final entry in _deltaBackedBaseDaos(db).entries)
        if (entry.value.updatedAtColumn == null) entry.key,
    ];
    expect(
      unbound,
      isEmpty,
      reason:
          'these DAOs back a /refresh delta applier but leave updatedAtColumn '
          'null, which silently disables the stale-row guard in '
          'applyRefreshDeltaTemplate',
    );
  });
  // Source scan, not a widget test: nothing a widget test builds reaches
  // `Services.build`'s `onPersistBundles` wiring, and the projections are
  // tolerant enough that forcing a real throw isn't practical. What matters is
  // structural — the loop must isolate each applier.
  test('the delta fan-out isolates each applier', () {
    final services = File('lib/app/services.dart').readAsStringSync();
    final loop = RegExp(
      r'for \(final entry in entities\.refreshDeltaAppliers\.entries\) \{'
      r'(.*?)\n          \}',
      dotAll: true,
    ).firstMatch(services);
    expect(
      loop,
      isNotNull,
      reason: 'the refreshDeltaAppliers fan-out loop moved or was rewritten',
    );
    final body = loop!.group(1)!;
    expect(
      body.contains('try {') && body.contains('} catch ('),
      isTrue,
      reason:
          'each delta applier must be wrapped in its own try/catch. The hook '
          'runs inside ONE transaction whose only try/catch is outside it, so '
          'an uncaught throw here rolls back the reference bundles and the '
          'user roster too — settings stop updating because one entity\'s '
          'payload was malformed.',
    );
    expect(
      body.contains('entry.key.name'),
      isTrue,
      reason:
          'name the failing entity in the warning, like resyncAllEntities does '
          '— otherwise the log says only that "something" failed',
    );
  });
}

/// The delta-backed DAOs that extend [BaseEntityDao], by name.
///
/// `BankTransactionDao` is deliberately absent: it does not extend
/// [BaseEntityDao] and hand-rolls both `upsertAllPreservingDirty` and
/// `updatedAtAmong`, so there is no `updatedAtColumn` to bind. Its guard is
/// covered by `bank_transaction_repository_test`.
Map<String, BaseEntityDao<dynamic, dynamic>> _deltaBackedBaseDaos(
  AppDatabase db,
) {
  return {
    'clientDao': db.clientDao,
    'productDao': db.productDao,
    'invoiceDao': db.invoiceDao,
    'recurringInvoiceDao': db.recurringInvoiceDao,
    'quoteDao': db.quoteDao,
    'creditDao': db.creditDao,
    'paymentDao': db.paymentDao,
    'taskDao': db.taskDao,
    'projectDao': db.projectDao,
    'expenseDao': db.expenseDao,
    'recurringExpenseDao': db.recurringExpenseDao,
    'vendorDao': db.vendorDao,
    'purchaseOrderDao': db.purchaseOrderDao,
  };
}
