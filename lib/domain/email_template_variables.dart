/// Email-template `$variables` — the catalog behind the chips Settings →
/// Templates & Reminders and the Send Email composer render in place of raw
/// tokens (invoiceninja/flutter#139), plus the pure string helpers the value
/// probe is built from.
///
/// Imports nothing, so the data layer (the probe) and the UI (chips, picker,
/// the Variables card) can share it without widening either's import graph.
///
/// ## Where a variable is valid is a property of the *server engine*
///
/// The server substitutes an email's variables with one of three engines, and
/// which one depends on the template, not on the screen:
///
/// | Template                                     | Engine               | Extras                         |
/// |----------------------------------------------|----------------------|--------------------------------|
/// | invoice, quote, credit, reminders, recurring | `HtmlEngine`         | —                              |
/// | purchase_order                               | `VendorHtmlEngine`   | —                              |
/// | payment, payment_partial                     | `PaymentEmailEngine` | —                              |
/// | payment_failed                               | `HtmlEngine`         | `$payment_error` (in the engine) |
/// | statement                                    | `HtmlEngine`         | `$start_date`, `$end_date`     |
/// | custom1–3                                    | any document's       | —                              |
///
/// So "is `$payment_button` valid here?" is answered from [_kEngines] — the set
/// of engines that define each catalogued token, extracted from the three PHP
/// engines' `$data['$…']` keys — never from which picker group happens to list
/// it. `HtmlEngine` defines `$vendor.name`, for instance, although no invoice
/// group lists it. `test/domain/email_template_variables_test.dart` re-extracts
/// the sets from the server checkout when one is present.
library;

/// The server engine that substitutes a template's variables on the send path.
enum TemplateVariableEngine { html, vendor, payment }

/// Which variables a template can use. Resolved from the template id in
/// Settings → Templates & Reminders ([templateVariableScopeForTemplate]) and
/// from the document type in the Send Email composer
/// ([templateVariableScopeForEntity]).
enum TemplateVariableScope {
  invoice(TemplateVariableEngine.html),
  quote(TemplateVariableEngine.html),
  credit(TemplateVariableEngine.html),
  purchaseOrder(TemplateVariableEngine.vendor),
  payment(TemplateVariableEngine.payment),

  /// Rendered by `ClientPaymentFailureObject` through `HtmlEngine` — not the
  /// payment engine the template's name suggests — plus `$payment_error`.
  paymentFailed(TemplateVariableEngine.html),

  /// `ClientService` hands the statement email `HtmlEngine` values from the
  /// client's first invoice invitation, plus `$start_date` / `$end_date`.
  statement(TemplateVariableEngine.html),

  /// `custom1`–`custom3`: sent with invoices, quotes, credits and purchase
  /// orders alike, so any catalogued token may resolve and none is flagged.
  any(null);

  const TemplateVariableScope(this.engine);

  /// Null for [any].
  final TemplateVariableEngine? engine;
}

/// One catalogued variable, as a picker row / chip label.
class TemplateVariable {
  const TemplateVariable(
    this.token,
    this.labelKey, {
    this.qualifierKey,
    this.subjectSafe = true,
  });

  /// The literal the server substitutes, `$` included (`$company.name`).
  final String token;

  /// Localization key of the friendly label ("Company Name").
  final String labelKey;

  /// When set, the label renders as `<qualifier> · <label>` — for a field
  /// whose own key is generic ("Street") and would be ambiguous on a chip
  /// ("Company · Street").
  final String? qualifierKey;

  /// False for variables whose value is HTML (a button, a table) — they are
  /// hidden from the subject picker, where markup has no business.
  final bool subjectSafe;
}

/// A titled run of [TemplateVariable]s — one section of the picker and of the
/// Variables card.
class TemplateVariableGroup {
  const TemplateVariableGroup(this.labelKey, this.variables);

  final String labelKey;
  final List<TemplateVariable> variables;
}

