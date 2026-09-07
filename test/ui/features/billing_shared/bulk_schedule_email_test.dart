// Regression: the bulk "Email → Schedule for later" path on all four billing
// list ViewModels.
//
// Three defects lived here, none of which any test could see because the
// bulk actions are built inside each list VM and nothing exercised the
// `applyArg` closure:
//
//   1. `sendAt` was sent as `scheduledFor.toUtc().toIso8601String()`. The
//      server truncates `send_at` to a date-only `next_run`, so converting
//      shifts an evening pick to the NEXT calendar day east of UTC and to the
//      PREVIOUS one west of it — firing a day late, or immediately because the
//      date is already past. `billing_doc_email_screen.dart` had already fixed
//      exactly this for the single-document composer; the four bulk call sites
//      never got it.
//   2. `ccEmail` was forwarded on the `email` branch and silently DROPPED on
//      the `scheduleEmail` branch, so a CC typed into the bulk compose sheet
//      never reached anyone.
//   3. A scheduled batch reported itself with the send-now copy.
//
// The assertions are written to be non-vacuous under CI's UTC clock (see
// CLAUDE.md § Strict rules): a LOCAL `DateTime.toIso8601String()` never ends
// in `Z`, while `.toUtc().toIso8601String()` always does — true in every zone,
// UTC included.

import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/credits_api.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart';
import 'package:admin/ui/features/credits/view_models/credit_list_view_model.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_list_view_model.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_list_view_model.dart';
import 'package:admin/ui/features/quotes/view_models/quote_list_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeInvoicesApi implements InvoicesApi {
  @override
  Future<({InvoiceListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async => (
    data: const InvoiceListApi(data: []),
    cursorUpdatedAt: null,
    cursorId: null,
  );

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeQuotesApi implements QuotesApi {
  @override
  Future<({QuoteListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async => (
    data: const QuoteListApi(data: []),
    cursorUpdatedAt: null,
    cursorId: null,
  );

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeCreditsApi implements CreditsApi {
  @override
  Future<({CreditListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async => (
    data: const CreditListApi(data: []),
    cursorUpdatedAt: null,
    cursorId: null,
  );

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakePurchaseOrdersApi implements PurchaseOrdersApi {
  @override
  Future<({PurchaseOrderListApi data, int? cursorUpdatedAt, String? cursorId})>
  list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async => (
    data: const PurchaseOrderListApi(data: []),
    cursorUpdatedAt: null,
    cursorId: null,
  );

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Every entity's `email` bulk action, keyed by the label used in failures.
  /// Each entry builds the real list VM over a real repository + in-memory
  /// Drift, so `applyArg` reaches the genuine `enqueueMutation` and the
  /// assertion reads the outbox row the drain would actually send.
  Map<String, BulkAction<Object?>> buildActions() {
    final userSettings = UserSettingsRepository(db: db);
    final settings = SettingsRepository(db: db);

    BulkAction<Object?> emailActionOf(Iterable<BulkAction<Object?>> actions) =>
        actions.firstWhere((a) => a.id == 'email');

    final invoiceVm = InvoiceListViewModel(
      repo: InvoiceRepository(
        db: db,
        api: _FakeInvoicesApi(),
        settings: settings,
      ),
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: userSettings,
    );
    final quoteVm = QuoteListViewModel(
      repo: QuoteRepository(db: db, api: _FakeQuotesApi()),
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: userSettings,
    );
    final creditVm = CreditListViewModel(
      repo: CreditRepository(db: db, api: _FakeCreditsApi()),
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: userSettings,
    );
    final poVm = PurchaseOrderListViewModel(
      repo: PurchaseOrderRepository(db: db, api: _FakePurchaseOrdersApi()),
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: userSettings,
    );

    return {
      'invoice': emailActionOf(invoiceVm.bulkActions.cast()),
      'quote': emailActionOf(quoteVm.bulkActions.cast()),
      'credit': emailActionOf(creditVm.bulkActions.cast()),
      'purchase_order': emailActionOf(poVm.bulkActions.cast()),
    };
  }

  Future<Map<String, dynamic>> payloadOf(String entityId) async {
    final rows = await db.outboxDao.pendingRowsForCompany('co');
    final row = rows.firstWhere((r) => r.entityId == entityId);
    return jsonDecode(row.payload) as Map<String, dynamic>;
  }

  test(
    'a scheduled bulk email sends send_at in LOCAL time, never UTC',
    () async {
      // 22:30 — the pick most likely to cross a date boundary under
      // `.toUtc()`, which is the bug. Kept far from midnight UTC is NOT
      // possible here (the whole point is an evening local time), so the
      // assertion is on the STRING SHAPE rather than on a calendar day: a
      // local ISO string carries no `Z`, in every zone including CI's UTC.
      final pick = DateTime(2026, 3, 14, 22, 30);
      final actions = buildActions();

      for (final entry in actions.entries) {
        final id = '${entry.key}_1';
        await entry.value.applyArg!(
          id,
          BillingEmailResult(
            template: 'reminder1',
            subject: '',
            body: '',
            ccEmail: '',
            scheduledFor: pick,
          ),
        );
        await settle();

        final payload = await payloadOf(id);
        expect(
          payload['send_at'],
          pick.toIso8601String(),
          reason: '${entry.key}: send_at must be the local ISO string',
        );
        expect(
          payload['send_at'] as String,
          isNot(endsWith('Z')),
          reason:
              '${entry.key}: a trailing Z means .toUtc() crept back in — the '
              'server truncates send_at to a date, so that shifts the run day',
        );
      }
    },
  );

  test('a scheduled bulk email forwards the CC address', () async {
    final actions = buildActions();

    for (final entry in actions.entries) {
      final id = '${entry.key}_cc';
      await entry.value.applyArg!(
        id,
        BillingEmailResult(
          template: 'reminder1',
          subject: 'subj',
          body: 'body',
          ccEmail: 'cc@example.com',
          scheduledFor: DateTime(2026, 3, 14, 11, 30),
        ),
      );
      await settle();

      final payload = await payloadOf(id);
      expect(
        payload['cc_email'],
        'cc@example.com',
        reason: '${entry.key}: a CC typed into the bulk sheet must be sent',
      );
      expect(payload['subject'], 'subj', reason: entry.key);
      expect(payload['body'], 'body', reason: entry.key);
    }
  });

  test('an unscheduled bulk email still takes the send-now branch', () async {
    final actions = buildActions();

    for (final entry in actions.entries) {
      final id = '${entry.key}_now';
      await entry.value.applyArg!(
        id,
        const BillingEmailResult(
          template: 'reminder1',
          subject: '',
          body: '',
          ccEmail: 'cc@example.com',
        ),
      );
      await settle();

      final payload = await payloadOf(id);
      expect(
        payload.containsKey('send_at'),
        isFalse,
        reason: '${entry.key}: no schedule was picked',
      );
      expect(payload['cc_email'], 'cc@example.com', reason: entry.key);
    }
  });

  test(
    'empty subject / body / cc are omitted rather than sent blank',
    () async {
      final actions = buildActions();
      final action = actions['invoice']!;
      await action.applyArg!(
        'inv_blank',
        BillingEmailResult(
          template: 'reminder1',
          subject: '',
          body: '',
          ccEmail: '',
          scheduledFor: DateTime(2026, 3, 14, 11, 30),
        ),
      );
      await settle();

      final payload = await payloadOf('inv_blank');
      expect(payload.containsKey('subject'), isFalse);
      expect(payload.containsKey('body'), isFalse);
      expect(payload.containsKey('cc_email'), isFalse);
      expect(payload['template'], 'reminder1');
    },
  );
}
