import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/dashboard_api.dart'
    show kDashboardListPageSize;
import 'package:admin/domain/clients/client_past_due.dart';

/// How far ahead "due soon" and "expiring" look, in days, today included.
const int kAttentionSoonDays = 7;

/// The buckets of the dashboard's needs-attention band, in the order their
/// tabs are drawn.
enum AttentionTab { pastDue, dueSoon, quotesExpiring }

/// A count that knows whether it is exact.
///
/// A dashboard list is one page of fifty. The paginator's total makes the
/// count exact; without one (a payload cached before the totals were kept) a
/// full page can only say "at least this many".
class AttentionCount {
  const AttentionCount(this.value, {required this.exact});

  final int value;

  /// False when more records may match than [value] says — drawn as "50+".
  final bool exact;

  @override
  bool operator ==(Object other) =>
      other is AttentionCount && other.value == value && other.exact == exact;

  @override
  int get hashCode => Object.hash(value, exact);

  @override
  String toString() => exact ? '$value' : '$value+';
}

/// The narrowest a column of the side-by-side band may be — the width at
/// which a stacked row still holds a number, a client and an amount on its
/// first line.
const double kAttentionMinColumnWidth = 300;

/// The most columns the band lays out, however wide it is. Three is the
/// number of lists; more would only stretch rows again.
const int kAttentionMaxColumns = 3;

/// How many equal columns a band [width] wide has room for.
int attentionMaxSlots(double width) {
  if (!width.isFinite || width <= 0) return 0;
  return (width / kAttentionMinColumnWidth).floor().clamp(
    0,
    kAttentionMaxColumns,
  );
}

/// How many of the band's columns each list takes, in list order — or empty
/// when the lists do not fit side by side and the band falls back to tabs.
///
/// [counts] is the number of rows each non-empty list has in hand.
///
/// **Columns stay narrow, and a list with more rows than fit takes more of
/// them.** Every list starts with one column; a spare column goes to whichever
/// list is tallest for the columns it has (the earliest on a tie), as long as
/// it has a row to put there. So one list of six runs three columns of two,
/// "4 past due + 6 quotes" is one column and two, and three lists take one
/// each. A column that no list can use is left empty rather than shared out:
/// widening the others is what put the Remind button 700 px from the name it
/// acted on.
///
/// Empty (tabs) when there are more lists than columns, or room for fewer
/// than two columns.
List<int> attentionSlots({required double width, required List<int> counts}) {
  final lists = counts.length;
  final max = attentionMaxSlots(width);
  if (lists == 0 || max < 2 || lists > max) return const [];
  final slots = List<int>.filled(lists, 1);
  for (var spare = max - lists; spare > 0; spare--) {
    var pick = -1;
    var tallest = 0.0;
    for (var i = 0; i < lists; i++) {
      // A list needs one more row than it has columns to use another.
      if (counts[i] <= slots[i]) continue;
      final height = counts[i] / slots[i];
      if (height > tallest) {
        tallest = height;
        pick = i;
      }
    }
    if (pick < 0) break;
    slots[pick]++;
  }
  return slots;
}

/// How [rows] rows of one list are laid out over [columns] columns: filled
/// column by column (the most urgent stay on the left) and balanced, so three
/// rows over two columns are two and one — not three beside an empty column.
List<int> attentionFlow(int rows, int columns) {
  if (rows <= 0 || columns <= 0) return const [];
  final used = rows < columns ? rows : columns;
  final base = rows ~/ used;
  final extra = rows % used;
  return [for (var i = 0; i < used; i++) base + (i < extra ? 1 : 0)];
}

/// What an invoice row knows about how its client has been chased so far —
/// the thing that decides whether to remind, call, or wait.
enum AttentionFactKind { reminded, viewed, notOpened }

class AttentionFact {
  const AttentionFact(this.kind, [this.date]);

  final AttentionFactKind kind;

  /// When it happened. Null for [AttentionFactKind.notOpened].
  final Date? date;

  @override
  bool operator ==(Object other) =>
      other is AttentionFact && other.kind == kind && other.date == date;

  @override
  int get hashCode => Object.hash(kind, date);

  @override
  String toString() => 'AttentionFact($kind, $date)';
}

/// Everything the needs-attention band shows, worked out from the three lists
/// the dashboard already downloads — no request of its own.
class NeedsAttention {
  const NeedsAttention({
    required this.pastDue,
    required this.pastDueCount,
    required this.pastDueSum,
    required this.pastDueCurrencyId,
    required this.dueSoon,
    required this.dueSoonCount,
    required this.quotesExpiring,
    required this.quotesExpiringCount,
    required this.nextDue,
  });