/// A catalogued variable found for a token, and whether the scope's engine
/// substitutes it.
typedef TemplateVariableLookup = ({TemplateVariable variable, bool inScope});

/// A `$token` found in running text: `text.substring(start, end) == token`.
typedef TemplateVariableMatch = ({int start, int end, String token});

/// The variable grammar: `$` + identifier + dotted segments. A sentence-final
/// `.` is not consumed (a segment needs a character after the dot) and money
/// (`$5`) never matches, since the first character must be a letter or `_`.
final RegExp kTemplateVariablePattern = RegExp(
  r'\$[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)*',
);

/// Every `$token` in [text], in order.
List<TemplateVariableMatch> findTemplateVariables(String text) => [
  for (final m in kTemplateVariablePattern.allMatches(text))
    (start: m.start, end: m.end, token: m.group(0)!),
];

/// Scope for a Settings → Templates & Reminders template id.
TemplateVariableScope templateVariableScopeForTemplate(String templateId) =>
    switch (templateId) {
      'quote' || 'quote_reminder1' => TemplateVariableScope.quote,
      'credit' => TemplateVariableScope.credit,
      'purchase_order' => TemplateVariableScope.purchaseOrder,
      'payment' || 'payment_partial' => TemplateVariableScope.payment,
      'payment_failed' => TemplateVariableScope.paymentFailed,
      'statement' => TemplateVariableScope.statement,
      'custom1' || 'custom2' || 'custom3' => TemplateVariableScope.any,
      // invoice, reminder1-3, reminder_endless.
      _ => TemplateVariableScope.invoice,
    };

/// Scope for the Send Email composer, from the document's server wire name
/// (`BillingDocType.wireName`). A recurring invoice sends as an invoice.
TemplateVariableScope templateVariableScopeForEntity(String wireName) =>
    switch (wireName) {
      'quote' => TemplateVariableScope.quote,
      'credit' => TemplateVariableScope.credit,
      'purchase_order' => TemplateVariableScope.purchaseOrder,
      _ => TemplateVariableScope.invoice,
    };

/// The `/api/v1/statics` `templates` key holding a template id's default
/// subject/body. The server keys the partial-payment defaults as
/// `partial_payment` (`StaticServiceProvider.php`) while the settings id is
/// `payment_partial`; `credit` and `custom1`–`custom3` have no entry at all.
String staticTemplateKeyFor(String templateId) =>
    templateId == 'payment_partial' ? 'partial_payment' : templateId;

/// The picker / Variables-card sections for [scope], everyday variables first.
List<TemplateVariableGroup> templateVariableGroups(
  TemplateVariableScope scope,
) => switch (scope) {
  TemplateVariableScope.invoice => const [
    TemplateVariableGroup('invoice', _invoiceVariables),
    _clientGroup,
    _contactGroup,
    _companyGroup,
  ],
  TemplateVariableScope.quote => const [
    TemplateVariableGroup('quote', _quoteVariables),
    _clientGroup,
    _contactGroup,
    _companyGroup,
  ],
  TemplateVariableScope.credit => const [
    TemplateVariableGroup('credit', _creditVariables),
    _clientGroup,
    _contactGroup,
    _companyGroup,
  ],
  TemplateVariableScope.purchaseOrder => const [
    TemplateVariableGroup('purchase_order', _purchaseOrderVariables),
    _vendorGroup,
    _contactGroup,
    _companyGroup,
  ],
  TemplateVariableScope.payment => const [
    TemplateVariableGroup('payment', _paymentVariables),
    _paymentClientGroup,
    _contactGroup,
    _companyGroup,
  ],
  TemplateVariableScope.paymentFailed => const [
    TemplateVariableGroup('invoice', _paymentFailedVariables),
    _clientGroup,
    _contactGroup,
    _companyGroup,
  ],
  TemplateVariableScope.statement => const [
    TemplateVariableGroup('statement', _statementVariables),
    _clientGroup,
    _contactGroup,
    _companyGroup,
  ],
  TemplateVariableScope.any => const [
    TemplateVariableGroup('invoice', _invoiceVariables),
    _clientGroup,
    _vendorGroup,
    _contactGroup,
    _companyGroup,
  ],
};

