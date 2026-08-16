import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/utils/calendar_week_start.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/features/shell/widgets/in_sidebar.dart';
import 'package:admin/utils/date_ranges.dart';
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
      // Resolved here rather than in `buildPage` because `barrierColor` is a
      // getter with no `BuildContext`; same arithmetic either way.
      compact:
          _resolvePopoverWidth(MediaQuery.sizeOf(context).width) <
          _kTwoMonthMinWidth,
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

  // No "reveal the month I just picked" here, deliberately: a tapped day is
  // always inside the month being rendered, in either layout, so there is
  // nothing to scroll to. Only a *typed* date can land off-screen — see
  // `_onEndTyped`.
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

  /// Moves the visible month onto [d] when it isn't already showing. Only ever
  /// called for the compact layout, where a single month is on screen.
  void _revealMonthOf(Date d) {
    if (d.year == _anchorMonth.year && d.month == _anchorMonth.month) return;
    _anchorMonth = DateTime(d.year, d.month, 1);
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
      // Unconditional — the start month is the anchor in both layouts.
      if (d != null) _anchorMonth = DateTime(d.year, d.month, 1);
    });
  }

  void _onEndTyped(Date? d, {required bool compact}) {
    if (d != null && !_inAllowedWindow(d)) return;
    setState(() {
      _previewEnd = d;
      _normalizeOrder();
      // Two months are shown side by side, so a typed end date is usually
      // already visible; with one, it lands off-screen unless we follow it.
      if (compact && d != null) _revealMonthOf(d);
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

  /// Whether the "next month" control is live. Compares against the *visible*
  /// right-most month, which is [_rightMonth] in the two-month layout but
  /// [_anchorMonth] in the compact one — reading `_rightMonth` unconditionally
  /// would strand a compact user one month short of [_lastAllowed].
  bool _canShiftRight(bool compact) {
    final rightmost = compact ? _anchorMonth : _rightMonth;
    final lastMonth = DateTime(_lastAllowed.year, _lastAllowed.month, 1);
    return rightmost.isBefore(lastMonth);
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
        // Measured, never computed: `SizedBox(width:)` is *enforced* by an
        // outer tight constraint, so the width we asked for and the width we
        // get are not the same number (a caller wrapping us in a narrower box
        // — every test in this file does — renders at the caller's width).
        // Choosing the layout from `popoverWidth` would then hand a 500 px box
        // the two-month layout, which is the bug being fixed.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < _kTwoMonthMinWidth;
            // The route caps our height against the viewport (and the
            // keyboard), so a tall body — compact stacks From/To, and touch
            // targets grow every row — scrolls instead of being clipped by
            // the overlay's `Stack`. Vertical only: the `Expanded` below is a
            // cross-axis flex, untouched by the unbounded height. The `Row`
            // must stay `start`-aligned — `stretch` would ask for
            // `tightFor(height: infinity)` and crash.
            return SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PresetRail(
                    compact: compact,
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
                              compact: compact,
                              leftMonth: _anchorMonth,
                              rightMonth: _rightMonth,
                              canShiftLeft: _canShiftLeft,
                              canShiftRight: _canShiftRight(compact),
                              onShiftLeft: () => _shiftMonth(-1),
                              onShiftRight: () => _shiftMonth(1),
                            ),
                            const SizedBox(height: InSpacing.sm),
                            _CalendarPane(
                              compact: compact,
                              leftMonth: _anchorMonth,
                              rightMonth: _rightMonth,
                              firstDate: _firstAllowed,
                              lastDate: _lastAllowed,
                              start: _previewStart,
                              end: _previewEnd,
                              onTap: _onCellTap,
                              onShiftMonth: _shiftMonth,
                              canShiftLeft: _canShiftLeft,
                              canShiftRight: _canShiftRight(compact),
                              // Resolved once here — the shared rule every
                              // rendered calendar in the app uses, so this grid
                              // and Tasks → Calendar/Weekly can't disagree.
                              firstDayOfWeek: calendarFirstDayOfWeek(
                                context,
                                widget.formatter,
                              ),
                            ),
                            SizedBox(height: InSpacing.md(context)),
                            _FromToDisplay(
                              compact: compact,
                              start: _previewStart,
                              end: _previewEnd,
                              formatter: widget.formatter,
                              firstDate: _firstAllowed,
                              lastDate: _lastAllowed,
                              onStartChanged: _onStartTyped,
                              onEndChanged: (d) =>
                                  _onEndTyped(d, compact: compact),
                            ),
                            SizedBox(height: InSpacing.md(context)),
                            // A `Wrap`, not a `Row`: Cancel + Apply need
                            // ~148 px and the compact column can be as narrow
                            // as 140 (a 320 px viewport), which a `Row`
                            // answers with a RenderFlex overflow. Longer
                            // localisations ("Abbrechen"/"Anwenden") hit it
                            // sooner. Identical to a `Row` whenever there's
                            // room, so the side-by-side pairing CLAUDE.md
                            // asks for is preserved.
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: InSpacing.sm,
                              runSpacing: InSpacing.sm,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.of(
                                    context,
                                  ).pop<DashboardDateRange?>(null),
                                  child: Text(context.tr('cancel')),
                                ),
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
            );
          },
        ),
      ),
    );
  }
}

