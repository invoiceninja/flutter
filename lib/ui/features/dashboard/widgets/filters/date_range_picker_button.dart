import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/features/shell/widgets/in_sidebar.dart';
import 'package:admin/utils/formatting.dart';

/// Ghost-style button in the TopBar that opens a single popover combining the
/// preset list and a two-month calendar for custom ranges. Matches
/// `screens.jsx:198`; replaces the previous two-step flow (Material `showMenu`
/// → Material `showDateRangePicker`) which was visually heavy and required two
/// clicks to reach the custom calendar.
class DateRangePickerButton extends StatelessWidget {
  const DateRangePickerButton({
    super.key,
    required this.current,
    required this.onChange,
    this.formatter,
  });

  final DashboardDateRange current;
  final ValueChanged<DashboardDateRange> onChange;
  // Nullable: the dashboard renders this button before its per-company
  // `Formatter` resolves on first paint. We fall back to ISO during that
  // brief window rather than gating the whole top bar on the formatter.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = _labelFor(context, current);
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: tokens.ink2,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InRadii.r2),
          side: BorderSide(color: tokens.border),
        ),
      ),
      icon: const Icon(Icons.filter_alt_outlined, size: 14),
      // A custom range renders a long two-date string, and the top bar's
      // action Wrap is now width-bounded (it can break to a second run), so
      // this label is the one that can actually get squeezed. Without a cap it
      // soft-wraps to two lines and grows the button; ellipsise instead.
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      onPressed: () => _open(context),
    );
  }

  Future<void> _open(BuildContext context) => openDateRangePicker(
    context,
    current: current,
    onChange: onChange,
    formatter: formatter,
  );

  String _labelFor(BuildContext context, DashboardDateRange r) {
    if (r is DashboardPresetRange) return _presetLabel(context, r.preset);
    if (r is DashboardCustomRange) {
      final start = formatter?.date(r.start.toIso()) ?? r.start.toIso();
      final end = formatter?.date(r.end.toIso()) ?? r.end.toIso();
      return '$start → $end';
    }
    return context.tr('date_range');
  }

  String _presetLabel(BuildContext context, DashboardDatePreset p) =>
      context.tr(_presetKey(p));
}

/// Opens the date-range popover anchored to whichever widget [context] points
/// at. Used by both [DateRangePickerButton] (wide) and the dashboard's mobile
/// AppBar filter icon (narrow) so the popover positioning logic stays in one
/// place.
Future<void> openDateRangePicker(
  BuildContext context, {
  required DashboardDateRange current,
  required ValueChanged<DashboardDateRange> onChange,
  Formatter? formatter,
}) async {
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  final Offset offset = box?.localToGlobal(Offset.zero) ?? Offset.zero;
  final size = box?.size ?? const Size(160, 32);
  final result = await Navigator.of(context).push<DashboardDateRange?>(
    _DateRangePickerRoute(
      anchor: Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
      current: current,
      formatter: formatter,
    ),
  );
  if (result != null) onChange(result);
}

/// Reuses the dashboard range popover as the value picker for a date
/// list-filter's [FilterOp.between] comparator. Returns the canonical
/// 3-part window wire `"<column>,<startIso>,<endIso>"` (the contract
/// `DateColumnFilterKey` / `parseDateRangeFilter` consume), or `null`
/// when the user cancels. [seed] pre-selects an existing window.
Future<String?> pickDateRangeWindow(
  BuildContext context, {
  required String column,
  Formatter? formatter,
  (String start, String end)? seed,
}) async {
  final seedStart = seed == null ? null : Date.tryParse(seed.$1);
  final seedEnd = seed == null ? null : Date.tryParse(seed.$2);
  final DashboardDateRange current = (seedStart != null && seedEnd != null)
      ? DashboardCustomRange(start: seedStart, end: seedEnd)
      : const DashboardPresetRange(DashboardDatePreset.thisMonth);
  String? wire;
  await openDateRangePicker(
    context,
    current: current,
    formatter: formatter,
    onChange: (r) {
      final (start, end) = r.resolve(
        firstMonthOfYear: formatter?.settings.firstMonthOfYear ?? 1,
      );
      wire = '$column,${start.toIso()},${end.toIso()}';
    },
  );
  return wire;
}

