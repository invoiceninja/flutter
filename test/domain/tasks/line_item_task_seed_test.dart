import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/domain/tasks/line_item_task_seed.dart';

LineItem _line({
  String productKey = '',
  String notes = '',
  String quantity = '1',
}) => emptyLineItem().copyWith(
  productKey: productKey,
  notes: notes,
  quantity: Decimal.parse(quantity),
);

void main() {
  group('lineItemTaskDescription', () {
    test('product key only', () {
      expect(lineItemTaskDescription(_line(productKey: 'SVC-01')), 'SVC-01');
    });

    test('notes only', () {
      expect(
        lineItemTaskDescription(_line(notes: 'Boiler service')),
        'Boiler service',
      );
    });

    test('key + notes joined by a blank line', () {
      expect(
        lineItemTaskDescription(
          _line(productKey: 'SVC-01', notes: 'Boiler service'),
        ),
        'SVC-01\n\nBoiler service',
      );
    });

    test('drops the key when the notes already open with it', () {
      expect(
        lineItemTaskDescription(
          _line(productKey: 'Boiler service', notes: 'boiler SERVICE\nAnnual'),
        ),
        'boiler SERVICE\nAnnual',
      );
    });

    test('collapses task-generated markup to plain text', () {
      expect(
        lineItemTaskDescription(
          _line(
            notes:
                '<div class="project-header">Acme Redesign</div>'
                'Homepage wireframes<br/>2.00 hours',
          ),
        ),
        'Acme Redesign\nHomepage wireframes\n2.00 hours',
      );
    });

    test('both blank', () {
      expect(lineItemTaskDescription(_line()), '');
    });
  });

  group('lineItemTaskDuration', () {
    test('whole hours', () {
      expect(
        lineItemTaskDuration(_line(quantity: '1')),
        const Duration(hours: 1),
      );
      expect(
        lineItemTaskDuration(_line(quantity: '8')),
        const Duration(hours: 8),
      );
    });

    test('fractional hours round to whole minutes', () {
      expect(
        lineItemTaskDuration(_line(quantity: '2.5')),
        const Duration(hours: 2, minutes: 30),
      );
      // 1.0083 h = 60.498 min -> 60.
      expect(
        lineItemTaskDuration(_line(quantity: '1.0083')),
        const Duration(minutes: 60),
      );
    });

    test('a sub-minute quantity floors at one minute', () {
      expect(
        lineItemTaskDuration(_line(quantity: '0.001')),
        const Duration(minutes: 1),
      );
    });

    test('zero, negative and out-of-range fall back to 1h', () {
      expect(
        lineItemTaskDuration(_line(quantity: '0')),
        const Duration(hours: 1),
      );
      expect(
        lineItemTaskDuration(_line(quantity: '-3')),
        const Duration(hours: 1),
      );
      // 500 units on a product line is a unit count, not 500 hours.
      expect(
        lineItemTaskDuration(_line(quantity: '500')),
        const Duration(hours: 1),
      );
      // The boundary itself is still a legal (if long) block.
      expect(
        lineItemTaskDuration(_line(quantity: '24')),
        const Duration(hours: 24),
      );
    });
  });

  group('seedTimeLogForLineItem', () {
    test('one entry spanning the duration, billable honoured', () {
      // Local wall-clock start — the delta below is tz-independent, and the
      // instant is built the same way in both the helper and the expectation.
      final start = DateTime(2026, 6, 14, 9);
      final log = seedTimeLogForLineItem(
        start: start,
        duration: const Duration(hours: 2),
        billable: false,
      );
      final entry = log.single;
      expect(entry.start, start);
      expect(entry.stop!.difference(entry.start!), const Duration(hours: 2));
      expect(entry.billable, isFalse);
    });
  });

  group('round trip with taskToLineItem', () {
    test('a clean 2h line seeds a 2h block', () {
      // `taskToLineItem` writes `quantity: taskBillableHours(task)`; this is
      // the return leg. Kept as an explicit check so a change to either
      // rounding convention shows up here.
      final duration = lineItemTaskDuration(_line(quantity: '2.000'));
      expect(duration, const Duration(hours: 2));
    });
  });
}
