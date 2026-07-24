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

  final List<ProjectBurnupPoint> series;

  bool get isEmpty => series.isEmpty;

  /// True when there is any non-zero money anywhere in the series — the
  /// signal to offer the money view at all. A time-only project would
  /// otherwise render a flat zero line.
  bool get hasMoneySeries => series.any(
    (p) =>
        p.cumulativeInvoicedAmount != Decimal.zero ||
        p.cumulativePaidToDate != Decimal.zero ||
        p.cumulativeExpenseAmount != Decimal.zero,
  );

  static ProjectBurnup fromJson(Map<String, dynamic> json) {
    final project = _asMap(json['project']);
    final markers = _asMap(json['markers']);
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

  static ProjectBurnupPoint fromJson(Map<String, dynamic> j) =>
      ProjectBurnupPoint(
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
