import 'package:admin/data/models/api/calendar_connection_api_model.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/calendar_event_seed.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/convert_event_to_task_sheet.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('seedTimeLogForEvent', () {
    test('timed event preserves the event duration', () {
      const e = CalendarEvent(
        start: '2026-06-14T09:00:00Z',
        end: '2026-06-14T10:30:00Z',
      );
      final entry = seedTimeLogForEvent(e).single;
      // start/stop render in local time, but their delta is tz-independent.
      expect(entry.stop!.difference(entry.start!), const Duration(minutes: 90));
      expect(entry.billable, isTrue);
    });

    test('zero-length timed event pads to 1h', () {
      const e = CalendarEvent(
        start: '2026-06-14T09:00:00Z',
        end: '2026-06-14T09:00:00Z',
      );
      final entry = seedTimeLogForEvent(e).single;
      expect(entry.stop!.difference(entry.start!), const Duration(hours: 1));
    });

    test('all-day event anchors a 1h block at 09:00 local on its date', () {
      const e = CalendarEvent(
        allDay: true,
        start: '2026-06-14',
        end: '2026-06-15',
      );
      final entry = seedTimeLogForEvent(e).single;
      expect(entry.start, DateTime(2026, 6, 14, 9));
      expect(entry.stop!.difference(entry.start!), const Duration(hours: 1));
    });
  });

  group('seedDescriptionForEvent', () {
    test('title only', () {
      expect(
        seedDescriptionForEvent(const CalendarEvent(title: 'Standup')),
        'Standup',
      );
    });

    test('title + body joined by a blank line', () {
      expect(
        seedDescriptionForEvent(
          const CalendarEvent(title: 'Standup', description: 'Daily sync'),
        ),
        'Standup\n\nDaily sync',
      );
    });
  });

  group('CalendarEvent helpers', () {
    test('all-day dayKey/startLocal use the floating date (no tz shift)', () {
      const e = CalendarEvent(allDay: true, start: '2026-06-14');
      expect(e.dayKey, '2026-06-14');
      expect(e.startLocal, DateTime(2026, 6, 14));
    });

    test('timed dayKey agrees with the local start date', () {
      const e = CalendarEvent(start: '2026-06-14T12:00:00Z');
      final local = e.startLocal!;
      final expected =
          '${local.year.toString().padLeft(4, '0')}-'
          '${local.month.toString().padLeft(2, '0')}-'
          '${local.day.toString().padLeft(2, '0')}';
      expect(e.dayKey, expected);
    });

    test('isCancelled reflects the status', () {
      expect(const CalendarEvent(status: 'cancelled').isCancelled, isTrue);
      expect(const CalendarEvent(status: 'confirmed').isCancelled, isFalse);
    });
  });
  group('seedTaskForEvent carries the plan beside the block', () {
    // Claiming a booking rewrites its start to `now`, so `due_date` and
    // `estimated_duration` are the only part of the promise that survives the
    // work starting — and `due_date` is what lets `taskScheduleState` tell a
    // booking from an ordinary forward-looking entry at all.
    test('due date is the block\'s LOCAL day, estimate its length', () {
      const e = CalendarEvent(
        start: '2026-06-14T09:00:00Z',
        end: '2026-06-14T10:30:00Z',
      );
      final task = seedTaskForEvent(e);
      final localStart = task.timeLog.single.start!.toLocal();

      expect(task.estimatedSeconds, const Duration(minutes: 90).inSeconds);
      expect(
        task.dueDate,
        Date(localStart.year, localStart.month, localStart.day),
        reason: 'the anchor must name the day the block renders on',
      );
    });

    test('the plan always matches whatever block was seeded', () {
      // An event with no usable window still seeds a 1 h block (the same
      // fallback `seedTimeLogForEvent` applies to an all-day event), so the
      // estimate must follow it rather than stay unset — otherwise the task
      // would carry a booking with no anchor and read as ordinary worked time
      // the moment its window closed.
      const e = CalendarEvent(start: '', end: '');
      final task = seedTaskForEvent(e);
      final entry = task.timeLog.single;
      expect(
        task.estimatedSeconds,
        entry.stop!.difference(entry.start!).inSeconds,
      );
      expect(task.dueDate, isNotNull);
    });
  });
}
