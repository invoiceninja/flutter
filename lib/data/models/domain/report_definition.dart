import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/reports/report_engine.dart';

/// What a report is for — how the gallery groups them.
enum ReportCategory {
  sales,
  receivables,
  expenses,
  financial,
  time,
  records;

  /// Localization key of the section heading. All six resolve in the
  /// bundle; `report_registry_presentation_test` asserts it.
  String get labelKey => switch (this) {
    ReportCategory.sales => 'sales',
    ReportCategory.receivables => 'aging',
    ReportCategory.expenses => 'expenses',
    ReportCategory.financial => 'financial',
    ReportCategory.time => 'time',
    ReportCategory.records => 'general',
  };
}

/// A ready-made way of looking at a report — "by month", "by client" — that
/// answers a question in one tap.
///
/// The gallery prints these as chips on the report's card, and a report that
/// is open and not grouped offers them as suggestions, so there is one list
/// of them. The first one a report declares is also how it opens the first
/// time. A view naming a column the server did not return is simply not
/// offered once the report has run.
class ReportStarterView {
  const ReportStarterView({
    required this.labelKey,
    required this.group,
    this.subgroup,
    this.measure,
  });

  /// Localization key of the dimension — `month`, `client`, `status`. The
  /// chip reads as the dimension alone; the card it sits on names the report.
  final String labelKey;

  /// Column to group by.
  final String group;

  /// Granularity, when [group] is a date.
  final ReportSubgroup? subgroup;

  /// Measure to chart, when it should not be the report's first headline.
  final String? measure;
}

/// A server-side filter a report can offer.
///
/// **A report lists a field only if its export reads the parameter.** The
/// server validates almost none of these and ignores what it does not use, so
/// a filter that does nothing looks exactly like one that matched every row.
/// Each entry in the registry was checked against the export class it names
/// (`app/Export/CSV/*Export.php`, `app/Services/Report/*.php`); the audit that
/// set them removed a vendor filter from the purchase-order reports (they
/// filter on `client_id`), a project filter from tasks, Include Deleted from
/// payments, contacts and documents, and a client filter from three reports
/// that never look at one.
enum ReportFilterField {
  /// The date range. Absent on the two reports whose export never calls
  /// `addDateRange` (project, aged-receivable summary), where a range would
  /// be decoration.
  dateRange,
  status, // invoice / quote / credit / payment / task status
  /// Clients, sent as `clients` — the expense and project reports.
  clientsMulti,

  /// One client, sent as `client_id` — the reports that go through
  /// `BaseExport::filterByClients`, which decodes a single hashed id.
  clientSingle,

  /// Clients, sent as a comma-separated `client_id` — every report that goes
  /// through `BaseExport::addClientFilter`, which explodes the string. These
  /// used to be offered one client at a time.
  clientIdsMulti,
  vendorsMulti,
  projectsMulti,
  tagsMulti, // multi-select of tags → tag_ids (see kReportTagEntityTypes)
  categoriesMulti,
  activityType,
  productKey,
  template,
  documentEmailAttachment,
  pdfEmailAttachment,
  includeDeleted,

