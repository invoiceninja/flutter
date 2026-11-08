import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invitation_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/api/recurring_invoice_api_model.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/data/services/credits_api.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/data/services/recurring_invoices_api.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A billing document's stored row keeps its invitations whole, while the save
/// request sends only what the server reads (docs/contacts-and-invitations.md).
/// Before this the stored row *was* the wire projection, so a local save
/// stripped every invitation's sent / viewed / delivery state until the
/// server's echo landed, and a second offline save could not get it back.
class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakePurchaseOrdersApi implements PurchaseOrdersApi {
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

class _FakeRecurringInvoicesApi implements RecurringInvoicesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _sent = InvitationApi(
  id: 'inv-a',
  key: 'key-a',
  link: 'https://portal/a',
  clientContactId: 'contact-a',
  sentDate: '2026-11-01 10:00:00',
  viewedDate: '2026-11-02 11:00:00',
  emailStatus: 'delivered',
  messageId: 'm-1',
  canSign: true,
);

const _legacy = InvitationApi(
  id: 'inv-b',
  key: 'key-b',
  clientContactId: 'contact-b',
  sentDate: '2026-11-01 10:00:00',
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<List<Map<String, dynamic>>> wireInvitations() async {
    final rows = await db.outboxDao.watchAll('co').first;
    final payload = jsonDecode(rows.last.payload) as Map<String, dynamic>;
    return (payload['invitations'] as List).cast<Map<String, dynamic>>();
  }

  group('an invoice', () {
    late InvoiceRepository repo;
    setUp(
      () => repo = InvoiceRepository(
        db: db,
        api: _FakeInvoicesApi(),
        settings: SettingsRepository(db: db),
      ),
    );

    Future<void> seed() => repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: const InvoiceApi(
        id: 'i1',
        number: 'I1',
        statusId: '2',
        updatedAt: 1700000000,
        invitations: [_sent, _legacy],
      ),
    );

    Future<Invoice> read() async =>
        (await repo.watch(companyId: 'co', id: 'i1').first)!;

    test(
      'keeps every invitation lifecycle field across two offline saves',
      () async {
        await seed();
        await repo.save(
          companyId: 'co',
          invoice: (await read()).copyWith(number: 'I2'),
        );
        await repo.save(
          companyId: 'co',
          invoice: (await read()).copyWith(number: 'I3'),
        );

        final invitations = (await read()).invitations;
        final a = invitations.firstWhere((x) => x.id == 'inv-a');
        expect(a.key, 'key-a');
        expect(a.link, 'https://portal/a');
        expect(a.sentDate, '2026-11-01 10:00:00');
        expect(a.viewedDate, '2026-11-02 11:00:00');
        expect(a.emailStatus, 'delivered');
        expect(a.messageId, 'm-1');
        expect(a.canSign, isTrue);
        final b = invitations.firstWhere((x) => x.id == 'inv-b');
        expect(b.sentDate, '2026-11-01 10:00:00');
        expect(b.canSign, isNull);
      },
    );

    test('sends only what the server reads, and never a key alone', () async {
      await seed();
      await repo.save(
        companyId: 'co',
        invoice: (await read()).copyWith(number: 'I2'),
      );

      final wire = await wireInvitations();
      final a = wire.firstWhere((x) => x['id'] == 'inv-a');
      expect(a, {
        'id': 'inv-a',
        'key': 'key-a',
        'client_contact_id': 'contact-a',
        'can_sign': true,
      });
      // Its can_sign is unknown, so it takes the key-less restore path that
      // keeps whatever the server holds.
      final b = wire.firstWhere((x) => x['id'] == 'inv-b');
      expect(b, {'id': 'inv-b', 'client_contact_id': 'contact-b'});
      for (final x in wire) {
        if (x.containsKey('key')) expect(x.containsKey('can_sign'), isTrue);
        expect(x.containsKey('sent_date'), isFalse);
      }
    });
  });

