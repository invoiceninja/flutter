import 'package:flutter/widgets.dart';

import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';

/// The dashboard's active window as literal dates — `Apr 1, 2026 — Jun 30,
/// 2026`. Every figure on the dashboard is scoped to this window, so the page
/// headers state it rather than baking a period into individual tile labels
/// (flutter#37: the "Paid" tile used to read "Paid this month" under every
/// range, and on mobile the window appeared nowhere at all).
///
/// A preset is deliberately rendered as its resolved dates, not its name: the
/// name is already on the picker button, and "there's no visible date to give
/// it context" was the actual complaint. `allTime` is the one exception — it
/// resolves to a 50-year window (`dashboard_filter.dart`), and
/// "Jan 1, 1976 — Aug 16, 2026" is noise rather than context.
///
/// [formatter] is nullable because the dashboard paints its chrome before the
/// per-company `Formatter` resolves; the ISO fallback mirrors
/// `DateRangePickerButton`. `resolveDates()` already folds in
/// `firstMonthOfYear`, so a fiscal-year company gets the right `This Year` /
/// `Last Year` window for free. [today] is the same test seam
/// `DashboardDateRange.resolve` exposes — it lets a test fix the calendar
/// instead of monkey-patching `DateTime.now`.
String dashboardRangeDates(
  BuildContext context,
  DashboardFilter filter, {
  Formatter? formatter,
  Date? today,
}) {
  final range = filter.range;
  if (range is DashboardPresetRange &&
      range.preset == DashboardDatePreset.allTime) {
    return context.tr('all_time');
  }
  final (start, end) = filter.resolveDates(today: today);
  String fmt(Date d) => formatter?.date(d.toIso()) ?? d.toIso();
  return '${fmt(start)} — ${fmt(end)}';
}
