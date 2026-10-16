import 'package:decimal/decimal.dart';

import 'package:admin/data/models/value/date.dart';

/// In-memory projection of `POST /api/v1/charts/project_burnup/{project}`.
///
/// Shape (from `app/Services/Chart/ProjectBurnUpService::buildResponse`):
/// ```
/// {
///   start_date, end_date, bucket_type,
///   project: { id, name, client_id, start_date, due_date,
///              budgeted_hours, task_rate, budgeted_amount, currency_id },
///   markers: { due_date, budgeted_hours, budgeted_amount },
///   series:  [ { period_end, …per-bucket…, cumulative_*, ideal_hours,
///                ideal_amount, budgeted_hours, budgeted_amount }, … ]
/// }
/// ```
///
/// This complements — it does not replace — `ProjectProgressCard`, which
/// computes a cumulative-hours-vs-ideal-pace chart locally from Drift time
/// logs and therefore keeps working offline. What only the server can produce
/// is the **money** side: invoiced / paid / outstanding / expense series.
///
/// Decoding is tolerant (see `ProjectAnalytics`) — the endpoint is new
/// (2026-06-30) and still 404s on the demo host, so unknown or missing keys
/// degrade to zeros rather than throwing.
class ProjectBurnup {
  const ProjectBurnup({
    required this.startDate,
    required this.endDate,
    required this.bucketType,
    required this.currencyId,
    required this.budgetedHours,
    required this.budgetedAmount,
    required this.dueDate,
    required this.series,
    this.taskEstimatedHours = 0,
    this.unestimatedTaskCount = 0,
    this.canViewFinancials = true,
  });

  final Date? startDate;
  final Date? endDate;

  /// Echo of the requested `daily|weekly|monthly`.
  final String bucketType;

  /// Currency for every money series — the project's client currency, falling
  /// back to the company's.
  final String currencyId;

  /// Horizontal marker lines: the hours and money budgets.
  final double budgetedHours;
  final Decimal budgetedAmount;

  /// Vertical marker line.
  final Date? dueDate;

  /// Horizontal marker: the sum of the tasks' estimates, in hours (React
  /// #3380). 0 when nothing is estimated — or on a server that predates task
  /// estimates — and then no line is drawn.
  final double taskEstimatedHours;

  /// Tasks with no estimate, so the estimate line isn't read as complete.
  final int unestimatedTaskCount;

  final List<ProjectBurnupPoint> series;

  /// `metadata.can_view_financials` — false strips every money series from
  /// the rows and the budget amount from the markers. Missing reads as true,
  /// as for `ProjectAnalytics.canViewFinancials`.
  final bool canViewFinancials;

  bool get isEmpty => series.isEmpty;

  /// Whether any money line has something to draw — the signal to offer the
  /// money view at all. A time-only project would otherwise get a switch to
  /// a page of flat zero lines. See [hasBillingSeries] for which view the
  /// chart opens on.
  bool get hasMoneySeries =>
      canViewFinancials &&
      series.any(
        (p) =>
            p.cumulativeInvoicedAmount != Decimal.zero ||
            p.cumulativePaidToDate != Decimal.zero ||
            p.cumulativeTaskValue != Decimal.zero ||
            p.cumulativeExpenseAmount != Decimal.zero,
      );

  /// Whether anything has been invoiced or paid — the money view's default
  /// lines. Only then does the chart OPEN on money; a project with spend but
  /// nothing billed opens on its hours, with money one switch away, instead
  /// of on two flat zero lines.
  bool get hasBillingSeries =>
      canViewFinancials &&
      series.any(
        (p) =>
            p.cumulativeInvoicedAmount != Decimal.zero ||
            p.cumulativePaidToDate != Decimal.zero,
      );

