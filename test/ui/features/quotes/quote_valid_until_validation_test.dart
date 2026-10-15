// The server refuses a quote's valid-until date once it is in the past — on a
// create (`IsExpiredRule`), and on an update that changes it
// (`UpdateQuoteRequest`). The edit form says so before a save queues a row
// that could only die.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';

class _UnusedQuotes implements QuotesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  final yesterday = Date.today().addDays(-1);
  final tomorrow = Date.today().addDays(1);

  QuoteEditViewModel vmFor({Quote? existing, bool enforces = true}) =>
      QuoteEditViewModel(
        repo: QuoteRepository(db: db, api: _UnusedQuotes()),
        companyId: 'co',
        clientRequiredMessage: 'client required',
        crossClientLineItemsMessage: '',
        partialInvalidMessage: '',
        enforcesValidUntil: () => enforces,
        validUntilPastMessage: 'in the past',
        existing: existing,
      )..setClientId('c1');

  Quote saved(String dueDate) =>
      Quote.fromApi(QuoteApi(id: 'q1', clientId: 'c1', dueDate: dueDate));

  test('a new quote cannot be valid until a date already gone', () {
    final vm = vmFor()..setDueDate(yesterday);
    expect(vm.validateAndPublish(), isFalse);
    expect(vm.fieldErrorFor('due_date'), 'in the past');

    vm.setDueDate(tomorrow);
    expect(vm.validateAndPublish(), isTrue);

    vm.setDueDate(Date.today());
    expect(vm.validateAndPublish(), isTrue, reason: 'valid through the day');
  });

  test('an existing quote may keep a past date it already had', () {
    final vm = vmFor(existing: saved(yesterday.toIso()));
    expect(vm.validateAndPublish(), isTrue);
  });

  test('an existing quote may not be moved onto a past date', () {
    final vm = vmFor(existing: saved(tomorrow.toIso()))..setDueDate(yesterday);
    expect(vm.validateAndPublish(), isFalse);
    expect(vm.fieldErrorFor('due_date'), 'in the past');
  });

  test('an older server accepts a past date, so nothing is checked', () {
    final vm = vmFor(enforces: false)..setDueDate(yesterday);
    expect(vm.validateAndPublish(), isTrue);
  });

  test('lapsed is the date alone, whatever the status', () {
    expect(saved(yesterday.toIso()).hasLapsedValidUntil, isTrue);
    expect(saved(Date.today().toIso()).hasLapsedValidUntil, isFalse);
    expect(saved('').hasLapsedValidUntil, isFalse);
  });
}
