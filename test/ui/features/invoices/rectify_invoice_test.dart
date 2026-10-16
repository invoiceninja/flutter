import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/line_item_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/invoices/widgets/rectify_invoice.dart';

Invoice _invoice({
  String id = 'inv1',
  String statusId = '2', // sent
  String amount = '100',
  String balance = '100',
  Map<String, dynamic>? backup = const {
    'document_type': 'F1',
    'adjustable_amount': 50,
  },
  bool isDeleted = false,
}) => Invoice.fromApi(
  InvoiceApi(
    id: id,
    statusId: statusId,
    clientId: 'c1',
    amount: amount,
    balance: balance,
    backup: backup,
    isDeleted: isDeleted,
    lineItems: const [
      LineItemApi(cost: '40', quantity: '2'),
      LineItemApi(cost: '20', quantity: '1'),
    ],
  ),
);

void main() {
  group('isRectifyEligible', () {
    test('all conditions met → true', () {
      expect(
        isRectifyEligible(
          invoice: _invoice(),
          clientCountryId: '724',
          eInvoiceType: 'VERIFACTU',
        ),
        isTrue,
      );
    });

    test('each condition individually flipped → false', () {
      // not sent — draft / partial / paid all excluded (strict React parity:
      // only status_id == Sent, NOT the broader Invoice.isSent).
      for (final s in ['1', '3', '4']) {
        expect(
          isRectifyEligible(
            invoice: _invoice(statusId: s),
            clientCountryId: '724',
            eInvoiceType: 'VERIFACTU',
          ),
          isFalse,
          reason: 'statusId $s must not be rectify-eligible',
        );
      }
      // client country not Spain
      expect(
        isRectifyEligible(
          invoice: _invoice(),
          clientCountryId: '840',
          eInvoiceType: 'VERIFACTU',
        ),
        isFalse,
      );
      // company e_invoice_type not VERIFACTU
      expect(
        isRectifyEligible(
          invoice: _invoice(),
          clientCountryId: '724',
          eInvoiceType: 'EN16931',
        ),
        isFalse,
      );
      // document_type not F1
      expect(
        isRectifyEligible(
          invoice: _invoice(
            backup: const {'document_type': 'R1', 'adjustable_amount': 50},
          ),
          clientCountryId: '724',
          eInvoiceType: 'VERIFACTU',
        ),
        isFalse,
      );
      // adjustable_amount <= 0
      expect(
        isRectifyEligible(
          invoice: _invoice(
            backup: const {'document_type': 'F1', 'adjustable_amount': 0},
          ),
          clientCountryId: '724',
          eInvoiceType: 'VERIFACTU',
        ),
        isFalse,
      );
      // amount <= 0
      expect(
        isRectifyEligible(
          invoice: _invoice(amount: '0'),
          clientCountryId: '724',
          eInvoiceType: 'VERIFACTU',
        ),
        isFalse,
      );
      // deleted
      expect(
        isRectifyEligible(
          invoice: _invoice(isDeleted: true),
          clientCountryId: '724',
          eInvoiceType: 'VERIFACTU',
        ),
        isFalse,
      );
      // null async inputs
      expect(
        isRectifyEligible(
          invoice: _invoice(),
          clientCountryId: null,
          eInvoiceType: null,
        ),
        isFalse,
      );
    });

    test('rectifyPreGate is the invoice-only subset', () {
      expect(rectifyPreGate(_invoice()), isTrue);
      expect(rectifyPreGate(_invoice(statusId: '1')), isFalse); // draft
      expect(rectifyPreGate(_invoice(statusId: '3')), isFalse); // partial
      expect(rectifyPreGate(_invoice(statusId: '4')), isFalse); // paid
      expect(rectifyPreGate(_invoice(amount: '0')), isFalse);
    });
  });

  group('rectifiedDraft', () {
    test(
      'clears identity, negates amounts/quantities, sets rectify fields',
      () {
        final original = _invoice();
        final draft = rectifiedDraft(original, 'wrong amount');

        expect(draft.id, '');
        expect(draft.number, '');
        expect(draft.statusId, InvoiceStatus.draft);
        expect(draft.date!.toIso(), Date.today().toIso());
        expect(draft.dueDate, isNull);
        expect(draft.isDeleted, isFalse);
        expect(draft.archivedAt, isNull);
        expect(draft.modifiedInvoiceId, 'inv1');
        expect(draft.reason, 'wrong amount');
        // Documents cleared (React parity: a fresh corrective invoice must not
        // carry the original's attachments into the editor).
        expect(draft.documents, isEmpty);

        // amount/balance negated
        expect(draft.amount, Decimal.fromInt(-100));
        expect(draft.balance, Decimal.fromInt(-100));

        // every line-item quantity negated (−abs)
        expect(draft.lineItems[0].quantity, Decimal.fromInt(-2));
        expect(draft.lineItems[1].quantity, Decimal.fromInt(-1));
        // cost is left untouched (gross = cost*qty becomes negative)
        expect(draft.lineItems[0].cost, Decimal.fromInt(40));
      },
    );

    test(
      'recomputed subtotal is negative (negate-quantity-only is correct)',
      () {
        final draft = rectifiedDraft(_invoice(), 'r');
        final subtotal = computeSubtotal(
          BillingTotalsInput(
            lineItems: draft.lineItems,
            discount: draft.discount,
            isAmountDiscount: draft.isAmountDiscount,
            usesInclusiveTaxes: draft.usesInclusiveTaxes,
          ),
          2,
        );
        // original subtotal = 40*2 + 20*1 = 100 → negated = -100
        expect(subtotal, Decimal.fromInt(-100));
        expect(subtotal < Decimal.zero, isTrue);
      },
    );

    test('payload carries modified_invoice_id + reason', () {
      final json = rectifiedDraft(_invoice(), 'duplicate billing').toApiJson();
      expect(json['modified_invoice_id'], 'inv1');
      expect(json['reason'], 'duplicate billing');
    });

    // `backup` is the source's e-invoice state: carried, the unsent draft
    // listed as "sent over PEPPOL" and wore the source's F1 chip.
    test("drops the source's e-invoice state", () {
      final source = _invoice(
        backup: const {
          'document_type': 'F1',
          'adjustable_amount': 50,
          'guid': 'peppol-guid',
        },
      );
      expect(rectifiedDraft(source, 'r').backup, isNull);
    });
  });
}
