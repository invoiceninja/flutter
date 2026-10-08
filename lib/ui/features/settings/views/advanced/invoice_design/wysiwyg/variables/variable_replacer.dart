import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/utils/formatting.dart';

/// Substitute `$client.name`, `$invoice.total`, etc. in a template string.
///
/// Mirrors React's `utils/variable-replacer.ts` token list and case order
/// (longest variants first so `$balance_due` is matched before `$balance`,
/// `$client.shipping_*` before bare `$client.*`).
///
/// `data == null` is **save mode** — leave tokens literal so the server's
/// `HtmlEngine::parseLabelsAndValues` substitutes them. `data != null` is
/// **edit mode** — substitute in-memory for the canvas preview.
///
/// `formatter` is optional. When present, money + dates run through the
/// company [Formatter] (per-client currency cascade, company date format).
/// When absent, money falls back to en-US USD and dates to the device
/// locale — fine for unit tests and the synthetic Acme-Corp fixture.
String replaceVariables(
  String template, {
  DesignerSampleData? data,
  Formatter? formatter,
}) {
  if (data == null) return template;

  var r = template;
  String money(Decimal v) => _formatMoney(v, formatter, data.currencyId);
  String date(String iso) => _formatDate(iso, formatter);

  // ── Company variables ────────────────────────────────────────────────
  final co = data.company;
  r = r
      .replaceAll(RegExp(r'\$company\.name\b'), co.name)
      .replaceAll(RegExp(r'\$company\.logo\b'), co.logo)
      .replaceAll(RegExp(r'\$company\.address1\b'), co.address1)
      .replaceAll(RegExp(r'\$company\.address2\b'), co.address2)
      .replaceAll(RegExp(r'\$company\.city_state_postal\b'), co.cityStatePostal)
      .replaceAll(RegExp(r'\$company\.postal_city_state\b'), co.postalCityState)
      .replaceAll(RegExp(r'\$company\.country\b'), co.country)
      .replaceAll(RegExp(r'\$company\.id_number\b'), co.idNumber)
      .replaceAll(RegExp(r'\$company\.phone\b'), co.phone)
      .replaceAll(RegExp(r'\$company\.email\b'), co.email)
      .replaceAll(RegExp(r'\$company\.website\b'), co.website)
      .replaceAll(RegExp(r'\$company\.vat_number\b'), co.vatNumber)
      .replaceAll(RegExp(r'\$company\.custom1\b'), co.customValue1)
      .replaceAll(RegExp(r'\$company\.custom2\b'), co.customValue2)
      .replaceAll(RegExp(r'\$company\.custom3\b'), co.customValue3)
      .replaceAll(RegExp(r'\$company\.custom4\b'), co.customValue4)
      .replaceAll(RegExp(r'\$company\.tags\b'), co.tags);

  // ── Client variables (longer tokens first) ───────────────────────────
  final cl = data.client;
  r = r
      // Shipping (compound) first so bare $client.address1 doesn't eat
      // $client.shipping_address1.
      .replaceAll(RegExp(r'\$client\.shipping_address1\b'), cl.shippingAddress1)
      .replaceAll(RegExp(r'\$client\.shipping_address2\b'), cl.shippingAddress2)
      .replaceAll(
        RegExp(r'\$client\.shipping_city_state_postal\b'),
        cl.shippingCityStatePostal,
      )
      .replaceAll(
        RegExp(r'\$client\.shipping_postal_city_state\b'),
        cl.shippingPostalCityState,
      )
      .replaceAll(
        RegExp(r'\$client\.shipping_postal_city\b'),
        cl.shippingPostalCity,
      )
      .replaceAll(
        RegExp(r'\$client\.shipping_postal_code\b'),
        cl.shippingPostalCode,
      )
      .replaceAll(RegExp(r'\$client\.shipping_city\b'), cl.shippingCity)
      .replaceAll(RegExp(r'\$client\.shipping_state\b'), cl.shippingState)
      .replaceAll(RegExp(r'\$client\.shipping_country\b'), cl.shippingCountry)
      // Then the bare $client.*.
      .replaceAll(RegExp(r'\$client\.name\b'), cl.name)
      .replaceAll(RegExp(r'\$client\.number\b'), cl.number)
      .replaceAll(RegExp(r'\$client\.address1\b'), cl.address1)
      .replaceAll(RegExp(r'\$client\.address2\b'), cl.address2)
      .replaceAll(RegExp(r'\$client\.address\b'), cl.address)
      .replaceAll(RegExp(r'\$client\.city_state_postal\b'), cl.cityStatePostal)
      .replaceAll(RegExp(r'\$client\.postal_city_state\b'), cl.postalCityState)
      .replaceAll(RegExp(r'\$client\.country\b'), cl.country)
      .replaceAll(RegExp(r'\$client\.id_number\b'), cl.idNumber)
      .replaceAll(RegExp(r'\$client\.phone\b'), cl.phone)
      .replaceAll(RegExp(r'\$client\.email\b'), cl.email)
      .replaceAll(RegExp(r'\$client\.vat_number\b'), cl.vatNumber)
      .replaceAll(RegExp(r'\$client\.location_name\b'), cl.locationName)
      .replaceAll(RegExp(r'\$client\.custom1\b'), cl.customValue1)
      .replaceAll(RegExp(r'\$client\.custom2\b'), cl.customValue2)
      .replaceAll(RegExp(r'\$client\.custom3\b'), cl.customValue3)
      .replaceAll(RegExp(r'\$client\.custom4\b'), cl.customValue4)
      .replaceAll(RegExp(r'\$client\.tags\b'), cl.tags);

  // ── Contact variables ($contact.* → data.client.contact_*) ───────────
  r = r
      .replaceAll(RegExp(r'\$contact\.full_name\b'), cl.contactFullName)
      .replaceAll(RegExp(r'\$contact\.email\b'), cl.contactEmail)
      .replaceAll(RegExp(r'\$contact\.phone\b'), cl.contactPhone)
      .replaceAll(RegExp(r'\$contact\.custom1\b'), cl.contactCustomValue1)
      .replaceAll(RegExp(r'\$contact\.custom2\b'), cl.contactCustomValue2)
      .replaceAll(RegExp(r'\$contact\.custom3\b'), cl.contactCustomValue3)
      .replaceAll(RegExp(r'\$contact\.custom4\b'), cl.contactCustomValue4);

  // ── Location variables ───────────────────────────────────────────────
  r = r
      .replaceAll(RegExp(r'\$location\.name\b'), cl.locationName)
      .replaceAll(RegExp(r'\$location\.custom1\b'), cl.locationCustomValue1)
      .replaceAll(RegExp(r'\$location\.custom2\b'), cl.locationCustomValue2)
      .replaceAll(RegExp(r'\$location\.custom3\b'), cl.locationCustomValue3)
      .replaceAll(RegExp(r'\$location\.custom4\b'), cl.locationCustomValue4);

  // ── $entity.* / $invoice.* aliases ───────────────────────────────────
  final inv = data.invoice;
  // Same string list — applied twice, once per prefix — except `tags`, which
  // is $invoice-only: it is one of the nine tag tokens the server is adding
  // and $entity.tags is not among them, so substituting it here would make
  // the canvas preview promise something the PDF won't render. Inline rather
  // than loop because the regex literals don't interpolate cleanly.
  r = r
      .replaceAll(r'$entity.number', inv.number)
      .replaceAll(r'$entity.date', date(inv.date))
      .replaceAll(r'$entity.due_date', date(inv.dueDate))
      .replaceAll(r'$entity.po_number', inv.poNumber)
      .replaceAll(r'$entity.public_url', inv.publicUrl)
      .replaceAll(r'$entity.public_notes', inv.publicNotes)
      .replaceAll(r'$entity.footer', inv.footer)
      .replaceAll(r'$entity.terms', inv.terms)
      .replaceAll(RegExp(r'\$entity\.custom1\b'), inv.customValue1)
      .replaceAll(RegExp(r'\$entity\.custom2\b'), inv.customValue2)
      .replaceAll(RegExp(r'\$entity\.custom3\b'), inv.customValue3)
      .replaceAll(RegExp(r'\$entity\.custom4\b'), inv.customValue4)
      .replaceAll(r'$invoice.number', inv.number)
      .replaceAll(r'$invoice.date', date(inv.date))
      .replaceAll(r'$invoice.due_date', date(inv.dueDate))
      .replaceAll(r'$invoice.po_number', inv.poNumber)
      .replaceAll(r'$invoice.public_url', inv.publicUrl)
      .replaceAll(r'$invoice.public_notes', inv.publicNotes)
      .replaceAll(r'$invoice.footer', inv.footer)
      .replaceAll(r'$invoice.terms', inv.terms)
      .replaceAll(RegExp(r'\$invoice\.custom1\b'), inv.customValue1)
      .replaceAll(RegExp(r'\$invoice\.custom2\b'), inv.customValue2)
      .replaceAll(RegExp(r'\$invoice\.custom3\b'), inv.customValue3)
      .replaceAll(RegExp(r'\$invoice\.custom4\b'), inv.customValue4)
      .replaceAll(RegExp(r'\$invoice\.tags\b'), inv.tags);

  // $invoice.* only — money + timestamps
  r = r
      .replaceAll(r'$invoice.subtotal', money(inv.subtotal))
      .replaceAll(r'$invoice.discount', money(inv.discount))
      .replaceAll(r'$invoice.tax', money(inv.tax))
      .replaceAll(r'$invoice.total', money(inv.total))
      .replaceAll(r'$invoice.paid_to_date', money(inv.paidToDate))
      .replaceAll(r'$invoice.balance', money(inv.balance))
      .replaceAll(r'$invoice.created_at', date(inv.createdAt))
      .replaceAll(r'$invoice.updated_at', date(inv.updatedAt))
      .replaceAll(r'$invoice.partial_due_date', date(inv.partialDueDate));

  // ── Flat entity-details variables (HtmlEngine.php parity) ────────────
  // Order: longer tokens first.
  r = r
      .replaceAll(RegExp(r'\$entity_label\b'), inv.label)
      .replaceAll(RegExp(r'\$po_number\b'), inv.poNumber)
      .replaceAll(RegExp(r'\$due_date\b'), date(inv.dueDate))
      .replaceAll(RegExp(r'\$public_url\b'), inv.publicUrl)
      .replaceAll(RegExp(r'\$public_notes\b'), inv.publicNotes)
      .replaceAll(RegExp(r'\$footer\b'), inv.footer)
      .replaceAll(RegExp(r'\$terms\b'), inv.terms)
      .replaceAll(RegExp(r'\$number\b'), inv.number)
      .replaceAll(RegExp(r'\$date\b'), date(inv.date))
      .replaceAll(RegExp(r'\$amount\b'), money(inv.total));

  // ── Flat total variables ─────────────────────────────────────────────
  r = r
      .replaceAll(
        RegExp(r'\$balance_due\b'),
        money(inv.balanceDue ?? inv.balance),
      )
      .replaceAll(RegExp(r'\$paid_to_date\b'), money(inv.paidToDate))
      .replaceAll(RegExp(r'\$subtotal\b'), money(inv.subtotal))
      .replaceAll(RegExp(r'\$discount\b'), money(inv.discount))
      .replaceAll(RegExp(r'\$custom_surcharge1\b'), money(inv.customSurcharge1))
      .replaceAll(RegExp(r'\$custom_surcharge2\b'), money(inv.customSurcharge2))
      .replaceAll(RegExp(r'\$custom_surcharge3\b'), money(inv.customSurcharge3))
      .replaceAll(RegExp(r'\$custom_surcharge4\b'), money(inv.customSurcharge4))
      .replaceAll(RegExp(r'\$taxes\b'), money(inv.totalTaxes))
      .replaceAll(RegExp(r'\$total\b'), money(inv.total))
      .replaceAll(RegExp(r'\$balance\b'), money(inv.balance))
      .replaceAll(
        RegExp(r'\$partial_due\b'),
        money(inv.partial ?? Decimal.zero),
      )
      .replaceAll(RegExp(r'\$partial\b'), money(inv.partial ?? Decimal.zero));

  // ── QR code placeholders ─────────────────────────────────────────────
  r = r
      .replaceAll(r'$payment_qr_code', '[Payment QR Code]')
      .replaceAll(r'$sepa_qr_code', '[SEPA/EPC QR Code]')
      .replaceAll(r'$swiss_qr', '[Swiss QR Bill]')
      .replaceAll(r'$spc_qr_code', '[SPC QR Code]')
      .replaceAll(r'$verifactu_qr_code', '[Verifactu QR Code]');

  return r;
}

