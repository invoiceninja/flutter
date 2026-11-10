import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/logging.dart';

/// `redact` feeds the diagnostics log, the debug-capture ring and Sentry
/// (`runWithCrashReporting`), so a Stripe secret must not survive it in any
/// shape it can arrive in (docs/in-person-payments.md).
void main() {
  test('a PaymentIntent client secret is redacted by key and by value', () {
    const secret = 'pi_3PabcDEF123_secret_XyZ987abc';

    final json = redact('{"id":"pi_3PabcDEF123","client_secret":"$secret"}');
    expect(json, isNot(contains('secret_XyZ')));
    expect(json, contains('"client_secret":"<redacted>"'));
    expect(json, contains('"id":"pi_3PabcDEF123"'));

    final text = redact('retrievePaymentIntent($secret) failed');
    expect(text, 'retrievePaymentIntent(<redacted>) failed');
  });

  test('a Terminal connection token is redacted wherever it appears', () {
    expect(redact('token pst_test_YWNjdF8xMjM0_abc'), 'token <redacted>');
    expect(
      redact('{"secret":"pst_live_YWNjdF8xMjM0"}'),
      '{"secret":"<redacted>"}',
    );
  });

  test('a secret inside a percent-encoded URL or query is redacted', () {
    expect(
      redact('u=%22pi_3Pabc_secret_XyZ%22&client_secret%3Dpi_9Q_secret_Ab1'),
      'u=%22<redacted>%22&client_secret%3D<redacted>',
    );
    expect(redact('x%3Apst_live_YWNj-dF8+/='), 'x%3A<redacted>');
  });

  test('ids that only look like a secret are left alone', () {
    const plain = 'pi_3PabcDEF123 ch_3PabcDEF123 pst_unknown tml_FAKE';
    expect(redact(plain), plain);
  });
}
