/// Schedule template + parameter constants. Wire keys exact-match both
/// legacy clients (admin-portal `schedule_model.dart` + React
/// `schedule.ts`); the server validates on these strings.
library;

// ---------- Templates ----------

const String kScheduleTemplateEmailStatement = 'email_statement';
const String kScheduleTemplateEmailRecord = 'email_record';
const String kScheduleTemplateEmailReport = 'email_report';
const String kScheduleTemplateInvoiceOutstandingTasks =
    'invoice_outstanding_tasks';
const String kScheduleTemplatePaymentSchedule = 'payment_schedule';

const List<String> kScheduleTemplates = <String>[
  kScheduleTemplateEmailStatement,
  kScheduleTemplateEmailRecord,
  kScheduleTemplateEmailReport,
  kScheduleTemplateInvoiceOutstandingTasks,
  kScheduleTemplatePaymentSchedule,
];

// ---------- Frequencies ----------

/// String keys match the wire — recurring invoices reuse the same map, so
/// the keys are the integer-as-string ids the server returns.
const Map<String, String> kScheduleFrequencies = <String, String>{
  '1': 'freq_daily',
  '2': 'freq_weekly',
  '3': 'freq_two_weeks',
  '4': 'freq_four_weeks',
  '5': 'freq_monthly',
  '6': 'freq_two_months',
  '7': 'freq_three_months',
  '8': 'freq_four_months',
  '9': 'freq_six_months',
  '10': 'freq_annually',
  '11': 'freq_two_years',
  '12': 'freq_three_years',
};

// ---------- Statement statuses ----------

const String kStatementStatusAll = 'all';
const String kStatementStatusPaid = 'paid';
const String kStatementStatusUnpaid = 'unpaid';

const List<String> kStatementStatuses = <String>[
  kStatementStatusAll,
  kStatementStatusPaid,
  kStatementStatusUnpaid,
];

// ---------- email_record entities + email templates ----------

const List<String> kEmailRecordEntityTypes = <String>[
  'invoice',
  'quote',
  'credit',
  'purchase_order',
];

/// For each entity type, the email-template options available on the
/// `parameters.template` dropdown. The first one in each list is the
/// default — the entity's *initial* email (the server names it after the
/// entity, e.g. `invoice`/`quote`/`credit`/`purchase_order`).
///
/// These strings must be in the server's accepted set
/// (`StoreSchedulerRequest::$templates` = invoice, quote, credit,
/// purchase_order, reminder1, reminder2, reminder3, reminder_endless,
/// custom1, custom2, custom3). The previous `'initial'` value was **not**
/// in that set and made every email_record schedule 422 on save. React
/// uses the entity name for the initial-email option (`EmailRecord.tsx`).
const Map<String, List<String>> kEmailRecordTemplatesPerEntity =
    <String, List<String>>{
      'invoice': <String>[
        'invoice',
        'reminder1',
        'reminder2',
        'reminder3',
        'reminder_endless',
        'custom1',
        'custom2',
        'custom3',
      ],
      'quote': <String>['quote', 'reminder1', 'custom1', 'custom2', 'custom3'],
      'credit': <String>['credit', 'custom1', 'custom2', 'custom3'],
      'purchase_order': <String>[
        'purchase_order',
        'custom1',
        'custom2',
        'custom3',
      ],
    };

// ---------- email_report ----------

/// Report names offered on `parameters.report_name`, restricted to the set
/// the server's `EmailReport::run()` `match` actually handles. Names that
/// pass request validation but have no exporter case (`vendor`,
/// `purchase_order`, `purchase_order_item`) are **omitted** — the server
/// `cancelSchedule()`s (force-deletes) them on first run. The singular
/// `contact`/`task` are likewise unhandled, so we use the server's
/// `client_contact` and `tasks`.
///
/// Source of truth: `app/Services/Scheduler/EmailReport.php`.
const List<String> kEmailReportReportNames = <String>[
  'activity',
  'invoice',
  'invoice_item',
  'recurring_invoice',
  'quote',
  'quote_item',
  'credit',
  'payment',
  'product',
  'product_sales',
  'profitloss',
  'ar_detailed',
  'ar_summary',
  'client_balance',
  'client_sales',
  'tax_summary',
  'user_sales',
  'client',
  'client_contact',
  'document',
  'expense',
  'tasks',
];

/// Field names a per-report-type spec may declare. The edit form renders
/// only the fields named in the active report's set.
enum EmailReportField {
  sendEmail,
  dateRange,
  startDate,
  endDate,
  status,
  documentEmailAttachment,
  pdfEmailAttachment,
  isExpenseBilled,
  isIncomeBilled,
  includeTax,
  includeDeleted,
  productKey,
  clientIdSingular,
  clients,
  vendors,
  projects,
  categories,
  // `tag_ids` — offered on every report whose rows carry tags
  // (`kReportTagEntityTypes`, React #3251); added at render time rather than
  // listed per report here.
  tags,
  templateId,
  groupBy,
  reportKeys,
}

/// Fields shown for a report with no explicit entry in
/// [kEmailReportFieldsByReport]. Mirrors React's `DEFAULT_REPORT_FIELDS`
/// (`EmailReport.tsx`) — the summary reports (ar_detailed, ar_summary,
/// client_balance, client_sales, tax_summary, user_sales) fall back to
/// this set.
const Set<EmailReportField> kDefaultEmailReportFields = <EmailReportField>{
  EmailReportField.sendEmail,
  EmailReportField.dateRange,
  EmailReportField.startDate,
  EmailReportField.endDate,
};

