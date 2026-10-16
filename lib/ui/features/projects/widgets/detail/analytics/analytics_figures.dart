import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/models/value/date.dart';

/// What the Analytics tab can honestly say, decided from the server's numbers
/// and the denominators behind them.
///
/// The server answers for every project, whether or not a figure means
/// anything: its `ratio()` is 0 for a zero denominator, remaining hours are
/// clamped at 0, and the forecast finish is *today* once nothing remains. So a
/// project with no hours budget "finishes today", one far over budget is
/// "N days ahead", a project with nothing invoiced has a 0% margin, and a new
/// project scores a green 100. Each function here turns one of those into
/// unknown, or into the thing it actually is.

/// The Forecast section's headline.
sealed class ForecastVerdict {
  const ForecastVerdict();
}

/// No hours budget: there is nothing to forecast the finish OF.
final class ForecastNeedsBudget extends ForecastVerdict {
  const ForecastNeedsBudget();
}

/// The budget is already spent — the server would say "finishes today".
final class ForecastOverBudget extends ForecastVerdict {
  const ForecastOverBudget(this.overBy);

  /// Logged minus budgeted hours, ≥ 0.
  final double overBy;
}

/// A budget and hours still to go, but no time logged to set a pace.
final class ForecastNeedsTime extends ForecastVerdict {
  const ForecastNeedsTime();
}

/// The server's forecast, which means what it says.
final class ForecastPace extends ForecastVerdict {
  const ForecastPace({
    required this.finish,
    required this.varianceDays,
    required this.velocity,
    required this.remainingHours,
  });

  final Date? finish;

  /// Positive ahead of the due date, negative behind; null without one.
  final int? varianceDays;
  final double velocity;
  final double remainingHours;
}

/// [forecast] read against the project's own budget. [budgetedHours] and
/// [loggedHours] come from wherever they are known — the analytics answer, or
/// the local project row when the user may not see the budget blocks.
ForecastVerdict forecastVerdict({
  required ProjectForecast? forecast,
  required double budgetedHours,
  required double loggedHours,
}) {
  if (budgetedHours <= 0) return const ForecastNeedsBudget();
  if (loggedHours >= budgetedHours) {
    return ForecastOverBudget(loggedHours - budgetedHours);
  }
  final f = forecast;
  if (f == null ||
      f.forecastFinishDate == null ||
      f.averageDailyVelocity <= 0) {
    return const ForecastNeedsTime();
  }
  return ForecastPace(
    finish: f.forecastFinishDate,
    varianceDays: f.scheduleVarianceDays,
    velocity: f.averageDailyVelocity,
    remainingHours: f.remainingHours,
  );
}

/// Whether the project has anything for the tab to show — time, money or
/// spend. Not whether the server sent rows: it always sends one per block,
/// so "no rows" never happened and a new project showed a page of zeros.
bool analyticsHasActivity(ProjectAnalytics a) {
  final hours = a.hours?.loggedHours ?? a.budgetSummary?.currentHours ?? 0;
  if (hours > 0) return true;
  if (a.velocity.isNotEmpty || a.team.isNotEmpty) return true;
  if (a.expenseCategories.isNotEmpty) return true;
  final money = [
    a.invoiceProgress?.invoicedAmount,
    a.invoiceProgress?.workValue,
    a.profitability?.expenseAmount,
    a.budgetVsActual?.actualAmount,
  ];
  return money.any((m) => m != null && m != Decimal.zero);
}

/// A share as a fraction, or null when its denominator is zero — the server
/// sends 0 there, which reads as "none" when it means "no basis".
double? shareOrNull(double ratio, {required bool hasBasis}) =>
    hasBasis ? ratio : null;

/// One line of a ranked breakdown.
class RankedRow<T> {
  const RankedRow({required this.value, this.item, this.folded = const []});

  /// The row's own item; null for "Other".
  final T? item;

  /// The ranking value — a bar length, so a `double`. A money row's figure
  /// is summed from [item] / [folded] in `Decimal`, never from this.
  final double value;

  /// The items "Other" stands for.
  final List<T> folded;

  int get foldedCount => folded.length;

  bool get isOther => item == null;
}