/// Whether the engine that renders [scope] substitutes [token]. Answers only
/// for catalogued tokens; anything else is `false` (unknown to the app, which
/// makes no claim about it — callers leave such text alone).
bool isTemplateVariableInScope(String token, TemplateVariableScope scope) {
  if (_extrasFor(scope).contains(token)) return true;
  final engine = scope.engine;
  // `any` never flags a catalogued token — including the statement extras,
  // the one kind no engine defines.
  if (engine == null) {
    return _kEngines.containsKey(token) || _kStatementExtras.contains(token);
  }
  return _kEngines[token]?.contains(engine) ?? false;
}

/// The catalogued variable behind [token], labelled as [scope] labels it when
/// the scope lists it (so `$number` reads "Quote Number" on a quote), else as
/// the first scope that does. Null for a token the catalog doesn't know.
TemplateVariableLookup? lookupTemplateVariable(
  String token,
  TemplateVariableScope scope,
) {
  var variable = _indexFor(scope)[token];
  for (final other in TemplateVariableScope.values) {
    if (variable != null) break;
    variable = _indexFor(other)[token];
  }
  if (variable == null) return null;
  return (variable: variable, inScope: isTemplateVariableInScope(token, scope));
}

/// The listed, in-scope variable nearest to [token] by edit distance (≤ 2,
/// case-insensitive) — the "Did you mean …?" row for a typo. Null when nothing
/// is that close or [token] is itself listed.
TemplateVariable? closestTemplateVariable(
  String token,
  TemplateVariableScope scope,
) {
  final needle = token.toLowerCase();
  TemplateVariable? best;
  var bestDistance = 3;
  for (final group in templateVariableGroups(scope)) {
    for (final v in group.variables) {
      final d = _levenshtein(needle, v.token.toLowerCase(), bestDistance);
      if (d == 0) return null;
      if (d < bestDistance) {
        best = v;
        bestDistance = d;
      }
    }
  }
  return best;
}

// ── Value probe ──────────────────────────────────────────────────────────────
//
// The server's `/api/v1/templates` substitutes a subject with plain
// `strtr(labels)` then `strtr(values)` — no markdown, no escaping — and leaves
// an unknown token literal. So a subject made of the tokens themselves, each
// behind a marker, comes back with each token replaced by exactly what the
// email will contain. The markers hold no `$` (every `strtr` key starts with
// one), start with `[` (which can't continue a token, so the server's
// longest-key match can't run into them) and aren't whitespace at either end
// (Laravel's global `TrimStrings` would eat it).

/// The probe subject for [tokens]: `[[in<nonce>:0]]$t0[[in<nonce>:1]]…[[in<nonce>:n]]`.
String buildTemplateVariableProbe(List<String> tokens, String nonce) {
  final out = StringBuffer();
  for (var i = 0; i < tokens.length; i++) {
    out
      ..write(_marker(nonce, i))
      ..write(tokens[i]);
  }
  out.write(_marker(nonce, tokens.length));
  return out.toString();
}

/// The raw rendered segment for each of [tokens] out of the server's rendering
/// of [buildTemplateVariableProbe]. Null when any marker is missing — the
/// response isn't the probe it should be, and no value is better than a wrong
/// one.
Map<String, String>? parseTemplateVariableProbe(
  String rendered,
  List<String> tokens,
  String nonce,
) {
  final out = <String, String>{};
  var cursor = 0;
  for (var i = 0; i < tokens.length; i++) {
    final open = _marker(nonce, i);
    final start = rendered.indexOf(open, cursor);
    if (start < 0) return null;
    final close = rendered.indexOf(_marker(nonce, i + 1), start + open.length);
    if (close < 0) return null;
    out[tokens[i]] = rendered.substring(start + open.length, close);
    cursor = close;
  }
  return out;
}

