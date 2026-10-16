import 'package:decimal/decimal.dart';

import 'package:admin/data/models/value/date.dart';

/// In-memory projection of `POST /api/v1/charts/project_analytics/{project}`.
///
/// The server returns 14 blocks, each a **list** of per-project rows
/// (`ProjectAnalyticsService::generate`), plus `metadata`. The route is
/// project-scoped, so every list holds at most one row — this class flattens
/// to that single row and exposes `null` when a block is absent or empty.
///
/// **Every figure is the project's lifetime.** The service reads no dates.
///
/// **A user who may not see money gets `forecast_completion` alone** — every
/// other block comes back `[]` and [canViewFinancials] is false. And for such
/// a user the forecast is built from their OWN time logs
/// (`ProjectAnalyticsService::tasks` narrows to `user_id`), while the hours it
/// still has to cover are the whole project's.
///
/// **The server's zeros are not all zeros.** `ratio()` answers 0 for a zero
/// denominator, remaining hours are clamped at 0, and the forecast finish is
/// *today* once nothing remains — so a project with no hours budget reads
/// "finishes today", and one 150% over budget reads "finishes today, days
/// ahead". The model keeps the server's numbers; deciding which of them are
/// unknown is the screen's job (see `ProjectAnalyticsView`).
///
/// Decoding is tolerant: unknown keys are ignored, missing keys fall back to
/// zero/null, and money arrives as `Decimal` whether the server sent a number
/// or a string.
class ProjectAnalytics {
  const ProjectAnalytics({
    this.budgetSummary,
    this.budgetVsActual,
    this.hours,
    this.invoiceProgress,
    this.forecast,
    this.timeline,
    this.profitability,
    this.health,
    this.estimates,
    this.unbilled,
    this.team = const [],
    this.tasks = const [],
    this.velocity = const [],
    this.expenseCategories = const [],
    this.cumulativeSpend = const [],
    this.canViewFinancials = true,
    this.includeDrafts = false,
  });

  final ProjectBudgetSummary? budgetSummary;
  final ProjectBudgetVsActual? budgetVsActual;

  /// `estimated_vs_logged_hours[0]`'s hours half — "estimated" there is the
  /// project's BUDGETED hours, not the tasks' estimates ([estimates]).
  final ProjectHours? hours;
  final ProjectInvoiceProgress? invoiceProgress;
  final ProjectForecast? forecast;
  final ProjectTimeline? timeline;
  final ProjectProfitability? profitability;
  final ProjectHealth? health;

  /// Task-estimate figures (React #3380). Null on a server older than the
  /// task `estimated_duration` field, and when nothing on the project is
  /// estimated — see [ProjectEstimates.hasAny].
  final ProjectEstimates? estimates;
  final ProjectUnbilled? unbilled;

  /// Who logged time on the project, in the server's order.
  final List<ProjectTeamMember> team;

  /// Every task on the project with its logged time, in the server's order —
  /// unsorted and uncapped.
  final List<ProjectTaskTime> tasks;

  /// Hours per calendar day — only the days that HAVE logs, ascending.
  final List<ProjectVelocityDay> velocity;

  final List<ProjectExpenseCategory> expenseCategories;

  /// Labour and expense spend summed day by day — again only the days that
  /// carry either, ascending.
  final List<ProjectSpendPoint> cumulativeSpend;

  /// `metadata.can_view_financials`. **Missing reads as true**: a 5.13.27
  /// server sends no metadata at all and gates the whole endpoint on
  /// `view_dashboard` instead, so anyone it answers may see the money.
  final bool canViewFinancials;

  /// `metadata.include_drafts`, echoed.
  final bool includeDrafts;

  static ProjectAnalytics fromJson(Map<String, dynamic> json) {
    final meta = _asMap(json['metadata']);
    final canView = meta['can_view_financials'];
    return ProjectAnalytics(
      budgetSummary: _firstRow(
        json['budget_summary'],
        ProjectBudgetSummary.fromJson,
      ),
      budgetVsActual: _firstRow(
        json['budget_vs_actual'],
        ProjectBudgetVsActual.fromJson,
      ),
      hours: _firstRow(
        json['estimated_vs_logged_hours'],
        ProjectHours.fromJson,
      ),
      invoiceProgress: _firstRow(
        json['invoice_progress'],
        ProjectInvoiceProgress.fromJson,
      ),
      forecast: _firstRow(
        json['forecast_completion'],
        ProjectForecast.fromJson,
      ),
      timeline: _firstRow(json['timeline_variance'], ProjectTimeline.fromJson),
      profitability: _firstRow(
        json['profitability'],
        ProjectProfitability.fromJson,
      ),
      health: _firstRow(json['project_health'], ProjectHealth.fromJson),
      estimates: _estimates(json['estimated_vs_logged_hours']),
      unbilled: _firstRow(json['unbilled_hours'], ProjectUnbilled.fromJson),
      team: _nested(
        json['team_contribution'],
        'team_contribution',
        ProjectTeamMember.fromJson,
      ),
      tasks: _nested(
        json['time_distribution'],
        'time_distribution',
        ProjectTaskTime.fromJson,
      ),
      velocity: _nested(
        json['velocity_trend'],
        'velocity_trend',
        ProjectVelocityDay.fromJson,
      ).where((d) => d.day != null).toList(growable: false),
      expenseCategories: _nested(
        json['expense_breakdown'],
        'expense_breakdown',
        ProjectExpenseCategory.fromJson,
      ),
      cumulativeSpend: _nested(
        json['cumulative_spend'],
        'cumulative_spend',
        ProjectSpendPoint.fromJson,
      ).where((p) => p.day != null).toList(growable: false),
      canViewFinancials:
          canView == null || const {'true', '1'}.contains('$canView'),
      includeDrafts: meta['include_drafts'] == true,
    );
  }

