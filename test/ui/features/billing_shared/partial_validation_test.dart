// The deposit (`partial`) save check shared by invoice, quote and credit.
//
// A negative total is a real workflow — a retainer invoice that opens at
// `-20 × hourly rate` and is logged up toward zero over the month — and the
// old `partial > total` check rejected it: the default-zero deposit is
// greater than any negative total, so the save asked for a deposit.

// ignore_for_file: avoid_dynamic_calls

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/credits_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/ui/features/credits/view_models/credit_edit_view_model.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';

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

final _viewModels = <String, dynamic Function(AppDatabase db)>{
  'invoice': (db) => InvoiceEditViewModel(
    repo: InvoiceRepository(
      db: db,
      api: _UnusedInvoices(),
      settings: SettingsRepository(db: db),
    ),
    companyId: 'co',
    clientRequiredMessage: 'client',
    crossClientLineItemsMessage: 'cross',
    partialInvalidMessage: 'partial',
  ),
  'quote': (db) => QuoteEditViewModel(
    repo: QuoteRepository(db: db, api: _UnusedQuotes()),
    companyId: 'co',
    clientRequiredMessage: 'client',
    crossClientLineItemsMessage: 'cross',
    partialInvalidMessage: 'partial',
  ),
  'credit': (db) => CreditEditViewModel(
    repo: CreditRepository(db: db, api: _UnusedCredits()),
    companyId: 'co',
    clientRequiredMessage: 'client',
    crossClientLineItemsMessage: 'cross',
    partialInvalidMessage: 'partial',
  ),
};

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  dynamic withTotal(String name, String cost) {
    final vm = _viewModels[name]!(db);
    addTearDown(() => vm.dispose());
    vm.setClientId('c1');
    vm.replaceLineItems([
      emptyLineItem().copyWith(
        notes: 'Retainer',
        cost: Decimal.parse(cost),
        quantity: Decimal.one,
      ),
    ]);
    return vm;
  }

  for (final name in _viewModels.keys) {
    group(name, () {
      test('a negative total with no deposit saves', () {
        final vm = withTotal(name, '-2000');
        expect(vm.totals.total, Decimal.parse('-2000'));
        expect(vm.validate(), isNot(contains('partial')));
      });

      // The server clamps a create's deposit to zero without a word and
      // stores an update's as sent, so the save is the place to refuse it.
      test('a deposit on a negative total is rejected', () {
        final vm = withTotal(name, '-2000');
        vm.setPartial('500');
        expect(vm.validate()['partial'], ['partial']);
      });

      test('a deposit within a positive total saves', () {
        final vm = withTotal(name, '100');
        vm.setPartial('40');
        expect(vm.validate(), isNot(contains('partial')));
      });

      test('a deposit above a positive total is rejected', () {
        final vm = withTotal(name, '100');
        vm.setPartial('150');
        expect(vm.validate()['partial'], ['partial']);
      });

      test('a negative deposit is rejected', () {
        final vm = withTotal(name, '100');
        vm.setPartial('-5');
        expect(vm.validate()['partial'], ['partial']);
      });
    });
  }
}
