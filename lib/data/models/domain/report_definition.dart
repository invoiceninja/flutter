import 'package:admin/domain/entity_type.dart';

/// Which optional filter fields a report exposes in the Filters popover.
/// Fields not listed are hidden — keeps the popover compact and per-report
/// relevant (e.g. a Clients report doesn't show "Cash / accrual basis").
enum ReportFilterField {
  dateRange, // every report; rendered on the toolbar, not the popover
  status, // invoice / quote / credit / payment / task status
  clientsMulti, // multi-select of clients
  clientSingle, // single-client picker (product_sales)
  vendorsMulti,
  projectsMulti,
  tagsMulti, // multi-select of tags (task / project reports → tag_ids)
  categoriesMulti,
  activityType,
  productKey,
  template,
  documentEmailAttachment,
  pdfEmailAttachment,
  includeDeleted,
  includeTax,
  isExpenseBilled,
  isIncomeBilled,
}

/// One row in the report registry. Declared as a `const` literal for each
/// of the 28 reports — no per-report Dart code (the data table is generic
/// over [ReportPreview]; per-report behavior is fully described here).
class ReportDefinition {
  const ReportDefinition({
    required this.identifier,
    required this.endpoint,
    required this.labelKey,
    required this.icon,
    this.requiredPermission = 'view_reports',
    this.supportsPreview = true,
    this.filterFields = const [
      ReportFilterField.dateRange,
      ReportFilterField.includeDeleted,
    ],
    this.dateRangeKey,
    this.optionalDateColumnId,
    this.defaultFilterValues = const {},
    this.defaultColumnIds = const [],
  });

  /// Stable wire name used as a route fragment, persistence key, and
  /// `report_keys` namespace (`clients`, `invoice_items`, `profitloss`, …).
  /// Must match the value React's `useReports.ts` uses as `identifier`.
  final String identifier;

  /// Server endpoint that returns this report's rows (or queues an export).
  /// Preview is `<endpoint>?output=json` → poll `/api/v1/reports/preview/<hash>`.
  /// Export is `<endpoint>` → poll `/api/v1/exports/preview/<hash>`.
  final String endpoint;

  /// Localization key for the user-facing report name (`client`, `invoice`,
  /// `profit_and_loss`, …). The picker renders `context.tr(labelKey)`.
  final String labelKey;

  /// The entity bucket the report is "about" — drives the picker icon and
  /// (when set) which entity sidebar tile would highlight if reports were
  /// reachable from one. Aggregate / financial reports point at their
  /// closest entity (P&L → invoice, AR → invoice) since `EntityType` has
  /// no aggregate-report values.
  final EntityType icon;

  /// Required permission for this report. Picker filters reports the
  /// current company can't access. Defaults to `view_reports` — finer-
  /// grained values (`view_invoice`, `view_client`, …) per report.
  final String requiredPermission;

  /// React-style flag: 9 of 28 report endpoints don't support the preview
  /// JSON output — for those the UI hides Run and goes export-only.
  final bool supportsPreview;

  /// Which optional filter fields render in the Filters popover for this
  /// report. `dateRange` is on every report and is rendered as the
  /// toolbar button rather than in the popover.
  final List<ReportFilterField> filterFields;

  /// The column the server's date range actually filters on, mirroring
  /// each export's `public string $date_key` (`app/Export/CSV/*.php` and
  /// `app/Services/Report/*.php`). Surfaced read-only under the Date Range
  /// control so "Last 30 days" says *which* date it means.
  ///
  /// Deliberately NOT a picker and NOT sent on the wire: `ClientExport`
  /// passes its table name to `addDateRange` as `' clients'` with a leading
  /// space, so `BaseExport::columnExists` always fails there and a
  /// caller-supplied `date_key` can never override the hard-wired
  /// `created_at`. Offering to change it would be a lie on the one report
  /// this matters most for.
  ///
  /// Null where the server applies no date filter at all (`project` —
  /// `ProjectReport::getPdf()` documents `date_range` in its input contract
  /// but never calls `addDateRange`) or owns its own date semantics
  /// (`profitloss`, `tax_period_report`).
  final String? dateRangeKey;

  /// A column to append to `report_keys` when the user asks for it, for a
  /// report whose [dateRangeKey] names a column the server's *default*
  /// column set omits. Only `client` has one today: the range filters on
  /// `clients.created_at`, but `BaseExport::$client_report_keys` carries no
  /// `created_at`, so there is nothing to group or chart by until we ask
  /// for it explicitly. Verified live — the server returns the column, with
  /// an epoch-seconds value (already handled by `_parseTyped`) and an
  /// unresolved `"texts."` header (replaced locally).
  final String? optionalDateColumnId;

  /// Canonical default values. Used by the "Filters (N)" badge counter
  /// (non-default = bumped) and by "Reset filters". Excludes `dateRange`
  /// (it has its own toolbar surface).
  ///
  /// Wire-format strings / bools / lists — same shape these fields take
  /// on `ReportPayload`.
  final Map<String, Object?> defaultFilterValues;

  /// Default visible columns until the user customizes. The server's
  /// returned column set is the source of truth — these are just initial
  /// `visibleColumnIds` until the user picks.
  final List<String> defaultColumnIds;
}