  test('a purchase order keeps its vendor invitations whole too', () async {
    final repo = PurchaseOrderRepository(db: db, api: _FakePurchaseOrdersApi());
    await repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: const PurchaseOrderApi(
        id: 'po1',
        number: 'PO1',
        statusId: '2',
        updatedAt: 1700000000,
        invitations: [
          InvitationApi(
            id: 'pi',
            key: 'pk',
            vendorContactId: 'vc',
            viewedDate: '2026-11-02 11:00:00',
            canSign: false,
          ),
        ],
      ),
    );
    final stored = await repo.watch(companyId: 'co', id: 'po1').first;
    await repo.save(
      companyId: 'co',
      purchaseOrder: stored!.copyWith(number: 'PO2'),
    );
    final edited = await repo.watch(companyId: 'co', id: 'po1').first;
    final i = edited!.invitations.single;
    expect(i.viewedDate, '2026-11-02 11:00:00');
    expect(i.canSign, isFalse);

    final wire = await wireInvitations();
    expect(wire.single, {
      'id': 'pi',
      'key': 'pk',
      'vendor_contact_id': 'vc',
      'can_sign': false,
    });
  });

  // Each repository spreads `toPayloadJson` into its own stored row, so each
  // is pinned: a lifecycle field survives a local save, and the request
  // carries the key only with can_sign.
  Future<void> expectWhole(Future<List<dynamic>> Function() invitations) async {
    final stored = await invitations();
    final a = stored.firstWhere((x) => x.id == 'inv-a');
    expect(a.viewedDate, '2026-11-02 11:00:00');
    expect(a.emailStatus, 'delivered');
    expect(a.canSign, isTrue);
    final wire = await wireInvitations();
    expect(wire.firstWhere((x) => x['id'] == 'inv-a'), {
      'id': 'inv-a',
      'key': 'key-a',
      'client_contact_id': 'contact-a',
      'can_sign': true,
    });
    expect(wire.firstWhere((x) => x['id'] == 'inv-b'), {
      'id': 'inv-b',
      'client_contact_id': 'contact-b',
    });
  }

  test('a quote keeps its invitations whole too', () async {
    final repo = QuoteRepository(db: db, api: _FakeQuotesApi());
    await repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: const QuoteApi(
        id: 'q1',
        number: 'Q1',
        statusId: '2',
        updatedAt: 1700000000,
        invitations: [_sent, _legacy],
      ),
    );
    final stored = await repo.watch(companyId: 'co', id: 'q1').first;
    await repo.save(
      companyId: 'co',
      quote: stored!.copyWith(number: 'Q2'),
    );
    await expectWhole(
      () async =>
          (await repo.watch(companyId: 'co', id: 'q1').first)!.invitations,
    );
  });

  test('a credit keeps its invitations whole too', () async {
    final repo = CreditRepository(db: db, api: _FakeCreditsApi());
    await repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: const CreditApi(
        id: 'c1',
        number: 'C1',
        statusId: '2',
        updatedAt: 1700000000,
        invitations: [_sent, _legacy],
      ),
    );
    final stored = await repo.watch(companyId: 'co', id: 'c1').first;
    await repo.save(
      companyId: 'co',
      credit: stored!.copyWith(number: 'C2'),
    );
    await expectWhole(
      () async =>
          (await repo.watch(companyId: 'co', id: 'c1').first)!.invitations,
    );
  });

  test('a recurring invoice keeps its invitations whole too', () async {
    final repo = RecurringInvoiceRepository(
      db: db,
      api: _FakeRecurringInvoicesApi(),
    );
    await repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: const RecurringInvoiceApi(
        id: 'r1',
        number: 'R1',
        statusId: '2',
        updatedAt: 1700000000,
        invitations: [_sent, _legacy],
      ),
    );
    final stored = await repo.watch(companyId: 'co', id: 'r1').first;
    await repo.save(
      companyId: 'co',
      recurringInvoice: stored!.copyWith(number: 'R2'),
    );
    await expectWhole(
      () async =>
          (await repo.watch(companyId: 'co', id: 'r1').first)!.invitations,
    );
  });
}
