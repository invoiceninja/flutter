import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/utils/formatting.dart';

/// Build the `notes` body of the invoice line item a task converts into.
///
/// Ports admin-portal's `convertTaskToInvoiceItem`
/// (`lib/redux/task/task_selectors.dart:17-222`), cross-checked against the
/// server's own converters — `Task::description()` (`app/Models/Task.php:442`)
/// and `ProjectRepository::invoice()` (`app/Repositories/ProjectRepository.php:117`).
/// Pure and widget-free so it unit-tests without a `BuildContext`; the two
/// localized hour labels are passed in for the same reason.
///
/// The body has three optional parts, in order:
///
///  1. a **project header**, emitted only for the first task of each project's
///     run on a shared invoice ([includeProjectHeader]) — this is the only way
///     a multi-project invoice can separate its projects, since an invoice
///     carries one `project_id` and a line item carries none at all;
///  2. the task's own `description`;
///  3. a `<div class="task-time-details">` block expanding the time log,
///     governed by the company's Task Settings toggles.
///
/// With every toggle off (the default) the result is exactly `task.description`
/// — the behaviour before this function existed.
///
/// Where the two reference implementations disagree, and why:
///
///  * **Hours as the only toggle** lists one bare `2.5 hours` line per entry —
///    the server's behaviour (`Task::description()` pushes the duration into
///    the line regardless of the other flags). v1 emits nothing at all, which
///    makes "Add the hours to the invoice line items" a setting that does
///    nothing when it's the only one on.
///  * **Time entries are filtered on `entry.billable` alone**, matching v1.
///    The server also admits non-billable entries when
///    `allow_billable_task_items` is on, which lists hours the line's own
///    quantity (billable-only) doesn't charge for.
///  * **Hours keep 3-decimal precision** (see `taskBillableHours`, matching
///    v1) where the server's `getQuantity()` rounds to 2. Singular reads
///    `1 hour`; the server writes `1 hours`.
///  * **Times render without seconds.** v1 and the server both emit `h:i:s A`;
///    `9:00:00 AM - 11:30:00 AM` is noise on a customer-facing line when the
///    hours are stated right beside it.
///  * **Dates in the aggregated (datelog-only) mode sort on the underlying
///    day**, not on the rendered string as v1 does — under a non-ISO
///    `date_format_id`, `12/31/2025` sorts above `01/15/2026` lexicographically
///    and the list comes out in a meaningless order.
///  * **No dangling `<br/>`** before the closing `</div>`, and **no wrapper at
///    all** when nothing would go inside it. v1 emits both; an empty
///    `<div class="task-time-details"></div>` is the entire notes body for a
///    task with no description whose entries are all non-billable.
///
/// **The output is HTML in both markdown modes**, which is the one place this
/// follows the server over v1. v1 swaps in `## Name` and bare newlines when
/// `markdown_enabled` is on; on the rendered PDF that is strictly worse:
///
///  * every stock design styles `.project-header` (1.2em, bold, #505050) and
///    `.task-time-details` (grey block), and **none** of them style `h1`–`h6`
///    — so the markdown heading lands as an unstyled `<h2>` with browser
///    default margins inside a table cell;
///  * a bare `\n` collapses in HTML, so the time entries run together on one
///    line — and `markdown_enabled` is **off** by default
///    (`CompanyFactory.php`), making that the common case.
///
/// The server's own converters (`ProjectRepository::invoice()`,
/// `InvoiceOutstandingTasksService`) hardcode the same `<div>` shapes and never
/// emit `##`. `PdfBuilder` passes anything containing `<…>` through as real
/// HTML regardless of the markdown setting, so this renders identically either
/// way.
String taskInvoiceNotes(
  Task task, {
  required Company company,
  Formatter? formatter,
  Project? project,
  bool includeProjectHeader = false,
  DateTime? now,
  String hourLabel = 'hour',
  String hoursLabel = 'hours',
}) {
  // Always an explicit `<br/>`: this block renders as HTML in a table cell, so
  // a bare newline collapses and every time entry runs onto one line.
  const lineBreak = '<br/>\n';

  final buffer = StringBuffer();

  // Two settings gate this, and both are checked here so a caller can't
  // accidentally print a header the company turned off: `invoice_task_project`
  // says "show the project" at all, and `invoice_task_project_header` — the
  // "Project Location" dropdown — says *where*: the description (here) or the
  // Service column (`product_key`, which `taskToLineItem` fills). All
  // [includeProjectHeader] itself means is "this line starts a project's run".
  if (includeProjectHeader &&
      company.invoiceTaskProject &&
      company.invoiceTaskProjectHeader &&
      project != null &&
      project.name.trim().isNotEmpty) {
    // `.project-header` is styled by every stock design; an `<h2>` from `##`
    // is styled by none. See the note above the function.
    buffer.write('<div class="project-header">${project.name.trim()}</div>\n');
  }

  buffer.write(task.description);

  final wantsTimeDetails =
      company.invoiceTaskDatelog ||
      company.invoiceTaskTimelog ||
      company.invoiceTaskHours;
  if (!wantsTimeDetails) return buffer.toString().trim();

  // Built separately from [buffer] so the `<div class="task-time-details">`
  // wrapper can be skipped entirely when nothing lands inside it — an empty
  // one is visible junk on the invoice, and for a task with no description
  // whose entries are all non-billable it would be the whole notes body.
  final lines = <String>[];

  // Date-only mode aggregates hours across every entry on the same day, so it
  // can't stream — collect keyed by the *sortable* day (the rendered date is
  // whatever `date_format_id` says, and sorting those strings puts 12/31 above
  // 01/15) and format once at the end.
  final perDayHours = <String, double>{};

  for (final entry in task.timeLog) {
    if (entry.start == null || entry.stop == null || !entry.billable) continue;
    final hours = entry.durationUpTo(now ?? DateTime.now()).inSeconds / 3600;
    final hoursText = _hoursText(hours, formatter, hourLabel, hoursLabel);
    final hoursSuffix = company.invoiceTaskHours ? ' • $hoursText' : '';

    if (company.invoiceTaskDatelog && company.invoiceTaskTimelog) {
      final start = _fmt(
        formatter,
        entry.start!,
        showDate: true,
        showTime: true,
      );
      final end = _fmt(formatter, entry.stop!, showDate: false, showTime: true);
      lines.add('$start - $end$hoursSuffix');
      _addEntryDescription(lines, entry, company);
    } else if (company.invoiceTaskTimelog) {
      final start = _fmt(
        formatter,
        entry.start!,
        showDate: false,
        showTime: true,
      );
      final end = _fmt(formatter, entry.stop!, showDate: false, showTime: true);
      lines.add('$start - $end$hoursSuffix');
      _addEntryDescription(lines, entry, company);
    } else if (company.invoiceTaskDatelog) {
      perDayHours[_isoDay(entry.start!)] =
          (perDayHours[_isoDay(entry.start!)] ?? 0) + hours;
    } else {
      // Hours only. The server lists the duration per entry here; v1 lists
      // nothing, which leaves "Add the hours to the invoice line items" doing
      // nothing at all when it's the only toggle on.
      lines.add(hoursText);
      _addEntryDescription(lines, entry, company);
    }
  }

  if (company.invoiceTaskDatelog && !company.invoiceTaskTimelog) {
    final days = perDayHours.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final day in days) {
      final date = _fmt(formatter, DateTime.parse(day), showDate: true);
      lines.add(
        company.invoiceTaskHours
            ? '$date • ${_hoursText(perDayHours[day]!, formatter, hourLabel, hoursLabel)}'
            : date,
      );
    }
  }

  if (lines.isEmpty) return buffer.toString().trim();

  if (buffer.toString().trim().isNotEmpty) buffer.write('\n');
  // `join`, not a trailing break per line: v1 closes the block with a dangling
  // `<br/>` that renders an extra blank line inside the details box.
  buffer
    ..write('<div class="task-time-details">\n')
    ..write(lines.join(lineBreak))
    ..write('\n</div>');
  return buffer.toString().trim();
}

