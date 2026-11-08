import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/domain/docuninja/docuninja_signed.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A quote's or purchase order's `sync` blob is server-written and read-only:
/// `toApiJson` leaves it off the wire, so the repository keeps it in the stored
/// row itself, as it does for invoices. Without that, a local edit drops
/// `sync.dn_completed` and the "Signed Document" pill disappears until the
/// server's echo lands (never, offline).
class _FakeQuotesApi implements QuotesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakePurchaseOrdersApi implements PurchaseOrdersApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _signed = <String, dynamic>{
  'dn_completed': true,
  'dn_document_hashed_id': 'abc',
  'invitations': [
    {'invitation_key': 'k1', 'dn_id': 'dn-doc-1', 'dn_invitation_id': 'i1'},
  ],
};

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('a quote keeps its DocuNinja sync across a local edit', () async {
    final repo = QuoteRepository(db: db, api: _FakeQuotesApi());
    await repo.applyUpdateResponse(
      companyId: 'co',
      serverResponse: const QuoteApi(
        id: 'q1',
        number: 'Q1',
        statusId: '2',
        updatedAt: 1700000000,
        sync: _signed,
      ),
    );
    final stored = await repo.watch(companyId: 'co', id: 'q1').first;
    expect(isDocuNinjaSigned(stored!.sync), isTrue);
    expect(stored.toApiJson().containsKey('sync'), isFalse);

    await repo.save(
      companyId: 'co',
      quote: stored.copyWith(number: 'Q2'),
    );
    final edited = await repo.watch(companyId: 'co', id: 'q1').first;
    expect(edited!.number, 'Q2');
    expect(isDocuNinjaSigned(edited.sync), isTrue);
    expect(docuNinjaDocumentId(edited.sync), 'dn-doc-1');
  });

  test(
    'a purchase order keeps its DocuNinja sync across a local edit',
    () async {
      final repo = PurchaseOrderRepository(
        db: db,
        api: _FakePurchaseOrdersApi(),
      );
      await repo.applyUpdateResponse(
        companyId: 'co',
        serverResponse: const PurchaseOrderApi(
          id: 'po1',
          number: 'PO1',
          statusId: '2',
          updatedAt: 1700000000,
          sync: _signed,
        ),
      );
      final stored = await repo.watch(companyId: 'co', id: 'po1').first;
      expect(isDocuNinjaSigned(stored!.sync), isTrue);
      expect(stored.toApiJson().containsKey('sync'), isFalse);

      await repo.save(
        companyId: 'co',
        purchaseOrder: stored.copyWith(number: 'PO2'),
      );
      final edited = await repo.watch(companyId: 'co', id: 'po1').first;
      expect(edited!.number, 'PO2');
      expect(isDocuNinjaSigned(edited.sync), isTrue);
    },
  );
}
