import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/credit_status.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/domain/purchase_order_status.dart';
import 'package:admin/ui/features/billing_shared/billing_cross_clone.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';

void main() {
  final source = emptyInvoice().copyWith(
    id: 'inv_9',
    number: 'INV-9',
    clientId: 'client_1',
    statusId: InvoiceStatus.paid,
    paidToDate: Decimal.fromInt(50),
    discount: Decimal.fromInt(5),
    isAmountDiscount: true,
    taxName1: 'GST',
    taxRate1: Decimal.fromInt(10),
    usesInclusiveTaxes: true,
    publicNotes: 'note',
    poNumber: 'PO-1',
    customValue1: 'cv1',
    lineItems: [
      emptyLineItem().copyWith(productKey: 'WIDGET', cost: Decimal.fromInt(20)),
    ],
  );

  test(
    'invoice→credit clone carries content but resets identity/paid/status',
    () {
      final credit = cloneToCredit(billingCloneFromInvoice(source));
      // Reset (must NOT leak from a Paid source):
      expect(credit.id, '');
      expect(credit.number, '');
      expect(credit.statusId, CreditStatus.draft);
      expect(credit.paidToDate, Decimal.zero);
      // Carried content:
      expect(credit.clientId, 'client_1');
      expect(credit.discount, Decimal.fromInt(5));
      expect(credit.isAmountDiscount, true);
      expect(credit.taxName1, 'GST');
      expect(credit.taxRate1, Decimal.fromInt(10));
      expect(credit.usesInclusiveTaxes, true);
      expect(credit.publicNotes, 'note');
      expect(credit.poNumber, 'PO-1');
      expect(credit.customValue1, 'cv1');
      expect(credit.lineItems.single.productKey, 'WIDGET');
    },
  );

  test('invoice→purchase_order clone drops the client (vendor-billed)', () {
    final po = cloneToPurchaseOrder(billingCloneFromInvoice(source));
    expect(po.statusId, PurchaseOrderStatus.draft);
    expect(po.clientId, ''); // not carried — PO has no client
    expect(
      po.invitations,
      isEmpty,
    ); // client-contact invitations don't transfer
    expect(po.lineItems.single.productKey, 'WIDGET'); // content still carried
    expect(po.taxName1, 'GST');
  });

  test('an hourly line stays hourly on an invoice, but not on a PO', () {
    // The server prints no task table on a purchase order, so a type-2 line
    // there would count in the totals and print nowhere.
    final hourly = source.copyWith(
      lineItems: [
        emptyLineItem().copyWith(
          productKey: 'Consulting',
          cost: Decimal.fromInt(50),
          quantity: Decimal.fromInt(2),
          typeId: LineItemType.task,
          taskId: 'task_1',
        ),
      ],
    );
    final invoice = cloneToInvoice(billingCloneFromInvoice(hourly));
    expect(invoice.lineItems.single.typeId, LineItemType.task);
    expect(invoice.lineItems.single.taskId, isNull);

    final po = cloneToPurchaseOrder(billingCloneFromInvoice(hourly));
    expect(po.lineItems.single.typeId, LineItemType.standard);
  });
}