class _PresetRail extends StatelessWidget {
  const _PresetRail({
    required this.compact,
    required this.current,
    required this.onSelect,
  });

  final bool compact;
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
      width: _railWidth(compact),
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
          // Tapping a preset is the primary action here — it applies and
          // closes — so the row carries the touch floor on a finger-first
          // platform. A *minimum* constraint, never a fixed height: the label
          // has to keep its full line box at large text scale.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 0,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: InSpacing.sm,
                vertical: 7,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
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
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.compact,
    required this.leftMonth,
    required this.rightMonth,
    required this.canShiftLeft,
    required this.canShiftRight,
    required this.onShiftLeft,
    required this.onShiftRight,
  });

  final bool compact;
  final DateTime leftMonth;
  final DateTime rightMonth;
  final bool canShiftLeft;
  final bool canShiftRight;
  final VoidCallback onShiftLeft;
  final VoidCallback onShiftRight;

  /// The paging chevrons. On touch these are the only way to change month, so
  /// they take the touch floor. Sized through `styleFrom(minimumSize:)` rather
  /// than the old `constraints:` + `visualDensity: compact` pair: M3 runs
  /// explicit constraints through `visualDensity.effectiveConstraints`, and
  /// `compact` subtracts 8 — so that 28 px box was really rendering ~20.
  /// `shrinkWrap` then stops `materialTapTargetSize: padded` (the iOS/Android
  /// default) from inflating the *layout* box to 48 and eating the header's
  /// width budget. Same shape as the sidebar's icon buttons.
  static double get _chevronExtent =>
      Env.isTouchPrimary ? InSizes.touchTarget : 28.0;

  Widget _chevron(
    BuildContext context, {
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      onPressed: enabled ? onPressed : null,
      style: IconButton.styleFrom(
        minimumSize: Size(_chevronExtent, _chevronExtent),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 18),
      color: context.inTheme.ink2,
    );
  }

  /// One month's title row: the name centred between two chevron-width
  /// gutters. Both gutters are always reserved — even the empty one — so the
  /// label centres over its own calendar column and can never slide under a
  /// button. `FittedBox` shrinks the name a hair rather than breaking
  /// "August 2026" across two lines, the same guard
  /// `entity_list_column_headers.dart` uses for fixed-width column labels.
  Widget _pane(
    BuildContext context,
    DateTime month, {
    Widget? leading,
    Widget? trailing,
  }) {
    final l = MaterialLocalizations.of(context);
    final gutter = SizedBox(width: _chevronExtent);
    return Row(
      children: [
        leading ?? gutter,
        Expanded(
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                l.formatMonthYear(month),
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.inTheme.ink,
                ),
              ),
            ),
          ),
        ),
        trailing ?? gutter,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final left = _chevron(
      context,
      icon: Icons.chevron_left,
      enabled: canShiftLeft,
      onPressed: onShiftLeft,
    );
    final right = _chevron(
      context,
      icon: Icons.chevron_right,
      enabled: canShiftRight,
      onPressed: onShiftRight,
    );

    if (compact) {
      return _pane(context, leftMonth, leading: left, trailing: right);
    }

    // Each half mirrors the grid below it — `Expanded │ gutter │ Expanded`,
    // the same split `_CalendarPane` uses — so a month name sits over its own
    // calendar. The old `[chevron][Expanded][Expanded][chevron]` shape could
    // not line up, because the chevrons came out of the row before the two
    // labels split what was left.
    return Row(
      children: [
        Expanded(child: _pane(context, leftMonth, leading: left)),
        SizedBox(width: InSpacing.md(context)),
        Expanded(child: _pane(context, rightMonth, trailing: right)),
      ],
    );
  }
}

