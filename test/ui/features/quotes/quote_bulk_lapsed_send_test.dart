import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/quote_status.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/ui/features/quotes/view_models/quote_list_view_model.dart';

/// Bulk Mark Sent and Email skip a quote past its valid-until date.
/// `BulkActionQuoteRequest` 422s the WHOLE request if any id has lapsed
/// (`Quote::hasLapsedValidUntil`), so one stray row would dead-letter the
/// batch — but only on a server that enforces it.
void main() {
  late AppDatabase db;
  final vms = <QuoteListViewModel>[];

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  tearDown(() async {
    for (final vm in vms) {
      vm.dispose();
    }
    vms.clear();
    await db.close();
  });

  bool eligible(String actionId, Quote q, {required bool enforces}) {
    final vm = QuoteListViewModel(
      repo: QuoteRepository(db: db, api: _UnusedQuotesApi()),
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      blocksLapsedSends: () => enforces,
    );
    vms.add(vm);
    return vm.bulkActions.firstWhere((a) => a.id == actionId).eligible(q);
  }

  Quote draft({String dueDate = ''}) => Quote.fromApi(
    QuoteApi(id: 'q1', statusId: QuoteStatus.draft.wireId, dueDate: dueDate),
  );

  for (final actionId in ['mark_sent', 'email']) {
    test('$actionId skips a lapsed quote', () {
      expect(eligible(actionId, draft(), enforces: true), isTrue);
      expect(
        eligible(actionId, draft(dueDate: '2999-01-01'), enforces: true),
        isTrue,
      );
      expect(
        eligible(actionId, draft(dueDate: '2000-01-01'), enforces: true),
        isFalse,
      );
    });

    test('$actionId still sends a lapsed quote on an older server', () {
      expect(
        eligible(actionId, draft(dueDate: '2000-01-01'), enforces: false),
        isTrue,
      );
    });
  }
}

class _UnusedQuotesApi implements QuotesApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
