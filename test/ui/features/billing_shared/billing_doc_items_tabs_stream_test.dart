import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/ui/features/billing_shared/items/billing_doc_items_tabs.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

/// The line-item columns follow `enabled_item_tax_rates`
/// (invoiceninja/flutter#85), so *something* has to read the company. This
/// section sits inside the edit layout's `AnimatedBuilder(animation: vm)` and
/// rebuilds on every VM notification, and `watchCompany` hands back a fresh
/// stream per call — so a `StreamBuilder` built here would restart the Drift
/// query each time.
///
/// It resolves one level down instead, in `LineItemEditor`, which already
/// watches the company for the discount column. This pins that: the whole
/// subtree opens no *additional* subscription as the VM notifies.
class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _CountingCompanyRepo implements CompanyRepository {
  _CountingCompanyRepo(this.company);

  final Company company;
  int watchCalls = 0;

  @override
  Stream<Company?> watchCompany(String companyId) {
    watchCalls++;
    // A real drift watch stays open; a broadcast controller that never closes
    // models that without keeping `pumpAndSettle` spinning.
    return Stream<Company?>.value(company).asBroadcastStream();
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.company);
  @override
  final CompanyRepository company;

  // The line-item cards render unformatted while the Formatter resolves,
  // which is all this test needs from it.
  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  testWidgets('rebuilds open no additional company subscription', (
    tester,
  ) async {
    final repo = _CountingCompanyRepo(
      const Company(id: 'co', enabledItemTaxRates: 2),
    );
    final vm = InvoiceEditViewModel(
      repo: InvoiceRepository(
        db: db,
        api: _FakeInvoicesApi(),
        settings: SettingsRepository(db: db),
      ),
      companyId: 'co',
      clientRequiredMessage: '',
      crossClientLineItemsMessage: '',
      partialInvalidMessage: '',
      existing: emptyInvoice(),
    );
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(repo),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            // Under 700 px the editor renders the mobile card list, whose
            // empty state needs nothing beyond a Formatter — the desktop
            // table would drag in the product and tax-rate pickers, none of
            // which this test is about.
            body: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                // Mirrors the real layout: the section sits inside a builder
                // driven by the VM, so any notification rebuilds it.
                child: AnimatedBuilder(
                  animation: vm,
                  builder: (context, _) => BillingDocItemsTabs(
                    vm: vm,
                    companyId: 'co',
                    lineItems: vm.draft.lineItems,
                    onChanged: vm.replaceLineItems,
                    newItemFactory: emptyLineItem,
                    rowErrors: null,
                    onPickItems: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final onMount = repo.watchCalls;
    expect(onMount, greaterThan(0), reason: 'the company is read at all');

    // Several VM notifications, as any edit session produces. Driven from a
    // header field rather than a line item deliberately: the point is that
    // *any* notification used to restart the query, and it keeps the tree in
    // its empty state so this test doesn't have to stand up the whole
    // product/tax picker graph.
    for (var i = 0; i < 5; i++) {
      vm.setPoNumber('PO-$i');
      await tester.pumpAndSettle();
    }

    expect(
      repo.watchCalls,
      onMount,
      reason: 'rebuilds must not restart the company query',
    );
  });
}
