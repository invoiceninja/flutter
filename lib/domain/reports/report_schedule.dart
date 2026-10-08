import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_schedule_seed.dart';
import 'package:admin/data/models/domain/schedule.dart';
import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/data/models/value/date.dart';

/// Maps the current reports-screen state ([ReportScheduleSeed]) to a
/// prefilled `email_report` [Schedule] draft, so "Schedule report" lands the
/// user in the normal recurring-email editor pre-populated.
///
/// Faithful port of React `useScheduleReport`
/// (`react/src/pages/reports/common/hooks/useScheduleReport.ts:24-72`):
/// identifier → `report_name`; the report's short-form date preset → the
/// scheduler's long-form `date_range` (React's `DATE_RANGES_ALIASES` only
/// rewrites `last7`/`last30`; everything else — `all`, `this_month`,
/// `last365_days`, … — passes through); CSV filters + bool flags copied across;
/// visible columns → `report_keys`; `send_email: true`. Pure +
/// unit-tested; `now` is injectable for deterministic `next_run`.
Schedule reportEmailSchedule(
  ReportScheduleSeed seed, {
  DateTime? now,
  String? name,
}) {
  final p = seed.payload;
  final base = Schedule.empty().withTemplate(kScheduleTemplateEmailReport);
  final params = Map<String, dynamic>.from(base.parameters)
    ..addAll(<String, dynamic>{
      'report_name': _scheduleReportName(seed.reportIdentifier),
      'date_range': _scheduleDateRange(p.datePreset),
      'start_date': p.startDate?.toIso() ?? '',
      'end_date': p.endDate?.toIso() ?? '',
      'client_id': p.clientId ?? '',
      'clients': _csv(p.clients),
      'vendors': p.vendors ?? '',
      'projects': p.projects ?? '',
      'categories': p.categories ?? '',
      'status': p.status ?? '',
      'product_key': p.productKey ?? '',
      'template_id': p.templateId ?? '',
      'group_by': seed.groupBy ?? '',
      'report_keys': seed.reportKeys,
      'is_income_billed': p.isIncomeBilled,
      'is_expense_billed': p.isExpenseBilled,
      'include_tax': p.includeTax,
      'include_deleted': p.includeDeleted,
      'document_email_attachment': p.documentEmailAttachment,
      'pdf_email_attachment': p.pdfEmailAttachment,
      'send_email': true,
    });
  final runAt = now == null ? Date.today() : Date(now.year, now.month, now.day);
  return base.copyWith(
    name: (name == null || name.isEmpty) ? seed.reportIdentifier : name,
    nextRun: runAt,
    parameters: params,
  );
}

/// Registry identifier → server `email_report` `report_name`. The report
/// registry exposes identifiers that don't all line up with the scheduler's
/// exporter set (`app/Services/Scheduler/EmailReport.php`): `contact`/`task`
/// need `client_contact`/`tasks`, and the aggregate reports use the short
/// names the server's `match` expects (`ar_detailed`, …) rather than the
/// registry's long identifiers (`aged_receivable_detailed_report`, …).
/// Without these the name misses the `match` and the schedule is
/// `cancelSchedule()`d (or, worse, silently falls back to a different report).
const Map<String, String> _kScheduleReportNameAliases = <String, String>{
  'contact': 'client_contact',
  'task': 'tasks',
  'aged_receivable_detailed_report': 'ar_detailed',
  'aged_receivable_summary_report': 'ar_summary',
  'client_balance_report': 'client_balance',
  'client_sales_report': 'client_sales',
  'tax_summary_report': 'tax_summary',
  'user_sales_report': 'user_sales',
};

/// The server-side `report_name` for a registry identifier, or `null` when the
/// report has no scheduler exporter and would self-destruct on first run.
String? _serverReportName(String reportIdentifier) {
  final mapped =
      _kScheduleReportNameAliases[reportIdentifier] ?? reportIdentifier;
  return kEmailReportReportNames.contains(mapped) ? mapped : null;
}

/// Whether "Schedule recurring email" should be offered for this report.
/// False for reports the server's `email_report` exporter doesn't handle
/// (`vendor`, `purchase_order[_item]`, `recurring_invoice_item`, `project`,
/// `tax_period_report`) — those pass scheduler validation but hit the `match`
/// `default` and are `cancelSchedule()`d on first run. Gate the Schedule
/// action on this so a user never seeds a schedule that silently vanishes.
bool isReportSchedulable(String reportIdentifier) =>
    _serverReportName(reportIdentifier) != null;

/// The `report_name` a schedule of [reportIdentifier] is stored under, or
/// null for a report that cannot be scheduled. What the Reports screen
/// matches existing schedules against, to say a report already has one.
String? scheduledReportName(String reportIdentifier) =>
    _serverReportName(reportIdentifier);

/// The `report_name` to store; falls back to `activity` defensively (callers
/// should gate on [isReportSchedulable], so the fallback is never reached).
String _scheduleReportName(String reportIdentifier) =>
    _serverReportName(reportIdentifier) ?? 'activity';

/// Scheduler `date_range` vocabulary is long-form; the report payload uses
/// short-form. React rewrites only `last7`/`last30`; all other presets are
/// accepted verbatim by the scheduler.
String _scheduleDateRange(ReportDatePreset preset) {
  switch (preset) {
    case ReportDatePreset.last7:
      return 'last7_days';
    case ReportDatePreset.last30:
      return 'last30_days';
    default:
      return preset.wire;
  }
}

/// `clients` is a `List<String>` on the wire (per
/// `EmailReportParametersAccess.reportClients`); the report payload carries
/// it as a CSV string. Empty → `[]` (matching the template default).
List<String> _csv(String? raw) {
  if (raw == null || raw.trim().isEmpty) return const <String>[];
  return raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}