/// [items] largest first, zeros dropped, the first [keep] shown and the rest
/// folded into one "Other" row. The server sends every task on a project,
/// unsorted — 200 bars nobody can read.
List<RankedRow<T>> rankWithOther<T>(
  List<T> items,
  double Function(T) valueOf, {
  int keep = 8,
}) {
  final sorted = [
    for (final i in items)
      if (valueOf(i) > 0) i,
  ]..sort((a, b) => valueOf(b).compareTo(valueOf(a)));
  if (sorted.length <= keep + 1) {
    return [for (final i in sorted) RankedRow(item: i, value: valueOf(i))];
  }
  final rest = sorted.skip(keep).toList(growable: false);
  return [
    for (final i in sorted.take(keep)) RankedRow(item: i, value: valueOf(i)),
    RankedRow(
      value: rest.fold(0.0, (sum, i) => sum + valueOf(i)),
      folded: rest,
    ),
  ];
}

/// Hours per period for the velocity chart.
class VelocityBucket {
  const VelocityBucket(this.start, this.hours, this.billableHours);

  final Date start;
  final double hours;
  final double billableHours;
}

/// [days] spread over every day from the first log to [today] — or, past
/// [maxDailyBars] days, over every week — with the empty ones as zeros.
///
/// The server sends only the days that have logs. Drawn as given, a project
/// worked on two days a month looked as busy as one worked on daily: the gaps
/// are the information.
({List<VelocityBucket> buckets, bool weekly}) velocityBuckets(
  List<ProjectVelocityDay> days, {
  required Date today,
  int maxDailyBars = 60,
}) {
  final dated = [
    for (final d in days)
      if (d.day != null) d,
  ];
  if (dated.isEmpty) return (buckets: const [], weekly: false);
  final first = dated
      .map((d) => d.day!)
      .reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  final last = dated
      .map((d) => d.day!)
      .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
  final end = today.compareTo(last) > 0 ? today : last;
  final span = end.differenceInDays(first) + 1;
  final weekly = span > maxDailyBars;

  Date bucketOf(Date d) =>
      weekly ? d.addDays(-((d.toDateTime().weekday - 1) % 7)) : d;

  final hours = <Date, double>{};
  final billable = <Date, double>{};
  for (final d in dated) {
    final key = bucketOf(d.day!);
    hours[key] = (hours[key] ?? 0) + d.hours;
    billable[key] = (billable[key] ?? 0) + d.billableHours;
  }
  final buckets = <VelocityBucket>[];
  for (
    var d = bucketOf(first);
    d.compareTo(end) <= 0;
    d = d.addDays(weekly ? 7 : 1)
  ) {
    buckets.add(VelocityBucket(d, hours[d] ?? 0, billable[d] ?? 0));
  }
  return (buckets: buckets, weekly: weekly);
}

/// Spend to date at the end of one period — money, so `Decimal`; the plot
/// takes `toDouble()` of each as a coordinate only.
class SpendBucket {
  const SpendBucket(this.start, this.labor, this.expenses, this.total);

  final Date start;
  final Decimal labor;
  final Decimal expenses;
  final Decimal total;
}

/// The running totals in [points] at the end of every day from the first to
/// [today] — every week past [maxDailyBars] days — each period holding the
/// last total reached by then. The server sends only the days something was
/// spent; joined point to point, a total that sat still for a month sloped
/// up across it.
({List<SpendBucket> buckets, bool weekly}) spendBuckets(
  List<ProjectSpendPoint> points, {
  required Date today,
  int maxDailyBars = 60,
}) {
  final dated = [
    for (final p in points)
      if (p.day != null) p,
  ]..sort((a, b) => a.day!.compareTo(b.day!));
  if (dated.isEmpty) return (buckets: const [], weekly: false);
  final first = dated.first.day!;
  final last = dated.last.day!;
  final end = today.compareTo(last) > 0 ? today : last;
  final weekly = end.differenceInDays(first) + 1 > maxDailyBars;
  final step = weekly ? 7 : 1;
  Date startOf(Date d) =>
      weekly ? d.addDays(-((d.toDateTime().weekday - 1) % 7)) : d;

  final buckets = <SpendBucket>[];
  var i = 0;
  var labor = Decimal.zero;
  var expenses = Decimal.zero;
  var total = Decimal.zero;
  for (var d = startOf(first); d.compareTo(end) <= 0; d = d.addDays(step)) {
    final periodEnd = d.addDays(step - 1);
    while (i < dated.length && dated[i].day!.compareTo(periodEnd) <= 0) {
      labor = dated[i].labor;
      expenses = dated[i].expenses;
      total = dated[i].total;
      i++;
    }
    buckets.add(SpendBucket(d, labor, expenses, total));
  }
  return (buckets: buckets, weekly: weekly);
}