String _marker(String nonce, int i) => '[[in$nonce:$i]]';

/// What a variable resolves to for one document.
sealed class TemplateVariableValue {
  const TemplateVariableValue();
}

/// The server substituted a non-blank value. [isMarkup] is true when it
/// rendered HTML (a button, a table) and [text] is its visible text.
final class TemplateVariableResolved extends TemplateVariableValue {
  const TemplateVariableResolved(this.text, {this.isMarkup = false});

  final String text;
  final bool isMarkup;
}

/// The server substituted an empty value — the variable is valid, the
/// document just has nothing there.
final class TemplateVariableEmpty extends TemplateVariableValue {
  const TemplateVariableEmpty();
}

/// The server left the token literal: the email will contain the raw text.
final class TemplateVariableUnknown extends TemplateVariableValue {
  const TemplateVariableUnknown();
}

// ── Catalog ──────────────────────────────────────────────────────────────────

const _h = TemplateVariableEngine.html;
const _v = TemplateVariableEngine.vendor;
const _p = TemplateVariableEngine.payment;

/// Which engines define each catalogued token — from the `$data['$…'] =`
/// assignments in `app/Utils/HtmlEngine.php`, `app/Utils/VendorHtmlEngine.php`
/// and `app/Mail/Engine/PaymentEmailEngine.php`. Pinned by the engine-oracle
/// test whenever the server checkout is present.
const Map<String, Set<TemplateVariableEngine>> _kEngines = {
  r'$number': {_h, _v, _p},
  r'$amount': {_h, _v, _p},
  r'$balance': {_h, _v},
  r'$due_date': {_h, _v},
  r'$date': {_h, _v},
  r'$po_number': {_h},
  r'$view_button': {_h, _v, _p},
  r'$view_url': {_h, _v, _p},
  r'$view_link': {_h, _v, _p},
  r'$payment_button': {_h},
  r'$payment_url': {_h},
  r'$public_notes': {_h, _v, _p},
  r'$terms': {_h, _v},
  r'$footer': {_h, _v},
  r'$discount': {_h, _v},
  r'$exchange_rate': {_h},
  r'$assigned_to_user': {_h, _v},
  r'$created_by_user': {_h, _v},
  r'$payments': {_h, _v},
  r'$invoices': {_p},
  r'$invoice': {_h, _p},
  r'$invoice_references': {_p},
  r'$invoices.amount': {_p},
  r'$invoices.balance': {_p},
  r'$invoices.due_date': {_p},
  r'$invoices.po_number': {_p},
  r'$payment.date': {_h, _v, _p},
  r'$payment.status': {_p},
  r'$transaction_reference': {_p},
  r'$total': {_h, _v},
  r'$account': {_h, _v},
  r'$payment_error': {_h},
  r'$client': {_h, _v, _p},
  r'$client_name': {_h, _v, _p},
  r'$client.name': {_h, _v, _p},
  r'$client.number': {_h, _v, _p},
  r'$client.email': {_h, _v, _p},
  r'$client.phone': {_h, _v, _p},
  r'$client.address1': {_h, _v, _p},
  r'$client.address2': {_h, _v, _p},
  r'$client.city': {_h, _v, _p},
  r'$client.state': {_h, _v, _p},
  r'$client.postal_code': {_h, _v, _p},
  r'$client.country': {_h, _v, _p},
  r'$client.id_number': {_h, _v, _p},
  r'$client.vat_number': {_h, _v, _p},
  r'$client.credit_balance': {_h},
  r'$client.public_notes': {_h, _v},
  r'$client.shipping_address1': {_h, _v},
  r'$client.shipping_address2': {_h, _v},
  r'$client.shipping_city': {_h, _v},
  r'$client.shipping_state': {_h, _v},
  r'$client.shipping_postal_code': {_h, _v},
  r'$client.shipping_country': {_h, _v},
  r'$contact.first_name': {_h, _v, _p},
  r'$contact.last_name': {_h, _v, _p},
  r'$contact.email': {_h, _v, _p},
  r'$contact.phone': {_h, _v, _p},
  r'$company.name': {_h, _v, _p},
  r'$company.email': {_h, _v, _p},
  r'$company.phone': {_h, _v, _p},
  r'$company.website': {_h, _v, _p},
  r'$company.address1': {_h, _v, _p},
  r'$company.address2': {_h, _v, _p},
  r'$company.city': {_h, _v, _p},
  r'$company.state': {_h, _v, _p},
  r'$company.postal_code': {_h, _v, _p},
  r'$company.country': {_h, _v, _p},
  r'$company.vat_number': {_h, _v, _p},
  r'$company.id_number': {_h, _v, _p},
  r'$vendor': {_h, _v},
  r'$vendor.name': {_h, _v},
  r'$vendor.number': {_h, _v},
  r'$vendor.email': {_v},
  r'$vendor.phone': {_h, _v},
  r'$vendor.website': {_h, _v},
  r'$vendor.address1': {_h, _v},
  r'$vendor.address2': {_h, _v},
  r'$vendor.city': {_h, _v},
  r'$vendor.state': {_h, _v},
  r'$vendor.postal_code': {_h, _v},
  r'$vendor.country': {_h, _v},
  r'$vendor.vat_number': {_h, _v},
  r'$vendor.id_number': {_h, _v},
};

