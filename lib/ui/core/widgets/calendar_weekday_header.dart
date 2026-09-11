import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// The seven-column weekday strip above a month grid, rotated so column 0 is
/// [firstDayOfWeek] (0 = Sunday … 6 = Saturday — resolve it through
/// `calendarFirstDayOfWeek`, never from a raw company field).
///
/// Shared rather than mirrored because the three lines that matter are all
/// traps. Two of the app's three month grids use it — the dashboard's
/// date-range popover and the task-calendar panel. The full-size
/// `task_calendar_grid.dart` deliberately does **not** yet: it builds
/// `DateFormat('EEE')` labels in the *company* locale at a wider cell, so
/// adopting this would change what that screen renders and drag its own tests
/// in. Consolidating it is a follow-up, not a claim this file already makes.
/// The traps:
///
///  * **`narrowWeekdays` is two characters in ru / uk / pl** (`вс`, `пн`), so
///    a column can starve exactly the way the day cells did (flutter#38) —
///    hence `FittedBox(scaleDown)` + `maxLines: 1` + `softWrap: false`, which
///    degrade the size and never the legibility.
///  * **The row's height must scale with the text scaler**, or it clips Inter
///    Tight's descenders past ~1.14x.
///  * **`Expanded` per column**, so the strip lines up with a grid whose cells
///    are also `Expanded` — a fixed width would drift out of alignment as soon
///    as the container is not an exact multiple of seven.
///
/// Deliberately *not* accompanied by a shared month grid or day cell: those are
/// coupled to what each surface renders inside a day (a range band and edge
/// circles here, a load bar there), and serving both would need a cell-builder
/// callback plus a state enum — a worse abstraction than two small grids that
/// each say what they mean. What must not drift is already shared with one home
/// each: `monthGridDays` for the 42-cell geometry and `calendarFirstDayOfWeek`
/// for the rotation.
class CalendarWeekdayHeaderRow extends StatelessWidget {
  const CalendarWeekdayHeaderRow({
    required this.firstDayOfWeek,
    this.color,
    this.fontSize = 10.5,
    this.height = 24,
    super.key,
  });

  /// 0 = Sunday … 6 = Saturday.
  final int firstDayOfWeek;

  /// Defaults to `tokens.ink3` — the strip is a label, never content.
  final Color? color;

  final double fontSize;

  /// Unscaled row height; the text scaler is applied here, not by the caller.
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final labels = MaterialLocalizations.of(context).narrowWeekdays;
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: SizedBox(
              height: MediaQuery.textScalerOf(context).scale(height),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    labels[(firstDayOfWeek + i) % 7],
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: color ?? tokens.ink3,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