/// The calendar body: two months side by side, or a single swipeable month
/// when [compact]. Two months only fit above [_kTwoMonthMinWidth] — below it
/// the 14 day columns starve and the day numbers wrap (flutter#38).
class _CalendarPane extends StatelessWidget {
  const _CalendarPane({
    required this.compact,
    required this.leftMonth,
    required this.rightMonth,
    required this.firstDate,
    required this.lastDate,
    required this.start,
    required this.end,
    required this.onTap,
    required this.onShiftMonth,
    required this.canShiftLeft,
    required this.canShiftRight,
    required this.firstDayOfWeek,
  });

  /// Resolved start-of-week (0=Sun..6=Sat) — see `calendarFirstDayOfWeek`.
  final int firstDayOfWeek;

  final bool compact;
  final DateTime leftMonth;
  final DateTime rightMonth;
  final DateTime firstDate;
  final DateTime lastDate;
  final Date? start;
  final Date? end;
  final ValueChanged<Date> onTap;
  final ValueChanged<int> onShiftMonth;
  final bool canShiftLeft;
  final bool canShiftRight;

  Widget _grid(DateTime month) => _MonthGrid(
    month: month,
    firstDate: firstDate,
    lastDate: lastDate,
    start: start,
    end: end,
    onTap: onTap,
    firstDayOfWeek: firstDayOfWeek,
  );

