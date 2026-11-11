import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/repositories/company_gateway_repository.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/ui/features/gateways/view_models/company_gateway_edit_view_model.dart';

/// The VM stores the repo but never calls it for these pure-default checks.
class _FakeGatewayRepo implements CompanyGatewayRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('CompanyGatewayEditViewModel new-gateway defaults', () {
    test('initialDraft and emptyDraft both seed token_billing = always', () {
      final vm = CompanyGatewayEditViewModel(
        repo: _FakeGatewayRepo(),
        companyId: 'co-1',
      );
      // Both new-gateway factories must agree (React + admin-portal default to
      // `always`); a divergence means "discard changes" silently flips the
      // setting versus a fresh create.
      expect(vm.draft.tokenBilling, kAutoBillAlways);
      expect(vm.emptyDraft().tokenBilling, kAutoBillAlways);
    });

    test(
      'initialDraft and emptyDraft seed accepted_credit_cards = all brands',
      () {
        final vm = CompanyGatewayEditViewModel(
          repo: _FakeGatewayRepo(),
          companyId: 'co-1',
        );
        // Seeded to all brands (31) so a new gateway never sends
        // `accepted_credit_cards: 0` — which would disable every card brand if
        // the server honors the field. The brand-picker UI is intentionally gone.
        expect(vm.draft.acceptedCreditCards, kAllCreditCardTypes);
        expect(vm.emptyDraft().acceptedCreditCards, kAllCreditCardTypes);
      },
    );
  });

  // Sentry PRODUCTION-85E: Save on a new PayPal Platform gateway posted a
  // record the web setup was about to create itself.
  group('CompanyGatewayEditViewModel.isCreatedOnWeb', () {
    CompanyGatewayEditViewModel vm(String key, {CompanyGateway? existing}) =>
        CompanyGatewayEditViewModel(
          repo: _FakeGatewayRepo(),
          companyId: 'co-1',
          existing: existing,
          initialGatewayKey: key,
        );

    test('a new web-setup gateway has nothing to save', () {
      expect(vm(kGatewayPayPalPlatform).isCreatedOnWeb(isHosted: true), isTrue);
      expect(vm(kGatewaySquare).isCreatedOnWeb(isHosted: true), isTrue);
    });

    test('a self-hosted Square gateway is a form, so it saves', () {
      expect(vm(kGatewaySquare).isCreatedOnWeb(isHosted: false), isFalse);
    });

    test('an existing web-setup gateway still saves its settings', () {
      const existing = CompanyGateway(
        id: 'Wpmbk5ezJn',
        gatewayKey: kGatewayPayPalPlatform,
      );
      expect(
        vm(
          kGatewayPayPalPlatform,
          existing: existing,
        ).isCreatedOnWeb(isHosted: true),
        isFalse,
      );
    });

    test('an ordinary new gateway saves', () {
      expect(vm(kGatewayStripe).isCreatedOnWeb(isHosted: true), isFalse);
    });
  });
}
