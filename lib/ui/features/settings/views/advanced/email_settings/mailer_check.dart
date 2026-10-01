import 'package:admin/data/models/domain/company_settings.dart';

/// The OAuth mailers: tested against the company's SAVED sending user — the
/// server resolves it itself, so the request carries nothing but the mailer.
const Set<String> kOAuthMailers = {'gmail', 'microsoft', 'office365'};

/// The API mailers `mailer/check` can test.
const Set<String> kApiMailers = {
  'client_brevo',
  'client_mailgun',
  'client_postmark',
  'client_ses',
};

/// Whether `mailer/check` covers [method] (SMTP keeps its own `smtp/check`).
bool supportsMailerCheck(String method) =>
    kOAuthMailers.contains(method) || kApiMailers.contains(method);

/// The `mailer/check` request for [method], from the settings being edited
/// (React #3357's `useCheckMailer`), plus the API keys of required values
/// still missing — non-empty means "don't send yet".
///
/// The from address is the one a real send would use: SES's own
/// `ses_from_address`, else the company's custom sending email, else the
/// signed-in user's address. Secrets come from the draft, so an unsaved key
/// can be tested before it's saved.
({Map<String, dynamic> payload, List<String> missing}) buildMailerCheckPayload({
  required String method,
  required CompanySettings settings,
  required String userEmail,
}) {
  if (kOAuthMailers.contains(method)) {
    return (payload: {'mailer': method}, missing: const []);
  }
  String t(String? v) => (v ?? '').trim();
  final missing = <String>[];
  String need(String apiKey, String? value) {
    final v = t(value);
    if (v.isEmpty) missing.add(apiKey);
    return v;
  }

  final fromAddress = [
    if (method == 'client_ses') t(settings.sesFromAddress),
    t(settings.customSendingEmail),
    t(userEmail),
  ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
  if (fromAddress.isEmpty) missing.add('from_address');
  final fromName = t(settings.emailFromName);

  final payload = <String, dynamic>{
    'mailer': method,
    'from_address': fromAddress,
    if (fromName.isNotEmpty) 'from_name': fromName,
  };
  switch (method) {
    case 'client_brevo':
      payload['brevo_secret'] = need('brevo_secret', settings.brevoSecret);
    case 'client_mailgun':
      payload['mailgun_secret'] = need(
        'mailgun_secret',
        settings.mailgunSecret,
      );
      payload['mailgun_domain'] = need(
        'mailgun_domain',
        settings.mailgunDomain,
      );
      final endpoint = t(settings.mailgunEndpoint);
      payload['mailgun_endpoint'] = endpoint.isEmpty
          ? 'api.mailgun.net'
          : endpoint;
    case 'client_postmark':
      payload['postmark_secret'] = need(
        'postmark_secret',
        settings.postmarkSecret,
      );
    case 'client_ses':
      payload['ses_access_key'] = need('ses_access_key', settings.sesAccessKey);
      payload['ses_secret_key'] = need('ses_secret_key', settings.sesSecretKey);
      payload['ses_region'] = need('ses_region', settings.sesRegion);
      final arn = t(settings.sesTopicArn);
      if (arn.isNotEmpty) payload['ses_topic_arn'] = arn;
  }
  return (payload: payload, missing: missing);
}
