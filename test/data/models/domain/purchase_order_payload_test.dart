import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/domain/purchase_order.dart';

/// `PurchaseOrderPayload.toApiJson` is the only purchase-order serializer —
/// the save, the stored Drift payload and the live preview all go through it.
void main() {
  group('PurchaseOrder.toApiJson source links', () {
    test('omits invoice_id and quote_id when the PO has neither — the server '
        'takes an empty string as "clear the link"', () {
      // A PO cached before `quote_id` was modelled: its stored payload has no
      // such key, so it decodes to '' — and sending that back on an edit
      // nulled the quote link server-side.
      final po = PurchaseOrder.fromApi(
        PurchaseOrderApi.fromJson({
          'id': 'po1',
          'number': 'PO-1',
          'vendor_id': 'v1',
        }),
      );
      expect(po.invoiceId, isEmpty);
      expect(po.quoteId, isEmpty);

      final json = po.toApiJson();
      expect(json.containsKey('invoice_id'), isFalse);
      expect(json.containsKey('quote_id'), isFalse);
    });

    test('sends both links when they are set', () {
      final po = PurchaseOrder.fromApi(
        PurchaseOrderApi.fromJson({
          'id': 'po1',
          'number': 'PO-1',
          'vendor_id': 'v1',
          'invoice_id': 'inv1',
          'quote_id': 'q1',
        }),
      );

      final json = po.toApiJson();
      expect(json['invoice_id'], 'inv1');
      expect(json['quote_id'], 'q1');
    });
  });
}