/// Whether a row whose variable resolved to [resolved] prints nothing — the
/// server's `resolvesEmpty` (`PdfBuilder.php`), which "hide if empty" turns
/// on: blank once trimmed, **or still holding a `$token`** nothing replaced.
/// A literal the user typed in place of a variable is neither, and prints.
bool resolvesEmpty(String resolved) =>
    resolved.trim().isEmpty || _unresolvedToken.hasMatch(resolved);

final RegExp _unresolvedToken = RegExp(r'\$[A-Za-z_][A-Za-z0-9_.]*');

/// Resolve a single `item.<field>` variable to its line-item value. Used
/// by tables and tasks-tables when rendering each row.
String resolveItemVariable(
  String variable,
  DesignerSampleLineItem? item, {
  DesignerSampleData? data,
  Formatter? formatter,
}) {
  if (data == null) return variable; // save mode
  if (item == null) return '';

  if (variable.startsWith('item.')) {
    final field = variable.substring(5);
    final value = switch (field) {
      'product_key' => item.productKey,
      'notes' => item.notes,
      'quantity' => item.quantity,
      'cost' => item.cost,
      'net_cost' => item.netCost,
      'gross_line_total' => item.grossLineTotal,
      'line_total' => item.lineTotal,
      'discount' => item.discount,
      'tax_rate1' => item.taxRate1,
      'custom_value1' => item.customValue1,
      'custom_value2' => item.customValue2,
      _ => '',
    };
    if (value is Decimal) {
      String plain(Decimal v) =>
          v == v.truncate() ? v.toBigInt().toString() : v.toString();
      // Money fields go through Formatter; quantity stays a plain count.
      if (field == 'quantity') return plain(value);
      // A percentage discount is a rate, not an amount.
      if (field == 'discount' && !data.isAmountDiscount) {
        return '${plain(value)}%';
      }
      return _formatMoney(value, formatter, data.currencyId);
    }
    return value.toString();
  }

  return replaceVariables(variable, data: data, formatter: formatter);
}

