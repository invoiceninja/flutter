import 'package:admin/domain/entity_registry.dart';

/// What kind of value a report column carries — drives parsing, rendering,
/// sorting, and which filter widget the column header shows.
///
/// The server returns `display_value` strings already formatted for the
/// account's locale, but reports also need to **sort numerically**, filter
/// **by range**, and aggregate **for totals** — none of which work on the
/// display string. So every cell carries both a typed value and a column
/// type so the local engine knows how to compare, filter, and sum it.
enum ReportColumnType {
  string,
  number,
  money,
  date, // calendar date — no time / timezone
  dateTime, // timestamp
  age, // days; -1 sentinel = "paid"
  duration, // seconds
  boolean,
}

/// Infer the column type from the column identifier the server returned
/// (e.g. `invoice.amount` → money, `client.created_at` → dateTime). The
/// server does **not** ship a column-type map, only display strings — so we
/// reconstruct one from naming conventions matching legacy admin-portal
/// (`getReportColumnType` in `lib/ui/reports/reports_screen.dart`).
ReportColumnType inferColumnType(String identifier) {
  final id = identifier.toLowerCase();
  final tail = id.contains('.') ? id.split('.').last : id;

  if (tail.endsWith('_at')) return ReportColumnType.dateTime;
  // `paid_to_date` ends in `_date` but is money, not a date — exclude it so it
  // falls through to the money block (sums in totals, right-aligns). Matches
  // admin-portal's `getReportColumnType`.
  if (tail != 'paid_to_date' && (tail.endsWith('_date') || tail == 'date')) {
    return ReportColumnType.date;
  }
  if (tail.endsWith('_age') || tail == 'age') return ReportColumnType.age;
  if (tail.endsWith('_duration') || tail == 'duration') {
    return ReportColumnType.duration;
  }

  // Money — explicit names + endings used across entity reports.
  const moneyTails = {
    'amount',
    'balance',
    'paid_to_date',
    'total',
    'subtotal',
    'tax',
    'tax_total',
    'discount',
    'cost',
    'price',
    'sub_total',
    'partial',
    'applied',
    'refunded',
    'credit_balance',
    'payment_balance',
    // Custom surcharge amounts (`invoice.custom_surcharge1`, …). Exact tails,
    // NOT a `contains('surcharge')` — that would also match the
    // `custom_surcharge_taxes1..4` booleans and sum them as money.
    'custom_surcharge1',
    'custom_surcharge2',
    'custom_surcharge3',
    'custom_surcharge4',
  };
  if (moneyTails.contains(tail) ||
      tail.endsWith('_total') ||
      tail.endsWith('_amount') ||
      tail.endsWith('_balance') ||
      tail.endsWith('_tax') ||
      tail.endsWith('_cost') ||
      tail.endsWith('_price')) {
    return ReportColumnType.money;
  }

  // Identifier-style fields look numeric but mustn't sort or sum like
  // numbers (e.g. invoice.number is "INV-0042", vat_number is a tax id).
  // Keep them as strings — the user expects lexicographic order.
  const identifierTails = {'number', 'id_number', 'vat_number', 'routing_id'};
  if (identifierTails.contains(tail)) {
    return ReportColumnType.string;
  }

  // Non-money numeric fallbacks.
  const numericTails = {
    'quantity',
    'qty',
    // Inventory counts — whitelisted explicitly (not a blanket `_quantity`
    // tail) so other reports' columns are untouched. Makes on-hand stock
    // right-align, sort numerically, total its units, and — crucially — emit a
    // `ReportNumberCell` the product report's computed `stock_value` reads.
    'in_stock_quantity',
    'max_quantity',
    'rate',
    'rate1',
    'rate2',
    'rate3',
    'hours',
    'count',
  };
  if (numericTails.contains(tail) ||
      tail.endsWith('_rate') ||
      tail.endsWith('_count')) {
    return ReportColumnType.number;
  }

  const booleanTails = {
    'is_active',
    'is_deleted',
    'is_dirty',
    'is_locked',
    'tax_exempt',
    'is_recurring',
    'is_billable',
    'is_running',
  };
  if (booleanTails.contains(tail) || tail.startsWith('is_')) {
    return ReportColumnType.boolean;
  }

  return ReportColumnType.string;
}

/// Resolve a server-side entity wire string (carried on every cell when the
/// server knows which row this cell belongs to) to the entity's
/// [EntityHandlers] in the registry, so drill-down navigates to the correct
/// `<routePath>/<id>` screen.
///
/// The server returns wire strings that don't map 1:1 to `EntityType` — e.g.
/// `contact`, `invoice_item`, `activity`, `*_report`. We map item rows to
/// their parent entity (drill from an invoice-item to the invoice), aliases
/// to their canonical wire name, and aggregate-report cells to null
/// (non-clickable — there is no entity to navigate to).
EntityHandlers? resolveDrillTarget(EntityRegistry registry, String wire) {
  if (wire.isEmpty) return null;
  const aliasToWire = <String, String?>{
    // Contact rows belong to their client/vendor.
    'contact': 'client',
    'client_contact': 'client',
    'vendor_contact': 'vendor',
    // Line-item rows drill to the parent document.
    'invoice_item': 'invoice',
    'quote_item': 'quote',
    'credit_item': 'credit',
    'recurring_invoice_item': 'recurring_invoice',
    'purchase_order_item': 'purchase_order',
    // Activity rows are read-only history — no destination.
    'activity': null,
  };
  if (aliasToWire.containsKey(wire)) {
    final mapped = aliasToWire[wire];
    if (mapped == null) return null;
    return registry.byWireName(mapped);
  }
  return registry.byWireName(wire);
}

/// True for column types that the totals card can sum over. Age is
/// deliberately excluded — a "sum of ages" (e.g. 612 days across 30 invoices)
/// is meaningless, so age columns show per-row values but no grand total.
bool isAggregatable(ReportColumnType type) =>
    type == ReportColumnType.money ||
    type == ReportColumnType.number ||
    type == ReportColumnType.duration;