/// The entry's start as a sortable `yyyy-MM-dd` in local time — the key the
/// datelog-only aggregation groups and orders by. Local, not UTC: a 9pm entry
/// belongs to the day the user worked it, which is what the rendered date will
/// say too (see [_fmt]).
String _isoDay(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// Per-entry note, added under its time line when
/// `invoice_task_item_description` is on and the entry actually has one.
void _addEntryDescription(
  List<String> lines,
  TimeEntry entry,
  Company company,
) {
  if (!company.invoiceTaskItemDescription) return;
  final text = entry.description.trim();
  if (text.isEmpty) return;
  lines.add(text);
}

/// `2.5 hours` / `1 hour`. Falls back to a plain `toString` when no company
/// [Formatter] is available (unit tests, pre-boot call sites).
String _hoursText(
  double hours,
  Formatter? formatter,
  String hourLabel,
  String hoursLabel,
) {
  final rounded = double.parse(hours.toStringAsFixed(3));
  if (rounded == 1) return '1 $hourLabel';
  final text =
      formatter?.decimal(rounded, maxDecimals: 3) ?? _plainNumber(rounded);
  return '$text $hoursLabel';
}

/// `2.5` not `2.5000000001`, and `2` not `2.0` — the no-Formatter fallback.
String _plainNumber(double value) {
  final text = value.toStringAsFixed(3);
  return text.contains('.') ? text.replaceFirst(RegExp(r'\.?0+$'), '') : text;
}

/// Render a timestamp through the company's date/time formats.
///
/// The two `Formatter.date` branches want different inputs and getting this
/// backwards silently shifts a late-evening entry onto the next day: the
/// `showTime` branch appends `Z` and calls `.toLocal()`, so it needs the UTC
/// instant, while the date-only branch parses the string as-is with no
/// conversion, so it needs the already-localized wall clock
/// (`formatting.dart:916-928`). Time-log entries are stored UTC.
String _fmt(
  Formatter? formatter,
  DateTime value, {
  bool showDate = true,
  bool showTime = false,
}) {
  if (formatter == null) {
    // No company formatter (tests / pre-boot): ISO date, 24-hour time.
    final local = value.toLocal();
    final date =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    if (showDate && showTime) return '$date $time';
    return showTime ? time : date;
  }
  return formatter.date(
    showTime
        ? value.toUtc().toIso8601String()
        : value.toLocal().toIso8601String(),
    showDate: showDate,
    showTime: showTime,
    showSeconds: false,
  );
}
