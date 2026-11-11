import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/ui/features/gateways/oauth_setup_launcher.dart';

void main() {
  String? url(String key, {String baseUrl = 'https://invoicing.co'}) =>
      buildOAuthSetupUrl(
        gatewayKey: key,
        baseUrl: baseUrl,
        hash: 'h4sh',
      )?.toString();

  test('every web-setup gateway has a setup URL', () {
    // A missing case is a Gateway Setup button that only shows an error.
    for (final key in {
      ...kWebSetupGatewayKeys,
      ...kHostedWebSetupGatewayKeys,
    }) {
      expect(url(key), isNotNull, reason: key);
    }
  });

  test('the URLs are the server web routes', () {
    expect(
      url(kGatewayStripeConnect),
      'https://invoicing.co/stripe/signup/h4sh',
    );
    expect(
      url(kGatewayPayPalPlatform),
      'https://invoicing.co/paypal?hash=h4sh',
    );
    expect(
      url(kGatewayGoCardlessOAuth),
      'https://invoicing.co/gocardless/oauth/connect/h4sh',
    );
    expect(
      url(kGatewaySquare),
      'https://invoicing.co/square/oauth/connect/h4sh',
    );
  });

  test('a base URL ending in /api/v1 lands on the bare host', () {
    expect(
      url(kGatewaySquare, baseUrl: 'https://invoicing.co/api/v1/'),
      'https://invoicing.co/square/oauth/connect/h4sh',
    );
  });

  test('an ordinary gateway has none', () {
    expect(url(kGatewayStripe), isNull);
  });
}