  /// Only when the server sends the task-estimate fields at all — an older
  /// server's `estimated_vs_logged_hours` row has none of them, and a card of
  /// zeros would claim "nothing is estimated" about a server that can't say.
  static ProjectEstimates? _estimates(Object? raw) {
    final row = _firstRow(raw, (j) => j);
    if (row == null || !row.containsKey('task_estimated_hours')) return null;
    final estimates = ProjectEstimates.fromJson(row);
    return estimates.hasAny ? estimates : null;
  }
}

/// `estimated_vs_logged_hours[0]` — hours against the project's budget.
class ProjectHours {
  const ProjectHours({
    required this.budgetedHours,
    required this.loggedHours,
    required this.billableHours,
    required this.remainingHours,
  });

  /// The project's budgeted hours (the server calls it `estimated_hours`).
  final double budgetedHours;
  final double loggedHours;
  final double billableHours;

  /// `max(budgeted − logged, 0)` — zero both with no budget and over it.
  final double remainingHours;

  static ProjectHours fromJson(Map<String, dynamic> j) => ProjectHours(
    budgetedHours: _double(j['estimated_hours']),
    loggedHours: _double(j['logged_hours']),
    billableHours: _double(j['billable_hours']),
    remainingHours: _double(j['remaining_hours']),
  );
}

/// `estimated_vs_logged_hours[0]`'s task-estimate half: what the project's
/// tasks were estimated at, against what has been logged.
class ProjectEstimates {
  const ProjectEstimates({
    required this.estimatedHours,
    required this.loggedHours,
    required this.remainingEstimatedHours,
    required this.unestimatedTasks,
    required this.tasksOverEstimate,
  });

  /// Sum of the tasks' `estimated_duration`, in hours.
  final double estimatedHours;
  final double loggedHours;

  /// Estimated hours still to go on active tasks.
  final double remainingEstimatedHours;

  /// Active tasks with no estimate — the caveat on every figure above.
  final int unestimatedTasks;

  /// Active tasks already past their estimate.
  final int tasksOverEstimate;

  /// Whether any task carries an estimate. With none, every figure here is a
  /// zero that means "not estimated", not "no work left".
  bool get hasAny => estimatedHours > 0;

  static ProjectEstimates fromJson(Map<String, dynamic> j) => ProjectEstimates(
    estimatedHours: _double(j['task_estimated_hours']),
    loggedHours: _double(j['logged_hours']),
    remainingEstimatedHours: _double(j['remaining_estimated_hours']),
    unestimatedTasks: _int(j['unestimated_active_task_count']),
    tasksOverEstimate: _int(j['active_tasks_over_estimate_count']),
  );
}

/// `forecast_completion[0]` — the one block every user gets.
class ProjectForecast {
  const ProjectForecast({
    required this.averageDailyVelocity,
    required this.remainingHours,
    required this.forecastFinishDate,
    required this.dueDate,
    required this.scheduleVarianceDays,
  });

  /// Hours per day ON THE DAYS SOMEONE LOGGED TIME — not per calendar day.
  final double averageDailyVelocity;

  /// `max(budgeted − logged, 0)`.
  final double remainingHours;

  /// Today plus `ceil(remaining ÷ velocity)` days; today once nothing
  /// remains, null when nothing has been logged.
  final Date? forecastFinishDate;
  final Date? dueDate;

  /// Due date minus forecast finish, in days: positive is ahead, negative
  /// behind. Null without both dates.
  final int? scheduleVarianceDays;

  static ProjectForecast fromJson(Map<String, dynamic> j) => ProjectForecast(
    averageDailyVelocity: _double(j['average_daily_velocity']),
    remainingHours: _double(j['remaining_hours']),
    forecastFinishDate: _date(j['forecast_finish_date']),
    dueDate: _date(j['due_date']),
    scheduleVarianceDays: _intOrNull(j['schedule_variance_days']),
  );
}

