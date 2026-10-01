import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/quote_status.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/features/quotes/view_models/quote_list_view_model.dart';

/// Bulk Cancel (invoiceninja/ui#3393). `BulkActionQuoteRequest` 422s the
/// WHOLE request unless every id reads as Sent — and a past-due Sent quote
/// reads as Expired — so eligibility must match the single-quote gate exactly
/// or one stray row dead-letters the batch.
void main() {
  late AppDatabase db;
  late BulkAction<Quote> cancel;
  late QuoteListViewModel vm;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vm = QuoteListViewModel(
      repo: QuoteRepository(db: db, api: _UnusedQuotesApi()),
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
    );
    cancel = vm.bulkActions.firstWhere((a) => a.id == 'cancel');
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  Quote quote(
    QuoteStatus status, {
    String dueDate = '',
    bool deleted = false,
  }) => Quote.fromApi(
    QuoteApi(
      id: 'q1',
      statusId: status.wireId,
      dueDate: dueDate,
      isDeleted: deleted,
    ),
  );

  test('confirmed, and labelled as the single action is', () {
    expect(cancel.confirm, isTrue);
    expect(cancel.labelKey, 'cancel_quote');
  });

  test('only a live Sent quote is eligible', () {
    for (final status in QuoteStatus.values) {
      expect(
        cancel.eligible(quote(status)),
        status == QuoteStatus.sent,
        reason: status.name,
      );
    }
  });

  test('a lapsed or deleted Sent quote is not', () {
    expect(
      cancel.eligible(quote(QuoteStatus.sent, dueDate: '2000-01-01')),
      isFalse,
    );
    expect(cancel.eligible(quote(QuoteStatus.sent, deleted: true)), isFalse);
  });
}

class _UnusedQuotesApi implements QuotesApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