/// Every catalogued token and the engines that define it — the data the
/// engine-oracle test checks against the PHP source.
Map<String, Set<TemplateVariableEngine>> get templateVariableEngines =>
    _kEngines;

/// Added by `ClientService::statement()` on top of `HtmlEngine`'s values; no
/// engine defines them.
const Set<String> _kStatementExtras = {r'$start_date', r'$end_date'};

Set<String> _extrasFor(TemplateVariableScope scope) =>
    scope == TemplateVariableScope.statement ? _kStatementExtras : const {};

const _invoiceVariables = <TemplateVariable>[
  TemplateVariable(r'$number', 'invoice_number'),
  TemplateVariable(r'$amount', 'amount'),
  TemplateVariable(r'$balance', 'balance'),
  TemplateVariable(r'$due_date', 'due_date'),
  TemplateVariable(r'$date', 'invoice_date'),
  TemplateVariable(r'$po_number', 'po_number'),
  TemplateVariable(r'$view_button', 'view_invoice', subjectSafe: false),
  TemplateVariable(r'$view_url', 'view_url'),
  TemplateVariable(r'$payment_button', 'pay_now', subjectSafe: false),
  TemplateVariable(r'$payment_url', 'payment_link'),
  TemplateVariable(r'$public_notes', 'public_notes'),
  TemplateVariable(r'$terms', 'terms'),
  TemplateVariable(r'$footer', 'footer'),
  TemplateVariable(r'$discount', 'discount'),
  TemplateVariable(r'$exchange_rate', 'exchange_rate'),
  TemplateVariable(r'$assigned_to_user', 'assigned_user'),
  TemplateVariable(r'$created_by_user', 'created_by_user'),
  TemplateVariable(r'$payments', 'payments', subjectSafe: false),
];

const _quoteVariables = <TemplateVariable>[
  TemplateVariable(r'$number', 'quote_number'),
  TemplateVariable(r'$amount', 'amount'),
  TemplateVariable(r'$balance', 'balance'),
  TemplateVariable(r'$due_date', 'quote_due_date'),
  TemplateVariable(r'$date', 'quote_date'),
  TemplateVariable(r'$po_number', 'po_number'),
  TemplateVariable(r'$view_button', 'view_quote', subjectSafe: false),
  TemplateVariable(r'$view_url', 'view_url'),
  TemplateVariable(r'$public_notes', 'public_notes'),
  TemplateVariable(r'$terms', 'terms'),
  TemplateVariable(r'$footer', 'footer'),
  TemplateVariable(r'$discount', 'discount'),
  TemplateVariable(r'$exchange_rate', 'exchange_rate'),
  TemplateVariable(r'$assigned_to_user', 'assigned_user'),
  TemplateVariable(r'$created_by_user', 'created_by_user'),
];

