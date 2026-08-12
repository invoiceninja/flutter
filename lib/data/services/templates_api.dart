import 'package:admin/data/services/api_client.dart';
import 'package:admin/domain/email_template_names.dart';

/// Renders an email template against a document, returning the
/// server-substituted subject, body, and full HTML wrapper that back the
/// preview panel on Settings → Templates & Reminders and in the send-email
/// composer.
///
/// The `/api/v1/templates` endpoint takes a subject + body string and a
/// template type, runs it through the server-side variable substitution
/// engine (`$client`, `$amount`, `$due_date`, …), and returns the rendered
/// HTML.
///
/// **Callers with a document in hand must pass `entity` + `entityId`.** The
/// server binds the real record only when *both* are non-empty
/// (`TemplateEngine::setEntity()`); otherwise it sniffs the template name for
/// a `quote` / `purchase` / `payment` substring and falls back to
/// `<Model>::whereHas('invitations')->withTrashed()->company()->first()` — an
/// unordered pick of the company's oldest matching record, soft-deleted rows
/// included. That fallback is what rendered another client's name, a
/// `0001_Deleted` number and a 0.00 amount in the email composer
/// (invoiceninja/flutter#31). React and v1 both pass the entity from their
/// send-email screens (Mailer.tsx:126-145, admin-portal
/// `lib/utils/templates.dart:17-78`).
///
/// Settings → Templates & Reminders is the one caller that correctly leaves
/// them empty: there is no document in scope there, so the generic sample is
/// the point (React does the same — TemplatesAndReminders.tsx:464).
///
/// `readOnly: true` on the POST bypasses the demo-mode short-circuit; this
/// endpoint mutates nothing.
class TemplatesApi {
  TemplatesApi(this._client);

  final ApiClient _client;

  /// [template] is the bare template id (`'invoice'`, `'quote_reminder1'`,
  /// `'custom2'`, …). This function transforms it to the wire name the
  /// server expects (`'email_template_invoice'`, `'email_quote_template_
  /// reminder1'`, …) before POSTing — mirrors v1 (`admin-portal/lib/utils/
  /// templates.dart:44-51`).
  ///
  /// The returned [TemplatePreview.wrapper] has the body substituted in
  /// for the `$body` placeholder that the server emits in the wrapper
  /// template, so callers can pass it straight to a WebView without an
  /// extra splice step (v1 + React both do
  /// `wrapper.replace('$body', body)` at the call site; we centralize it
  /// here).
  ///
  /// [entity] is the server's short entity name — `invoice`, `quote`,
  /// `credit`, `purchase_order` or `recurring_invoice` (`BillingDocType.
  /// wireName` emits exactly these) — and [entityId] its hashed server id.
  /// Both default to empty for the settings preview; see the class doc for
  /// why the composer must supply them.
  Future<TemplatePreview> render({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
  }) async {
    final wireTemplate = emailTemplateWireName(template);
    final response = await _client.postJson(
      '/api/v1/templates',
      readOnly: true,
      body: <String, dynamic>{
        'entity': entity,
        'entity_id': entityId,
        'template': wireTemplate,
        'subject': subject,
        'body': body,
      },
    );
    final json = response is Map<String, dynamic>
        ? response
        : const <String, dynamic>{};
    final rawWrapper = (json['wrapper'] as String?) ?? '';
    final renderedBody = (json['body'] as String?) ?? '';
    return TemplatePreview(
      subject: (json['subject'] as String?) ?? '',
      body: renderedBody,
      wrapper: rawWrapper.replaceFirst(r'$body', renderedBody),
      rawSubject: (json['raw_subject'] as String?) ?? '',
      rawBody: (json['raw_body'] as String?) ?? '',
    );
  }
}

class TemplatePreview {
  const TemplatePreview({
    required this.subject,
    required this.body,
    required this.wrapper,
    required this.rawSubject,
    required this.rawBody,
  });

  /// Subject line with variables substituted.
  final String subject;

  /// Rendered body HTML (no `<html>` wrapper).
  final String body;

  /// Full HTML document — `<html>` + `<style>` + body — suitable for
  /// `WebViewController.loadHtmlString`. Already has [body] substituted
  /// in for the server-side `$body` placeholder.
  final String wrapper;

  /// Original subject string echoed back (matches the request).
  final String rawSubject;

  /// Original body string echoed back.
  final String rawBody;
}