  /// Nothing in any bucket — what a section that has not loaded yields too.
  static const NeedsAttention none = NeedsAttention(
    pastDue: [],
    pastDueCount: AttentionCount(0, exact: true),
    pastDueSum: null,
    pastDueCurrencyId: '',
    dueSoon: [],
    dueSoonCount: AttentionCount(0, exact: true),
    quotesExpiring: [],
    quotesExpiringCount: AttentionCount(0, exact: true),
    nextDue: null,
  );

  /// Past-due invoices, most overdue first (the server's order).
  final List<DashboardInvoiceRow> pastDue;
  final AttentionCount pastDueCount;

  /// What is late across [pastDue] — **null unless it is proven**: every
  /// past-due invoice is in the list, and they share one currency. A sum over
  /// the first fifty of eighty, or of pounds and euros together, is a number
  /// that looks like a fact and is not one.
  final Decimal? pastDueSum;

  /// The currency [pastDueSum] is in; empty for the company's own.
  final String pastDueCurrencyId;

  /// Unpaid invoices with something falling due within [kAttentionSoonDays],
  /// soonest first.
  final List<DashboardInvoiceRow> dueSoon;
  final AttentionCount dueSoonCount;

  /// Sent quotes that stop being valid within [kAttentionSoonDays], soonest
  /// first.
  final List<DashboardQuoteRow> quotesExpiring;
  final AttentionCount quotesExpiringCount;

  /// The next invoice to fall due, however far off — what the band says on a
  /// day with nothing in it.
  final DashboardInvoiceRow? nextDue;

  bool get isEmpty =>
      pastDue.isEmpty && dueSoon.isEmpty && quotesExpiring.isEmpty;

  /// The tabs that have something in them, in order.
  List<AttentionTab> get tabs => [
    if (pastDue.isNotEmpty) AttentionTab.pastDue,
    if (dueSoon.isNotEmpty) AttentionTab.dueSoon,
    if (quotesExpiring.isNotEmpty) AttentionTab.quotesExpiring,
  ];

  AttentionCount countFor(AttentionTab tab) => switch (tab) {
    AttentionTab.pastDue => pastDueCount,
    AttentionTab.dueSoon => dueSoonCount,
    AttentionTab.quotesExpiring => quotesExpiringCount,
  };
}

/// Builds the band's buckets.
///
/// A list that is null has not loaded (or failed with nothing cached) and
/// contributes nothing — the band never claims a bucket is empty on the
/// strength of a fetch that did not answer; it simply has no tab for it yet.
/// [invoices] / [quotes] are the module-and-permission gates: a company that
/// switched quotes off still has quote rows on the server, and they must not
/// surface here.
///
/// [companyCurrencyId] is what a row with no currency of its own is in. Given
/// it, a client with no override and one explicitly set to the company's
/// currency count as the same currency for the proven sum.
///
/// [today] is a parameter so nothing in this file reads a clock.
NeedsAttention needsAttention({
  required List<DashboardInvoiceRow>? pastDue,
  required List<DashboardInvoiceRow>? upcomingInvoices,
  required List<DashboardQuoteRow>? upcomingQuotes,
  required Date today,
  bool invoices = true,
  bool quotes = true,
  String companyCurrencyId = '',
}) {
  final horizon = today.addDays(kAttentionSoonDays);
  bool soon(Date? d) =>
      d != null && d.compareTo(today) >= 0 && d.compareTo(horizon) <= 0;

  final lateRows = invoices
      ? (pastDue ?? const <DashboardInvoiceRow>[])
      : const <DashboardInvoiceRow>[];
  final upcoming = invoices
      ? (upcomingInvoices ?? const <DashboardInvoiceRow>[])
      : const <DashboardInvoiceRow>[];
  final upcomingQ = quotes
      ? (upcomingQuotes ?? const <DashboardQuoteRow>[])
      : const <DashboardQuoteRow>[];

  final dueSoon = [
    for (final r in upcoming)
      if (soon(nextDueDate(r, today))) r,
  ]..sort((a, b) => nextDueDate(a, today)!.compareTo(nextDueDate(b, today)!));

  final expiring = [
    for (final q in upcomingQ)
      if (soon(q.validUntil)) q,
  ]..sort((a, b) => a.validUntil!.compareTo(b.validUntil!));

  DashboardInvoiceRow? nextDue;
  Date? nextDueOn;
  for (final r in upcoming) {
    final d = nextDueDate(r, today);
    if (d == null) continue;
    if (nextDueOn == null || d.compareTo(nextDueOn) < 0) {
      nextDue = r;
      nextDueOn = d;
    }
  }

  String currencyOf(DashboardInvoiceRow r) =>
      r.currencyId.isEmpty ? companyCurrencyId : r.currencyId;
  return NeedsAttention(
    pastDue: lateRows,
    pastDueCount: _countOf(lateRows),
    pastDueSum: _provenLateSum(lateRows, today, currencyOf),
    pastDueCurrencyId: lateRows.isEmpty ? '' : currencyOf(lateRows.first),
    dueSoon: dueSoon,
    // "Soon" is a slice of the upcoming list, so it is exact only when that
    // whole list was fetched; otherwise more may be due this week than the
    // page happened to hold.
    dueSoonCount: AttentionCount(dueSoon.length, exact: _isWhole(upcoming)),
    quotesExpiring: expiring,
    quotesExpiringCount: AttentionCount(
      expiring.length,
      exact: _isWhole(upcomingQ),
    ),
    nextDue: nextDue,
  );
}