String _presetKey(DashboardDatePreset p) => switch (p) {
  DashboardDatePreset.last7 => 'last7_days',
  DashboardDatePreset.last30 => 'last_30_days',
  DashboardDatePreset.last365 => 'last_365_days',
  DashboardDatePreset.thisMonth => 'this_month',
  DashboardDatePreset.lastMonth => 'last_month',
  DashboardDatePreset.thisQuarter => 'this_quarter',
  DashboardDatePreset.lastQuarter => 'last_quarter',
  DashboardDatePreset.thisYear => 'this_year',
  DashboardDatePreset.lastYear => 'last_year',
  DashboardDatePreset.allTime => 'all_time',
};

/// The unified picker body. Pops with either:
///   * a [DashboardPresetRange] when a preset chip is clicked (apply-and-close),
///   * a [DashboardCustomRange] when Apply is clicked after two calendar taps,
///   * `null` when Cancel is clicked or the popover is dismissed.
@visibleForTesting
class DashboardDateRangePopover extends StatefulWidget {
  const DashboardDateRangePopover({
    super.key,
    required this.current,
    this.formatter,
    this.width,
  });

  final DashboardDateRange current;
  final Formatter? formatter;

  /// Explicit popover width. When null, the popover picks one based on the
  /// current `MediaQuery` width (the responsive default used by the route).
  final double? width;

  @override
  State<DashboardDateRangePopover> createState() =>
      _DashboardDateRangePopoverState();
}

class _DashboardDateRangePopoverState extends State<DashboardDateRangePopover> {
  static final DateTime _firstAllowed = DateTime(2000, 1, 1);
  // `DashboardCustomRange` is used for offset analytics (e.g. "last X days"),
  // so it makes sense to allow future dates as a target. Match the old picker's
  // `now + 5 years` window.
  static final DateTime _lastAllowed = DateTime(
    DateTime.now().year + 5,
    DateTime.now().month,
    DateTime.now().day,
  );

  late DateTime _anchorMonth;
  Date? _previewStart;
  Date? _previewEnd;

  @override
  void initState() {
    super.initState();
    final (start, end) = widget.current.resolve(
      firstMonthOfYear: widget.formatter?.settings.firstMonthOfYear ?? 1,
    );
    _previewStart = start;
    _previewEnd = end;
    final anchor = _previewStart ?? Date.today();
    _anchorMonth = DateTime(anchor.year, anchor.month, 1);
  }

  bool get _canApply => _previewStart != null && _previewEnd != null;

  void _onCellTap(Date d) {
    setState(() {
      if (_previewStart == null || _previewEnd != null) {
        // Fresh start (no previous start, OR both already set → restart).
        _previewStart = d;
        _previewEnd = null;
        return;
      }
      // Second click: complete the range, swapping if user clicked earlier.
      if (d.compareTo(_previewStart!) < 0) {
        _previewEnd = _previewStart;
        _previewStart = d;
      } else {
        _previewEnd = d;
      }
    });
  }

  bool _inAllowedWindow(Date d) {
    final dt = d.toDateTime();
    return !dt.isBefore(_firstAllowed) && !dt.isAfter(_lastAllowed);
  }

  // Mirror the calendar's auto-swap (`_onCellTap`) so a typed range never
  // ends up with start > end — `_canApply` and `DashboardCustomRange` both
  // assume an ordered pair.
  void _normalizeOrder() {
    final s = _previewStart;
    final e = _previewEnd;
    if (s != null && e != null && e.compareTo(s) < 0) {
      _previewStart = e;
      _previewEnd = s;
    }
  }

  void _onStartTyped(Date? d) {
    // Out-of-window dates can't be reached on the grid; ignore them so typed
    // input stays consistent with what the calendar can represent.
    if (d != null && !_inAllowedWindow(d)) return;
    setState(() {
      _previewStart = d;
      _normalizeOrder();
      if (d != null) _anchorMonth = DateTime(d.year, d.month, 1);
    });
  }

  void _onEndTyped(Date? d) {
    if (d != null && !_inAllowedWindow(d)) return;
    setState(() {
      _previewEnd = d;
      _normalizeOrder();
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _anchorMonth = DateTime(_anchorMonth.year, _anchorMonth.month + delta, 1);
    });
  }

  DateTime get _rightMonth =>
      DateTime(_anchorMonth.year, _anchorMonth.month + 1, 1);

  bool get _canShiftLeft => _anchorMonth.isAfter(
    DateTime(_firstAllowed.year, _firstAllowed.month, 1),
  );

