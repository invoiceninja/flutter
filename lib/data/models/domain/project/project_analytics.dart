import 'package:decimal/decimal.dart';

import 'package:admin/data/models/value/date.dart';

/// In-memory projection of `POST /api/v1/charts/project_analytics/{project}`.
///
/// The server returns 14 blocks, each a **list** of per-project rows
/// (`ProjectAnalyticsService::generate`). The route is project-scoped, so every
/// list holds at most one row — this class flattens to that single row and
/// exposes `null` when a block is absent or empty.
///
/// Decoding is deliberately tolerant: unknown keys are ignored, missing keys
/// fall back to zero/null, and money arrives as `Decimal` regardless of
/// whether the server sent a number or a string. A block the server later
/// renames simply renders as an empty card rather than throwing — this payload
/// is new (2026-06-30) and not yet deployed to the demo host, so its shape is
/// modelled from `app/Services/Chart/ProjectAnalyticsService.php`.
class ProjectAnalytics {
  const ProjectAnalytics({
    this.budgetSummary,
    this.budgetVsActual,
    this.invoiceProgress,
    this.profitability,
    this.health,
  });

  final ProjectBudgetSummary? budgetSummary;
  final ProjectBudgetVsActual? budgetVsActual;
  final ProjectInvoiceProgress? invoiceProgress;
  final ProjectProfitability? profitability;
  final ProjectHealth? health;

  /// True when the server answered but every block we render came back empty —
  /// the signal to show an empty state rather than a grid of zeros.
  bool get isEmpty =>
      budgetSummary == null &&
      budgetVsActual == null &&
      invoiceProgress == null &&
      profitability == null &&
      health == null;

  static ProjectAnalytics fromJson(Map<String, dynamic> json) =>
      ProjectAnalytics(
        budgetSummary: _firstRow(
          json['budget_summary'],
          ProjectBudgetSummary.fromJson,
        ),
        budgetVsActual: _firstRow(
          json['budget_vs_actual'],
          ProjectBudgetVsActual.fromJson,
        ),
        invoiceProgress: _firstRow(
          json['invoice_progress'],
          ProjectInvoiceProgress.fromJson,
        ),
        profitability: _firstRow(
          json['profitability'],
          ProjectProfitability.fromJson,
        ),
        health: _firstRow(json['project_health'], ProjectHealth.fromJson),
      );
}

/// `budget_summary[0]` — headline budget/utilization counters.
class ProjectBudgetSummary {
  const ProjectBudgetSummary({
    required this.budgetedHours,
    required this.currentHours,
    required this.hoursRemaining,
    required this.utilization,
    required this.budgetedAmount,
    required this.actualAmount,
    required this.remainingBudget,
    required this.budgetUtilization,
    required this.totalTasks,
    required this.invoicedTasks,
    required this.uninvoicedTasks,
    required this.runningTasks,
    required this.currencyId,
    required this.dueDate,
  });

  final double budgetedHours;
  final double currentHours;
  final double hoursRemaining;

  /// Logged ÷ budgeted hours, as a 0..1+ ratio (server rounds to 4 places).
  final double utilization;

  final Decimal budgetedAmount;
  final Decimal actualAmount;
  final Decimal remainingBudget;

  /// Actual ÷ budgeted money, as a 0..1+ ratio.
  final double budgetUtilization;

  final int totalTasks;
  final int invoicedTasks;
  final int uninvoicedTasks;
  final int runningTasks;
  final String currencyId;
  final Date? dueDate;

  static ProjectBudgetSummary fromJson(Map<String, dynamic> j) =>
      ProjectBudgetSummary(
        budgetedHours: _double(j['budgeted_hours']),
        currentHours: _double(j['current_hours']),
        hoursRemaining: _double(j['hours_remaining']),
        utilization: _double(j['utilization']),
        budgetedAmount: _money(j['budgeted_amount']),
        actualAmount: _money(j['actual_amount']),
        remainingBudget: _money(j['remaining_budget']),
        budgetUtilization: _double(j['budget_utilization']),
        totalTasks: _int(j['total_tasks']),
        invoicedTasks: _int(j['invoiced_tasks']),
        uninvoicedTasks: _int(j['uninvoiced_tasks']),
        runningTasks: _int(j['running_tasks']),
        currencyId: j['currency_id']?.toString() ?? '',
        dueDate: Date.tryParse(j['due_date']?.toString() ?? ''),
      );
}

/// `budget_vs_actual[0]` — splits actual spend into labor vs expense.
class ProjectBudgetVsActual {
  const ProjectBudgetVsActual({
    required this.budgetedAmount,
    required this.actualAmount,
    required this.laborValue,
    required this.expenseAmount,
    required this.remainingBudget,
    required this.budgetUtilization,
    required this.currencyId,
  });

  final Decimal budgetedAmount;
  final Decimal actualAmount;
  final Decimal laborValue;
  final Decimal expenseAmount;
  final Decimal remainingBudget;
  final double budgetUtilization;
  final String currencyId;

