// End-to-end wiring for the `/refresh` delta top-up (invoiceninja/flutter#170).
//
// `refresh_delta_coverage_test` asserts every browsable entity HAS an applier;
// this asserts the appliers are actually reached, land rows in Drift, and are
// skipped on a full sync. It drives the real `auth.onPersistBundles` closure
// that `Services.build` installs — the same one `_persistAndActivate` calls per
// company — so a wiring mistake between the envelope, `refreshDeltaAppliers`
// and the fan-out loop fails here rather than silently shipping.

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/models/api/product_api_model.dart';

import '../ui/features/shell/_shell_test_helpers.dart';

void main() {
  late ShellFixture fixture;

  Future<void> persist(
    CompanyEnvelopeApi company, {
    required bool fullSync,
  }) async {
    final hook = fixture.services.auth.onPersistBundles;
    expect(hook, isNotNull, reason: 'Services.build must install the fan-out');
    await hook!(companyId: 'c1', company: company, fullSync: fullSync);
  }

  setUp(() async {
    fixture = await buildFixture(
      companies: const [
        FakeCompany(id: 'c1', name: 'Acme Co', token: 'tok-c1'),
      ],
      currentCompanyId: 'c1',
    );
    addTearDown(() {
      fixture.services.recentlyViewed.dispose();
      fixture.dispose();
    });
  });

  test('a DELTA envelope lands its browsable entity rows in Drift', () async {
    await persist(
      const CompanyEnvelopeApi(
        id: 'c1',
        invoices: [InvoiceApi(id: 'in_1', number: 'INV-1', updatedAt: 500)],
        products: [ProductApi(id: 'pr_1', productKey: 'SKU-1', updatedAt: 500)],
      ),
      fullSync: false,
    );

    final invoice = await fixture.services.invoices
        .watch(companyId: 'c1', id: 'in_1')
        .first;
    expect(invoice, isNotNull, reason: 'the invoice delta must reach Drift');
    expect(invoice!.number, 'INV-1');

    final product = await fixture.services.products
        .watch(companyId: 'c1', id: 'pr_1')
        .first;
    expect(product, isNotNull);
  });

  test('a FULL-sync envelope skips them entirely', () async {
    // Cold start and Force-full-sync send the whole dataset for every company;
    // `Services.resyncAllEntities` owns that path, and applying here would turn
    // a launch into one very long write inside the per-company transaction.
    await persist(
      const CompanyEnvelopeApi(
        id: 'c1',
        invoices: [InvoiceApi(id: 'in_full', number: 'INV-F', updatedAt: 500)],
      ),
      fullSync: true,
    );

    final invoice = await fixture.services.invoices
        .watch(companyId: 'c1', id: 'in_full')
        .first;
    expect(
      invoice,
      isNull,
      reason: '_deltaOnly must skip the browsable tables on a full sync',
    );
  });

  test('a quiet DELTA writes nothing at all', () async {
    // The common case: a 5-minute tick where nothing changed server-side. Every
    // applier must short-circuit on its empty array, or every mounted list
    // repaints on a timer for no reason.
    await persist(const CompanyEnvelopeApi(id: 'c1'), fullSync: false);

    final cursor = await fixture.db.syncStateDao.read(
      companyId: 'c1',
      entityType: 'invoice',
    );
    expect(cursor.isEmpty, isTrue);
  });
}