const _creditVariables = <TemplateVariable>[
  TemplateVariable(r'$number', 'credit_number'),
  TemplateVariable(r'$amount', 'amount'),
  TemplateVariable(r'$balance', 'balance'),
  TemplateVariable(r'$date', 'credit_date'),
  TemplateVariable(r'$due_date', 'due_date'),
  TemplateVariable(r'$po_number', 'po_number'),
  TemplateVariable(r'$view_button', 'view_credit', subjectSafe: false),
  TemplateVariable(r'$view_url', 'view_url'),
  TemplateVariable(r'$public_notes', 'public_notes'),
  TemplateVariable(r'$terms', 'terms'),
  TemplateVariable(r'$footer', 'footer'),
  TemplateVariable(r'$discount', 'discount'),
  TemplateVariable(r'$exchange_rate', 'exchange_rate'),
  TemplateVariable(r'$assigned_to_user', 'assigned_user'),
  TemplateVariable(r'$created_by_user', 'created_by_user'),
];

const _purchaseOrderVariables = <TemplateVariable>[
  TemplateVariable(r'$number', 'purchase_order_number'),
  TemplateVariable(r'$amount', 'amount'),
  TemplateVariable(r'$balance', 'balance'),
  TemplateVariable(r'$due_date', 'due_date'),
  TemplateVariable(r'$date', 'purchase_order_date'),
  TemplateVariable(r'$view_button', 'view_purchase_order', subjectSafe: false),
  TemplateVariable(r'$view_url', 'view_url'),
  TemplateVariable(r'$public_notes', 'public_notes'),
  TemplateVariable(r'$terms', 'terms'),
  TemplateVariable(r'$footer', 'footer'),
  TemplateVariable(r'$discount', 'discount'),
  TemplateVariable(r'$assigned_to_user', 'assigned_user'),
  TemplateVariable(r'$created_by_user', 'created_by_user'),
];

const _paymentVariables = <TemplateVariable>[
  TemplateVariable(r'$number', 'payment_number'),
  TemplateVariable(r'$amount', 'payment_amount'),
  TemplateVariable(r'$payment.date', 'payment_date'),
  TemplateVariable(r'$payment.status', 'payment_status'),
  TemplateVariable(r'$transaction_reference', 'transaction_reference'),
  TemplateVariable(r'$invoices', 'invoices', subjectSafe: false),
  TemplateVariable(r'$invoice', 'invoice'),
  TemplateVariable(r'$invoice_references', 'invoice_references'),
  TemplateVariable(r'$invoices.amount', 'invoice_amount'),
  TemplateVariable(r'$invoices.balance', 'invoice_balance'),
  TemplateVariable(r'$invoices.due_date', 'due_date', qualifierKey: 'invoices'),
  TemplateVariable(
    r'$invoices.po_number',
    'po_number',
    qualifierKey: 'invoices',
  ),
  TemplateVariable(r'$view_button', 'view_payment', subjectSafe: false),
  TemplateVariable(r'$view_url', 'view_url'),
  TemplateVariable(r'$public_notes', 'public_notes'),
];

const _paymentFailedVariables = <TemplateVariable>[
  TemplateVariable(r'$number', 'invoice_number'),
  TemplateVariable(r'$amount', 'amount'),
  TemplateVariable(r'$payment_error', 'error'),
  TemplateVariable(r'$balance', 'balance'),
  TemplateVariable(r'$due_date', 'due_date'),
  TemplateVariable(r'$date', 'invoice_date'),
  TemplateVariable(r'$po_number', 'po_number'),
  TemplateVariable(r'$view_button', 'view_invoice', subjectSafe: false),
  TemplateVariable(r'$view_url', 'view_url'),
  TemplateVariable(r'$payment_button', 'pay_now', subjectSafe: false),
  TemplateVariable(r'$payment_url', 'payment_link'),
];