/// How many days late [row] is as of [today]; zero when nothing on it is.
///
/// Measured from the invoice's own due date once that has passed, otherwise
/// from its deposit's — the server lists an invoice as past due the moment a
/// deposit is late, with the full due date still ahead, and measuring those
/// from `dueDate` gave a negative number.
int daysLate(DashboardInvoiceRow row, Date today) {
  final due = row.dueDate;
  if (due != null && due.compareTo(today) < 0) {
    return today.differenceInDays(due);
  }
  final depositDue = row.partialDueDate;
  if (depositDue != null &&
      (row.partial ?? Decimal.zero) > Decimal.zero &&
      depositDue.compareTo(today) < 0) {
    return today.differenceInDays(depositDue);
  }
  return 0;
}

/// How much of [row]'s balance is late as of [today] — the deposit alone while
/// only the deposit is. The same rule the client screen totals with.
Decimal lateAmountOfRow(DashboardInvoiceRow row, Date today) => lateAmount(
  dueDate: row.dueDate,
  partialDueDate: row.partialDueDate,
  partial: row.partial ?? Decimal.zero,
  balance: row.balance,
  today: today,
);

/// The next date something on [row] falls due, today included — its deposit's
/// date if that comes first. Null when it has no date still ahead.
Date? nextDueDate(DashboardInvoiceRow row, Date today) {
  Date? next;
  void consider(Date? d) {
    if (d == null || d.compareTo(today) < 0) return;
    if (next == null || d.compareTo(next!) < 0) next = d;
  }

  if ((row.partial ?? Decimal.zero) > Decimal.zero) {
    consider(row.partialDueDate);
  }
  consider(row.dueDate);
  return next;
}

/// What [row] knows about how its client has been chased, most recent first;
/// null when it was never sent to anyone.
AttentionFact? attentionFact(DashboardInvoiceRow row) {
  final reminded = row.lastReminderDate;
  final viewed = row.lastViewed;
  if (reminded != null && (viewed == null || reminded.compareTo(viewed) >= 0)) {
    return AttentionFact(AttentionFactKind.reminded, reminded);
  }
  if (viewed != null) return AttentionFact(AttentionFactKind.viewed, viewed);
  if (row.wasSent) return const AttentionFact(AttentionFactKind.notOpened);
  return null;
}

/// The reminder template a "Remind" on [row] should open on: the first of the
/// three numbered reminders not yet sent, then the endless one.
String nextInvoiceReminderTemplate(DashboardInvoiceRow row) =>
    switch (row.remindersSent) {
      <= 0 => 'reminder1',
      1 => 'reminder2',
      2 => 'reminder3',
      _ => 'reminder_endless',
    };

/// The one reminder template quotes have.
const String kQuoteReminderTemplate = 'quote_reminder1';

AttentionCount _countOf(List<Object?> rows) {
  final total = rows.serverTotal;
  if (total != null) return AttentionCount(total, exact: true);
  return AttentionCount(rows.length, exact: _isWhole(rows));
}

/// Whether [rows] is every matching record: the paginator says so, or — for a
/// payload with no total — the page came back short.
bool _isWhole(List<Object?> rows) {
  final total = rows.serverTotal;
  if (total != null) return total == rows.length;
  return rows.length < kDashboardListPageSize;
}

Decimal? _provenLateSum(
  List<DashboardInvoiceRow> rows,
  Date today,
  String Function(DashboardInvoiceRow) currencyOf,
) {
  if (rows.isEmpty || !_isWhole(rows)) return null;
  final currency = currencyOf(rows.first);
  var sum = Decimal.zero;
  for (final row in rows) {
    if (currencyOf(row) != currency) return null;
    sum += lateAmountOfRow(row, today);
  }
  return sum;
}
