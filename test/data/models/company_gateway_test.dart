import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/company_gateway_api_model.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/domain/gateway_constants.dart';

void main() {
  group('CompanyGateway.fromApi token_billing normalization', () {
    String billing(String wire) => CompanyGateway.fromApi(
      CompanyGatewayApi(tokenBilling: wire),
    ).tokenBilling;

    test('empty string coerces to off', () {
      expect(billing(''), kAutoBillOff);
    });

    test('value outside the known options coerces to off', () {
      // A non-empty stray value (legacy `opt_out`/`opt_in`, or anything else
      // the server might return) must not reach the Settings-tab dropdown
      // verbatim — it would trip Flutter's "exactly one item" assertion.
      // fromApi is the boundary that normalizes it.
      expect(billing('opt_out'), kAutoBillOff);
      expect(billing('opt_in'), kAutoBillOff);
      expect(billing('garbage'), kAutoBillOff);
    });

    test('known options pass through unchanged', () {
      for (final option in kAutoBillOptions) {
        expect(billing(option), option);
      }
    });
  });

  // Sentry PRODUCTION-85E: a blank `config` on POST /company_gateways is
  // nulled by the server's middleware and 500s on the NOT NULL column.
  group('CompanyGateway.toApiJson config on create', () {
    test('a new gateway with no credentials sends an empty JSON object', () {
      expect(const CompanyGateway().toApiJson()['config'], '{}');
      expect(const CompanyGateway(id: 'tmp_abc').toApiJson()['config'], '{}');
    });

    test('typed credentials are sent as they are', () {
      const config = '{"apiKey":"k"}';
      expect(
        const CompanyGateway(
          id: 'tmp_abc',
          config: config,
        ).toApiJson()['config'],
        config,
      );
    });

    test('an update keeps a blank config blank', () {
      expect(const CompanyGateway(id: 'Wpmbk5ezJn').toApiJson()['config'], '');
    });
  });

  group('CompanyGateway.usesWebSetup', () {
    bool uses(
      String key, {
      required bool isHosted,
      String id = '',
      String config = '',
    }) => CompanyGateway(
      id: id,
      gatewayKey: key,
      config: config,
    ).usesWebSetup(isHosted: isHosted);

    test('Stripe Connect, PayPal Platform and WePay always do', () {
      for (final key in [
        kGatewayStripeConnect,
        kGatewayPayPalPlatform,
        kGatewayWePay,
      ]) {
        expect(uses(key, isHosted: true), isTrue, reason: key);
        expect(uses(key, isHosted: false), isTrue, reason: key);
        expect(uses(key, isHosted: true, id: 'Wpmbk5ezJn'), isTrue);
      }
    });

    test('Square does on hosted only', () {
      expect(uses(kGatewaySquare, isHosted: true), isTrue);
      expect(uses(kGatewaySquare, isHosted: true, id: 'Wpmbk5ezJn'), isTrue);
      expect(uses(kGatewaySquare, isHosted: false), isFalse);
    });

    test('GoCardless does on hosted while new or connected by OAuth', () {
      const key = kGatewayGoCardlessOAuth;
      expect(uses(key, isHosted: true), isTrue);
      expect(uses(key, isHosted: true, id: 'tmp_abc'), isTrue);
      expect(
        uses(key, isHosted: true, id: 'Wpmbk5ezJn', config: '{"oauth2":true}'),
        isTrue,
      );
      // Set up with an access token: its credentials stay editable.
      expect(
        uses(
          key,
          isHosted: true,
          id: 'Wpmbk5ezJn',
          config: '{"accessToken":"t"}',
        ),
        isFalse,
      );
      expect(uses(key, isHosted: false), isFalse);
    });

    test('an ordinary gateway never does', () {
      expect(uses(kGatewayStripe, isHosted: true), isFalse);
      expect(uses(kGatewayStripe, isHosted: false), isFalse);
    });
  });
}
