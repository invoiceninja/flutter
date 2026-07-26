import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/payment_status.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/features/payments/widgets/payment_actions.dart';

import '../../shell/_shell_test_helpers.dart';

/// Gating coverage for `PaymentActions.itemsFor`, mirroring the harness in
/// `purchase_order_actions_test.dart`.
///
/// The invariant worth locking down is **Refund**: it needs BOTH
/// `canRefund` (something left to refund, and a Completed / Partially-refunded
/// status) AND `hasInvoiceAllocations`. The refund screen is
/// invoice-allocation-only by design (React parity — there is no
/// client-account-refund path), so offering Refund on an unapplied payment
/// dead-ends the user on an empty screen.
///
/// Payment is the one action class that reads no permissions — gating is
/// purely entity state.
Payment _payment({
  String id = 'pay1',
  String statusId = kPaymentStatusCompleted,
  String amount = '100',
  String refunded = '0',
  List<PaymentableApi> paymentables = const [],
  bool isDeleted = false,
  int archivedAt = 0,
}) => Payment.fromApi(
  PaymentApi(
    id: id,
    statusId: statusId,
    amount: amount,
    refunded: refunded,
    paymentables: paymentables,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
  ),
);

const _invoiceAllocation = PaymentableApi(invoiceId: 'inv1', amount: '100');
const _creditAllocation = PaymentableApi(creditId: 'cr1', amount: '100');

void main() {
  Future<List<EntityActionItem<PaymentAction>>> resolveItems(
    WidgetTester tester,
    Payment payment,
  ) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);

    late List<EntityActionItem<PaymentAction>> items;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            items = PaymentActions.itemsFor(context, payment, (_) {});
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return items;
  }

  bool enabled(
    List<EntityActionItem<PaymentAction>> items,
    PaymentAction kind,
  ) {
    final match = flattenActionItems(items).where((i) => i.kind == kind);
    return match.isNotEmpty && match.first.enabled;
  }

  bool present(
    List<EntityActionItem<PaymentAction>> items,
    PaymentAction kind,
  ) => flattenActionItems(items).any((i) => i.kind == kind);

  group('refund needs an invoice allocation AND a refundable balance', () {
    testWidgets('completed payment applied to an invoice → enabled', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _payment(paymentables: const [_invoiceAllocation]),
      );

      expect(enabled(items, PaymentAction.refund), isTrue);
    });

    testWidgets('unapplied payment (no allocations) → disabled', (
      tester,
    ) async {
      final items = await resolveItems(tester, _payment());

      expect(
        enabled(items, PaymentAction.refund),
        isFalse,
        reason:
            'the refund screen has no client-account-refund path, so an '
            'unapplied payment would dead-end',
      );
    });

    testWidgets('credit-only allocation → disabled', (tester) async {
      final items = await resolveItems(
        tester,
        _payment(paymentables: const [_creditAllocation]),
      );

      expect(
        enabled(items, PaymentAction.refund),
        isFalse,
        reason: 'hasInvoiceAllocations looks for a non-empty invoiceId',
      );
    });

    testWidgets('fully refunded payment → disabled even with an allocation', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _payment(
          amount: '100',
          refunded: '100',
          paymentables: const [_invoiceAllocation],
        ),
      );

      expect(enabled(items, PaymentAction.refund), isFalse);
    });

    testWidgets('partially refunded payment → still enabled', (tester) async {
      final items = await resolveItems(
        tester,
        _payment(
          statusId: kPaymentStatusPartiallyRefunded,
          amount: '100',
          refunded: '40',
          paymentables: const [_invoiceAllocation],
        ),
      );

      expect(enabled(items, PaymentAction.refund), isTrue);
    });

    testWidgets('a pending (non-completed) payment → disabled', (tester) async {
      final items = await resolveItems(
        tester,
        _payment(statusId: '1', paymentables: const [_invoiceAllocation]),
      );

      expect(enabled(items, PaymentAction.refund), isFalse);
    });

    testWidgets('a fully refunded status → disabled', (tester) async {
      final items = await resolveItems(
        tester,
        _payment(
          statusId: kPaymentStatusRefunded,
          paymentables: const [_invoiceAllocation],
        ),
      );

      expect(enabled(items, PaymentAction.refund), isFalse);
    });
  });

  group('send email', () {
    testWidgets('enabled on a live payment', (tester) async {
      final items = await resolveItems(tester, _payment());

      expect(enabled(items, PaymentAction.sendEmail), isTrue);
    });

    testWidgets('disabled once deleted', (tester) async {
      final items = await resolveItems(tester, _payment(isDeleted: true));

      expect(enabled(items, PaymentAction.sendEmail), isFalse);
    });
  });

  group('lifecycle actions reflect entity state', () {
    testWidgets('a live payment offers archive and delete, not restore', (
      tester,
    ) async {
      final items = await resolveItems(tester, _payment());

      expect(present(items, PaymentAction.archive), isTrue);
      expect(present(items, PaymentAction.delete), isTrue);
      expect(present(items, PaymentAction.restore), isFalse);
    });

    testWidgets('an archived payment offers restore, not archive', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _payment(archivedAt: 1700000000),
      );

      expect(present(items, PaymentAction.restore), isTrue);
      expect(present(items, PaymentAction.archive), isFalse);
    });

    testWidgets('a deleted payment offers restore but not delete', (
      tester,
    ) async {
      final items = await resolveItems(tester, _payment(isDeleted: true));

      expect(present(items, PaymentAction.restore), isTrue);
      expect(present(items, PaymentAction.delete), isFalse);
    });
  });

  testWidgets('edit and add-comment are always available', (tester) async {
    final items = await resolveItems(tester, _payment(isDeleted: true));

    expect(enabled(items, PaymentAction.edit), isTrue);
    expect(enabled(items, PaymentAction.addComment), isTrue);
  });

  group('isLifecycle marks exactly the create-screen-hidden actions', () {
    test('archive, restore and delete are lifecycle; the rest are not', () {
      expect(PaymentActions.isLifecycle(PaymentAction.archive), isTrue);
      expect(PaymentActions.isLifecycle(PaymentAction.restore), isTrue);
      expect(PaymentActions.isLifecycle(PaymentAction.delete), isTrue);
      expect(PaymentActions.isLifecycle(PaymentAction.edit), isFalse);
      expect(PaymentActions.isLifecycle(PaymentAction.refund), isFalse);
      expect(PaymentActions.isLifecycle(PaymentAction.sendEmail), isFalse);
    });

    test('only refund navigates unconditionally after a create', () {
      expect(PaymentActions.navigatesOnCreate(PaymentAction.refund), isTrue);
      expect(PaymentActions.navigatesOnCreate(PaymentAction.edit), isFalse);
      expect(
        PaymentActions.navigatesOnCreate(PaymentAction.sendEmail),
        isFalse,
      );
    });
  });
}