  /// Accrual (on) versus cash (off) — `is_income_billed`. The only one of the
  /// profit-and-loss report's three documented switches the server acts on:
  /// `ProfitLoss` stores `is_expense_billed` and `include_tax` and never
  /// reads either again.
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
    this.readsAsDocument = false,
    this.textColumnIds = const {},
    this.filterFields = const [
      ReportFilterField.dateRange,
      ReportFilterField.includeDeleted,
    ],
    this.dateRangeKey,
    this.optionalDateColumnId,
    this.rowIdKey,
    this.rowRecordWire,
    this.lineItemPrefix,
    this.oncePerRecordColumnIds = const {},
    this.defaultFilterValues = const {},
    this.defaultColumnIds = const [],
    this.category = ReportCategory.records,
    this.headlineMeasureIds = const [],
    this.starterViews = const [],
    this.opensGrouped = true,
    this.defaultRange = ReportDatePreset.allTime,
  });

  /// Stable wire name used as a route fragment, persistence key, and
  /// `report_keys` namespace (`clients`, `invoice_items`, `profitloss`, …).
  /// Must match the value React's `useReports.ts` uses as `identifier`.
  final String identifier;

  /// Server endpoint that returns this report's rows (or queues an export).
  /// Preview is `<endpoint>?output=json` → poll `/api/v1/reports/preview/<hash>`.
  /// Export is `<endpoint>` → poll `/api/v1/exports/preview/<hash>`.
  final String endpoint;

  /// Localization key for the user-facing report name (`clients`,
  /// `invoices`, `profit_and_loss`, …), rendered with `context.tr`.
  ///
  /// **Plural for a report of records.** It names a list — "Invoices", the
  /// way the sidebar names the same list — and it doubles as the label of
  /// the report's row count ("Invoices 214"). The singular read as a field
  /// label ("Invoice") on a card and as nonsense on a count.
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

  /// Whether the file this report is produced as can be read back and shown
  /// on screen (`ReportDocument`). True for the reports the server writes as
  /// a CSV with no JSON form — profit and loss, the aged-receivable pair,
  /// the client balance and sales reports, the tax summary, user and
  /// product sales. They used to be a page that said "download it".
  ///
  /// Only meaningful with [supportsPreview] false. A file that turns out not
  /// to parse falls back to that page, so this is a claim about what the
  /// server normally writes, not a promise the screen depends on.
  final bool readsAsDocument;

  /// Whether the report shows *something* of its own on screen — rows and a
  /// chart, or a document — and so is opened by running it.
  bool get showsOnScreen => supportsPreview || readsAsDocument;

  /// Columns of the preview to treat as plain text whatever their name
  /// suggests. The activity report's `date` is the one: the server writes it
  /// in the company's display format (`08/Oct/2026`), not as a date, so as a
  /// date column every cell is unreadable — it would sort nowhere and group
  /// into one blank bucket. As text it reads exactly as written.
  final Set<String> textColumnIds;

  /// The filters this report offers — see [ReportFilterField].
  final List<ReportFilterField> filterFields;

  /// Whether the server applies the date range to this report at all.
  bool get honoursDateRange =>
      filterFields.contains(ReportFilterField.dateRange);

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
  /// column set omits. `client`, `contact`, `vendor` and `product` have one:
  /// each range filters on `created_at`, but none of their report-key maps
  /// carries it, so there is nothing to group, split or chart by until we
  /// ask for it explicitly. Verified live for all four — the server returns
  /// the column (products' keys are unprefixed server-side, yet
  /// `product.created_at` still resolves through `Decorator::product()`),
  /// with an epoch-seconds value (already handled by `_parseTyped`) and an
  /// unresolved `"texts."` header (replaced locally).
  final String? optionalDateColumnId;

  /// The `report_keys` entry that makes the server send each row's own record
  /// id, and [rowRecordWire], the wire name of the record that id names.
  ///
  /// The export does not send a row's id unasked. `BaseExport::processMetaData`
  /// fills `hashed_id` only for a cell of a *related* entity
  /// (`$report_keys[0] == $entity ? null : …`), so an invoice row arrives with
  /// its client's id and without its own. But each export's `buildRow` reads
  /// `<entity>.<key>` straight off the transformed model, whose `id` is the
  /// hashed one — so asking for the key as a column brings it. Each key here
  /// was probed live, or read off its export's `buildRow` where the demo
  /// data has no rows to answer with. It is **not** uniformly `<entity>.id`:
  /// the product report's keys are unprefixed and `product.id` falls through
  /// to the raw integer primary key, so it asks for `product.hashed_id`; and
  /// `RecurringInvoiceItemExport` resolves its parent under `invoice.`.
  ///
  /// On a line-item report this is the *parent document's* id — the invoice an
  /// item row belongs to — which is both where the row opens and what
  /// [ReportAggregation.oncePerRecord] counts by.
  ///
  /// Null where there is no record to open, or where the key is unverified:
  /// an export that does not know a key answers with an empty cell at best
  /// and a dead job at worst.
  final String? rowIdKey;
  final String? rowRecordWire;

  /// On a line-item report, the prefix of the columns that belong to the line
  /// itself (`item`). Every other quantity on the row is the parent
  /// document's, repeated on each of its lines, and is totalled
  /// [ReportAggregation.oncePerRecord].
  final String? lineItemPrefix;

  /// Further columns that repeat per record though the report has no line
  /// prefix — the task report emits a row per time-log entry, each carrying
  /// the task's own `estimated_duration`.
  final Set<String> oncePerRecordColumnIds;

  /// Canonical default values. Used by the "Filters (N)" badge counter
  /// (non-default = bumped) and by "Reset filters". Excludes `dateRange`
  /// (it has its own toolbar surface).
  ///
  /// Wire-format strings / bools / lists — same shape these fields take
  /// on `ReportPayload`.
  final Map<String, Object?> defaultFilterValues;

  /// The columns a report shows until the reader chooses their own.
  ///
  /// The server's default set is everything it has — 42 columns on the
  /// invoice report, 65 on its line items, most of them the client's
  /// address, four custom fields and three tax rates nobody set. This is the
  /// handful that answers what the report is for; the rest stay one tap away
  /// in the column picker, which is fed from what the server returned.
  ///
  /// An id the server does not return is ignored, and when none of them
  /// match — a server that renamed its keys — every column shows, as before.
  /// Empty means "show everything", which is right for a report of four
  /// columns.
  final List<String> defaultColumnIds;

  /// Which section of the gallery the report is listed under.
  final ReportCategory category;

  /// The figures the report leads with, most important first — the amounts
  /// a reader opens it to see. Declared rather than "every number in the
  /// table": the invoice report has a dozen numeric columns, and its
  /// surcharges are not the headline. Empty leads with the row count alone.
  final List<String> headlineMeasureIds;

  /// The report's ready-made views; the first is how it opens. See
  /// [ReportStarterView].
  final List<ReportStarterView> starterViews;

  /// Whether the report opens on its first starter view. False where the
  /// report is, first of all, a list — clients, recurring invoices — and a
  /// grouping is something the reader reaches for.
  final bool opensGrouped;

  /// The view a report opens on the first time, or null to open as a plain
  /// table.
  ReportStarterView? get openingView =>
      opensGrouped && starterViews.isNotEmpty ? starterViews.first : null;

  /// The range a report opens on. A year for a report of things that happen
  /// (a decade of invoices is a slow job and a flat line); all time for a
  /// report of things that exist, where "clients created this year" would
  /// silently hide most of the list.
  final ReportDatePreset defaultRange;
}