  bool get _canShiftRight {
    final right = _rightMonth;
    final lastMonth = DateTime(_lastAllowed.year, _lastAllowed.month, 1);
    return right.isBefore(lastMonth);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final popoverWidth =
        widget.width ??
        _responsivePopoverWidth(MediaQuery.sizeOf(context).width);
    return SizedBox(
      width: popoverWidth,
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PresetRail(
              current: widget.current,
              onSelect: (preset) {
                Navigator.of(
                  context,
                ).pop<DashboardDateRange?>(DashboardPresetRange(preset));
              },
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: tokens.border)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(InSpacing.md(context)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MonthHeader(
                        leftMonth: _anchorMonth,
                        rightMonth: _rightMonth,
                        canShiftLeft: _canShiftLeft,
                        canShiftRight: _canShiftRight,
                        onShiftLeft: () => _shiftMonth(-1),
                        onShiftRight: () => _shiftMonth(1),
                      ),
                      const SizedBox(height: InSpacing.sm),
                      _TwoMonthCalendar(
                        leftMonth: _anchorMonth,
                        rightMonth: _rightMonth,
                        firstDate: _firstAllowed,
                        lastDate: _lastAllowed,
                        start: _previewStart,
                        end: _previewEnd,
                        onTap: _onCellTap,
                        firstDayOfWeek:
                            widget.formatter?.settings.firstDayOfWeek,
                      ),
                      SizedBox(height: InSpacing.md(context)),
                      _FromToDisplay(
                        start: _previewStart,
                        end: _previewEnd,
                        formatter: widget.formatter,
                        firstDate: _firstAllowed,
                        lastDate: _lastAllowed,
                        onStartChanged: _onStartTyped,
                        onEndChanged: _onEndTyped,
                      ),
                      SizedBox(height: InSpacing.md(context)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pop<DashboardDateRange?>(null),
                            child: Text(context.tr('cancel')),
                          ),
                          const SizedBox(width: InSpacing.sm),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(64, 44),
                            ),
                            onPressed: _canApply
                                ? () => Navigator.of(context)
                                      .pop<DashboardDateRange?>(
                                        DashboardCustomRange(
                                          start: _previewStart!,
                                          end: _previewEnd!,
                                        ),
                                      )
                                : null,
                            child: Text(context.tr('apply')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetRail extends StatelessWidget {
  const _PresetRail({required this.current, required this.onSelect});

  final DashboardDateRange current;
  final ValueChanged<DashboardDatePreset> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final activePreset = switch (current) {
      DashboardPresetRange(:final preset) => preset,
      _ => null,
    };
    return SizedBox(
      width: 160,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.sm,
          vertical: InSpacing.md(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final preset in DashboardDatePreset.values)
              _PresetChip(
                label: context.tr(_presetKey(preset)),
                active: preset == activePreset,
                onTap: () => onSelect(preset),
                tokens: tokens,
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.tokens,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(InRadii.r1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: active ? tokens.accentSoft : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: InSpacing.sm,
              vertical: 7,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: active ? tokens.accent : tokens.ink2,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.leftMonth,
    required this.rightMonth,
    required this.canShiftLeft,
    required this.canShiftRight,
    required this.onShiftLeft,
    required this.onShiftRight,
  });

  final DateTime leftMonth;
  final DateTime rightMonth;
  final bool canShiftLeft;
  final bool canShiftRight;
  final VoidCallback onShiftLeft;
  final VoidCallback onShiftRight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final l = MaterialLocalizations.of(context);
    return Row(
      children: [
        IconButton(
          onPressed: canShiftLeft ? onShiftLeft : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          color: tokens.ink2,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Text(
            l.formatMonthYear(leftMonth),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.ink,
            ),
          ),
        ),
        Expanded(
          child: Text(
            l.formatMonthYear(rightMonth),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.ink,
            ),
          ),
        ),
        IconButton(
          onPressed: canShiftRight ? onShiftRight : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          color: tokens.ink2,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _TwoMonthCalendar extends StatelessWidget {
  const _TwoMonthCalendar({
    required this.leftMonth,
    required this.rightMonth,
    required this.firstDate,
    required this.lastDate,
    required this.start,
    required this.end,
    required this.onTap,
    this.firstDayOfWeek,
  });

  /// Company `first_day_of_week` (0=Sun..6=Sat). Null → fall back to the device
  /// locale's `firstDayOfWeekIndex`.
  final int? firstDayOfWeek;

  final DateTime leftMonth;
  final DateTime rightMonth;
  final DateTime firstDate;
  final DateTime lastDate;
  final Date? start;
  final Date? end;
  final ValueChanged<Date> onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MonthGrid(
            month: leftMonth,
            firstDate: firstDate,
            lastDate: lastDate,
            start: start,
            end: end,
            onTap: onTap,
            firstDayOfWeek: firstDayOfWeek,
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          child: _MonthGrid(
            month: rightMonth,
            firstDate: firstDate,
            lastDate: lastDate,
            start: start,
            end: end,
            onTap: onTap,
            firstDayOfWeek: firstDayOfWeek,
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.start,
    required this.end,
    required this.onTap,
    this.firstDayOfWeek,
  });

  final DateTime month;
  final DateTime firstDate;
  final DateTime lastDate;
  final Date? start;
  final Date? end;
  final ValueChanged<Date> onTap;

  /// Company `first_day_of_week` (0=Sun..6=Sat); null → device locale default.
  final int? firstDayOfWeek;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final l = MaterialLocalizations.of(context);
    // Company setting wins; fall back to the device locale's first day.
    final firstWeekday = firstDayOfWeek ?? l.firstDayOfWeekIndex;
    // Reorder narrowWeekdays so column 0 matches the first day of week.
    final headers = <String>[
      for (var i = 0; i < 7; i++) l.narrowWeekdays[(firstWeekday + i) % 7],
    ];

    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final monthFirst = DateTime(month.year, month.month, 1);
    // 0 = Sunday in Dart's DateTime.weekday convention is 7. Translate to
    // a slot offset relative to the locale's first day of week.
    final dartWeekday = monthFirst.weekday % 7; // 0..6, where 0 = Sunday
    final leadingBlanks = (dartWeekday - firstWeekday + 7) % 7;

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }
    for (var d = 1; d <= daysInMonth; d++) {
      final date = Date(month.year, month.month, d);
      cells.add(
        _DayCell(
          date: date,
          state: _stateFor(date),
          enabled: !date.isBefore(firstDate) && !date.isAfter(lastDate),
          isToday: _isToday(date),
          onTap: () => onTap(date),
          tokens: tokens,
        ),
      );
    }
    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final h in headers)
              Expanded(
                child: SizedBox(
                  height: 24,
                  child: Center(
                    child: Text(
                      h,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink3,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        for (var row = 0; row < cells.length / 7; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(child: cells[row * 7 + col]),
            ],
          ),
      ],
    );
  }

  _CellState _stateFor(Date d) {
    final s = start;
    final e = end;
    if (s != null && e != null) {
      final cmpStart = d.compareTo(s);
      final cmpEnd = d.compareTo(e);
      if (cmpStart == 0 && cmpEnd == 0) return _CellState.singleEdge;
      if (cmpStart == 0) return _CellState.startEdge;
      if (cmpEnd == 0) return _CellState.endEdge;
      if (cmpStart > 0 && cmpEnd < 0) return _CellState.inRange;
    } else if (s != null && d.compareTo(s) == 0) {
      return _CellState.singleEdge;
    }
    return _CellState.normal;
  }

  bool _isToday(Date d) {
    final t = Date.today();
    return d == t;
  }
}

extension on Date {
  bool isBefore(DateTime other) =>
      compareTo(Date(other.year, other.month, other.day)) < 0;
  bool isAfter(DateTime other) =>
      compareTo(Date(other.year, other.month, other.day)) > 0;
}

enum _CellState { normal, inRange, startEdge, endEdge, singleEdge }

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.state,
    required this.enabled,
    required this.isToday,
    required this.onTap,
    required this.tokens,
  });

  final Date date;
  final _CellState state;
  final bool enabled;
  final bool isToday;
  final VoidCallback onTap;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    // Range fill (accentSoft) extends edge-to-edge across the row so adjacent
    // days visually connect; only the start/end edges round the outside corner.
    final isEdge =
        state == _CellState.startEdge ||
        state == _CellState.endEdge ||
        state == _CellState.singleEdge;
    final inRange = state == _CellState.inRange;
    final hasFill = isEdge || inRange;

    Color? fillBg;
    if (isEdge) {
      fillBg = tokens.accent;
    } else if (inRange) {
      fillBg = tokens.accentSoft;
    }

    final textColor = isEdge
        ? Colors.white
        : (enabled ? tokens.ink : tokens.ink3);

    Widget label = Center(
      child: Text(
        '${date.day}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: isEdge ? FontWeight.w600 : FontWeight.w500,
          color: textColor,
        ),
      ),
    );

    if (isToday && !isEdge) {
      label = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: tokens.border),
        ),
        child: SizedBox(width: 26, height: 26, child: label),
      );
    }

    final shape = isEdge
        ? const CircleBorder()
        : (inRange
              ? const RoundedRectangleBorder()
              : const RoundedRectangleBorder());

    return SizedBox(
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasFill && !isEdge)
            Positioned.fill(child: Container(color: fillBg)),
          if (isEdge)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Material(
                  color: fillBg,
                  shape: shape,
                  child: const SizedBox.shrink(),
                ),
              ),
            ),
          Positioned.fill(
            child: InkWell(
              onTap: enabled ? onTap : null,
              customBorder: const CircleBorder(),
              child: label,
            ),
          ),
        ],
      ),
    );
  }
}

