import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/features/payment_links/widgets/payment_link_actions.dart';

import '../shell/_shell_test_helpers.dart';

/// Coverage for the Payment Link clone action (invoiceninja/flutter#62).
///
/// Two halves:
///   * `cloneDraftFor` is pure — what it strips is what keeps the server's
///     `StoreSubscriptionRequest` happy (unique + present `name`) and what
///     keeps the *source's* public purchase URL off the clone's detail
///     screen while the offline create is still pending;
///   * the action item is Pro-gated, mirroring the list's `canCreate`.
PaymentLink _source() => emptyPaymentLink().copyWith(
  id: 'sub_1',
  userId: 'u1',
  companyId: 'co1',
  name: 'Pro Monthly',
  price: Decimal.parse('19.50'),
  currencyId: '1',
  frequencyId: '5',
  productIds: 'p1,p2',
  recurringProductIds: 'rp1',
  optionalProductIds: 'op1',
  optionalRecurringProductIds: 'orp1',
  groupId: 'g1',
  autoBill: 'always',
  remainingCycles: 12,
  refundPeriod: 604800,
  trialEnabled: true,
  trialDuration: 86400,
  promoCode: 'LAUNCH',
  promoDiscount: Decimal.parse('10'),
  isAmountDiscount: true,
  allowCancellation: true,
  registrationRequired: true,
  perSeatEnabled: true,
  maxSeatsLimit: 25,
  steps: 'cart,auth.login-or-register,rff',
  webhookConfiguration: const PaymentLinkWebhook(
    returnUrl: 'https://example.test/thanks',
    postPurchaseUrl: 'https://example.test/hook',
    postPurchaseRestMethod: 'post',
    postPurchaseHeaders: {'X-Token': 'abc'},
    postPurchaseBody: '{}',
  ),
  purchasePage: 'https://co.invoicing.co/client/subscriptions/sub_1/purchase',
  planMap: 'legacy-blob',
  updatedAt: DateTime.utc(2026, 8, 20, 12),
  createdAt: DateTime.utc(2026, 8, 1, 12),
  archivedAt: DateTime.utc(2026, 8, 22, 12),
  isDeleted: true,
  isDirty: true,
);

void main() {
  const epoch0 = 0;

  group('PaymentLinkActions.cloneDraftFor', () {
    test('strips identity, lifecycle and server-owned fields', () {
      final draft = PaymentLinkActions.cloneDraftFor(_source());

      expect(draft.id, isEmpty, reason: 'empty id makes the VM a create');
      expect(draft.archivedAt, isNull);
      expect(draft.isDeleted, isFalse);
      expect(draft.isDirty, isFalse);
      expect(draft.createdAt.millisecondsSinceEpoch, epoch0);
      expect(draft.updatedAt.millisecondsSinceEpoch, epoch0);
      // Built from the SOURCE's hashed id, and the repo persists it into the
      // local row — carrying it would show the source's public URL on the
      // clone's detail screen until the create drains.
      expect(draft.purchasePage, isEmpty);
      expect(draft.planMap, isEmpty);
    });

    test('suffixes the name so the unique-per-company rule is satisfied', () {
      expect(
        PaymentLinkActions.cloneDraftFor(_source()).name,
        'Pro Monthly (copy)',
      );
    });

    test('leaves an empty name empty rather than emitting a bare suffix', () {
      final draft = PaymentLinkActions.cloneDraftFor(
        _source().copyWith(name: ''),
      );

      expect(draft.name, isEmpty);
    });

    test('carries the whole configuration payload over', () {
      final src = _source();
      final draft = PaymentLinkActions.cloneDraftFor(src);

      expect(draft.price, src.price);
      expect(draft.currencyId, src.currencyId);
      expect(draft.frequencyId, src.frequencyId);
      expect(draft.remainingCycles, src.remainingCycles);
      expect(draft.autoBill, src.autoBill);
      expect(draft.groupId, src.groupId);
      // Shared product *references*, not owned children — safe to copy.
      expect(draft.productIds, src.productIds);
      expect(draft.recurringProductIds, src.recurringProductIds);
      expect(draft.optionalProductIds, src.optionalProductIds);
      expect(
        draft.optionalRecurringProductIds,
        src.optionalRecurringProductIds,
      );
      expect(draft.promoCode, src.promoCode);
      expect(draft.promoDiscount, src.promoDiscount);
      expect(draft.isAmountDiscount, isTrue);
      expect(draft.allowCancellation, isTrue);
      expect(draft.refundPeriod, src.refundPeriod);
      expect(draft.trialEnabled, isTrue);
      expect(draft.trialDuration, src.trialDuration);
      expect(draft.perSeatEnabled, isTrue);
      expect(draft.maxSeatsLimit, src.maxSeatsLimit);
      expect(draft.registrationRequired, isTrue);
      // `steps` is server-validated on create; the source's set is valid.
      expect(draft.steps, src.steps);
      expect(draft.webhookConfiguration, src.webhookConfiguration);
      expect(draft.webhookConfiguration.postPurchaseHeaders, {
        'X-Token': 'abc',
      });
    });
  });

  group('PaymentLinkActions.isLifecycle', () {
    test('clone is lifecycle, so the create screen drops it', () {
      expect(PaymentLinkActions.isLifecycle(PaymentLinkAction.clone), isTrue);
    });

    test('edit is not', () {
      expect(PaymentLinkActions.isLifecycle(PaymentLinkAction.edit), isFalse);
    });
  });

  group('PaymentLinkActions.itemsFor — clone is Pro-gated', () {
    Future<List<EntityActionItem<PaymentLinkAction>>> resolveItems(
      WidgetTester tester, {
      String plan = 'pro',
    }) async {
      final fixture = await buildFixture(
        companies: const [FakeCompany(id: 'co1', name: 'Co')],
        plan: plan,
      );
      addTearDown(fixture.dispose);

      late List<EntityActionItem<PaymentLinkAction>> items;
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          Builder(
            builder: (context) {
              items = PaymentLinkActions.itemsFor(context, _source(), (_) {});
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return items;
    }

    bool enabled(
      List<EntityActionItem<PaymentLinkAction>> items,
      PaymentLinkAction kind,
    ) {
      final match = flattenActionItems(items).where((i) => i.kind == kind);
      return match.isNotEmpty && match.first.enabled;
    }

    testWidgets('enabled on a Pro plan', (tester) async {
      final items = await resolveItems(tester);

      expect(
        flattenActionItems(items).any((i) => i.kind == PaymentLinkAction.clone),
        isTrue,
      );
      expect(enabled(items, PaymentLinkAction.clone), isTrue);
    });

    testWidgets('disabled on a hosted free plan, like the New button', (
      tester,
    ) async {
      final items = await resolveItems(tester, plan: '');

      expect(
        flattenActionItems(items).any((i) => i.kind == PaymentLinkAction.clone),
        isTrue,
      );
      expect(enabled(items, PaymentLinkAction.clone), isFalse);
    });
  });
}