String _formatMoney(Decimal amount, Formatter? formatter, String? currencyId) {
  if (formatter != null) {
    return formatter.money(amount, clientCurrencyId: currencyId);
  }
  // Fallback — matches React's hardcoded Intl.NumberFormat('en-US', USD).
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
  ).format(amount.toDouble());
}

String _formatDate(String iso, Formatter? formatter) {
  if (formatter != null) {
    return formatter.date(iso);
  }
  // Fallback — matches React's "Dec 9, 2025"-style output.
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '';
  return DateFormat.yMMMd('en_US').format(parsed);
}

/// Translator typedef: same shape as `BuildContext.tr` so callers in
/// renderers can pass `context.tr` directly.
typedef LabelTranslator = String Function(String key);

/// Maps a label-variable token (e.g. `$subtotal_label`,
/// `$client.email_label`) to its localization key. Mirrors React's
/// `LABEL_TRANSLATION_MAP` in `utils/label-variables.ts` 1:1. Default
/// block library properties (e.g. the `total` block's items + the
/// `invoice-details` block's fieldConfigs) seed labels as these tokens
/// — without the map, the canvas renders the raw `$..._label` text.
const Map<String, String> kLabelTranslationMap = {
  // Core entity labels.
  r'$number_label': 'invoice_number',
  r'$date_label': 'invoice_date',
  r'$due_date_label': 'due_date',
  r'$po_number_label': 'po_number',
  r'$amount_label': 'amount',
  r'$balance_label': 'balance',
  // "Partial Due" — the server's label for `$partial` is `$partial_due`'s
  // (probed), not the form field's "Partial/Deposit".
  r'$partial_label': 'partial_due',
  r'$subtotal_label': 'subtotal',
  r'$discount_label': 'discount',
  r'$taxes_label': 'taxes',
  r'$total_label': 'total',
  r'$paid_to_date_label': 'paid_to_date',
  r'$balance_due_label': 'balance_due',
  r'$custom_surcharge1_label': 'custom_surcharge1',
  r'$custom_surcharge2_label': 'custom_surcharge2',
  r'$custom_surcharge3_label': 'custom_surcharge3',
  r'$custom_surcharge4_label': 'custom_surcharge4',
  r'$entity_label': 'invoice',
  // Client labels.
  r'$client.name_label': 'client_name',
  r'$client.number_label': 'client_number',
  r'$client.email_label': 'email',
  r'$client.phone_label': 'phone',
  r'$client.address1_label': 'address1',
  r'$client.address2_label': 'address2',
  r'$client.city_label': 'city',
  r'$client.state_label': 'state',
  r'$client.postal_code_label': 'postal_code',
  r'$client.postal_city_state_label': 'postal_city_state',
  r'$client.city_state_postal_label': 'city_state_postal',
  r'$client.country_label': 'country',
  r'$client.vat_number_label': 'vat_number',
  r'$client.id_number_label': 'id_number',
  r'$client.website_label': 'website',
  r'$client.balance_label': 'client_balance',
  r'$client.location_name_label': 'location_name',
  r'$client.custom1_label': 'custom1',
  r'$client.custom2_label': 'custom2',
  r'$client.custom3_label': 'custom3',
  r'$client.custom4_label': 'custom4',
  // Company labels.
  r'$company.name_label': 'company_name',
  r'$company.email_label': 'email',
  r'$company.phone_label': 'phone',
  r'$company.address1_label': 'address1',
  r'$company.address2_label': 'address2',
  r'$company.city_label': 'city',
  r'$company.state_label': 'state',
  r'$company.postal_code_label': 'postal_code',
  r'$company.postal_city_state_label': 'postal_city_state',
  r'$company.city_state_postal_label': 'city_state_postal',
  r'$company.country_label': 'country',
  r'$company.vat_number_label': 'vat_number',
  r'$company.id_number_label': 'id_number',
  r'$company.website_label': 'website',
  r'$company.custom1_label': 'custom1',
  r'$company.custom2_label': 'custom2',
  r'$company.custom3_label': 'custom3',
  r'$company.custom4_label': 'custom4',
  // Product/item labels — keys are the ones `HtmlEngine` passes to `ctrans`.
  r'$product.item_label': 'item',
  r'$product.product_key_label': 'product_key',
  r'$product.description_label': 'description',
  r'$product.notes_label': 'description',
  r'$product.quantity_label': 'quantity',
  r'$product.unit_cost_label': 'unit_cost',
  r'$product.net_cost_label': 'unit_cost',
  r'$product.line_total_label': 'line_total',
  r'$product.gross_line_total_label': 'gross_line_total',
  r'$product.discount_label': 'discount',
  r'$product.tax_label': 'tax',
  r'$product.tax_amount_label': 'tax_amount',
  r'$product.tax_name1_label': 'tax',
  r'$product.tax_name2_label': 'tax',
  r'$product.tax_name3_label': 'tax',
  r'$product.tax_rate1_label': 'tax',
  r'$product.tax_rate2_label': 'tax',
  r'$product.tax_rate3_label': 'tax',
  r'$product.date_label': 'date',
  r'$product.product1_label': 'product1',
  r'$product.product2_label': 'product2',
  r'$product.product3_label': 'product3',
  r'$product.product4_label': 'product4',
  // Section headings.
  r'$bill_to_label': 'bill_to',
  r'$ship_to_label': 'ship_to',
  r'$shipping_label': 'shipping_address',
  r'$from_label': 'from',
  r'$to_label': 'to',
  r'$details_label': 'details',
  // Contact labels.
  r'$contact.first_name_label': 'first_name',
  r'$contact.last_name_label': 'last_name',
  r'$contact.full_name_label': 'full_name',
  r'$contact.email_label': 'email',
  r'$contact.phone_label': 'phone',
  r'$contact.name_label': 'contact',
  r'$contact.custom1_label': 'contact_custom_value1',
  r'$contact.custom2_label': 'contact_custom_value2',
  r'$contact.custom3_label': 'contact_custom_value3',
  r'$contact.custom4_label': 'contact_custom_value4',
  // Location labels.
  r'$location.name_label': 'location_name',
  r'$location.custom1_label': 'custom1',
  r'$location.custom2_label': 'custom2',
  r'$location.custom3_label': 'custom3',
  r'$location.custom4_label': 'custom4',
  // Invoice/entity custom labels.
  r'$entity.custom1_label': 'custom1',
  r'$entity.custom2_label': 'custom2',
  r'$entity.custom3_label': 'custom3',
  r'$entity.custom4_label': 'custom4',
  r'$invoice.custom1_label': 'custom1',
  r'$invoice.custom2_label': 'custom2',
  r'$invoice.custom3_label': 'custom3',
  r'$invoice.custom4_label': 'custom4',
  // Task labels.
  r'$task.service_label': 'service',
  r'$task.description_label': 'description',
  r'$task.hours_label': 'hours',
  r'$task.rate_label': 'rate',
  r'$task.cost_label': 'cost',
  r'$task.line_total_label': 'line_total',
  r'$task.gross_line_total_label': 'gross_line_total',
  r'$task.discount_label': 'discount',
  r'$task.tax_label': 'tax',
  r'$task.tax_amount_label': 'tax_amount',
  r'$task.date_label': 'date',
};