/// Typeable from/to fields beneath the calendar. Backed by [InDateField], so
/// users can type a date or a shortcut (`+2`, `-7`, `today`, ISO, the company
/// pattern) instead of only clicking the grid. Calendar taps flow back in
/// through `start` / `end` — `InDateField`'s cursor-stable re-seed keeps the
/// text in sync.
class _FromToDisplay extends StatelessWidget {
  const _FromToDisplay({
    required this.start,
    required this.end,
    required this.formatter,
    required this.firstDate,
    required this.lastDate,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final Date? start;
  final Date? end;
  final Formatter? formatter;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<Date?> onStartChanged;
  final ValueChanged<Date?> onEndChanged;

  Date? _toDate(DateTime? dt) =>
      dt == null ? null : Date(dt.year, dt.month, dt.day);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InDateField(
            labelText: context.tr('from'),
            value: start?.toDateTime(),
            onChanged: (dt) => onStartChanged(_toDate(dt)),
            formatter: formatter,
            firstDate: firstDate,
            lastDate: lastDate,
          ),
        ),
        const SizedBox(width: InSpacing.sm),
        Expanded(
          child: InDateField(
            labelText: context.tr('to'),
            value: end?.toDateTime(),
            onChanged: (dt) => onEndChanged(_toDate(dt)),
            formatter: formatter,
            firstDate: firstDate,
            lastDate: lastDate,
          ),
        ),
      ],
    );
  }
}

