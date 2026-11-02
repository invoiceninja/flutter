import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/dashboard/needs_attention.dart';
import 'package:admin/domain/dashboard/totals_math.dart';
import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/domain/home_widgets/widget_snapshot.dart';
import 'package:admin/utils/formatting.dart';

/// `tr()` without a `BuildContext`.
typedef WidgetTranslate =
    String Function(String key, [Map<String, String>? params]);

/// The translation keys the widgets draw, sent in the snapshot's `strings` so
/// a widget speaks the app's language rather than the device's. Native code
/// reads them by key; a key it does not find falls back to its own English
/// (Android: `values*/widget_strings.xml`; iOS: the literal in the code).
const List<String> kWidgetStringKeys = [
  'outstanding',
  'past_due',
  'invoices',
  'payments',
  'expenses',
  'unpaid_count_label',
  'past_due_count_label',
  'days_late_count_singular',
  'days_late_count_plural',
  'widget_due_in_days',
  'widget_due_today',
  'widget_due_soon',
  'widget_nothing_past_due',
  'next_due',
  'updated',
  'widget_tap_to_refresh',
  'widget_open_company_to_update',
  'widget_running_count',
  'widget_running_since',
  'widget_start_a_task',
  'widget_stopped_syncs',
  'widget_sign_in',
  'widget_open_to_load',
  'widget_no_dashboard_permission',
  'widget_choose_company',
  'widget_update_app',
  'widget_amount_hidden',
  'widget_trend_up',
  'widget_trend_down',
  'widget_stop_task',
  'widget_start_task',
  'widget_in_currency',
  'stop',
  'today',
  'email_invoice',
  'this_month',
  'last30_days',
  'this_year',
];

/// Everything the builder needs about one company, read by the publisher
/// from Drift. Plain data so the builder is a pure function.
class WidgetCompanyInput {
  const WidgetCompanyInput({
    required this.id,
    required this.name,
    this.accent = '',
    this.canViewDashboard = false,
    this.showExpenses = false,
    this.showInvoices = true,
    this.formatter,
    this.currencyKey,
    this.baseCurrencyId = '',
    this.localeTag = 'en',
    this.firstMonthOfYear = 1,
    this.outstanding,
    this.outstandingFetchedAt,
    this.periods = const {},
    this.pastDue,
    this.upcoming,
    this.listsFetchedAt,
    this.runningTasks = const [],
    this.recentTasks = const [],
    this.clientNames = const {},
    this.canEditTask,
  });

  final String id;
  final String name;
  final String accent;

  /// `view_dashboard` (or admin) — without it no figure is written.
  final bool canViewDashboard;

  /// The in-app `showExpenses` gate (module + permission).
  final bool showExpenses;

  /// The invoices module: off, the past-due and due-soon rows are left out,
  /// as the dashboard leaves out its band.
  final bool showInvoices;

  /// Null until the company's formatter has resolved; no money is written
  /// without one.
  final Formatter? formatter;

  /// The dashboard's saved currency, as `selectedCurrencyKey` gives it: null
  /// for "All currencies".
  final String? currencyKey;
  final String baseCurrencyId;
  final String localeTag;
  final int firstMonthOfYear;

  final DashboardTotals? outstanding;
  final DateTime? outstandingFetchedAt;
  final Map<WidgetPeriod, WidgetPeriodInput> periods;

  /// Null while not loaded — never treated as "nothing past due".
  final List<DashboardInvoiceRow>? pastDue;
  final List<DashboardInvoiceRow>? upcoming;
  final DateTime? listsFetchedAt;

  /// Running tasks, newest first.
  final List<Task> runningTasks;

  /// Recently worked tasks that are not running, newest first.
  final List<Task> recentTasks;
  final Map<String, String> clientNames;

  /// The user's edit rule for a task (`AuthSession.canEditRecord`); null
  /// offers no Stop at all.
  final bool Function(Task task)? canEditTask;
}

class WidgetPeriodInput {
  const WidgetPeriodInput({
    required this.start,
    required this.end,
    this.current,
    this.previous,
    this.fetchedAt,
  });

  final Date start;
  final Date end;
  final DashboardTotals? current;
  final DashboardTotals? previous;
  final DateTime? fetchedAt;
}

/// How many days into a period a trend starts to mean something. Before that
/// a single invoice swings it ±90%.
const int kWidgetTrendMinDays = 6;

/// The largest trend shown as a number; beyond it the arrow alone says it.
const int kWidgetTrendMaxPct = 999;

WidgetSnapshot buildWidgetSnapshot({
  required String userId,
  required String activeCompanyId,
  required bool appLock,
  required bool rtl,
  required WidgetTranslate tr,
  required List<WidgetCompanyInput> companies,
  required Date today,

  /// The device's local clock, for the "Today" total. Defaults to now.
  DateTime? now,
}) => WidgetSnapshot(
  signedIn: true,
  userId: userId,
  appLock: appLock,
  rtl: rtl,
  activeCompanyId: activeCompanyId,
  strings: widgetStrings(tr),
  companies: [
    for (final c in companies) _company(c, today, now ?? DateTime.now(), tr),
  ],
);