/// `timeline_variance[0]` — how far along the project is against how far
/// along the calendar says it should be.
class ProjectTimeline {
  const ProjectTimeline({
    required this.completionPercentage,
    required this.idealProgressPercentage,
  });

  /// Logged ÷ budgeted hours (capped at 100), or completed ÷ total tasks when
  /// there is no hours budget.
  final double completionPercentage;

  /// Share of the created → due span already elapsed; null with no due date.
  final double? idealProgressPercentage;

  static ProjectTimeline fromJson(Map<String, dynamic> j) => ProjectTimeline(
    completionPercentage: _double(j['completion_percentage']),
    idealProgressPercentage: j['ideal_progress_percentage'] == null
        ? null
        : _double(j['ideal_progress_percentage']),
  );
}

/// `unbilled_hours[0]` — billable time on tasks not yet invoiced.
class ProjectUnbilled {
  const ProjectUnbilled({
    required this.hours,
    required this.amount,
    required this.uninvoicedTasks,
    required this.currencyId,
  });

  final double hours;
  final Decimal amount;
  final int uninvoicedTasks;
  final String currencyId;

  static ProjectUnbilled fromJson(Map<String, dynamic> j) => ProjectUnbilled(
    hours: _double(j['unbilled_hours']),
    amount: _money(j['unbilled_amount']),
    uninvoicedTasks: _int(j['uninvoiced_tasks']),
    currencyId: j['currency_id']?.toString() ?? '',
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
    required this.taskRate,
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

  final Decimal taskRate;
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
        taskRate: _money(j['task_rate']),
        totalTasks: _int(j['total_tasks']),
        invoicedTasks: _int(j['invoiced_tasks']),
        uninvoicedTasks: _int(j['uninvoiced_tasks']),
        runningTasks: _int(j['running_tasks']),
        currencyId: j['currency_id']?.toString() ?? '',
        dueDate: _date(j['due_date']),
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

  /// Invoiced ÷ work value, 0..1+ — and 0 when there is no work value.
  final double invoiceProgress;

  /// Paid ÷ invoiced, 0..1+ — and 0 when nothing is invoiced.
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

  /// Margin ÷ invoiced, 0..1 (can be negative) — and 0 when nothing is
  /// invoiced, which is not a 0% margin.
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

/// The server's health verdict, `green` / `amber` / `red` from the score
/// (`ProjectAnalyticsService::healthStatus`: ≥ 75, ≥ 50, below).
enum ProjectHealthStatus {
  good,
  fair,
  poor,
  unknown;

  static ProjectHealthStatus parse(String wire) => switch (wire) {
    'green' => good,
    'amber' => fair,
    'red' => poor,
    _ => unknown,
  };
}

/// `project_health[0]` — the server's 0–100 score and the five inputs it is
/// docked for.
class ProjectHealth {
  const ProjectHealth({
    required this.score,
    required this.status,
    required this.budgetUtilization,
    required this.scheduleVarianceDays,
    required this.marginRatio,
    required this.unbilledRatio,
    required this.outstandingRatio,
  });

  /// 0..100; lower is worse. Docked up to 25 for a budget overrun, 25 for
  /// slipping (20 for being past due unfinished), 20 for a negative margin
  /// (10 under 15%), 10 each for unbilled and outstanding shares.
  final double score;
  final ProjectHealthStatus status;

  /// Actual ÷ budgeted money — 0 with no money budget.
  final double budgetUtilization;

  /// Positive ahead, negative behind; null without a due date or forecast.
  final int? scheduleVarianceDays;

  /// Margin ÷ invoiced — 0 with nothing invoiced.
  final double marginRatio;

  /// Unbilled ÷ work value — 0 with no work value.
  final double unbilledRatio;

  /// Outstanding ÷ invoiced — 0 with nothing invoiced.
  final double outstandingRatio;

  static ProjectHealth fromJson(Map<String, dynamic> j) {
    final i = _asMap(j['indicators']);
    return ProjectHealth(
      score: _double(j['health_score']),
      status: ProjectHealthStatus.parse(j['health_status']?.toString() ?? ''),
      budgetUtilization: _double(i['budget_utilization']),
      scheduleVarianceDays: _intOrNull(i['schedule_variance_days']),
      marginRatio: _double(i['margin_ratio']),
      unbilledRatio: _double(i['unbilled_ratio']),
      outstandingRatio: _double(i['outstanding_ratio']),
    );
  }
}

/// One person in `team_contribution[0].team_contribution`.
class ProjectTeamMember {
  const ProjectTeamMember({
    required this.userId,
    required this.userName,
    required this.loggedHours,
    required this.billableHours,
    required this.billableValue,
    required this.taskCount,
  });

  final String userId;
  final String userName;
  final double loggedHours;
  final double billableHours;
  final Decimal billableValue;
  final int taskCount;

  static ProjectTeamMember fromJson(Map<String, dynamic> j) =>
      ProjectTeamMember(
        userId: j['user_id']?.toString() ?? '',
        userName: j['user_name']?.toString() ?? '',
        loggedHours: _double(j['logged_hours']),
        billableHours: _double(j['billable_hours']),
        billableValue: _money(j['billable_value']),
        taskCount: _int(j['task_count']),
      );
}

/// One task in `time_distribution[0].time_distribution`.
class ProjectTaskTime {
  const ProjectTaskTime({
    required this.taskId,
    required this.number,
    required this.description,
    required this.statusName,
    required this.loggedHours,
    required this.billableHours,
    required this.isCompleted,
    required this.isInvoiced,
  });

  final String taskId;
  final String number;
  final String description;
  final String statusName;
  final double loggedHours;
  final double billableHours;
  final bool isCompleted;
  final bool isInvoiced;

  static ProjectTaskTime fromJson(Map<String, dynamic> j) => ProjectTaskTime(
    taskId: j['task_id']?.toString() ?? '',
    number: j['task_number']?.toString() ?? '',
    description: j['description']?.toString() ?? '',
    statusName: j['status_name']?.toString() ?? '',
    loggedHours: _double(j['logged_hours']),
    billableHours: _double(j['billable_hours']),
    isCompleted: j['is_completed'] == true,
    isInvoiced: j['is_invoiced'] == true,
  );
}

/// One day in `velocity_trend[0].velocity_trend`.
class ProjectVelocityDay {
  const ProjectVelocityDay({
    required this.day,
    required this.hours,
    required this.billableHours,
  });

  final Date? day;
  final double hours;
  final double billableHours;

  static ProjectVelocityDay fromJson(Map<String, dynamic> j) =>
      ProjectVelocityDay(
        day: _date(j['period']),
        hours: _double(j['hours']),
        billableHours: _double(j['billable_hours']),
      );
}

/// One category in `expense_breakdown[0].expense_breakdown`.
class ProjectExpenseCategory {
  const ProjectExpenseCategory({
    required this.categoryId,
    required this.name,
    required this.count,
    required this.amount,
  });

  /// Null for expenses with no category — the server names that bucket
  /// "Uncategorized" in English, so the screen labels it itself.
  final String? categoryId;
  final String name;
  final int count;
  final Decimal amount;

  static ProjectExpenseCategory fromJson(Map<String, dynamic> j) {
    final id = j['category_id']?.toString() ?? '';
    return ProjectExpenseCategory(
      categoryId: id.isEmpty ? null : id,
      name: j['category_name']?.toString() ?? '',
      count: _int(j['expense_count']),
      amount: _money(j['expense_amount']),
    );
  }
}

/// One day in `cumulative_spend[0].cumulative_spend`.
class ProjectSpendPoint {
  const ProjectSpendPoint({
    required this.day,
    required this.labor,
    required this.expenses,
    required this.total,
  });

  final Date? day;

  /// Running totals to the end of [day].
  final Decimal labor;
  final Decimal expenses;
  final Decimal total;

  static ProjectSpendPoint fromJson(Map<String, dynamic> j) =>
      ProjectSpendPoint(
        day: _date(j['period']),
        labor: _money(j['cumulative_labor_value']),
        expenses: _money(j['cumulative_expense_amount']),
        total: _money(j['cumulative_actual_amount']),
      );
}

// ── shared tolerant decoders ────────────────────────────────────────────

/// Every analytics block is a list of per-project rows; the project-scoped
/// route returns exactly one. Returns null for absent / empty / wrong-typed
/// blocks so the UI can hide the card.
T? _firstRow<T>(Object? raw, T Function(Map<String, dynamic>) decode) {
  if (raw is! List || raw.isEmpty) return null;
  final first = raw.first;
  if (first is! Map) return null;
  return decode(_asMap(first));
}

/// The series blocks nest their rows one level down:
/// `team_contribution: [{project_id, …, team_contribution: [rows]}]`.
List<T> _nested<T>(
  Object? raw,
  String key,
  T Function(Map<String, dynamic>) decode,
) {
  final row = _firstRow(raw, (j) => j);
  final rows = row?[key];
  if (rows is! List) return const [];
  return [
    for (final r in rows)
      if (r is Map) decode(_asMap(r)),
  ];
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
  return const <String, dynamic>{};
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

int? _intOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.round();
  return int.tryParse(v.toString());
}

Date? _date(Object? v) => Date.tryParse(v?.toString() ?? '');