/// Per-report-type field spec. Mirrors React `EmailReport.tsx:60‑208`.
/// Every report carries `sendEmail` and most carry `dateRange`; the
/// distinguishing fields are domain-specific (invoices add `status`,
/// expenses add `is_expense_billed`, profit-and-loss adds
/// `is_income_billed`, etc.). Reports not listed here use
/// [kDefaultEmailReportFields].
const Map<String, Set<EmailReportField>> kEmailReportFieldsByReport =
    <String, Set<EmailReportField>>{
      // `activity` and the summary reports (ar_*, client_balance,
      // client_sales, tax_summary, user_sales) are intentionally absent —
      // they fall back to [kDefaultEmailReportFields].
      'invoice': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.status,
        EmailReportField.documentEmailAttachment,
        EmailReportField.pdfEmailAttachment,
        EmailReportField.includeDeleted,
        EmailReportField.clientIdSingular,
        EmailReportField.templateId,
      },
      'invoice_item': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.status,
        EmailReportField.productKey,
        EmailReportField.documentEmailAttachment,
        EmailReportField.includeDeleted,
        EmailReportField.clientIdSingular,
        EmailReportField.templateId,
      },
      'product_sales': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.productKey,
        EmailReportField.clientIdSingular,
      },
      'profitloss': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.isIncomeBilled,
        EmailReportField.isExpenseBilled,
        EmailReportField.includeTax,
      },
      'client': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.documentEmailAttachment,
        EmailReportField.includeDeleted,
        EmailReportField.templateId,
      },
      'client_contact': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.templateId,
      },
      'recurring_invoice': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.status,
        EmailReportField.includeDeleted,
        EmailReportField.clientIdSingular,
        EmailReportField.templateId,
      },
      'quote': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.documentEmailAttachment,
        EmailReportField.status,
        EmailReportField.includeDeleted,
        EmailReportField.clientIdSingular,
        EmailReportField.pdfEmailAttachment,
        EmailReportField.templateId,
      },
      'quote_item': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.documentEmailAttachment,
        EmailReportField.status,
        EmailReportField.includeDeleted,
        EmailReportField.clientIdSingular,
        EmailReportField.templateId,
      },
      'credit': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.documentEmailAttachment,
        EmailReportField.includeDeleted,
        EmailReportField.status,
        EmailReportField.clientIdSingular,
        EmailReportField.pdfEmailAttachment,
        EmailReportField.templateId,
      },
      'document': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.documentEmailAttachment,
      },
      'payment': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.documentEmailAttachment,
        EmailReportField.status,
        EmailReportField.clientIdSingular,
        EmailReportField.templateId,
      },
      'expense': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.documentEmailAttachment,
        EmailReportField.clients,
        EmailReportField.vendors,
        EmailReportField.projects,
        EmailReportField.categories,
        EmailReportField.status,
        EmailReportField.includeDeleted,
        EmailReportField.templateId,
      },
      'tasks': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.documentEmailAttachment,
        EmailReportField.status,
        EmailReportField.includeDeleted,
        EmailReportField.clientIdSingular,
        EmailReportField.templateId,
      },
      'product': <EmailReportField>{
        EmailReportField.sendEmail,
        EmailReportField.dateRange,
        EmailReportField.startDate,
        EmailReportField.endDate,
        EmailReportField.documentEmailAttachment,
        EmailReportField.templateId,
      },
    };

/// Categorize each report for grouped typeahead rendering (UX D in the
/// plan). Returns the localization key for the group label.
String emailReportCategoryOf(String reportName) {
  switch (reportName) {
    case 'invoice':
    case 'invoice_item':
    case 'recurring_invoice':
    case 'quote':
    case 'quote_item':
    case 'credit':
      return 'invoices';
    case 'payment':
    case 'product_sales':
    case 'profitloss':
    case 'ar_detailed':
    case 'ar_summary':
    case 'client_balance':
    case 'client_sales':
    case 'tax_summary':
    case 'user_sales':
      return 'financial';
    case 'client':
    case 'client_contact':
      return 'clients';
    case 'product':
      return 'products';
    case 'expense':
      return 'vendors';
    case 'tasks':
      return 'tasks';
    default:
      return 'other';
  }
}

// ---------- Date-range options ----------

/// Date-range options for `email_statement` + `invoice_outstanding_tasks`.
/// Matches React's hardcoded list in `EmailStatement.tsx` /
/// `InvoiceOutstandingTasks.tsx` — note these templates render **no**
/// start/end fields, so `custom` is deliberately excluded (the server
/// makes `start_date`/`end_date` `required_if date_range=custom`, which
/// would 422).
const List<String> kStatementDateRangeOptions = <String>[
  'last7_days',
  'last30_days',
  'last365_days',
  'this_month',
  'last_month',
  'this_quarter',
  'last_quarter',
  'this_year',
  'last_year',
  'all_time',
];

/// Date-range options for `email_report`. Superset of React's `ranges`
/// constant (`reports/index/Reports.tsx`) — includes `all` and `custom`
/// (the report section renders start/end fields when `custom` is picked),
/// plus `last365_days`: it's a server-valid range that the reports
/// "Schedule" launcher (`report_schedule.dart`) can seed through verbatim,
/// so the dropdown must be able to display it rather than render blank
/// (React omits it and shows an empty selection for such schedules).
const List<String> kReportDateRangeOptions = <String>[
  'all',
  'last7_days',
  'last30_days',
  'last365_days',
  'this_month',
  'last_month',
  'this_quarter',
  'last_quarter',
  'this_year',
  'last_year',
  'custom',
];

// ---------- Remaining cycles ----------

/// The "endless" sentinel the server treats as "no fixed end".
const int kScheduleRemainingCyclesEndless = -1;

/// Inclusive max for the cycle dropdown (matches admin-portal which goes
/// 0..60).
const int kScheduleRemainingCyclesMax = 60;
