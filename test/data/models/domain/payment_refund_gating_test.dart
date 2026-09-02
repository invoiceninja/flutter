import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/payment_status.dart';

/// M2 / M3: refund gating + the allocated-amount the Full-refund label must
/// show. The refund flow is invoice-allocation-only (matching React + server),
/// so the Refund action must be gated on [Payment.hasInvoiceAllocations], and
/// the Full-refund figure is the sum of allocations, NOT [Payment.refundable]
/// (which includes unapplied funds the server won't refund through this path).
void main() {
  Payment payment({
    required String amount,
    String refunded = '0',
    String statusId = kPaymentStatusCompleted,
    List<PaymentableApi> paymentables = const [],
  }) => Payment.fromApi(
    PaymentApi(
      id: 'p1',
      amount: amount,
      refunded: refunded,
      statusId: statusId,
      paymentables: paymentables,
      updatedAt: 1,
    ),
  );

  group('M2 — Refund action gating', () {
    test('an unapplied payment (no invoice allocations) is not refundable via '
        'the action', () {
      final p = payment(
        amount: '100',
      ); // completed, refundable, no paymentables
      expect(
        p.canRefund,
        isTrue,
        reason: 'refundable funds + completed status',
      );
      expect(
        p.hasInvoiceAllocations,
        isFalse,
        reason: 'no invoice paymentables → the refund screen would dead-end',
      );
    });

    test('a payment applied to an invoice is refundable', () {
      final p = payment(
        amount: '100',
        paymentables: const [PaymentableApi(invoiceId: 'i1', amount: '100')],
      );
      expect(p.canRefund, isTrue);
      expect(p.hasInvoiceAllocations, isTrue);
    });

    test('credit-only allocations do not count as invoice allocations', () {
      final p = payment(
        amount: '100',
        paymentables: const [PaymentableApi(creditId: 'cr1', amount: '100')],
      );
      expect(p.hasInvoiceAllocations, isFalse);
    });
  });

  group('M3 — Full-refund amount = allocated sum, not refundable', () {
    test(
      'unapplied funds: allocated sum (60) differs from refundable (100)',
      () {
        final p = payment(
          amount: '100',
          paymentables: const [PaymentableApi(invoiceId: 'i1', amount: '60')],
        );
        // refundable spans the whole payment...
        expect(p.refundable, Decimal.fromInt(100));
        // ...but Full mode only refunds the allocated 60.
        final allocated = p.paymentables
            .where((pa) => pa.invoiceId.isNotEmpty)
            .fold(Decimal.zero, (s, pa) => s + (pa.amount - pa.refunded));
        expect(allocated, Decimal.fromInt(60));
        expect(allocated, isNot(equals(p.refundable)));
      },
    );
  });

  // The payment detail strip hides its Refunded / Refundable pair on this
  // predicate (invoiceninja/flutter#113), so what counts as "a refund exists"
  // is load-bearing for what the user can see.
  group('hasRefund — the detail strip\'s refund-pair gate', () {
    test('no refund recorded', () {
      expect(payment(amount: '100').hasRefund, isFalse);
    });

    test('a refund recorded', () {
      expect(payment(amount: '100', refunded: '25').hasRefund, isTrue);
    });

    test('a negative refunded figure still counts', () {
      // `!= zero`, not `> zero`: a negative is a data anomaly, and hiding it
      // would leave the user staring at a strip that silently omits it.
      expect(payment(amount: '100', refunded: '-25').hasRefund, isTrue);
    });
  });
}
