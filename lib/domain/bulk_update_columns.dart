/// The fields the list multiselect's **Bulk Update** can set — the server's
/// `bulk_update` bulk action, one whitelisted `column` and a `new_value`
/// written to every selected record (`BaseRepository::bulkUpdate`).
///
/// The server publishes each entity's whitelist as `statics.bulk_updates`
/// (`Client::$bulk_update_columns`, …), so the columns offered are that list —
/// a column a self-hosted server doesn't have yet is never offered — filtered
/// to the ones this app can render a value input for ([bulkUpdateValueKind]).
/// A leaf: it imports nothing, so the dialog, the repositories and their tests
/// all share it.
library;

/// The value input a column needs, and so the shape of its `new_value`.
enum BulkUpdateValueKind {
  /// Plain text, sent as typed.
  text,

  /// A rich-text field that is HTML on the wire: typed as plain text and sent
  /// through `htmlFromPlainText`.
  html,

  industry,
  size,
  country,

  /// `custom_value1..4`, by the slot's configured type.
  customField,

  /// `tax1..3`: a tax rate, sent as `name||rate`. The server splits that into
  /// `tax_name<n>` + `tax_rate<n>`.
  tax,

  /// A boolean, sent as `1` / `0` — what Laravel's `boolean` rule accepts.
  toggle,

  /// `-1` (endless) or `0..36`.
  remainingCycles,

  /// `off` / `always` / `optout` / `optin`.
  autoBill,

  taskStatus,
  user,
  project,
  client,
}

/// The `statics.bulk_updates` key for each entity, which is also its wire name.
const String kBulkUpdateClient = 'client';
const String kBulkUpdateTask = 'task';
const String kBulkUpdateExpense = 'expense';
const String kBulkUpdateRecurringInvoice = 'recurring_invoice';

/// What a server without `statics.bulk_updates` (older than 2024) allows: the
/// client columns alone. The other three entities joined the whitelist later,
/// so with no catalog they offer nothing.
const List<String> kLegacyClientBulkUpdateColumns = [
  'public_notes',
  'industry_id',
  'size_id',
  'country_id',
  'custom_value1',
  'custom_value2',
  'custom_value3',
  'custom_value4',
];

/// The value input [column] takes on [entity], or null when this app does not
/// offer it — a column the server added after this build, or
/// `auto_bill_enabled`, which a recurring invoice derives from `auto_bill`
/// (picking Auto Bill sends both; see `RecurringInvoiceRepository.bulkUpdate`).
BulkUpdateValueKind? bulkUpdateValueKind(String entity, String column) {
  if (column.startsWith('custom_value')) return BulkUpdateValueKind.customField;
  switch (column) {
    case 'public_notes':
    case 'private_notes':
      // Expense notes are plain text; the others are rich text.
      return entity == kBulkUpdateExpense
          ? BulkUpdateValueKind.text
          : BulkUpdateValueKind.html;
    case 'terms':
    case 'footer':
      return BulkUpdateValueKind.html;
    case 'industry_id':
      return BulkUpdateValueKind.industry;
    case 'size_id':
      return BulkUpdateValueKind.size;
    case 'country_id':
      return BulkUpdateValueKind.country;
    case 'tax1':
    case 'tax2':
    case 'tax3':
      return BulkUpdateValueKind.tax;
    case 'uses_inclusive_taxes':
    case 'should_be_invoiced':
      return BulkUpdateValueKind.toggle;
    case 'remaining_cycles':
      return BulkUpdateValueKind.remainingCycles;
    case 'auto_bill':
      return BulkUpdateValueKind.autoBill;
    case 'status_id':
      return entity == kBulkUpdateTask ? BulkUpdateValueKind.taskStatus : null;
    case 'assigned_user_id':
      return BulkUpdateValueKind.user;
    case 'project_id':
      return BulkUpdateValueKind.project;
    case 'client_id':
      return BulkUpdateValueKind.client;
    default:
      return null;
  }
}

/// The translation key naming [column] in the Field picker. Most columns are
/// their own key; the `_id` ones are not — `context.tr('assigned_user_id')`
/// would render the raw slug. (`custom_value` slots use the company's label
/// instead.)
String bulkUpdateLabelKey(String column) => switch (column) {
  'industry_id' => 'industry',
  'country_id' => 'country',
  'status_id' => 'status',
  'assigned_user_id' => 'assigned_user',
  'client_id' => 'client',
  'project_id' => 'project',
  _ => column,
};

/// The company `custom_fields` key prefix for [entity]'s `custom_value` slots.
/// A recurring invoice shares the invoice's labels, as its edit screen does.
String bulkUpdateCustomFieldPrefix(String entity) =>
    entity == kBulkUpdateRecurringInvoice ? 'invoice' : entity;

/// The columns to offer for [entity]: [serverColumns] (the server's
/// whitelist, or null when its statics carry none) narrowed to what this app
/// renders. Tax slots past [enabledTaxRates] are dropped, as are custom slots
/// with no label in [customFieldLabels] (keyed `<prefix><n>`).
List<String> availableBulkUpdateColumns(
  String entity, {
  required List<String>? serverColumns,
  required int enabledTaxRates,
  required Map<String, String> customFieldLabels,
}) {
  final source =
      serverColumns ??
      (entity == kBulkUpdateClient
          ? kLegacyClientBulkUpdateColumns
          : const <String>[]);
  final prefix = bulkUpdateCustomFieldPrefix(entity);
  bool offered(String column) {
    switch (bulkUpdateValueKind(entity, column)) {
      case null:
        return false;
      case BulkUpdateValueKind.tax:
        return (int.tryParse(column.substring(3)) ?? 99) <= enabledTaxRates;
      case BulkUpdateValueKind.customField:
        final key = column.replaceFirst('custom_value', prefix);
        return (customFieldLabels[key] ?? '').isNotEmpty;
      default:
        return true;
    }
  }

  return [
    for (final column in source)
      if (offered(column)) column,
  ];
}

/// The `new_value` for a tax column: `name||rate`, which the server splits
/// into `tax_name<n>` and `tax_rate<n>`.
String bulkUpdateTaxValue(String name, num rate) => '$name||$rate';

/// The name and rate back out of a [bulkUpdateTaxValue] string, for the
/// optimistic local write. Null when it isn't one.
({String name, String rate})? parseBulkUpdateTaxValue(String value) {
  final parts = value.split('||');
  if (parts.length != 2) return null;
  return (name: parts[0], rate: parts[1]);
}
