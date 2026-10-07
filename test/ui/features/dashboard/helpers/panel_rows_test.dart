import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/ui/features/dashboard/helpers/panel_rows.dart';
import 'package:flutter_test/flutter_test.dart';

const _iq = DashboardKind.invoicesAndQuotes;
const _cal = DashboardKind.taskCalendar;
const _a = DashboardKind.upcomingInvoices;
const _b = DashboardKind.recentPayments;
const _c = DashboardKind.upcomingQuotes;
const _d = DashboardKind.expiredQuotes;
const _e = DashboardKind.upcomingRecurring;

void main() {
  group('two columns', () {
    test('the default arrangement leaves no half row empty', () {
      expect(layoutPanelRows([_iq, _a, _b, _c, _d, _e, _cal], columns: 2), [
        const PanelRow.span(_iq),
        const PanelRow.pair(_a, _b),
        const PanelRow.pair(_c, _d),
        const PanelRow.pair(_e, _cal),
      ]);
    });

    test('Invoices & Quotes takes a whole row wherever the user put it', () {
      expect(layoutPanelRows([_a, _b, _iq, _c, _d], columns: 2), [
        const PanelRow.pair(_a, _b),
        const PanelRow.span(_iq),
        const PanelRow.pair(_c, _d),
      ]);
    });

    test('an odd run gives its last table the whole row', () {
      expect(layoutPanelRows([_a, _b, _c], columns: 2), [
        const PanelRow.pair(_a, _b),
        const PanelRow.span(_c),
      ]);
    });

    test('the calendar is never the panel that is stretched', () {
      // Five panels ending in the calendar: a table takes the row instead, and
      // the calendar keeps a neighbour.
      expect(layoutPanelRows([_a, _b, _c, _d, _cal], columns: 2), [
        const PanelRow.pair(_a, _b),
        const PanelRow.span(_c),
        const PanelRow.pair(_d, _cal),
      ]);
    });

    test('a calendar in the middle of an odd run still pairs', () {
      expect(layoutPanelRows([_a, _b, _cal, _c, _d], columns: 2), [
        const PanelRow.pair(_a, _b),
        const PanelRow.pair(_cal, _c),
        const PanelRow.span(_d),
      ]);
    });

    test('a calendar leading a run of three pairs with its neighbour', () {
      expect(layoutPanelRows([_cal, _a, _b], columns: 2), [
        const PanelRow.pair(_cal, _a),
        const PanelRow.span(_b),
      ]);
    });

    test('the calendar on its own keeps its half width', () {
      expect(layoutPanelRows([_cal], columns: 2), [const PanelRow.half(_cal)]);
      // Cut off from the other panels by the full-width row, it is still on
      // its own.
      expect(layoutPanelRows([_a, _b, _iq, _cal], columns: 2), [
        const PanelRow.pair(_a, _b),
        const PanelRow.span(_iq),
        const PanelRow.half(_cal),
      ]);
    });

    test('a single table takes the row', () {
      expect(layoutPanelRows([_a], columns: 2), [const PanelRow.span(_a)]);
    });

    test('nothing to show is no rows', () {
      expect(layoutPanelRows(const [], columns: 2), isEmpty);
    });

    test('every panel is placed exactly once, in order', () {
      const all = [_iq, _a, _b, _c, _d, _e, _cal];
      // Every ordered subset the user could reach by hiding panels.
      for (var mask = 0; mask < (1 << all.length); mask++) {
        final kinds = [
          for (var i = 0; i < all.length; i++)
            if (mask & (1 << i) != 0) all[i],
        ];
        final rows = layoutPanelRows(kinds, columns: 2);
        final placed = [
          for (final r in rows) ...[r.first, if (r.second != null) r.second!],
        ];
        expect(placed, kinds, reason: 'order changed for $kinds');
        for (final r in rows) {
          if (r.spans) {
            expect(r.first, isNot(_cal), reason: 'calendar stretched: $kinds');
          }
          if (r.second == null && !r.spans) {
            // The only half row allowed: a calendar with no table in its run.
            expect(r.first, _cal, reason: 'empty half row in $kinds');
          }
        }
      }
    });
  });

  test('one column: every panel is its own row', () {
    expect(layoutPanelRows([_iq, _a, _cal], columns: 1), [
      const PanelRow.span(_iq),
      const PanelRow.span(_a),
      const PanelRow.span(_cal),
    ]);
  });
}