const _statementVariables = <TemplateVariable>[
  TemplateVariable(r'$start_date', 'start_date'),
  TemplateVariable(r'$end_date', 'end_date'),
];

const _clientGroup = TemplateVariableGroup('client', [
  TemplateVariable(r'$client', 'client'),
  TemplateVariable(r'$client.name', 'client_name'),
  TemplateVariable(r'$client.number', 'client_number'),
  TemplateVariable(r'$client.email', 'client_email'),
  TemplateVariable(r'$client.phone', 'client_phone'),
  TemplateVariable(r'$client.address1', 'client_address1'),
  TemplateVariable(r'$client.address2', 'client_address2'),
  TemplateVariable(r'$client.city', 'client_city'),
  TemplateVariable(r'$client.state', 'client_state'),
  TemplateVariable(r'$client.postal_code', 'client_postal_code'),
  TemplateVariable(r'$client.country', 'client_country'),
  TemplateVariable(r'$client.shipping_address1', 'client_shipping_address1'),
  TemplateVariable(r'$client.shipping_address2', 'client_shipping_address2'),
  TemplateVariable(r'$client.shipping_city', 'client_shipping_city'),
  TemplateVariable(r'$client.shipping_state', 'client_shipping_state'),
  TemplateVariable(
    r'$client.shipping_postal_code',
    'client_shipping_postal_code',
  ),
  TemplateVariable(r'$client.shipping_country', 'client_shipping_country'),
  TemplateVariable(r'$client.credit_balance', 'credit_balance'),
  TemplateVariable(
    r'$client.public_notes',
    'public_notes',
    qualifierKey: 'client',
  ),
  TemplateVariable(r'$client.id_number', 'client_id_number'),
  TemplateVariable(r'$client.vat_number', 'client_vat_number'),
]);

/// The client fields `PaymentEmailEngine` defines — no shipping address,
/// credit balance or public notes.
const _paymentClientGroup = TemplateVariableGroup('client', [
  TemplateVariable(r'$client', 'client'),
  TemplateVariable(r'$client.name', 'client_name'),
  TemplateVariable(r'$client.number', 'client_number'),
  TemplateVariable(r'$client.email', 'client_email'),
  TemplateVariable(r'$client.phone', 'client_phone'),
  TemplateVariable(r'$client.address1', 'client_address1'),
  TemplateVariable(r'$client.address2', 'client_address2'),
  TemplateVariable(r'$client.city', 'client_city'),
  TemplateVariable(r'$client.state', 'client_state'),
  TemplateVariable(r'$client.postal_code', 'client_postal_code'),
  TemplateVariable(r'$client.country', 'client_country'),
  TemplateVariable(r'$client.id_number', 'client_id_number'),
  TemplateVariable(r'$client.vat_number', 'client_vat_number'),
]);

const _contactGroup = TemplateVariableGroup('contact', [
  TemplateVariable(r'$contact.first_name', 'contact_first_name'),
  TemplateVariable(r'$contact.last_name', 'contact_last_name'),
  TemplateVariable(r'$contact.email', 'contact_email'),
  TemplateVariable(r'$contact.phone', 'contact_phone'),
]);