/// The `strings` map for [tr].
Map<String, String> widgetStrings(WidgetTranslate tr) => {
  for (final key in kWidgetStringKeys) key: tr(key),
};

WidgetCompany _company(
  WidgetCompanyInput c,
  Date today,
  DateTime now,
  WidgetTranslate tr,
) {
  final running = c.runningTasks
      .map((t) => _timer(t, c.clientNames, c.canEditTask))
      .whereType<WidgetTimer>()
      .toList();
  return WidgetCompany(
    id: c.id,
    name: c.name,
    accent: c.accent,
    canViewDashboard: c.canViewDashboard,
    figures: c.canViewDashboard && c.formatter != null
        ? _figures(c, c.formatter!, today, tr)
        : null,
    timers: running.take(kWidgetMaxTimers).toList(),
    runningCount: running.length,
    recentTasks: [
      for (final t in c.recentTasks.take(kWidgetRecentTasks))
        WidgetTask(
          taskId: t.id,
          description: t.description,
          client: c.clientNames[t.clientId] ?? '',
        ),
    ],
    today: c.runningTasks.isEmpty && c.recentTasks.isEmpty
        ? null
        : WidgetToday(
            date: today.toIso(),
            doneSeconds: _doneToday([
              ...c.runningTasks,
              ...c.recentTasks,
            ], now: now).inSeconds,
          ),
  );
}

/// Finished, worked (not booked) time inside [now]'s local day, across
/// [tasks] — each counted once. A running entry is left to the widget.
Duration _doneToday(List<Task> tasks, {required DateTime now}) {
  final local = now.toLocal();
  final midnight = DateTime(local.year, local.month, local.day);
  final seen = <String>{};
  var total = Duration.zero;
  for (final t in tasks) {
    if (!seen.add(t.id)) continue;
    for (final e in t.timeLog) {
      final start = e.start;
      final stop = e.stop;
      if (start == null || stop == null) continue;
      if (isTimeEntryBooking(e, now: now, dueDate: t.dueDate)) continue;
      final from = start.isAfter(midnight) ? start : midnight;
      final to = stop.isBefore(now) ? stop : now;
      if (to.isAfter(from)) total += to.difference(from);
    }
  }
  return total;
}

WidgetFigures? _figures(
  WidgetCompanyInput c,
  Formatter f,
  Date today,
  WidgetTranslate tr,
) {
  WidgetMoney money(Decimal amount, String? currencyId) => WidgetMoney(
    text: f.money(amount, currencyId: currencyId),
    compact: f.money(amount, currencyId: currencyId, compact: true),
  );

  final key = c.currencyKey;
  final attention = c.pastDue == null && c.upcoming == null
      ? null
      : needsAttention(
          pastDue: c.pastDue,
          upcomingInvoices: c.upcoming,
          upcomingQuotes: const [],
          today: today,
          invoices: c.showInvoices,
          companyCurrencyId: c.baseCurrencyId,
        );

  WidgetOutstanding? outstanding;
  final outstandingTotals = c.outstanding;
  if (outstandingTotals != null) {
    final bucket = selectCurrencyTotals(outstandingTotals, key);
    final late = c.pastDue == null ? null : attention?.pastDueCount;
    final lateSum = attention?.pastDueSum;
    outstanding = WidgetOutstanding(
      amount: money(bucket?.outstandingAmount ?? Decimal.zero, key),
      unpaidCount: bucket?.outstandingCount ?? 0,
      pastDueCount: late?.value,
      pastDueExact: late?.exact ?? true,
      pastDueAmount: lateSum == null
          ? null
          : money(
              lateSum,
              attention!.pastDueCurrencyId.isEmpty
                  ? null
                  : attention.pastDueCurrencyId,
            ),
      pastDueShare: _share(
        lateSum,
        attention?.pastDueCurrencyId,
        bucket?.outstandingAmount,
        key ?? c.baseCurrencyId,
        c.baseCurrencyId,
      ),
    );
  }

  final periods = <WidgetPeriod, WidgetPeriodFigures>{};
  for (final MapEntry(key: period, value: input) in c.periods.entries) {
    final current = input.current == null
        ? null
        : selectCurrencyTotals(input.current, key);
    final previous = input.previous == null
        ? null
        : selectCurrencyTotals(input.previous, key);
    final known = input.current != null;
    final elapsed = today.differenceInDays(input.start) + 1;
    WidgetFigure? figure(
      Decimal? Function(DashboardCurrencyTotals? t) pick, {
      bool goodWhenUp = true,
    }) {
      if (!known) return null;
      final trend = widgetTrend(
        pick(current),
        pick(previous),
        elapsedDays: elapsed,
        goodWhenUp: goodWhenUp,
      );
      return WidgetFigure(
        amount: money(pick(current) ?? Decimal.zero, key),
        deltaPct: trend?.pct,
        good: trend?.good,
      );
    }

    periods[period] = WidgetPeriodFigures(
      label: tr(period.wire),
      name: widgetPeriodName(
        period,
        start: input.start,
        end: input.end,
        localeTag: c.localeTag,
        label: tr(period.wire),
      ),
      endsOn: input.end.toIso(),
      fetchedAt: input.fetchedAt,
      invoices: figure((t) => t?.invoicedAmount),
      payments: figure((t) => t?.revenuePaidToDate),
      expenses: c.showExpenses
          ? figure((t) => t?.expensesAmount, goodWhenUp: false)
          : null,
    );
  }

  WidgetAttention? attentionRows;
  if (attention != null) {
    WidgetInvoiceRow row(DashboardInvoiceRow r) {
      final late = daysLate(r, today);
      final next = nextDueDate(r, today);
      return WidgetInvoiceRow(
        id: r.id,
        number: r.number,
        client: r.clientName,
        amount: money(
          late > 0 ? lateAmountOfRow(r, today) : r.balance,
          r.currencyId.isEmpty ? null : r.currencyId,
        ),
        lateSince: late > 0 ? today.addDays(-late).toIso() : null,
        dueOn: late > 0 ? null : next?.toIso(),
      );
    }

    attentionRows = WidgetAttention(
      pastDue: [
        for (final r in attention.pastDue.take(kWidgetAttentionRows)) row(r),
      ],
      dueSoon: [
        for (final r in attention.dueSoon.take(kWidgetAttentionRows)) row(r),
      ],
      nextDue: attention.nextDue == null ? null : row(attention.nextDue!),
    );
  }

  if (outstanding == null && periods.isEmpty && attentionRows == null) {
    return null;
  }

  final stamps = [
    c.outstandingFetchedAt,
    c.listsFetchedAt,
    for (final p in c.periods.values) p.fetchedAt,
  ].whereType<DateTime>();
  return WidgetFigures(
    fetchedAt: stamps.isEmpty
        ? null
        : stamps.reduce((a, b) => a.isBefore(b) ? a : b),
    outstanding: outstanding,
    periods: periods,
    attention: attentionRows,
    // The server's "All currencies" bucket carries no code of its own: it is
    // the company's base currency, so the formatter names it.
    inCurrency:
        key == null && hasForeignCurrency(c.outstanding, c.baseCurrencyId)
        ? f.currencies[c.baseCurrencyId]?.code ?? ''
        : '',
  );
}

