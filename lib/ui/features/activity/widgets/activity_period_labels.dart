import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/activity/activity_timeline.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';

/// "1 event" / "N events".
String activityEventCount(BuildContext context, int n) => n == 1
    ? context.tr('activity_event_count_one')
    : context.tr('activity_event_count', {'count': '$n'});

/// A local calendar day in the company's date format, or ISO before the
/// company `Formatter` has loaded.
String activityDayLabel(DateTime day, Formatter? formatter) {
  final iso = Date(day.year, day.month, day.day).toIso();
  return formatter?.date(iso) ?? iso;
}

/// A local instant as the company date plus time.
///
/// `Formatter.date(showTime: true)` reads its input as server UTC and calls
/// `toLocal()`, so the local instant goes in as UTC to come back out as itself.
String activityInstantLabel(DateTime at, Formatter? formatter) =>
    formatter?.date(
      at.toUtc().toIso8601String(),
      showTime: true,
      showSeconds: false,
    ) ??
    at.toIso8601String();

bool _isMidnight(DateTime t) =>
    t.hour == 0 && t.minute == 0 && t.second == 0 && t.millisecond == 0;

/// `[from, until)` as the user reads it.
///
/// Whole days (both ends at midnight — a day / week / month / year bar, or a
/// calendar pick) print as an inclusive day range, so a single day is one
/// date rather than "6 Oct – 7 Oct". Anything finer (an hour bar) prints both
/// instants. An open end reads as "From …" / "To …".
String activityRangeLabel(
  BuildContext context, {
  required DateTime? from,
  required DateTime? until,
  required Formatter? formatter,
}) {
  final days =
      (from == null || _isMidnight(from)) &&
      (until == null || _isMidnight(until));
  String start(DateTime t) => days
      ? activityDayLabel(t, formatter)
      : activityInstantLabel(t, formatter);
  // The exclusive end, shown inclusively: the day before a midnight bound.
  String end(DateTime t) => days
      ? activityDayLabel(DateTime(t.year, t.month, t.day - 1), formatter)
      : activityInstantLabel(t, formatter);

  if (from != null && until != null) {
    final a = start(from);
    // An hour bar: one date, two times — "6 Oct 2026 3:00 PM – 4:00 PM".
    if (!days &&
        from.year == until.year &&
        from.month == until.month &&
        from.day == until.day &&
        formatter != null) {
      final b = formatter.date(
        until.toUtc().toIso8601String(),
        showDate: false,
        showTime: true,
        showSeconds: false,
      );
      return '$a – $b';
    }
    final b = end(until);
    return a == b ? a : '$a – $b';
  }
  if (from != null) return '${context.tr('from')} ${start(from)}';
  if (until != null) return '${context.tr('to')} ${end(until)}';
  return '';
}

/// A short axis tick for a bar starting at [start].
///
/// Locale-aware `DateFormat` **skeletons**, never literal patterns — a literal
/// pins the field order and drops the locale's own connectives. There is no
/// `Formatter` month-only or hour-only method, which is the same exception
/// `task_calendar_header.dart` documents.
String activityAxisLabel(
  DateTime start,
  TimelineBucketSize size,
  Formatter? formatter,
) {
  final locale = formatter?.settings.locale ?? '';
  // `DateFormat` misbehaves on `''`.
  final tag = locale.isEmpty ? null : locale;
  return switch (size) {
    TimelineBucketSize.hour => DateFormat.j(tag).format(start),
    TimelineBucketSize.day ||
    TimelineBucketSize.week => DateFormat.MMMd(tag).format(start),
    TimelineBucketSize.month => DateFormat.yMMM(tag).format(start),
    TimelineBucketSize.year => DateFormat.y(tag).format(start),
  };
}
