import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/domain/tasks/task_schedule.dart';

/// Booked-vs-worked rules (invoiceninja/flutter#149).
///
/// Fixtures are built with the LOCAL `DateTime(...)` constructor and compared
/// against a local `now`, so every calendar-day derivation here is
/// zone-agnostic — the rule CLAUDE.md records for `TZ=UTC` on CI. The
/// `timeLogProblem` block is the exception: it reuses the server's own
/// epoch-second fixtures verbatim, where no calendar day is involved.
void main() {
  /// The server's wire shape, so a fixture reads like the PHP it mirrors.
  TimeEntry wire(int start, int stop) =>
      TimeEntry.fromWire(<dynamic>[start, stop]);

  TimeEntry block(DateTime start, Duration length) =>
      TimeEntry(start: start, stop: start.add(length));

  group('sortTimeLog', () {
    test('orders by start and drops entries with no start', () {
      final a = block(DateTime(2026, 9, 14, 9), const Duration(hours: 1));
      final b = block(DateTime(2026, 9, 14, 14), const Duration(hours: 1));
      const orphan = TimeEntry(start: null, stop: null);

      expect(sortTimeLog([b, orphan, a]), [a, b]);
    });

    test('leaves a running entry last when it starts last', () {
      final past = block(DateTime(2026, 9, 14, 9), const Duration(hours: 1));
      final running = TimeEntry(start: DateTime(2026, 9, 14, 11), stop: null);
      expect(sortTimeLog([running, past]), [past, running]);
    });
  });

  group('timeLogProblem — the server fixtures', () {
    // Ported one-for-one from tests/Feature/TaskApiTest.php's
    // testTimeLogChecker1..12, which is the only executable statement of
    // `Request::checkTimeLog`'s contract.
    final accepted = <String, List<TimeEntry>>{
      '1 — a lone running entry': [wire(50, 0)],
      '6 — out of order but disjoint': [wire(4, 5), wire(1, 3)],
      '7 — in order and disjoint': [wire(1, 3), wire(4, 5)],
      '8 — running entry starts last': [wire(1, 3), wire(50, 0)],
      '11 — adjacent, not overlapping': [wire(1, 2), wire(3, 4)],
    };
    final rejected = <String, (List<TimeEntry>, TimeLogProblemKind)>{
      '2 — second entry inverted': (
        [wire(4, 5), wire(5, 1)],
        TimeLogProblemKind.inverted,
      ),
      '3 — the later entry starts inside the earlier one': (
        [wire(4, 5), wire(3, 50)],
        TimeLogProblemKind.overlap,
      ),
      '4 — a running entry precedes a stopped one': (
        [wire(4, 5), wire(3, 0)],
        TimeLogProblemKind.runningNotLast,
      ),
      '5 — inverted once sorted': (
        [wire(4, 5), wire(3, 1)],
        TimeLogProblemKind.inverted,
      ),
    };

    for (final entry in accepted.entries) {
      test('accepts ${entry.key}', () {
        expect(timeLogProblem(entry.value), isNull);
      });
    }
    for (final entry in rejected.entries) {
      test('rejects ${entry.key}', () {
        expect(timeLogProblem(entry.value.$1)?.kind, entry.value.$2);
      });
    }

    test('an overlap names the window the server would name', () {
      // `Overlap detected: <max(start) > - <min(stop)>.`
      final problem = timeLogProblem([wire(10, 30), wire(20, 40)]);
      expect(problem!.kind, TimeLogProblemKind.overlap);
      expect(problem.from, wire(20, 40).start);
      expect(problem.to, wire(10, 30).stop);
    });

    test('a half-typed entry with no start is ignored, not rejected', () {
      // The draft holds one between "+ Add time" and the first keystroke.
      // Treated as epoch 0 it would sort first and read as a second running
      // entry, putting a permanent error banner on the edit form.
      final running = TimeEntry(start: DateTime(2026, 9, 14, 11), stop: null);
      const orphan = TimeEntry(start: null, stop: null);
      expect(timeLogProblem([orphan, running]), isNull);
    });
  });

  group('taskScheduleState', () {
    final now = DateTime(2026, 9, 14, 11, 30);
    final today = Date(2026, 9, 14);

    test('nothing booked reads none', () {
      final worked = block(DateTime(2026, 9, 13, 9), const Duration(hours: 2));
      expect(taskScheduleState([worked], now: now), TaskScheduleState.none);
    });

    test('a block starting later reads upcoming', () {
      final booked = block(DateTime(2026, 9, 14, 14), const Duration(hours: 2));
      expect(taskScheduleState([booked], now: now), TaskScheduleState.upcoming);
    });

    test(
      'a block the clock is inside reads dueNow — WITH the due-date anchor',
      () {
        final booked = block(
          DateTime(2026, 9, 14, 11),
          const Duration(hours: 2),
        );
        expect(
          taskScheduleState([booked], now: now, dueDate: today),
          TaskScheduleState.dueNow,
        );
      },
    );

    test('an unanchored block the clock is inside is WORK, not a booking', () {
      // The regression that made this rule necessary: the weekly grid
      // synthesizes every cell at local 09:00, so "8" typed into today's
      // column is 09:00–17:00 and looked exactly like a booking until 17:00 —
      // it billed zero, listed under Upcoming, and Start destroyed it. The
      // server reaches the same state by rounding an entry's end up.
      final worked = block(DateTime(2026, 9, 14, 9), const Duration(hours: 8));
      expect(taskScheduleState([worked], now: now), TaskScheduleState.none);
      expect(
        workedDuration([worked], now: now),
        const Duration(hours: 8),
        reason: 'counted in full — the user typed eight hours and meant them',
      );
      expect(scheduledDuration([worked], now: now), Duration.zero);
      // Not `append` either: a running entry started now would sit inside the
      // 09:00–17:00 block, which the server rejects as an overlap. There is no
      // legal log, which is what `blocked` means — and the crucial part is
      // that the work is left alone rather than claimed and rewritten.
      final plan = planTaskStart([worked], now: now);
      expect(plan.outcome, TaskStartOutcome.blocked);
      expect(plan.claimed, isNull);
      expect(plan.entries, [worked]);
    });

    test(
      'a running task is never a schedule state — claiming already happened',
      () {
        final running = TimeEntry(start: DateTime(2026, 9, 14, 11), stop: null);
        final booked = block(
          DateTime(2026, 9, 14, 14),
          const Duration(hours: 2),
        );
        expect(
          taskScheduleState([booked, running], now: now),
          TaskScheduleState.none,
        );
      },
    );

    test(
      'a passed block on the due date, matching the estimate, reads late',
      () {
        final booked = block(
          DateTime(2026, 9, 14, 9),
          const Duration(hours: 2),
        );
        expect(
          taskScheduleState(
            [booked],
            now: now,
            dueDate: today,
            estimatedSeconds: const Duration(hours: 2).inSeconds,
          ),
          TaskScheduleState.late,
        );
        expect(
          lateBy(
            [booked],
            now: now,
            dueDate: today,
            estimatedSeconds: const Duration(hours: 2).inSeconds,
          ),
          const Duration(hours: 2, minutes: 30),
        );
      },
    );

    test('a passed block that does NOT match the estimate is worked time', () {
      // Without this clause a task with one real logged entry on its due date
      // reads `late`, and claiming offers to discard it. The two scheduling
      // sheets seed the estimate from the block's own length, so an untouched
      // booking matches and worked-then-adjusted time does not.
      final worked = block(DateTime(2026, 9, 14, 9), const Duration(hours: 2));
      expect(
        taskScheduleState(
          [worked],
          now: now,
          dueDate: today,
          estimatedSeconds: const Duration(hours: 5).inSeconds,
        ),
        TaskScheduleState.none,
      );
      expect(
        taskScheduleState([worked], now: now, dueDate: today),
        TaskScheduleState.none,
        reason: 'no estimate at all is not a booking either',
      );
    });

    test(
      'without a due date a passed block is indistinguishable from work',
      () {
        // The permanent limitation: nothing in the log separates an unworked
        // booking from a finished session once its window closes.
        final booked = block(
          DateTime(2026, 9, 14, 9),
          const Duration(hours: 2),
        );
        expect(taskScheduleState([booked], now: now), TaskScheduleState.none);
        expect(lateBy([booked], now: now), isNull);
      },
    );

    test(
      'late needs a SINGLE entry — prior work means the block was worked',
      () {
        final earlier = block(
          DateTime(2026, 9, 14, 7),
          const Duration(hours: 1),
        );
        final booked = block(
          DateTime(2026, 9, 14, 9),
          const Duration(hours: 2),
        );
        expect(
          taskScheduleState([earlier, booked], now: now, dueDate: today),
          TaskScheduleState.none,
        );
      },
    );

    test('late needs the block to sit ON the due date', () {
      final booked = block(DateTime(2026, 9, 13, 9), const Duration(hours: 2));
      expect(
        taskScheduleState([booked], now: now, dueDate: today),
        TaskScheduleState.none,
      );
    });

    test("the anchor uses the entry's LOCAL day, agreeing with task_day.dart", () {
      // `task_schedule.dart` duplicates `timeEntryLocalDate` to stay a leaf, so
      // the two can drift. Exercised through the public API rather than by
      // re-asserting `timeEntryLocalDate` against a literal — that version
      // never touched this file at all, and stayed green when the private copy
      // was changed to bucket in UTC.
      final lateEvening = block(
        DateTime(2026, 9, 14, 22),
        const Duration(minutes: 30),
      );
      expect(timeEntryLocalDate(lateEvening), Date(2026, 9, 14));
      expect(
        taskScheduleState(
          [lateEvening],
          now: DateTime(2026, 9, 14, 23, 30),
          dueDate: Date(2026, 9, 14),
          estimatedSeconds: const Duration(minutes: 30).inSeconds,
        ),
        TaskScheduleState.late,
        reason: 'the block sits on its due date in LOCAL time',
      );
      expect(
        taskScheduleState(
          [lateEvening],
          now: DateTime(2026, 9, 14, 23, 30),
          dueDate: Date(2026, 9, 15),
          estimatedSeconds: const Duration(minutes: 30).inSeconds,
        ),
        TaskScheduleState.none,
        reason: 'the next day is not the anchor',
      );
    });
  });

  group('worked vs scheduled', () {
    final now = DateTime(2026, 9, 14, 11, 30);

    test(
      'a booking contributes nothing to worked, and all of it to scheduled',
      () {
        final booked = block(
          DateTime(2026, 9, 14, 14),
          const Duration(hours: 2),
        );
        expect(workedDuration([booked], now: now), Duration.zero);
        expect(scheduledDuration([booked], now: now), const Duration(hours: 2));
      },
    );

    test('an ANCHORED block the clock is inside is wholly scheduled', () {
      final booked = block(DateTime(2026, 9, 14, 11), const Duration(hours: 2));
      const anchor = Date(2026, 9, 14);
      expect(
        workedDuration([booked], now: now, dueDate: anchor),
        Duration.zero,
      );
      expect(
        scheduledDuration([booked], now: now, dueDate: anchor),
        const Duration(hours: 2),
      );
    });

    test('a running entry counts up to now', () {
      final running = TimeEntry(start: DateTime(2026, 9, 14, 11), stop: null);
      expect(workedDuration([running], now: now), const Duration(minutes: 30));
      expect(scheduledDuration([running], now: now), Duration.zero);
    });

    test('a finished block counts fully', () {
      final worked = block(DateTime(2026, 9, 14, 9), const Duration(hours: 2));
      expect(workedDuration([worked], now: now), const Duration(hours: 2));
      expect(scheduledDuration([worked], now: now), Duration.zero);
    });
  });

  group('planTaskStart', () {
    final now = DateTime(2026, 9, 14, 11, 30);
    final today = Date(2026, 9, 14);

    test('no booking appends, exactly as before', () {
      final worked = block(DateTime(2026, 9, 14, 9), const Duration(hours: 1));
      final plan = planTaskStart([worked], now: now);
      expect(plan.outcome, TaskStartOutcome.append);
      expect(plan.entries, hasLength(2));
      expect(plan.entries.last.start, now);
      expect(plan.entries.last.stop, isNull);
    });

    test('an appended entry never inherits billable from the last one', () {
      final worked = TimeEntry(
        start: DateTime(2026, 9, 14, 9),
        stop: DateTime(2026, 9, 14, 10),
        description: 'carried',
        billable: false,
      );
      final plan = planTaskStart([worked], now: now);
      expect(plan.entries.last.description, 'carried');
      expect(plan.entries.last.billable, isTrue);
    });

    test('a live booking is claimed in one step', () {
      final booked = block(DateTime(2026, 9, 14, 11), const Duration(hours: 2));
      final plan = planTaskStart([booked], now: now, dueDate: today);
      expect(plan.outcome, TaskStartOutcome.claim);
      expect(plan.entries, hasLength(1));
      expect(plan.entries.single.start, now);
      expect(plan.entries.single.stop, isNull);
      expect(plan.claimed, booked);
    });

    test('a booking later the same day claims without a prompt', () {
      final booked = block(DateTime(2026, 9, 14, 14), const Duration(hours: 2));
      expect(planTaskStart([booked], now: now).outcome, TaskStartOutcome.claim);
    });

    test('a booking on another day asks first', () {
      final booked = block(DateTime(2026, 9, 15, 9), const Duration(hours: 2));
      final plan = planTaskStart([booked], now: now);
      expect(plan.outcome, TaskStartOutcome.claimOtherDay);
      expect(plan.entries.single.start, now);
    });

    test('a passed booking on the due date offers to replace itself', () {
      final booked = block(DateTime(2026, 9, 14, 9), const Duration(hours: 2));
      final plan = planTaskStart(
        [booked],
        now: now,
        dueDate: today,
        estimatedSeconds: const Duration(hours: 2).inSeconds,
      );
      expect(plan.outcome, TaskStartOutcome.claimLate);
      expect(plan.entries.single.start, now);
      expect(plan.entries.single.stop, isNull);
    });

    test('two unfinished bookings are blocked — no legal log exists', () {
      final a = block(DateTime(2026, 9, 14, 14), const Duration(hours: 1));
      final b = block(DateTime(2026, 9, 15, 9), const Duration(hours: 1));
      final plan = planTaskStart([a, b], now: now);
      expect(plan.outcome, TaskStartOutcome.blocked);
      expect(plan.entries, [a, b]);
      // Proving the point: claiming either one still leaves the other after
      // the running entry, which the server rejects outright.
      expect(
        timeLogProblem([a.copyWith(start: now, stop: null), b])?.kind,
        TimeLogProblemKind.runningNotLast,
      );
    });

    test('an already-running entry is closed before the new one opens', () {
      final running = TimeEntry(start: DateTime(2026, 9, 14, 10), stop: null);
      final plan = planTaskStart([running], now: now);
      expect(plan.outcome, TaskStartOutcome.append);
      expect(plan.entries.first.stop, now);
      expect(plan.entries.last.stop, isNull);
    });

    test(
      'a running entry that starts in the future is dropped, not claimed',
      () {
        // Foreign data: another client can store one. Closing it at `now` would
        // invert it, and keeping it as a zero-length future block would read as
        // a booking — so "Start" on a task with a stuck timer opened a claim
        // dialog instead of starting.
        final running = TimeEntry(start: DateTime(2026, 9, 14, 18), stop: null);
        final plan = planTaskStart([running], now: now);
        expect(plan.outcome, TaskStartOutcome.append);
        expect(plan.claimed, isNull);
        expect(plan.entries.single.start, now);
        expect(timeLogProblem(plan.entries), isNull);
      },
    );

    test('every plan the server would accept, it accepts', () {
      final cases = <List<TimeEntry>>[
        [],
        [block(DateTime(2026, 9, 14, 9), const Duration(hours: 1))],
        [block(DateTime(2026, 9, 14, 11), const Duration(hours: 2))],
        [block(DateTime(2026, 9, 14, 14), const Duration(hours: 2))],
        [block(DateTime(2026, 9, 15, 9), const Duration(hours: 2))],
        [
          block(DateTime(2026, 9, 14, 7), const Duration(hours: 1)),
          block(DateTime(2026, 9, 14, 14), const Duration(hours: 2)),
        ],
        [TimeEntry(start: DateTime(2026, 9, 14, 10), stop: null)],
      ];
      for (final entries in cases) {
        for (final due in <Date?>[null, today]) {
          final plan = planTaskStart(
            entries,
            now: now,
            dueDate: due,
            estimatedSeconds: const Duration(hours: 2).inSeconds,
          );
          if (plan.outcome == TaskStartOutcome.blocked) continue;
          expect(
            timeLogProblem(plan.entries),
            isNull,
            reason: 'plan ${plan.outcome} produced a log the server rejects',
          );
          expect(
            plan.entries.last.isRunning,
            isTrue,
            reason: 'a start must leave exactly one open entry, last',
          );
        }
      }
    });
  });
}
