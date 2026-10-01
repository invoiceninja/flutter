import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/ui/features/settings/views/advanced/email_settings/mailer_check.dart';

/// The `mailer/check` request (React #3357), validated against
/// `CheckMailerRequest::rules`.
void main() {
  test(
    'OAuth mailers send only the mailer — the server uses the saved user',
    () {
      final r = buildMailerCheckPayload(
        method: 'gmail',
        settings: const CompanySettings(),
        userEmail: 'me@acme.test',
      );
      expect(r.payload, {'mailer': 'gmail'});
      expect(r.missing, isEmpty);
    },
  );

  test('Mailgun carries its secret, domain and endpoint', () {
    final r = buildMailerCheckPayload(
      method: 'client_mailgun',
      settings: const CompanySettings(
        mailgunSecret: 'key-1',
        mailgunDomain: 'mg.acme.test',
        customSendingEmail: 'billing@acme.test',
        emailFromName: 'Acme',
      ),
      userEmail: 'me@acme.test',
    );
    expect(r.missing, isEmpty);
    expect(r.payload, {
      'mailer': 'client_mailgun',
      'from_address': 'billing@acme.test',
      'from_name': 'Acme',
      'mailgun_secret': 'key-1',
      'mailgun_domain': 'mg.acme.test',
      'mailgun_endpoint': 'api.mailgun.net',
    });
  });

  test('SES prefers its own from address and names what is missing', () {
    final r = buildMailerCheckPayload(
      method: 'client_ses',
      settings: const CompanySettings(
        sesFromAddress: 'ses@acme.test',
        customSendingEmail: 'billing@acme.test',
        sesAccessKey: 'AKIA',
      ),
      userEmail: 'me@acme.test',
    );
    expect(r.payload['from_address'], 'ses@acme.test');
    expect(r.missing, ['ses_secret_key', 'ses_region']);
  });

  test('the signed-in user is the from address of last resort', () {
    final r = buildMailerCheckPayload(
      method: 'client_postmark',
      settings: const CompanySettings(postmarkSecret: 'tok'),
      userEmail: 'me@acme.test',
    );
    expect(r.payload['from_address'], 'me@acme.test');
    expect(r.missing, isEmpty);
  });

  test("SMTP is not this endpoint's business", () {
    expect(supportsMailerCheck('smtp'), isFalse);
    expect(supportsMailerCheck('client_brevo'), isTrue);
    expect(supportsMailerCheck('office365'), isTrue);
  });
}
