import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';

/// Guards the per-type capability flags the shared billing widgets branch on.
void main() {
  group('BillingDocType.supportsScheduledSend', () {
    test('recurring invoices cannot be scheduled (server task_scheduler '
        'rejects them) — so the email composer hides its Schedule action', () {
      expect(BillingDocType.recurringInvoice.supportsScheduledSend, isFalse);
    });

    test('every other billing doc supports a scheduled send', () {
      for (final t in BillingDocType.values) {
        if (t == BillingDocType.recurringInvoice) continue;
        expect(
          t.supportsScheduledSend,
          isTrue,
          reason: '$t should support scheduled send',
        );
      }
    });
  });

  group('BillingDocType.supportsDeliveryNote', () {
    test('invoice-only', () {
      for (final t in BillingDocType.values) {
        expect(t.supportsDeliveryNote, t == BillingDocType.invoice);
      }
    });
  });

  group('the edit layout\'s capability spec', () {
    // `BillingDocEditLayout` is ONE layout for five documents; every way they
    // differ is one of these values. A value that changes changes a screen,
    // so each is pinned — the accidental differences too (the partial
    // field's three placements, the recurring invoice's desktop number
    // label), since unifying them is a product decision.
    const i = BillingDocType.invoice;
    const q = BillingDocType.quote;
    const c = BillingDocType.credit;
    const p = BillingDocType.purchaseOrder;
    const r = BillingDocType.recurringInvoice;

    Map<BillingDocType, Object?> of(Object? Function(BillingDocType) read) => {
      for (final t in BillingDocType.values) t: read(t),
    };

    test('party', () {
      expect(of((t) => t.party), {
        i: BillingDocParty.client,
        q: BillingDocParty.client,
        c: BillingDocParty.client,
        p: BillingDocParty.vendor,
        r: BillingDocParty.client,
      });
    });

    test('labels', () {
      expect(of((t) => t.dateLabelKey), {
        i: 'invoice_date',
        q: 'quote_date',
        c: 'credit_date',
        p: 'purchase_order_date',
        r: null,
      });
      expect(of((t) => t.dueDateLabelKey), {
        i: 'due_date',
        q: 'valid_until',
        c: 'due_date',
        p: 'due_date',
        r: null,
      });
      expect(of((t) => t.numberLabelKey), {
        i: 'invoice_number',
        q: 'quote_number',
        c: 'credit_number',
        p: 'po_number',
        r: 'recurring_invoice_number',
      });
      expect(of((t) => t.desktopNumberLabelKey), {
        i: 'invoice_number',
        q: 'quote_number',
        c: 'credit_number',
        p: 'po_number',
        r: 'invoice_number',
      });
      expect(of((t) => t.hasPoNumberField), {
        i: true,
        q: true,
        c: true,
        p: false,
        r: true,
      });
    });

    test('partial payment', () {
      expect(of((t) => t.mobilePartialPlacement), {
        i: BillingDocPartialPlacement.afterDatesRow,
        q: BillingDocPartialPlacement.afterDiscount,
        c: BillingDocPartialPlacement.afterDates,
        p: BillingDocPartialPlacement.none,
        r: BillingDocPartialPlacement.none,
      });
      expect(of((t) => t.hasPartial), {
        i: true,
        q: true,
        c: true,
        p: false,
        r: false,
      });
    });

    test('features', () {
      expect(of((t) => t.supportsCreateTaskFromLineItem), {
        i: true,
        q: true,
        c: false,
        p: false,
        r: false,
      });
      expect(of((t) => t.excludesInactiveTabFocus), {
        i: false,
        q: false,
        c: false,
        p: false,
        r: true,
      });
      expect(of((t) => t.showsProductStock), {
        i: true,
        q: false,
        c: false,
        p: false,
        r: false,
      });
    });

    test('terms / footer defaults, and the recurring invoice has none', () {
      expect(of((t) => t.termsDefaultKey), {
        i: 'invoice_terms',
        q: 'quote_terms',
        c: 'credit_terms',
        p: 'purchase_order_terms',
        r: null,
      });
      expect(of((t) => t.footerDefaultKey), {
        i: 'invoice_footer',
        q: 'quote_footer',
        c: 'credit_footer',
        p: 'purchase_order_footer',
        r: null,
      });
    });

    test('hero tags derive from the wire name', () {
      for (final t in BillingDocType.values) {
        expect(t.pickerFabHeroTag, '${t.wireName}_picker_fab');
        expect(t.mobilePickerFabHeroTag, '${t.wireName}_picker_fab_mobile');
      }
    });
  });
}