  static ProjectBudgetVsActual fromJson(Map<String, dynamic> j) =>
      ProjectBudgetVsActual(
        budgetedAmount: _money(j['budgeted_amount']),
        actualAmount: _money(j['actual_amount']),
        laborValue: _money(j['labor_value']),
        expenseAmount: _money(j['expense_amount']),
        remainingBudget: _money(j['remaining_budget']),
        budgetUtilization: _double(j['budget_utilization']),
        currencyId: j['currency_id']?.toString() ?? '',
      );
}

/// `invoice_progress[0]` — work value → invoiced → paid funnel.
class ProjectInvoiceProgress {
  const ProjectInvoiceProgress({
    required this.workValue,
    required this.invoicedAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.unbilledAmount,
    required this.invoiceProgress,
    required this.paidProgress,
    required this.completionPercentage,
    required this.currencyId,
  });

  final Decimal workValue;
  final Decimal invoicedAmount;
  final Decimal paidAmount;
  final Decimal outstandingAmount;
  final Decimal unbilledAmount;

  /// Invoiced ÷ work value, 0..1+.
  final double invoiceProgress;

  /// Paid ÷ invoiced, 0..1+.
  final double paidProgress;

  /// Server-computed completion, already a percentage (0..100).
  final double completionPercentage;

  final String currencyId;

  static ProjectInvoiceProgress fromJson(Map<String, dynamic> j) =>
      ProjectInvoiceProgress(
        workValue: _money(j['work_value']),
        invoicedAmount: _money(j['invoiced_amount']),
        paidAmount: _money(j['paid_amount']),
        outstandingAmount: _money(j['outstanding_amount']),
        unbilledAmount: _money(j['unbilled_amount']),
        invoiceProgress: _double(j['invoice_progress']),
        paidProgress: _double(j['paid_progress']),
        completionPercentage: _double(j['completion_percentage']),
        currencyId: j['currency_id']?.toString() ?? '',
      );
}

/// `profitability[0]` — invoiced minus expenses.
class ProjectProfitability {
  const ProjectProfitability({
    required this.invoicedAmount,
    required this.expenseAmount,
    required this.netMargin,
    required this.marginRatio,
    required this.currencyId,
  });

  final Decimal invoicedAmount;
  final Decimal expenseAmount;
  final Decimal netMargin;

  /// Margin ÷ invoiced, 0..1 (can be negative).
  final double marginRatio;

  final String currencyId;

  static ProjectProfitability fromJson(Map<String, dynamic> j) =>
      ProjectProfitability(
        invoicedAmount: _money(j['invoiced_amount']),
        expenseAmount: _money(j['expense_amount']),
        netMargin: _money(j['net_margin']),
        marginRatio: _double(j['margin_ratio']),
        currencyId: j['currency_id']?.toString() ?? '',
      );
}

/// `project_health[0]` — server-scored health plus its contributing reasons.
class ProjectHealth {
  const ProjectHealth({
    required this.score,
    required this.status,
    required this.indicators,
  });

  /// 0..100 (server's own scale); lower is worse.
  final int score;

  /// Server-supplied status token, e.g. `healthy` / `at_risk` / `critical`.
  final String status;

  /// Free-form reason strings. The server may send a list or a
  /// keyed map — both flatten to a list of display strings here.
  final List<String> indicators;

  static ProjectHealth fromJson(Map<String, dynamic> j) {
    final raw = j['indicators'];
    final indicators = <String>[];
    if (raw is List) {
      for (final v in raw) {
        final s = _indicatorText(v);
        if (s.isNotEmpty) indicators.add(s);
      }
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        // Skip flags that are explicitly false — they aren't active reasons.
        if (entry.value == false) continue;
        final s = entry.value == true
            ? entry.key.toString()
            : _indicatorText(entry.value);
        if (s.isNotEmpty) indicators.add(s);
      }
    }
    return ProjectHealth(
      score: _int(j['health_score']),
      status: j['health_status']?.toString() ?? '',
      indicators: indicators,
    );
  }

  static String _indicatorText(Object? v) {
    if (v == null) return '';
    if (v is Map) {
      // Prefer a human-ish field if the server nests one.
      for (final key in const ['label', 'message', 'name', 'reason']) {
        final candidate = v[key];
        if (candidate != null && candidate.toString().isNotEmpty) {
          return candidate.toString();
        }
      }
      return '';
    }
    return v.toString();
  }
}

// ── shared tolerant decoders ────────────────────────────────────────────

/// Every analytics block is a list of per-project rows; the project-scoped
/// route returns exactly one. Returns null for absent / empty / wrong-typed
/// blocks so the UI can hide the card.
T? _firstRow<T>(Object? raw, T Function(Map<String, dynamic>) decode) {
  if (raw is! List || raw.isEmpty) return null;
  final first = raw.first;
  if (first is Map<String, dynamic>) return decode(first);
  if (first is Map) {
    return decode(first.map((k, v) => MapEntry(k.toString(), v)));
  }
  return null;
}

/// Money as `Decimal`, never `double` — the server emits floats here, but
/// routing through the string form keeps the domain type consistent with the
/// rest of the app.
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
  if (v is num) return v.round();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}