/// A period-over-period trend worth showing, or null.
///
/// Hidden in a period's first [kWidgetTrendMinDays] days (one invoice swings
/// it wildly) and wherever `percentDelta` has nothing to divide by.
({int pct, bool good})? widgetTrend(
  Decimal? current,
  Decimal? previous, {
  required int elapsedDays,
  required bool goodWhenUp,
}) {
  if (elapsedDays < kWidgetTrendMinDays) return null;
  final delta = percentDelta(current, previous);
  if (delta == null || delta.isNaN || delta.isInfinite) return null;
  final pct = delta.round().clamp(-kWidgetTrendMaxPct, kWidgetTrendMaxPct);
  if (pct == 0) return (pct: 0, good: true);
  return (pct: pct, good: goodWhenUp ? pct > 0 : pct < 0);
}

/// The concrete name of a period — "October", "2026", "2025–26" for a fiscal
/// year that straddles two — or [label] for a rolling window, which has none.
String widgetPeriodName(
  WidgetPeriod period, {
  required Date start,
  required Date end,
  required String localeTag,
  required String label,
}) {
  switch (period) {
    case WidgetPeriod.thisMonth:
      try {
        return DateFormat.MMMM(
          localeTag,
        ).format(DateTime(start.year, start.month));
      } on Object {
        // No date symbols for the locale (only outside the app, whose Material
        // localizations load them): the label still says which period it is.
        return label;
      }
    case WidgetPeriod.thisYear:
      return start.year == end.year
          ? '${start.year}'
          : '${start.year}–${end.year % 100}';
    case WidgetPeriod.last30Days:
      return label;
  }
}

WidgetTimer? _timer(
  Task task,
  Map<String, String> clientNames,
  bool Function(Task task)? canEdit,
) {
  if (!task.isRunning) return null;
  final since = task.timeLog.last.start;
  if (since == null) return null;
  return WidgetTimer(
    taskId: task.id,
    description: task.description,
    client: clientNames[task.clientId] ?? '',
    runningSince: since,
    // Everything worked before the running entry: measured at its start, the
    // running entry itself contributes nothing. `workedTime` leaves bookings
    // out, as every duration in the app does.
    priorSeconds: task.workedTime(since).inSeconds,
    canStop: canEdit?.call(task) ?? false,
  );
}

/// [late] over [total], 0–1 to two places — null unless both are known, in
/// one currency (`''` is the company's own), and [total] is above zero.
double? _share(
  Decimal? late,
  String? lateCurrencyId,
  Decimal? total,
  String totalCurrencyId,
  String baseCurrencyId,
) {
  if (late == null || lateCurrencyId == null || total == null) return null;
  if (total <= Decimal.zero) return null;
  final lateCurrency = lateCurrencyId.isEmpty ? baseCurrencyId : lateCurrencyId;
  if (lateCurrency != totalCurrencyId) return null;
  final share = (late.toDouble() / total.toDouble()).clamp(0.0, 1.0);
  return (share * 100).round() / 100;
}
