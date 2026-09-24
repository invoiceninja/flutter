import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/quote_status.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/credit_status.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/models/domain/purchase_order_status.dart';
import 'package:admin/data/models/domain/recurring_invoice_status.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/data/services/credits_api.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/data/services/recurring_invoices_api.dart';
import 'package:admin/ui/features/credits/view_models/credit_edit_view_model.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_edit_view_model.dart';

class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeQuotesApi implements QuotesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeCreditsApi implements CreditsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakePurchaseOrdersApi implements PurchaseOrdersApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeRecurringInvoicesApi implements RecurringInvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Finding #28: a billing-doc edit must stamp the recomputed `amount` /
/// `balance` / `taxAmount` onto the draft before save, so the list tile + KPI
/// strip (which read the stored fields) match the Overview tab offline. The
/// stamp runs as a `beforeSaveHook` registered by `GenericBillingDocEditViewModel`
/// — exercised here directly via `stampTotalsForSave()` at the precision the
/// totals widget captured.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  LineItem item(String cost, String qty) => emptyLineItem().copyWith(
    cost: Decimal.parse(cost),
    quantity: Decimal.parse(qty),
  );

  test('invoice: stamp sets amount = computeTotals.total and balance = total '
      '− paidToDate (partial-payment aware)', () {
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
      // SENT, not draft: the server only recomputes `balance` for
      // non-draft invoices (`InvoiceSum::setCalculatedAttributes`), and the
      // client mirrors that — see `copyWithStampedTotals`.
      existing: emptyInvoice().copyWith(
        paidToDate: Decimal.parse('30'),
        statusId: InvoiceStatus.sent,
      ),
    );
    vm.addLineItem(item('100', '1'));
    vm.addLineItem(item('50', '2')); // +100 → total 200

    // Pre-stamp the stored amount is stale (the seed's 0), even though the
    // Overview/totals widget already computes 200.
    expect(vm.draft.amount, Decimal.zero);
    vm.totalsAt(2); // the totals widget captures the live precision

    vm.stampTotalsForSave();

    expect(vm.draft.amount, Decimal.parse('200'));
    expect(
      vm.draft.balance,
      Decimal.parse('170'),
      reason: 'balance = total (200) − paidToDate (30)',
    );
  });

  test('invoice: a DRAFT keeps its stored balance — the server never '
      'recomputes a draft balance, and a stamped one lit up "Past Due" and '
      'made the draft an auto-apply target', () {
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
    vm.addLineItem(item('100', '1'));
    vm.totalsAt(2);

    vm.stampTotalsForSave();

    expect(vm.draft.amount, Decimal.parse('100'));
    expect(vm.draft.balance, Decimal.zero);
    expect(vm.draft.isPastDue, isFalse);
  });

  QuoteEditViewModel quoteVm({Quote? existing}) => QuoteEditViewModel(
    repo: QuoteRepository(db: db, api: _FakeQuotesApi()),
    companyId: 'co',
    clientRequiredMessage: '',
    crossClientLineItemsMessage: '',
    partialInvalidMessage: '',
    existing: existing,
  );

  test('quote: a SENT quote stamps balance = total (no paidToDate)', () {
    final vm = quoteVm(
      existing: emptyQuote().copyWith(statusId: QuoteStatus.sent),
    );
    vm.addLineItem(item('100', '1'));
    vm.totalsAt(2);

    vm.stampTotalsForSave();

    expect(vm.draft.amount, Decimal.parse('100'));
    expect(vm.draft.balance, Decimal.parse('100'));
  });

  test('quote: a DRAFT keeps its stored balance — InvoiceSum::getQuote() '
      'skips a draft balance exactly like invoices', () {
    final vm = quoteVm();
    vm.addLineItem(item('100', '1'));
    vm.totalsAt(2);

    vm.stampTotalsForSave();

    expect(vm.draft.amount, Decimal.parse('100'));
    expect(vm.draft.balance, Decimal.zero);
  });

  // The other three billing documents had no stamp coverage at all, so the
  // rule each one follows was pinned only by the copy it lived in.

  CreditEditViewModel creditVm(Credit existing) => CreditEditViewModel(
    repo: CreditRepository(db: db, api: _FakeCreditsApi()),
    companyId: 'co',
    clientRequiredMessage: '',
    crossClientLineItemsMessage: '',
    partialInvalidMessage: '',
    existing: existing,
  );

  test('credit: a SENT credit stamps balance = total − paidToDate, like an '
      'invoice', () {
    final vm = creditVm(
      emptyCredit().copyWith(
        paidToDate: Decimal.parse('30'),
        statusId: CreditStatus.sent,
      ),
    );
    vm.addLineItem(item('100', '2'));
    vm.totalsAt(2);

    vm.stampTotalsForSave();

    expect(vm.draft.amount, Decimal.parse('200'));
    expect(vm.draft.balance, Decimal.parse('170'));
  });

  test('credit: a DRAFT keeps its stored balance', () {
    final vm = creditVm(emptyCredit());
    vm.addLineItem(item('100', '1'));
    vm.totalsAt(2);

    vm.stampTotalsForSave();

    expect(vm.draft.amount, Decimal.parse('100'));
    expect(vm.draft.balance, Decimal.zero);
  });

  PurchaseOrderEditViewModel poVm(PurchaseOrder existing) =>
      PurchaseOrderEditViewModel(
        repo: PurchaseOrderRepository(db: db, api: _FakePurchaseOrdersApi()),
        companyId: 'co',
        vendorRequiredMessage: '',
        existing: existing,
      );

  test('purchase order: SENT stamps balance = total; a DRAFT keeps its '
      'stored balance', () {
    final sent = poVm(
      emptyPurchaseOrder().copyWith(statusId: PurchaseOrderStatus.sent),
    );
    sent.addLineItem(item('100', '1'));
    sent.totalsAt(2);
    sent.stampTotalsForSave();
    expect(sent.draft.balance, Decimal.parse('100'));

    final draft = poVm(emptyPurchaseOrder());
    draft.addLineItem(item('100', '1'));
    draft.totalsAt(2);
    draft.stampTotalsForSave();
    expect(draft.draft.amount, Decimal.parse('100'));
    expect(draft.draft.balance, Decimal.zero);
  });

  test('recurring invoice: balance = total at EVERY status, draft included '
      '— the server does the same', () {
    // Unlike the other four there is no draft guard, and that is correct,
    // not drift: `InvoiceSum::getRecurringInvoice()` sets `balance = amount`
    // unconditionally (invoiceninja `app/Helpers/Invoice/InvoiceSum.php`),
    // and `BaseRepository` saves recurring invoices through it.
    for (final status in [
      RecurringInvoiceStatus.draft,
      RecurringInvoiceStatus.active,
    ]) {
      final vm = RecurringInvoiceEditViewModel(
        repo: RecurringInvoiceRepository(
          db: db,
          api: _FakeRecurringInvoicesApi(),
        ),
        companyId: 'co',
        clientRequiredMessage: '',
        crossClientLineItemsMessage: '',
        existing: emptyRecurringInvoice().copyWith(statusId: status),
      );
      vm.addLineItem(item('100', '1'));
      vm.totalsAt(2);
      vm.stampTotalsForSave();
      expect(vm.draft.balance, Decimal.parse('100'), reason: status.name);
    }
  });
}
