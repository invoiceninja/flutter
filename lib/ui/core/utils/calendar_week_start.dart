import 'package:flutter/material.dart';

import 'package:admin/utils/date_ranges.dart';
import 'package:admin/utils/formatting.dart';

/// Start-of-week for a **rendered calendar** (0=Sun..6=Sat): the company's
/// `first_day_of_week` when it was actually configured, otherwise the device
/// locale's first day.
///
/// Use this for every weekday-header grid — the dashboard date-range calendar,
/// Tasks → Calendar, Tasks → Weekly. Going through one helper is the point: the
/// three of them drifting apart is exactly the bug this fixes, and the next
/// calendar someone adds inherits the right rule for free.
///
/// **Not for date math.** Chart bucketing and report week grouping keep
/// `formatter.settings.firstDayOfWeek`, whose stable `0` default is what makes
/// grouped data comparable between two users — a locale-dependent bucket
/// boundary would make the same report disagree with itself across devices.
///
/// The distinction only exists because [CompanyFormatSettings] keeps
/// `configuredFirstDayOfWeek` nullable. Reading the non-null `firstDayOfWeek`
/// getter here would hand back a hard `0` and pin every unconfigured company to
/// Sunday, which is the dead-fallback bug this replaced. Normalized for the same
/// reason `startOfWeek` normalizes: an out-of-range value must fall back rather
/// than silently rotate the grid.
///
/// Needs `MaterialLocalizations`, so it cannot be called from `initState` —
/// seed from the company value there and correct in `didChangeDependencies`.
int calendarFirstDayOfWeek(BuildContext context, Formatter? formatter) =>
    normalizeFirstDayOfWeek(
      formatter?.settings.configuredFirstDayOfWeek ??
          MaterialLocalizations.of(context).firstDayOfWeekIndex,
    );
