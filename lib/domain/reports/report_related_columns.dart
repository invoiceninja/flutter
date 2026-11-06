/// Columns a report can add from the record its rows belong to — the
/// client of a payment, the vendor of an expense — beyond the ones the
/// server returns by default.
///
/// The server already answers them: every export falls back to
/// `Decorator::transform` for a key outside its own map, and the
/// `ClientDecorator` / `ContactDecorator` / `VendorDecorator` read the row's
/// client, primary contact or vendor. `BaseExport::buildHeader` labels each
/// one ("Client City") — but a vendor's custom field only by its slot
/// ("Vendor Custom Value 1"), which [withCustomFieldLabels] fixes. React
/// offers the same per report (`useReports.ts` `custom_columns`).
///
/// The lists mirror `BaseExport::$client_report_keys` and
/// `$vendor_report_keys`. Left out on purpose:
/// * `client.assigned_user` — `ClientDecorator::assigned_user` prints the
///   client's *creator*, so it would show the wrong person;
/// * the vendor contact (`vendor_contact.*`) — `VendorContactDecorator`
///   reads only `$entity->contacts`, which neither an expense nor a purchase
///   order has, so every row is blank (and `contact.*` there falls through
///   to the client's contact when the record has a client);
/// * the invoice map React offers on Payments — `invoice.number` makes
///   `PaymentExport` write a row per applied invoice, so the payment's own
///   amount would repeat on each.
library;

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';

/// One column a report can add.
class ReportRelatedColumn {
  const ReportRelatedColumn(this.id, this.labelKey, {this.customFieldSlot});

  /// The server's report key, e.g. `client.city`.
  final String id;

  /// Translation key for the field's name, read under its group's heading.
  final String labelKey;

  /// The company custom-field slot (`client1`, `vendor3`) this column
  /// shows, or null. A slot the company has not configured is not offered:
  /// every row would be blank.
  final String? customFieldSlot;
}

/// The columns of one related record, under one heading.
class ReportRelatedColumnGroup {
  const ReportRelatedColumnGroup(this.labelKey, this.columns);

  /// Translation key for the heading — `client`, `contact`, `vendor`.
  final String labelKey;
  final List<ReportRelatedColumn> columns;
}

List<ReportRelatedColumn> _customFields(String prefix, String slot) => [
  for (var n = 1; n <= 4; n++)
    ReportRelatedColumn(
      '$prefix.custom_value$n',
      'custom_value$n',
      customFieldSlot: '$slot$n',
    ),
];

/// A client's money figures, which are in the client's currency. A cell is
/// shown in its *row's* currency, so they are offered only where that is the
/// client's: a billing document's (`client.currency_id` is in its default
/// set) or a payment's (`payment.currency`, the client's). The task report
/// has no currency column — every row is the company's — and an expense's
/// is its own, so there a euro client's balance would read as dollars.
const List<ReportRelatedColumn> _clientFigures = [
  ReportRelatedColumn('client.balance', 'balance'),
  ReportRelatedColumn('client.paid_to_date', 'paid_to_date'),
  ReportRelatedColumn('client.credit_balance', 'credit_balance'),
  ReportRelatedColumn('client.payment_balance', 'payment_balance'),
];

ReportRelatedColumnGroup _clientGroup({
  required bool figures,
}) => ReportRelatedColumnGroup('client', [
  const ReportRelatedColumn('client.name', 'name'),
  const ReportRelatedColumn('client.number', 'number'),
  const ReportRelatedColumn('client.user', 'user'),
  if (figures) ..._clientFigures,
  const ReportRelatedColumn('client.currency_id', 'currency'),
  const ReportRelatedColumn('client.phone', 'phone'),
  const ReportRelatedColumn('client.website', 'website'),
  const ReportRelatedColumn('client.vat_number', 'vat_number'),
  const ReportRelatedColumn('client.id_number', 'id_number'),
  const ReportRelatedColumn('client.address1', 'address1'),
  const ReportRelatedColumn('client.address2', 'address2'),
  const ReportRelatedColumn('client.city', 'city'),
  const ReportRelatedColumn('client.state', 'state'),
  const ReportRelatedColumn('client.postal_code', 'postal_code'),
  const ReportRelatedColumn('client.country_id', 'country'),
  const ReportRelatedColumn('client.shipping_address1', 'shipping_address1'),
  const ReportRelatedColumn('client.shipping_address2', 'shipping_address2'),
  const ReportRelatedColumn('client.shipping_city', 'shipping_city'),
  const ReportRelatedColumn('client.shipping_state', 'shipping_state'),
  const ReportRelatedColumn(
    'client.shipping_postal_code',
    'shipping_postal_code',
  ),
  const ReportRelatedColumn('client.shipping_country_id', 'shipping_country'),
  const ReportRelatedColumn('client.industry_id', 'industry'),
  const ReportRelatedColumn('client.size_id', 'size'),
  const ReportRelatedColumn('client.classification', 'classification'),
  const ReportRelatedColumn('client.payment_terms', 'payment_terms'),
  const ReportRelatedColumn('client.public_notes', 'public_notes'),
  const ReportRelatedColumn('client.private_notes', 'private_notes'),
  const ReportRelatedColumn('client.tags', 'tags'),
  ..._customFields('client', 'client'),
]);

final ReportRelatedColumnGroup _client = _clientGroup(figures: true);
final ReportRelatedColumnGroup _clientNoFigures = _clientGroup(figures: false);