  static ProjectBurnup fromJson(Map<String, dynamic> json) {
    final project = _asMap(json['project']);
    final markers = _asMap(json['markers']);
    final meta = _asMap(json['metadata']);
    final canView = meta['can_view_financials'];
    final rawSeries = json['series'];
    return ProjectBurnup(
      startDate: Date.tryParse(json['start_date']?.toString() ?? ''),
      endDate: Date.tryParse(json['end_date']?.toString() ?? ''),
      bucketType: json['bucket_type']?.toString() ?? '',
      currencyId: project['currency_id']?.toString() ?? '',
      budgetedHours: _double(
        markers['budgeted_hours'] ?? project['budgeted_hours'],
      ),
      budgetedAmount: _money(
        markers['budgeted_amount'] ?? project['budgeted_amount'],
      ),
      dueDate: Date.tryParse(
        (markers['due_date'] ?? project['due_date'])?.toString() ?? '',
      ),
      series: [
        if (rawSeries is List)
          for (final row in rawSeries)
            if (row is Map) ProjectBurnupPoint.fromJson(_asMap(row)),
      ],
      taskEstimatedHours: _double(
        markers['task_estimated_hours'] ?? project['task_estimated_hours'],
      ),
      unestimatedTaskCount: _int(meta['unestimated_task_count']),
      canViewFinancials:
          canView == null || const {'true', '1'}.contains('$canView'),
    );
  }
}

/// One bucket of the burn-up series. Only the cumulative values are modelled —
/// they're what the chart plots; the per-bucket deltas are recoverable by
/// differencing and aren't needed by any card today.
class ProjectBurnupPoint {
  const ProjectBurnupPoint({
    required this.periodEnd,
    required this.cumulativeLoggedHours,
    required this.cumulativeBillableHours,
    required this.cumulativeTaskValue,
    required this.cumulativeInvoicedAmount,
    required this.cumulativePaidToDate,
    required this.cumulativeOutstandingAmount,
    required this.cumulativeExpenseAmount,
    required this.idealHours,
    required this.idealAmount,
    this.cumulativeNetInvoiced,
    this.cumulativeNetPaid,
  });

  final Date? periodEnd;
  final double cumulativeLoggedHours;
  final double cumulativeBillableHours;
  final Decimal cumulativeTaskValue;
  final Decimal cumulativeInvoicedAmount;
  final Decimal cumulativePaidToDate;
  final Decimal cumulativeOutstandingAmount;
  final Decimal cumulativeExpenseAmount;

  /// Linear pace lines from project start to due date — what "on schedule"
  /// would look like at this bucket.
  final double idealHours;
  final Decimal idealAmount;

  /// Invoiced / paid minus expenses, running. Null on a server that does not
  /// send them — a missing series is not a zero one.
  final Decimal? cumulativeNetInvoiced;
  final Decimal? cumulativeNetPaid;

  static ProjectBurnupPoint fromJson(Map<String, dynamic> j) =>
      ProjectBurnupPoint(
        cumulativeNetInvoiced: j.containsKey('cumulative_net_invoiced_amount')
            ? _money(j['cumulative_net_invoiced_amount'])
            : null,
        cumulativeNetPaid: j.containsKey('cumulative_net_paid_amount')
            ? _money(j['cumulative_net_paid_amount'])
            : null,
        periodEnd: Date.tryParse(j['period_end']?.toString() ?? ''),
        cumulativeLoggedHours: _double(j['cumulative_logged_hours']),
        cumulativeBillableHours: _double(j['cumulative_billable_hours']),
        cumulativeTaskValue: _money(j['cumulative_task_value']),
        cumulativeInvoicedAmount: _money(j['cumulative_invoiced_amount']),
        cumulativePaidToDate: _money(j['cumulative_paid_to_date']),
        cumulativeOutstandingAmount: _money(j['cumulative_outstanding_amount']),
        cumulativeExpenseAmount: _money(j['cumulative_expense_amount']),
        idealHours: _double(j['ideal_hours']),
        idealAmount: _money(j['ideal_amount']),
      );
}

// ── shared tolerant decoders ────────────────────────────────────────────

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
  return const <String, dynamic>{};
}

Decimal _money(Object? v) {
  if (v == null) return Decimal.zero;
  if (v is num) return Decimal.parse(v.toString());
  return Decimal.tryParse(v.toString()) ?? Decimal.zero;
}

double _double(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

int _int(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}
