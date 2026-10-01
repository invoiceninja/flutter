import 'package:admin/data/services/api_client.dart';

/// API for `POST /api/v1/smtp/check` — the "Send Test Email" probe on
/// Settings → Email Settings. Verifies the SMTP credentials the user just
/// entered (or the company's saved SMTP settings) by attempting a real
/// connection + send. Returns the server's status message verbatim so the
/// toast can quote it.
///
/// **Bypasses the outbox** because it's a probe, not a mutation — there's
/// no entity to persist optimistically, and a retry-on-resume of the failed
/// connect attempt would be confusing rather than helpful. The user runs
/// it ad-hoc and reads the response immediately. Matches the React /
/// admin-portal precedent.
class SmtpApi {
  SmtpApi(this.client);

  final ApiClient client;

  /// POST the SMTP config to `/smtp/check`. [payload] is the seven-field
  /// `{ smtp_host, smtp_port, smtp_encryption, smtp_username, smtp_password,
  /// smtp_local_domain, smtp_verify_peer }` map. Returns the server's
  /// `message` field (e.g. `"Successfully sent email"`). Throws on
  /// connection / auth failure — the caller surfaces it via `Notify.error`.
  Future<String> check({required Map<String, dynamic> payload}) async {
    final raw = await client.postJson('/api/v1/smtp/check', body: payload);
    if (raw is Map<String, dynamic>) {
      final message = raw['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return '';
  }

  /// `POST /api/v1/mailer/check` — the same probe for the API and OAuth
  /// mailers (Gmail / Microsoft / Brevo / Mailgun / Postmark / SES, React
  /// #3357). [payload] is built by `buildMailerCheckPayload`. Admin-only and
  /// throttled to 10 a minute server-side; a failed send is a **400** with a
  /// generic message, so the caller shows its own copy with that as detail.
  Future<String> checkMailer({required Map<String, dynamic> payload}) async {
    final raw = await client.postJson('/api/v1/mailer/check', body: payload);
    if (raw is Map<String, dynamic>) {
      final message = raw['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return '';
  }
}