final ReportRelatedColumnGroup _contact = ReportRelatedColumnGroup('contact', [
  const ReportRelatedColumn('contact.first_name', 'first_name'),
  const ReportRelatedColumn('contact.last_name', 'last_name'),
  const ReportRelatedColumn('contact.email', 'email'),
  const ReportRelatedColumn('contact.phone', 'phone'),
  ..._customFields('contact', 'contact'),
]);

final ReportRelatedColumnGroup _vendor = ReportRelatedColumnGroup('vendor', [
  const ReportRelatedColumn('vendor.name', 'name'),
  const ReportRelatedColumn('vendor.number', 'number'),
  const ReportRelatedColumn('vendor.currency', 'currency'),
  const ReportRelatedColumn('vendor.phone', 'phone'),
  const ReportRelatedColumn('vendor.website', 'website'),
  const ReportRelatedColumn('vendor.vat_number', 'vat_number'),
  const ReportRelatedColumn('vendor.id_number', 'id_number'),
  const ReportRelatedColumn('vendor.address1', 'address1'),
  const ReportRelatedColumn('vendor.address2', 'address2'),
  const ReportRelatedColumn('vendor.city', 'city'),
  const ReportRelatedColumn('vendor.state', 'state'),
  const ReportRelatedColumn('vendor.postal_code', 'postal_code'),
  const ReportRelatedColumn('vendor.country_id', 'country'),
  const ReportRelatedColumn('vendor.classification', 'classification'),
  const ReportRelatedColumn('vendor.public_notes', 'public_notes'),
  const ReportRelatedColumn('vendor.private_notes', 'private_notes'),
  const ReportRelatedColumn('vendor.tags', 'tags'),
  ..._customFields('vendor', 'vendor'),
]);

/// A related column offered to the reader: [labelKey] to translate, or the
/// company's own [label] for a custom field.
class ReportRelatedOffer {
  const ReportRelatedOffer({
    required this.id,
    required this.labelKey,
    this.label,
  });

  final String id;
  final String labelKey;
  final String? label;
}

/// The columns of one related record still on offer, under [labelKey].
class ReportRelatedOfferGroup {
  const ReportRelatedOfferGroup({
    required this.labelKey,
    required this.columns,
  });

  final String labelKey;
  final List<ReportRelatedOffer> columns;
}

/// Report identifier → the related records whose columns it can add. Only
/// server reports: one built on the device has no server to ask.
final Map<String, List<ReportRelatedColumnGroup>> kReportRelatedColumns = {
  'invoice': [_client, _contact],
  'invoice_item': [_client, _contact],
  'quote': [_client, _contact],
  'quote_item': [_client, _contact],
  'credit': [_client, _contact],
  'recurring_invoice': [_client, _contact],
  'recurring_invoice_item': [_client, _contact],
  'payment': [_client, _contact],
  'task': [_clientNoFigures, _contact],
  // No client contact: `ContactDecorator` falls through to the *vendor's*
  // contact on an expense with no client, under a "Contact" heading.
  'expense': [_vendor, _clientNoFigures],
  'purchase_order': [_vendor],
  'purchase_order_item': [_vendor],
};

/// The groups [report] can add columns from; empty when it can add none.
List<ReportRelatedColumnGroup> reportRelatedColumnGroups(String report) =>
    kReportRelatedColumns[report] ?? const [];

/// Custom-field column id → its company slot, for the columns [report] can
/// add (`client.custom_value2` → `client2`).
Map<String, String> reportRelatedCustomFieldSlots(String report) => {
  for (final group in reportRelatedColumnGroups(report))
    for (final column in group.columns)
      if (column.customFieldSlot case final slot?) column.id: slot,
};

/// Every column id [report] can add.
Set<String> reportRelatedColumnIds(String report) => {
  for (final group in reportRelatedColumnGroups(report))
    for (final column in group.columns) column.id,
};

/// [preview] with every quantity column of a related record — a client's
/// balance on the payment report — shown per row and never totalled.
///
/// The figure is the client's, so it repeats on each of the client's rows:
/// summed, a client with ten payments counts its balance ten times. It is
/// not once per *row record* either ([ReportAggregation.oncePerRecord]) —
/// the record is the payment, not the client. An explicit aggregation
/// already on a column is left alone.
ReportPreview withRelatedColumnsUntotalled(
  ReportPreview preview,
  Set<String> relatedIds,
) {
  if (relatedIds.isEmpty) return preview;
  var touched = false;
  final columns = [
    for (final column in preview.columns)
      if (column.aggregation == null &&
          relatedIds.contains(column.identifier) &&
          column.effectiveAggregation != ReportAggregation.none)
        () {
          touched = true;
          return column.copyWith(aggregation: ReportAggregation.none);
        }()
      else
        column,
  ];
  if (!touched) return preview;
  return ReportPreview(columns: columns, rows: preview.rows);
}

/// [preview] with each related custom-field column headed by the label the
/// company gave it ([labels], by slot). The server does this for a client's
/// and a contact's fields, but heads a vendor's by its slot ("Vendor Custom
/// Value 1"), so the picker said "Region" and the table did not.
ReportPreview withCustomFieldLabels(
  ReportPreview preview,
  Map<String, String> slotsById,
  Map<String, String> labels,
) {
  if (slotsById.isEmpty || labels.isEmpty) return preview;
  var touched = false;
  final columns = [
    for (final column in preview.columns)
      if (labels[slotsById[column.identifier]] case final label?
          when label.isNotEmpty && label != column.displayLabel)
        () {
          touched = true;
          return column.copyWith(displayLabel: label);
        }()
      else
        column,
  ];
  if (!touched) return preview;
  return ReportPreview(columns: columns, rows: preview.rows);
}