  @override
  Widget build(BuildContext context) {
    if (compact) {
      // With only one month on screen, paging stops being incidental — so the
      // grid also accepts the horizontal swipe a phone user expects. The
      // header chevrons remain the discoverable (and accessible) control.
      return GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < 0 && canShiftRight) {
            onShiftMonth(1);
          } else if (velocity > 0 && canShiftLeft) {
            onShiftMonth(-1);
          }
        },
        child: _grid(leftMonth),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _grid(leftMonth)),
        SizedBox(width: InSpacing.md(context)),
        Expanded(child: _grid(rightMonth)),
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
    required this.firstDayOfWeek,
  });

  final DateTime month;
  final DateTime firstDate;
  final DateTime lastDate;
  final Date? start;
  final Date? end;
  final ValueChanged<Date> onTap;

  /// Resolved start-of-week (0=Sun..6=Sat) — see `calendarFirstDayOfWeek`.
  final int firstDayOfWeek;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final l = MaterialLocalizations.of(context);
    // Already resolved + normalized by `calendarFirstDayOfWeek` at the popover
    // root — company setting when configured, device locale otherwise.
    final firstWeekday = firstDayOfWeek;
    // Reorder narrowWeekdays so column 0 matches the first day of week.
    final headers = <String>[
      for (var i = 0; i < 7; i++) l.narrowWeekdays[(firstWeekday + i) % 7],
    ];

    // Fixed 6 rows via the shared grid helper. Deriving the row count from the
    // month instead (`ceil((leadingBlanks + daysInMonth) / 7)`) swings between
    // 4 and 6 depending on the month AND the first-day-of-week — Feb 2026 is 4
    // rows and Aug 2026 is 6 — so the popover jumped ~72px as the user paged,
    // and the two side-by-side month panes rendered at different heights.
    // Days outside `month` stay blank; they are geometry only, not tappable
    // cells (the neighbouring month is already on screen in the wide layout).
    // They must still carry the cell's HEIGHT: a `Row` whose children are all
    // `SizedBox.shrink()` measures zero, so blank-filling a trailing week would
    // collapse it and leave the height varying exactly as before.
    final blank = SizedBox(height: _dayCellExtent(context));
    final cells = <Widget>[
      for (final date in monthGridDays(
        Date(month.year, month.month, 1),
        firstWeekday,
      ))
        if (date.month != month.month || date.year != month.year)
          blank
        else
          _DayCell(
            date: date,
            state: _stateFor(date),
            enabled: !date.isBefore(firstDate) && !date.isAfter(lastDate),
            isToday: _isToday(date),
            onTap: () => onTap(date),
            tokens: tokens,
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final h in headers)
              Expanded(
                // Same treatment as the day numbers: `narrowWeekdays` is two
                // characters in ru / uk / pl (`вс`, `пн`), so this column can
                // starve exactly the way the day cells did, and the extent has
                // to scale or it clips descenders at large text scale.
                child: SizedBox(
                  height: MediaQuery.textScalerOf(context).scale(24),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        h,
                        maxLines: 1,
                        softWrap: false,
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

    // A day column can get narrow (a compact month on a 320 px device is ~20 px
    // per cell), and the number must never break across two lines the way it
    // did in flutter#38. `maxLines` + `softWrap: false` make wrapping
    // impossible and `scaleDown` shrinks the glyphs a hair if the column is
    // genuinely too tight — degrade the size, never the legibility.
    Widget label = Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '${date.day}',
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isEdge ? FontWeight.w600 : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );

    final extent = _dayCellExtent(context);
    // The selection visuals stay sized to the *text*, not to the (touch-sized)
    // cell — otherwise the range band becomes a thick bar and dwarfs the
    // circular edge markers inside it. Scaled like everything else here, or a
    // user on large text ends up with numbers bigger than their own highlight.
    final bandHeight = math.min(
      extent,
      MediaQuery.textScalerOf(context).scale(_kDayBandExtent),
    );

    final shape = isEdge
        ? const CircleBorder()
        : (inRange
              ? const RoundedRectangleBorder()
              : const RoundedRectangleBorder());

    // A concrete height, not `ConstrainedBox(minHeight:)`: every cell in a row
    // has to be *exactly* as tall as its neighbours or the range band breaks
    // into visible steps (the day rows align on `center`, so they won't
    // equalise themselves). The text-scale rule is still honoured — the extent
    // is scaled, so it can't clip Inter Tight's descenders.
    return SizedBox(
      height: extent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasFill && !isEdge)
            Center(
              child: SizedBox(
                height: bandHeight,
                width: double.infinity,
                child: ColoredBox(color: fillBg!),
              ),
            ),
          if (isEdge)
            Center(
              child: SizedBox(
                height: bandHeight,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Material(
                    color: fillBg,
                    shape: shape,
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          // Drawn as a sibling sized to the cell rather than a fixed 26 px box
          // around the label: a `BoxDecoration` circle uses
          // `rect.shortestSide`, so it stays round in a narrow column, whereas
          // the old `SizedBox(26, 26)` was silently squashed to an oval once
          // the column dropped under 26 px.
          if (isToday && !isEdge)
            Center(
              child: SizedBox(
                height: bandHeight,
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: tokens.border),
                    ),
                  ),
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

/// The visual extent of a day's selection band — the height the range fill and
/// the circular start/end markers are drawn at. Independent of the cell's own
/// (touch-sized) extent so the calendar reads the same on every platform.
const double _kDayBandExtent = 30;

/// Day-cell extent, scaled with the user's text size and grown on a
/// finger-first platform. A fixed extent slices Inter Tight's descenders once
/// UI text scale passes ~1.14 — same trap `searchable_dropdown_field.dart`'s
/// `_optionExtent` guards against.
///
/// 36 rather than the full [InSizes.touchTarget]: a grid cell can't grow
/// *width* to match (seven columns share the pane, and a compact month gives
/// each ~26 px), so 44 would leave the rows visibly loose around a 30 px
/// selection band without making the cell meaningfully easier to hit.
double _dayCellExtent(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(Env.isTouchPrimary ? 36.0 : 30.0);

/// Typeable from/to fields beneath the calendar. Backed by [InDateField], so
/// users can type a date or a shortcut (`+2`, `-7`, `today`, ISO, the company
/// pattern) instead of only clicking the grid. Calendar taps flow back in
/// through `start` / `end` — `InDateField`'s cursor-stable re-seed keeps the
/// text in sync.
class _FromToDisplay extends StatelessWidget {
  const _FromToDisplay({
    required this.compact,
    required this.start,
    required this.end,
    required this.formatter,
    required this.firstDate,
    required this.lastDate,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final bool compact;
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
    final from = InDateField(
      labelText: context.tr('from'),
      value: start?.toDateTime(),
      onChanged: (dt) => onStartChanged(_toDate(dt)),
      formatter: formatter,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    final to = InDateField(
      labelText: context.tr('to'),
      value: end?.toDateTime(),
      onChanged: (dt) => onEndChanged(_toDate(dt)),
      formatter: formatter,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    // Side by side, each field is half the pane minus its ~28 px calendar
    // suffix — on a phone that left ~20 px of text area and clipped both the
    // value and the floating label. Stack them and each gets the full pane.
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          from,
          const SizedBox(height: InSpacing.sm),
          to,
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: from),
        const SizedBox(width: InSpacing.sm),
        Expanded(child: to),
      ],
    );
  }
}

double _responsivePopoverWidth(double screenWidth) =>
    screenWidth >= 1024 ? 960.0 : 600.0;

/// Below this popover width the two-month grid starves its 14 day columns.
/// The pane left for the calendars is `width - rail - 2 * padding`, split
/// across two months and then seven `Expanded` cells each — so at 328 px (a
/// 360 px phone minus margins) a cell is ~10 px and a two-digit day soft-wraps
/// to two lines (invoiceninja/flutter#38). Below this we render one month,
/// which keeps a cell above ~20 px even on a 320 px device. 520 is the point
/// where the *two*-month layout still leaves every cell ≈24 px (23 when
/// `InSpacing.md` is at its wide 12 px value, 24 at the narrow 8).
const double _kTwoMonthMinWidth = 520;

/// Floor for the popover itself. Deliberately below the narrowest phone
/// (a 320 px viewport yields 288 px) so it only bites on absurdly small
/// windows, where overhanging the margin beats crushing the layout.
const double _kMinPopoverWidth = 280;

/// Preset rail width. The compact rail still fits the longest label
/// ("Last 365 days" ≈ 78 px at `fontSize: 12.5`) inside its 16 px of
/// horizontal padding, and hands the ~28 px it gives up to the calendar.
double _railWidth(bool compact) => compact ? 132 : 160;

/// Left edge the popover must stay clear of. The persistent rail
/// (`InSidebar`) sits to the left of the navigation shell on wide layouts, and
/// the route's Overlay spans the full viewport (sidebar included), so the
/// strip has to be reserved here — otherwise the popover slides under the
/// sidebar and its preset-rail labels render half-clipped.
///
/// Shared by [_resolvePopoverWidth] and the route's horizontal placement:
/// those two have to agree, and derived the same expression independently
/// before this existed.
double _safeLeftFor(double screenWidth) => screenWidth >= Breakpoints.wide
    ? kInSidebarWidth + _kPopoverMargin
    : _kPopoverMargin;

/// Resolves the popover width the route would use for [screenWidth], so the
/// route can decide `barrierColor` (a `BuildContext`-free getter) with the
/// same arithmetic `buildPage` uses for the layout itself.
double _resolvePopoverWidth(double screenWidth) {
  final available = screenWidth - _safeLeftFor(screenWidth) - _kPopoverMargin;
  return math.max(
    _kMinPopoverWidth,
    math.min(_responsivePopoverWidth(screenWidth), available),
  );
}

const double _kPopoverMargin = 16;

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
    required this.compact,
  });

  final Rect anchor;
  final DashboardDateRange current;
  final Formatter? formatter;

  /// Whether the popover will render its narrow (single-month) layout. Decided
  /// by the caller because [barrierColor] is a `BuildContext`-free getter.
  final bool compact;

  // The compact popover covers most of a phone screen; leaving it undimmed
  // reads as a rendering glitch and gives no hint that tapping outside
  // dismisses. A small popover anchored to its button on desktop doesn't need
  // one — a scrim there would be heavier than the thing it's framing.
  //
  // Captured once at open, unlike the layout itself (which re-measures through
  // a `LayoutBuilder`), so rotating a phone to landscape while this is open
  // keeps the scrim over what is now the two-month layout. Making it react
  // needs a mutable field plus `changedInternalState()`; not worth it for
  // rotate-while-open.
  @override
  Color? get barrierColor => compact ? Colors.black54 : null;

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
    const margin = _kPopoverMargin;
    final safeLeft = _safeLeftFor(media.width);
    // Not `clamp`: `num.clamp` throws when the upper limit falls below the
    // lower one, which every viewport under ~352 px did (320 px-class devices,
    // Android split-screen, a pinched desktop window).
    final popoverWidth = _resolvePopoverWidth(media.width);
    // Right-anchor to the button's right edge. The dashboard's date-filter
    // button is always near the right of the top bar, so opening the popover
    // *toward the left* keeps it on-screen without after-the-fact clamping.
    double right = media.width - anchor.right;
    if (right < margin) right = margin;
    if (media.width - right - popoverWidth < safeLeft) {
      right = media.width - popoverWidth - safeLeft;
    }

    // Vertical fit. Two things make "just pin it below the anchor" wrong:
    // the soft keyboard, which covers the bottom of the screen the moment a
    // user types into From/To (and those fields exist to be typed into), and
    // anchors that aren't near the top — the narrow Client Statement screen
    // opens this from a button inside a bottom sheet. So measure the real
    // usable box, open upward when that side has more room, and cap the
    // height so the body scrolls rather than being clipped by the `Stack`.
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.paddingOf(context);
    final usableTop = viewPadding.top + margin;
    final usableBottom = media.height - viewInsets.bottom - margin;
    final spaceBelow = usableBottom - (anchor.bottom + 4);
    final spaceAbove = (anchor.top - 4) - usableTop;
    final openUpward = spaceBelow < spaceAbove;
    final maxHeight = math.max(
      _kMinPopoverHeight,
      openUpward ? spaceAbove : spaceBelow,
    );

    final popover = ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
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
    );

    return FadeTransition(
      opacity: animation,
      child: Stack(
        children: [
          // Exactly one of `top` / `bottom` — setting both would stretch the
          // popover to fill the gap instead of letting it size to its content.
          Positioned(
            right: right,
            top: openUpward ? null : anchor.bottom + 4,
            bottom: openUpward ? media.height - anchor.top + 4 : null,
            child: popover,
          ),
        ],
      ),
    );
  }
}

/// Floor for the popover's height cap. Below this the calendar is unusable
/// anyway, so we'd rather overhang a very short viewport than collapse.
const double _kMinPopoverHeight = 200;
