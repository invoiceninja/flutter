import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/expense_category_api_model.dart';
import 'package:admin/data/models/api/token_api_model.dart';
import 'package:admin/data/models/api/webhook_api_model.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/models/domain/token.dart';
import 'package:admin/data/models/domain/webhook.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/data/repositories/token_repository.dart';
import 'package:admin/data/repositories/webhook_repository.dart';
import 'package:admin/data/services/expense_categories_api.dart';
import 'package:admin/data/services/tokens_api.dart';
import 'package:admin/data/services/webhooks_api.dart';
import 'package:admin/ui/features/expense_categories/view_models/expense_category_edit_view_model.dart';
import 'package:admin/ui/features/tokens/view_models/token_edit_view_model.dart';
import 'package:admin/ui/features/webhooks/view_models/webhook_edit_view_model.dart';

/// Covers the three remaining entity edit VMs that had zero references under
/// `test/`: webhooks, API tokens and expense categories.
///
/// Each is small enough that the whole surface is `draftIsNonEmpty()` (the
/// discard-changes prompt) plus `performSave()` routing create vs update to the
/// right repository call. Grouped in one file because the shape is identical
/// and a file each would be mostly boilerplate.
class _FakeWebhooksApi implements WebhooksApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeTokensApi implements TokensApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeExpenseCategoriesApi implements ExpenseCategoriesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<int> pendingOutboxCount() async {
    final rows = await db.outboxDao.nextReady(companyId: 'co', now: 1 << 60);
    return rows.length;
  }

  group('WebhookEditViewModel', () {
    WebhookEditViewModel vmFor([Webhook? existing]) => WebhookEditViewModel(
      repo: WebhookRepository(db: db, api: _FakeWebhooksApi()),
      companyId: 'co',
      existing: existing,
    );

    test('a fresh create reads as empty', () {
      expect(vmFor().draftIsNonEmpty(), isFalse);
    });

    test('a target URL marks it dirty', () {
      expect(
        (vmFor()..setTargetUrl('https://hooks.example.com')).draftIsNonEmpty(),
        isTrue,
      );
    });

    test('an event id alone marks it dirty', () {
      expect((vmFor()..setEventId('1')).draftIsNonEmpty(), isTrue);
    });

    test(
      'the rest method is not part of the dirty check (it is defaulted)',
      () {
        expect((vmFor()..setRestMethod('post')).draftIsNonEmpty(), isFalse);
      },
    );

    test('a create enqueues one outbox row', () async {
      final vm = vmFor()
        ..setTargetUrl('https://hooks.example.com')
        ..setEventId('1');

      expect(await vm.save(), isNotNull);
      expect(await pendingOutboxCount(), 1);
    });

    test('an edit enqueues an update', () async {
      final existing = Webhook.fromApi(
        const WebhookApi(
          id: 'w1',
          targetUrl: 'https://old.example.com',
          updatedAt: 1700000000,
        ),
      );
      final vm = vmFor(existing)..setTargetUrl('https://new.example.com');

      expect(await vm.save(), isNotNull);
      expect(await pendingOutboxCount(), 1);
    });
  });

  group('TokenEditViewModel', () {
    TokenEditViewModel vmFor([Token? existing]) => TokenEditViewModel(
      repo: TokenRepository(db: db, api: _FakeTokensApi()),
      companyId: 'co',
      existing: existing,
    );

    test('a fresh create reads as empty', () {
      expect(vmFor().draftIsNonEmpty(), isFalse);
    });

    test('a whitespace-only name does not count as input', () {
      expect((vmFor()..setName('   ')).draftIsNonEmpty(), isFalse);
    });

    test('a real name marks it dirty', () {
      expect((vmFor()..setName('CI token')).draftIsNonEmpty(), isTrue);
    });

    test('a create enqueues one outbox row', () async {
      final vm = vmFor()..setName('CI token');

      expect(await vm.save(), isNotNull);
      expect(await pendingOutboxCount(), 1);
    });

    test('an edit enqueues an update', () async {
      final existing = Token.fromApi(
        const TokenApi(id: 't1', name: 'Old', updatedAt: 1700000000),
      );
      final vm = vmFor(existing)..setName('Renamed');

      expect(await vm.save(), isNotNull);
      expect(await pendingOutboxCount(), 1);
    });
  });

  group('ExpenseCategoryEditViewModel', () {
    ExpenseCategoryEditViewModel vmFor([ExpenseCategory? existing]) =>
        ExpenseCategoryEditViewModel(
          repo: ExpenseCategoryRepository(
            db: db,
            api: _FakeExpenseCategoriesApi(),
          ),
          companyId: 'co',
          existing: existing,
        );

    test('a fresh create reads as empty', () {
      expect(vmFor().draftIsNonEmpty(), isFalse);
    });

    test('a name marks it dirty', () {
      expect((vmFor()..setName('Travel')).draftIsNonEmpty(), isTrue);
    });

    test('a colour alone marks it dirty', () {
      expect((vmFor()..setColor('#ff0000')).draftIsNonEmpty(), isTrue);
    });

    test('a create enqueues one outbox row', () async {
      final vm = vmFor()..setName('Travel');

      expect(await vm.save(), isNotNull);
      expect(await pendingOutboxCount(), 1);
    });

    test('cloneFrom seeds the draft but still saves as a create', () {
      final source = ExpenseCategory.fromApi(
        const ExpenseCategoryApi(
          id: 'ec1',
          name: 'Source',
          updatedAt: 1700000000,
        ),
      );
      final vm = ExpenseCategoryEditViewModel(
        repo: ExpenseCategoryRepository(
          db: db,
          api: _FakeExpenseCategoriesApi(),
        ),
        companyId: 'co',
        cloneFrom: source,
      );

      expect(vm.draft.name, 'Source');
      expect(vm.isCreate, isTrue);
    });
  });
}
