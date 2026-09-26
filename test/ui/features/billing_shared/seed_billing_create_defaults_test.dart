// A new billing document takes its inclusive-tax mode from the settings
// cascade, the way the server does on create. `empty*()` hard-code
// `usesInclusiveTaxes: false` and the app always sends the field, so every
// new document of an inclusive-tax company used to save exclusive — and its
// totals added the tax on top of prices that already carried it.

// ignore_for_file: avoid_dynamic_calls

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
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
import 'package:admin/domain/billing/billing_doc_totals.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/billing_shared/add_unbilled/unbilled_line_items.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/seed_billing_create_defaults.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';
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

/// The cascade, programmable per client (`null` = the company layer alone).
/// With [hold] set, each `resolved()` waits for the test to answer it.
class _Settings extends SettingsRepository {
  _Settings(AppDatabase db) : super(db: db);

  final answers = <String?, bool>{};
  Map<String?, bool>? ready;
  bool hold = false;
  final pending = <({String? clientId, Completer<Map<String, dynamic>> c})>[];

  Map<String, dynamic> _layer(String? clientId) => {
    'inclusive_taxes': answers[clientId] ?? answers[null] ?? false,
  };

  void answer(String? clientId) {
    final i = pending.indexWhere((p) => p.clientId == clientId);
    pending.removeAt(i).c.complete(_layer(clientId));
  }

  @override
  Future<Map<String, dynamic>> resolved({
    required String companyId,
    String? clientId,
  }) {
    if (!hold) return Future.value(_layer(clientId));
    final c = Completer<Map<String, dynamic>>();
    pending.add((clientId: clientId, c: c));
    return c.future;
  }

  @override
  Map<String, dynamic>? resolvedIfReady({
    required String companyId,
    String? clientId,
  }) {
    final r = ready;
    if (r == null) return null;
    return {'inclusive_taxes': r[clientId] ?? r[null] ?? false};
  }
}

typedef _Make = dynamic Function(AppDatabase db, {Object? cloneFrom});

final _docs = <BillingDocType, _Make>{
  BillingDocType.invoice: (db, {cloneFrom}) => InvoiceEditViewModel(
    repo: InvoiceRepository(
      db: db,
      api: _UnusedInvoices(),
      settings: SettingsRepository(db: db),
    ),
    companyId: 'co',
    clientRequiredMessage: 'client',
    crossClientLineItemsMessage: '',
    partialInvalidMessage: '',
    cloneFrom: cloneFrom as Invoice?,
  ),
  BillingDocType.quote: (db, {cloneFrom}) => QuoteEditViewModel(
    repo: QuoteRepository(db: db, api: _UnusedQuotes()),
    companyId: 'co',
    clientRequiredMessage: 'client',
    crossClientLineItemsMessage: '',
    partialInvalidMessage: '',
    cloneFrom: cloneFrom as Quote?,
  ),
  BillingDocType.credit: (db, {cloneFrom}) => CreditEditViewModel(
    repo: CreditRepository(db: db, api: _UnusedCredits()),
    companyId: 'co',
    clientRequiredMessage: 'client',
    crossClientLineItemsMessage: '',
    partialInvalidMessage: '',
    cloneFrom: cloneFrom as Credit?,
  ),
  BillingDocType.purchaseOrder: (db, {cloneFrom}) => PurchaseOrderEditViewModel(
    repo: PurchaseOrderRepository(db: db, api: _UnusedPo()),
    companyId: 'co',
    vendorRequiredMessage: 'vendor',
    cloneFrom: cloneFrom as PurchaseOrder?,
  ),
  BillingDocType.recurringInvoice: (db, {cloneFrom}) =>
      RecurringInvoiceEditViewModel(
        repo: RecurringInvoiceRepository(db: db, api: _UnusedRi()),
        companyId: 'co',
        clientRequiredMessage: 'client',
        crossClientLineItemsMessage: '',
        cloneFrom: cloneFrom as RecurringInvoice?,
      ),
};

final _pricedLine = emptyLineItem().copyWith(
  productKey: 'Widget',
  cost: Decimal.parse('100'),
);

Expense _expense() => Expense.fromApi(
  const ExpenseApi(
    id: 'e1',
    amount: '100',
    taxName1: 'VAT',
    taxRate1: '20',
    shouldBeInvoiced: true,
  ),
);

