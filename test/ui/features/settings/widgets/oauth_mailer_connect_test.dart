import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/widgets/oauth_mailer_connect.dart';

void main() {
  group('mailerConnectUri', () {
    test('Microsoft is /auth/microsoft — the server 400s "microsoft365"', () {
      expect(
        mailerConnectUri('https://invoicing.co', isGoogle: false).toString(),
        'https://invoicing.co/auth/microsoft',
      );
    });

    test('Google is /auth/google', () {
      expect(
        mailerConnectUri('https://invoicing.co', isGoogle: true).toString(),
        'https://invoicing.co/auth/google',
      );
    });

    test('keeps a self-hosted sub-path and drops a trailing slash', () {
      expect(
        mailerConnectUri(
          'https://example.com/ninja/',
          isGoogle: true,
        ).toString(),
        'https://example.com/ninja/auth/google',
      );
    });
  });

  test('canLaunchMailerConnect needs a base URL', () {
    expect(canLaunchMailerConnect(''), isFalse);
  });
}