const _companyGroup = TemplateVariableGroup('company', [
  TemplateVariable(r'$company.name', 'company_name'),
  TemplateVariable(r'$company.email', 'email', qualifierKey: 'company'),
  TemplateVariable(r'$company.phone', 'phone', qualifierKey: 'company'),
  TemplateVariable(r'$company.website', 'website', qualifierKey: 'company'),
  TemplateVariable(r'$company.address1', 'address1', qualifierKey: 'company'),
  TemplateVariable(r'$company.address2', 'address2', qualifierKey: 'company'),
  TemplateVariable(r'$company.city', 'city', qualifierKey: 'company'),
  TemplateVariable(r'$company.state', 'state', qualifierKey: 'company'),
  TemplateVariable(
    r'$company.postal_code',
    'postal_code',
    qualifierKey: 'company',
  ),
  TemplateVariable(r'$company.country', 'country', qualifierKey: 'company'),
  TemplateVariable(
    r'$company.vat_number',
    'vat_number',
    qualifierKey: 'company',
  ),
  TemplateVariable(r'$company.id_number', 'id_number', qualifierKey: 'company'),
]);

const _vendorGroup = TemplateVariableGroup('vendor', [
  TemplateVariable(r'$vendor', 'vendor'),
  TemplateVariable(r'$vendor.name', 'name', qualifierKey: 'vendor'),
  TemplateVariable(r'$vendor.number', 'vendor_number'),
  TemplateVariable(r'$vendor.email', 'email', qualifierKey: 'vendor'),
  TemplateVariable(r'$vendor.phone', 'phone', qualifierKey: 'vendor'),
  TemplateVariable(r'$vendor.website', 'website', qualifierKey: 'vendor'),
  TemplateVariable(r'$vendor.address1', 'address1', qualifierKey: 'vendor'),
  TemplateVariable(r'$vendor.address2', 'address2', qualifierKey: 'vendor'),
  TemplateVariable(r'$vendor.city', 'vendor_city'),
  TemplateVariable(r'$vendor.state', 'state', qualifierKey: 'vendor'),
  TemplateVariable(
    r'$vendor.postal_code',
    'postal_code',
    qualifierKey: 'vendor',
  ),
  TemplateVariable(r'$vendor.country', 'country', qualifierKey: 'vendor'),
  TemplateVariable(r'$vendor.vat_number', 'vat_number', qualifierKey: 'vendor'),
  TemplateVariable(r'$vendor.id_number', 'id_number', qualifierKey: 'vendor'),
]);

/// Tokens the server treats as synonyms of a listed one. They render as chips
/// (the PO default subject uses `$account`) but are kept out of the picker so
/// the same field isn't offered twice.
List<TemplateVariable> _aliasesFor(TemplateVariableScope scope) {
  final viewLabel = switch (scope) {
    TemplateVariableScope.quote => 'view_quote',
    TemplateVariableScope.credit => 'view_credit',
    TemplateVariableScope.purchaseOrder => 'view_purchase_order',
    TemplateVariableScope.payment => 'view_payment',
    _ => 'view_invoice',
  };
  return [
    TemplateVariable(r'$view_link', viewLabel, subjectSafe: false),
    const TemplateVariable(r'$client_name', 'client_name'),
    const TemplateVariable(r'$account', 'company_name'),
    const TemplateVariable(r'$total', 'total'),
  ];
}

final Map<TemplateVariableScope, Map<String, TemplateVariable>> _indexes = {};

Map<String, TemplateVariable> _indexFor(TemplateVariableScope scope) =>
    _indexes.putIfAbsent(scope, () {
      final index = <String, TemplateVariable>{};
      for (final group in templateVariableGroups(scope)) {
        for (final v in group.variables) {
          index.putIfAbsent(v.token, () => v);
        }
      }
      for (final alias in _aliasesFor(scope)) {
        index.putIfAbsent(alias.token, () => alias);
      }
      return index;
    });

/// Levenshtein distance, giving up (returning [cap]) once every cell in a row
/// reaches [cap] — only distances below it matter to the caller.
int _levenshtein(String a, String b, int cap) {
  if ((a.length - b.length).abs() >= cap) return cap;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    var rowMin = current[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final value = [
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
      current[j] = value;
      if (value < rowMin) rowMin = value;
    }
    if (rowMin >= cap) return cap;
    previous = current;
  }
  return previous[b.length] < cap ? previous[b.length] : cap;
}