void main() {
  late AppDatabase db;
  late _Settings settings;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = _Settings(db);
  });
  tearDown(() async => db.close());

  test('the cascade value is read leniently', () {
    for (final on in [true, 1, '1', 'true']) {
      expect(
        inclusiveTaxesSetting({'inclusive_taxes': on}),
        isTrue,
        reason: '$on',
      );
    }
    for (final off in [false, 0, '0', 'false', null, '']) {
      expect(
        inclusiveTaxesSetting({'inclusive_taxes': off}),
        isFalse,
        reason: '$off',
      );
    }
    expect(inclusiveTaxesSetting(const {}), isFalse);
  });

  for (final MapEntry(key: type, value: make) in _docs.entries) {
    group(type.name, () {
      dynamic open({Object? cloneFrom}) {
        final dynamic vm = make(db, cloneFrom: cloneFrom);
        addTearDown(() => vm.dispose());
        seedBillingCreateDefaults(
          settings: settings,
          companyId: 'co',
          type: type,
          vm: vm as BillingDocEditViewModel,
        );
        return vm;
      }

      test('an inclusive company opens it inclusive, and clean', () async {
        settings.answers[null] = true;
        final dynamic vm = open();
        await pumpEventQueue();
        expect(vm.draft.usesInclusiveTaxes, isTrue);
        expect(vm.isDirty, isFalse);
      });

      test('the first-frame guess is always corrected by resolved()', () async {
        settings
          ..ready = {null: true}
          ..answers[null] = false;
        final dynamic vm = open();
        expect(vm.draft.usesInclusiveTaxes, isTrue, reason: 'the guess');
        await pumpEventQueue();
        expect(vm.draft.usesInclusiveTaxes, isFalse, reason: 'the answer');
        expect(vm.isDirty, isFalse);
      });

      test('a clone with lines keeps its source mode', () async {
        settings.answers[null] = true;
        final probe = make(db);
        addTearDown(() => probe.dispose());
        final clone = probe.writer.lineItems(probe.writer.empty(), [
          _pricedLine,
        ]);
        final dynamic vm = open(cloneFrom: clone);
        await pumpEventQueue();
        expect(vm.draft.usesInclusiveTaxes, isFalse);
      });

      test('a staged draft is dirty from the start, even unchanged', () {
        final probe = make(db);
        addTearDown(() => probe.dispose());
        final dynamic vm = open(cloneFrom: probe.writer.empty());
        expect(vm.isDirty, isTrue);
        vm.resetToEmpty();
        expect(vm.isDirty, isFalse);
      });

      test('the switch, once touched, is the user\'s', () async {
        settings
          ..answers[null] = true
          ..hold = true;
        final dynamic vm = open();
        vm.setUsesInclusiveTaxes(false);
        settings.answer(null);
        await pumpEventQueue();
        expect(vm.draft.usesInclusiveTaxes, isFalse);
      });

      test('a line priced before the answer keeps the mode', () async {
        settings
          ..answers[null] = true
          ..hold = true;
        final dynamic vm = open();
        vm.addLineItem(_pricedLine);
        settings.answer(null);
        await pumpEventQueue();
        expect(vm.draft.usesInclusiveTaxes, isFalse);
      });

      test('discard → clean, on the company value', () async {
        settings.answers[null] = true;
        final dynamic vm = open();
        await pumpEventQueue();
        vm.setNumber('0042');
        vm.setUsesInclusiveTaxes(false);
        expect(vm.isDirty, isTrue);
        vm.resetToEmpty();
        expect(vm.isDirty, isFalse);
        expect(vm.draft.usesInclusiveTaxes, isTrue);
        expect(vm.draft.number, '');
      });

      if (type.party == BillingDocParty.client) {
        test('a client override is honoured, and re-resolved on a client '
            'change', () async {
          settings
            ..answers[null] = false
            ..answers['c1'] = true;
          final dynamic vm = open();
          await pumpEventQueue();
          expect(vm.draft.usesInclusiveTaxes, isFalse);
          vm.setClientId('c1');
          await pumpEventQueue();
          expect(vm.draft.usesInclusiveTaxes, isTrue);
          vm.setClientId('');
          await pumpEventQueue();
          expect(vm.draft.usesInclusiveTaxes, isFalse);
        });

        test('a prefilled client is resolved on open', () async {
          settings
            ..answers[null] = false
            ..answers['c1'] = true;
          final probe = make(db);
          addTearDown(() => probe.dispose());
          final dynamic vm = open(
            cloneFrom: probe.writer.clientId(probe.writer.empty(), 'c1'),
          );
          await pumpEventQueue();
          expect(vm.draft.usesInclusiveTaxes, isTrue);
          expect(vm.isDirty, isTrue, reason: 'a staged draft is unsaved');
        });

        test(
          'a late answer for client A is ignored once B is picked',
          () async {
            settings
              ..answers['A'] = true
              ..answers['B'] = false
              ..hold = true;
            final dynamic vm = open();
            settings.answer(null);
            vm.setClientId('A');
            vm.setClientId('B');
            settings.answer('B');
            await pumpEventQueue();
            settings.answer('A');
            await pumpEventQueue();
            expect(vm.draft.usesInclusiveTaxes, isFalse);
          },
        );
      } else {
        test('reads the company layer only', () async {
          settings
            ..answers[null] = false
            ..answers['c1'] = true;
          final dynamic vm = open();
          vm.setClientId('c1');
          await pumpEventQueue();
          expect(vm.draft.usesInclusiveTaxes, isFalse);
        });
      }
    });
  }

  test('an answer that arrives after the save leaves the form clean', () async {
    settings
      ..answers[null] = true
      ..hold = true;
    final vm = _docs[BillingDocType.invoice]!(db) as InvoiceEditViewModel;
    addTearDown(() => vm.dispose());
    seedBillingCreateDefaults(
      settings: settings,
      companyId: 'co',
      type: BillingDocType.invoice,
      vm: vm,
    );
    vm.setClientId('c1');
    expect(await vm.save(), isNotNull);
    expect(vm.isDirty, isFalse);
    settings
      ..answer(null)
      ..answer('c1');
    await pumpEventQueue();
    expect(vm.isDirty, isFalse);
    expect(vm.draft.usesInclusiveTaxes, isFalse);
  });

  // project → invoice builds its expense lines before the edit screen opens,
  // so the mode it prices them in must be the mode it stages on the draft.
  test('project → invoice on an inclusive invoice: the line total is the '
      'expense gross', () {
    final expense = _expense(); // 100 net + 20% VAT = 120 gross.
    Decimal totalOn({required bool linesInclusive}) {
      final lines = projectInvoiceLineItems(
        tasks: const [],
        expenses: [expense],
        invoiceInclusive: linesInclusive,
      );
      final invoice = emptyInvoice().copyWith(
        usesInclusiveTaxes: true,
        lineItems: lines,
      );
      return computeTotals(invoice.totalsInput, 2).total;
    }

    expect(totalOn(linesInclusive: true), Decimal.parse('120'));
    expect(
      totalOn(linesInclusive: false),
      Decimal.parse('100'),
      reason: 'lines priced exclusive on an inclusive invoice lose the tax',
    );
  });
}
