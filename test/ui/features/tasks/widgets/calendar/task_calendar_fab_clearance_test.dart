import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/utils/fab_clearance.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/task_calendar_day_cell.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/task_calendar_grid.dart';

/// The month grid never scrolls, so the FAB clearance (invoiceninja/flutter#167)
/// comes straight out of its six week rows — and the day cells clip **silently**
/// rather than throwing, so nothing would report the loss. These pin the clamp
/// that keeps a short viewport from spending height it does not have.
///
/// The calendar screen has no widget-test harness, so this covers the rule where
/// `fab_clearance_wiring_test.dart` only covers the wiring.
void main() {
  // The two real cases, measured on a 412x915 phone: content is the viewport
  // less the status bar, the `InSizes.headerBand` app bar and the view header.
  const portraitGrid = 723.0;
  const landscapeGrid = 220.0;
  const desired = kFabClearance + 8; // what `fabScrollClearance` asks for

  test('a tall grid affords the whole clearance', () {
    expect(
      taskCalendarFabClearance(availableHeight: portraitGrid, desired: desired),
      desired,
    );
  });

  test('portrait keeps room for three chips after paying it', () {
    final rowHeight = (portraitGrid - desired - 43) / 6;
    expect(
      rowHeight,
      greaterThan(TaskCalendarDayCell.minHeight),
      reason: 'the date must still render',
    );
    expect(rowHeight, greaterThan(95), reason: 'and so must three task chips');
  });

  test('a short grid spends nothing rather than clipping its dates', () {
    // 220 is already under the floor, so there is nothing spare at all. The
    // regression this guards: an unconditional 80 px here left ~23 px a row
    // against a 30 px date.
    expect(
      taskCalendarFabClearance(
        availableHeight: landscapeGrid,
        desired: desired,
      ),
      0,
    );
  });

  test('it never returns more than is spare, and never less than zero', () {
    // Just above the floor: pays only the surplus.
    expect(
      taskCalendarFabClearance(
        availableHeight: kTaskCalendarMinGridHeight + 30,
        desired: desired,
      ),
      30,
    );
    // Degenerate viewports stay non-negative — a negative padding asserts.
    expect(taskCalendarFabClearance(availableHeight: 0, desired: desired), 0);
  });

  test('the floor is derived from the cell, not typed twice', () {
    // If someone retunes the day circle or the cell padding, the floor has to
    // move with it — that is the whole point of `TaskCalendarDayCell.minHeight`.
    expect(
      kTaskCalendarMinGridHeight,
      greaterThanOrEqualTo(6 * TaskCalendarDayCell.minHeight),
    );
    expect(TaskCalendarDayCell.minHeight, 30);
  });
}
