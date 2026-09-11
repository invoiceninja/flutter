import 'package:intl/intl.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/utils/formatting.dart';

/// Display text for one group bucket key.
///
/// `ReportEngine` keys a date bucket by its **start date in ISO form**
/// (`2026-04-01` for April 2026), and that key is identity, not display:
/// `compute` re-derives it from the row's own cell to match `selectedGroup`
/// on drill-down, so a key whose *format* changes stops matching. Only what
/// the four render surfaces *show* may change (the chart's x-axis, the wide
/// group row, the drill breadcrumb, and the narrow card list).
///
/// Non-date columns pass through untouched: their key already *is* the
/// cell's display string.
///
/// Month / quarter / year go through a `DateFormat` **skeleton**
/// (`yMMMM` / `yQQQ` / `y`), never a literal pattern like `'MMMM yyyy'`.
/// A literal pins the field order and drops the locale's own connectives,
/// so it renders "septiembre 2026" without the `de` that `es` requires and
/// "9月 2026" instead of "2026年9月" — a backwards date in both bundled CJK
/// locales. The locale tag is the **company's** language
/// (`formatter.settings.locale`), not the UI's, matching every other date
/// the report renders. `task_calendar_header.dart` makes the same call for
/// the same reason.
///
/// Day and week resolve through [Formatter.date] instead, so they honour
/// the company's `date_format_id` like every other date on the screen; a
/// week bucket is labelled by the date it starts on.
String reportGroupDisplayLabel({
  required String key,
  required ReportColumnType? columnType,
  required ReportSubgroup? subgroup,
  required Formatter? formatter,
}) {
  if (columnType != ReportColumnType.date &&
      columnType != ReportColumnType.dateTime) {
    return key;
  }
  final date = Date.tryParse(key);
  // An unparsable key is the engine's own '' bucket for a null cell, or a
  // display string that only looked like a date — show it as-is.
  if (date == null) return key;

  switch (subgroup ?? ReportSubgroup.day) {
    case ReportSubgroup.day:
    case ReportSubgroup.week:
      return formatter?.date(key) ?? key;
    case ReportSubgroup.month:
      return _skeleton(formatter, (tag) => DateFormat.yMMMM(tag), date, key);
    case ReportSubgroup.quarter:
      return _skeleton(formatter, (tag) => DateFormat.yQQQ(tag), date, key);
    case ReportSubgroup.year:
      // The fiscal-year bucket is keyed by its start date, so a company on
      // an April fiscal year labels FY26/27 as "2026" — the conventional
      // reading, and the same one the range presets use.
      return _skeleton(formatter, (tag) => DateFormat.y(tag), date, key);
  }
}

/// Runs [build] against the company's locale, falling back to the raw key
/// if that locale's date symbols were never loaded. `DateFormat` throws
/// rather than degrading, and a report is not worth a crash: the app's
/// `GlobalMaterialLocalizations` delegate loads the bundled set, but
/// `settings.locale` is the company's language, which is not limited to it.
String _skeleton(
  Formatter? formatter,
  DateFormat Function(String? locale) build,
  Date date,
  String fallback,
) {
  final locale = formatter?.settings.locale;
  final tag = locale == null || locale.isEmpty ? null : locale;
  try {
    return build(tag).format(DateTime(date.year, date.month, date.day));
  } catch (_) {
    return fallback;
  }
}

/// Localization key naming a report's [ReportDefinition.dateRangeKey] — the
/// column its date range actually filters on.
///
/// Null for a key we have no translated name for: render nothing rather
/// than guess, since the whole point is to stop the range meaning something
/// the screen never said. `report_registry_date_keys_test` pins that every
/// key the registry declares resolves here.
String? reportDateKeyLabelKey(String? dateRangeKey) {
  switch (dateRangeKey) {
    case 'created_at':
      return 'created_at'; // "Date Created"
    case 'date':
      return 'date';
    case 'calculated_start_date':
      return 'start_date'; // tasks: `calculated_start_date`
    default:
      return null;
  }
}