/// Replace every `$..._label` token in [text] with what the server prints
/// for it.
///
/// - A custom field's label is **the name the company gave the field**
///   ([customFieldLabels], by slot) — `HtmlEngine` builds it with
///   `makeCustomField`, so a translation of "custom1" was never what printed.
///   A slot with no name prints nothing.
/// - While [document] asks for a deposit, the balance-due row is relabelled
///   "Partial Due".
/// - A token [kLabelTranslationMap] lists is that string.
/// - Any other is read from the token's own last word
///   (`$client.vat_number_label` → the `vat_number` string): the server
///   makes a label for every value it knows.
/// - One with no such string is left as typed, which is also what prints.
String replaceLabelVariables(
  String text,
  LabelTranslator tr, {
  DesignerSampleData? document,
  Map<String, String>? customFieldLabels,
}) {
  return text.replaceAllMapped(RegExp(r'\$[\w.]+_label\b'), (m) {
    final token = m.group(0)!;
    final custom = _customFieldToken.firstMatch(token);
    // Null is "not known here" (a thumbnail, a test): the generic string.
    if (custom != null && customFieldLabels != null) {
      final owner = custom.group(1);
      final slot = switch (owner) {
        null || 'entity' => 'invoice',
        _ => owner,
      };
      return customFieldLabels['$slot${custom.group(2)}']?.trim() ?? '';
    }
    if (token == r'$balance_due_label' &&
        (document?.invoice.hasPartial ?? false)) {
      return tr('partial_due');
    }
    final key = kLabelTranslationMap[token];
    if (key != null) return tr(key);
    final word = token
        .substring(1, token.length - '_label'.length)
        .split('.')
        .last;
    final translated = tr(word);
    return translated == word ? token : translated;
  });
}

/// `$invoice.custom1_label`, `$client.custom3_label`, bare `$custom2_label`.
final RegExp _customFieldToken = RegExp(
  r'^\$(?:(client|contact|company|invoice|entity)\.)?custom([1-4])_label$',
);
