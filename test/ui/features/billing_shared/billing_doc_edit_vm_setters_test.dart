// The 35 setters every billing-document edit view model shares — once five
// hand-written copies, now written once on `BillingDocEditViewModel` over each
// entity's `BillingDocWriter`. This pins what each one writes, in both decimal
// locales, for all five documents, so a writer closure pointed at the wrong
// field cannot change one quietly.
//
// Driven dynamically: a table over `dynamic` runs one expectation against all
// five.

// ignore_for_file: avoid_dynamic_calls

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/credits_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/data/services/recurring_invoices_api.dart';
import 'package:admin/ui/features/credits/view_models/credit_edit_view_model.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_edit_view_model.dart';

class _UnusedInvoices implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedQuotes implements QuotesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedCredits implements CreditsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedPo implements PurchaseOrdersApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _UnusedRi implements RecurringInvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

typedef _Make = dynamic Function(AppDatabase db, {required bool comma});

final _viewModels = <String, _Make>{
  'invoice': (db, {required comma}) => InvoiceEditViewModel(
    repo: InvoiceRepository(
      db: db,
      api: _UnusedInvoices(),
      settings: SettingsRepository(db: db),
    ),
    companyId: 'co',
    clientRequiredMessage: '',
    crossClientLineItemsMessage: '',
    partialInvalidMessage: '',
    useCommaAsDecimalPlace: comma,
  ),
  'quote': (db, {required comma}) => QuoteEditViewModel(
    repo: QuoteRepository(db: db, api: _UnusedQuotes()),
    companyId: 'co',
    clientRequiredMessage: '',
    crossClientLineItemsMessage: '',
    partialInvalidMessage: '',
    useCommaAsDecimalPlace: comma,
  ),
  'credit': (db, {required comma}) => CreditEditViewModel(
    repo: CreditRepository(db: db, api: _UnusedCredits()),
    companyId: 'co',
    clientRequiredMessage: '',
    crossClientLineItemsMessage: '',
    partialInvalidMessage: '',
    useCommaAsDecimalPlace: comma,
  ),
  'purchase order': (db, {required comma}) => PurchaseOrderEditViewModel(
    repo: PurchaseOrderRepository(db: db, api: _UnusedPo()),
    companyId: 'co',
    vendorRequiredMessage: '',
    useCommaAsDecimalPlace: comma,
  ),
  'recurring invoice': (db, {required comma}) => RecurringInvoiceEditViewModel(
    repo: RecurringInvoiceRepository(db: db, api: _UnusedRi()),
    companyId: 'co',
    clientRequiredMessage: '',
    crossClientLineItemsMessage: '',
    useCommaAsDecimalPlace: comma,
  ),
};

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  for (final MapEntry(key: name, value: make) in _viewModels.entries) {
    for (final comma in [false, true]) {
      final locale = comma ? 'comma' : 'dot';

      test(
        '$name: every shared setter writes its field ($locale decimals)',
        () {
          final dynamic vm = make(db, comma: comma);
          // A decimal as a user in this locale types it.
          String typed(String dot) => comma ? dot.replaceAll('.', ',') : dot;
          final d = Decimal.parse;

          vm.setClientId('client_1');
          expect(vm.draft.clientId, 'client_1');
          vm.setVendorId('vendor_1');
          expect(vm.draft.vendorId, 'vendor_1');
          vm.setProjectId('project_1');
          expect(vm.draft.projectId, 'project_1');
          vm.setAssignedUserId('user_1');
          expect(vm.draft.assignedUserId, 'user_1');
          vm.setDesignId('design_1');
          expect(vm.draft.designId, 'design_1');
          vm.setNumber('0042');
          expect(vm.draft.number, '0042');
          vm.setPoNumber('PO-7');
          expect(vm.draft.poNumber, 'PO-7');
          vm.setTagIds(['t1', 't2']);
          expect(vm.draft.tagIds, ['t1', 't2']);

          vm.setDate(const Date(2026, 1, 15));
          expect(vm.draft.date, const Date(2026, 1, 15));
          vm.setDueDate(const Date(2026, 2, 15));
          expect(vm.draft.dueDate, const Date(2026, 2, 15));

          vm.setExchangeRate(typed('1.5'));
          expect(vm.draft.exchangeRate, d('1.5'));
          vm.setExchangeRate('');
          expect(
            vm.draft.exchangeRate,
            Decimal.one,
            reason: 'blank → 1, not 0',
          );

          vm.setDiscount(typed('2.5'), isAmount: true);
          expect(vm.draft.discount, d('2.5'));
          expect(vm.draft.isAmountDiscount, isTrue);
          vm.setDiscount('10', isAmount: false);
          expect(vm.draft.discount, d('10'));
          expect(vm.draft.isAmountDiscount, isFalse);

          vm.setUsesInclusiveTaxes(true);
          expect(vm.draft.usesInclusiveTaxes, isTrue);

          vm.setTaxName1('VAT');
          vm.setTaxName2('GST');
          vm.setTaxName3('PST');
          expect(
            [vm.draft.taxName1, vm.draft.taxName2, vm.draft.taxName3],
            ['VAT', 'GST', 'PST'],
          );
          vm.setTaxRate1(typed('19.5'));
          vm.setTaxRate2(typed('7.25'));
          vm.setTaxRate3(typed('3.5'));
          expect(
            [vm.draft.taxRate1, vm.draft.taxRate2, vm.draft.taxRate3],
            [d('19.5'), d('7.25'), d('3.5')],
          );
          // From a value, so the fallback is seen to write.
          vm.setTaxRate3('not a number');
          expect(vm.draft.taxRate3, Decimal.zero, reason: 'garbage → 0');

          vm.setCustomSurcharge1(typed('1.25'));
          vm.setCustomSurcharge2(typed('2.5'));
          vm.setCustomSurcharge3('3');
          vm.setCustomSurcharge4(typed('4.75'));
          expect(
            [
              vm.draft.customSurcharge1,
              vm.draft.customSurcharge2,
              vm.draft.customSurcharge3,
              vm.draft.customSurcharge4,
            ],
            [d('1.25'), d('2.5'), d('3'), d('4.75')],
          );
          vm.setCustomSurcharge4('');
          expect(vm.draft.customSurcharge4, Decimal.zero, reason: 'blank → 0');

          // One at a time from all-false, so a setter that writes a sibling's
          // field fails here.
          List<Object?> customTaxes() => [
            vm.draft.customTaxes1,
            vm.draft.customTaxes2,
            vm.draft.customTaxes3,
            vm.draft.customTaxes4,
          ];
          expect(customTaxes(), [false, false, false, false]);
          vm.setCustomTaxes1(true);
          expect(customTaxes(), [true, false, false, false]);
          vm.setCustomTaxes2(true);
          expect(customTaxes(), [true, true, false, false]);
          vm.setCustomTaxes3(true);
          expect(customTaxes(), [true, true, true, false]);
          vm.setCustomTaxes4(true);
          expect(customTaxes(), [true, true, true, true]);
          vm.setCustomTaxes2(false);
          expect(customTaxes(), [true, false, true, true]);

          vm.setCustomValue1('a');
          vm.setCustomValue2('b');
          vm.setCustomValue3('c');
          vm.setCustomValue4('d');
          expect(
            [
              vm.draft.customValue1,
              vm.draft.customValue2,
              vm.draft.customValue3,
              vm.draft.customValue4,
            ],
            ['a', 'b', 'c', 'd'],
          );

          vm.setPublicNotes('public');
          vm.setPrivateNotes('private');
          vm.setTerms('terms');
          vm.setFooter('footer');
          expect(
            [
              vm.draft.publicNotes,
              vm.draft.privateNotes,
              vm.draft.terms,
              vm.draft.footer,
            ],
            ['public', 'private', 'terms', 'footer'],
          );

          vm.dispose();
        },
      );
    }
  }
}