double _responsivePopoverWidth(double screenWidth) =>
    screenWidth >= 1024 ? 960.0 : 600.0;

/// Hosts [DashboardDateRangePopover] directly on the overlay so the popover's
/// `SizedBox(width: ...)` is honored. `showMenu()` wraps its content in a
/// `_PopupMenu` that caps width at `5 * 56 = 280 px`, which crushes the
/// two-month calendar layout — this route bypasses that constraint while
/// keeping `Navigator.pop<T>(value)` semantics intact.
class _DateRangePickerRoute extends PopupRoute<DashboardDateRange?> {
  _DateRangePickerRoute({
    required this.anchor,
    required this.current,
    required this.formatter,
  });

  final Rect anchor;
  final DashboardDateRange current;
  final Formatter? formatter;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.sizeOf(context);
    final tokens = context.inTheme;
    const margin = 16.0;
    // The persistent rail (`InSidebar`) sits to the left of the navigation
    // shell on wide layouts. The PopupRoute's Overlay spans the full
    // viewport (sidebar included), so we have to reserve that strip
    // ourselves — otherwise the popover slides under the sidebar and its
    // preset-rail labels render half-clipped.
    final safeLeft = media.width >= Breakpoints.wide
        ? kInSidebarWidth + margin
        : margin;
    final preferredWidth = _responsivePopoverWidth(media.width);
    final popoverWidth = preferredWidth.clamp(
      320.0,
      media.width - safeLeft - margin,
    );
    // Right-anchor to the button's right edge. The dashboard's date-filter
    // button is always near the right of the top bar, so opening the popover
    // *toward the left* keeps it on-screen without after-the-fact clamping.
    double right = media.width - anchor.right;
    if (right < margin) right = margin;
    if (media.width - right - popoverWidth < safeLeft) {
      right = media.width - popoverWidth - safeLeft;
    }
    final top = anchor.bottom + 4;
    return FadeTransition(
      opacity: animation,
      child: Stack(
        children: [
          Positioned(
            right: right,
            top: top,
            child: Material(
              color: tokens.surface,
              elevation: 8,
              borderRadius: BorderRadius.circular(InRadii.r3),
              clipBehavior: Clip.antiAlias,
              child: DashboardDateRangePopover(
                current: current,
                formatter: formatter,
                width: popoverWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
