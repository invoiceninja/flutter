import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';

/// `tasks.due_date` + `tasks.estimated_duration` — the 2026-08-31 server
/// fields that carry a booking's *plan*, and the only part of it that survives
/// the booked block being claimed (invoiceninja/flutter#149).
void main() {
  TaskApi api(Map<String, dynamic> overrides) =>
      TaskApi.fromJson(<String, dynamic>{'id': 't1', ...overrides});

  test('parses the wire shape', () {
    final t = Task.fromApi(
      api({'due_date': '2026-09-14', 'estimated_duration': 5400}),
    );
    expect(t.dueDate, Date(2026, 9, 14));
    expect(t.estimatedSeconds, 5400);
  });

  test(
    'an unset pair round-trips as unset, in every spelling the wire uses',
    () {
      // The server sends `''` for an unset date (`$task->due_date ?: ''`) and
      // `null` for an unset estimate; a self-hosted install older than the
      // 2026-08-31 migration sends neither key at all.
      for (final raw in [
        <String, dynamic>{'due_date': '', 'estimated_duration': null},
        <String, dynamic>{},
      ]) {
        final t = Task.fromApi(api(raw));
        expect(t.dueDate, isNull, reason: '$raw');
        expect(t.estimatedSeconds, 0, reason: '$raw');
      }
    },
  );

  test('toApiJson emits BOTH keys, always', () {
    // `_domainToCompanion` stores this map as the Drift payload and `_fromRow`
    // reads the domain back out of it, so an omitted key round-trips to
    // "unset": a local edit would blank a value the user never touched.
    final t = Task.fromApi(
      api({'due_date': '2026-09-14', 'estimated_duration': 5400}),
    );
    final json = t.toApiJson();
    expect(json.containsKey('due_date'), isTrue);
    expect(json.containsKey('estimated_duration'), isTrue);
    expect(json['due_date'], '2026-09-14');
    expect(json['estimated_duration'], 5400);

    final blank = Task.fromApi(api({})).toApiJson();
    // `''`, not a missing key — and safe, because Invoice Ninja runs
    // `ConvertEmptyStringsToNull` globally, so it reaches the `nullable` rule
    // as null rather than failing `date:Y-m-d`.
    expect(blank['due_date'], '');
    expect(blank['estimated_duration'], isNull);
  });

  test('the payload round trip is lossless', () {
    final t = Task.fromApi(
      api({'due_date': '2026-09-14', 'estimated_duration': 5400}),
    );
    final back = Task.fromApi(
      TaskApi.fromJson(
        jsonDecode(jsonEncode(t.toApiJson())) as Map<String, dynamic>,
      ),
    );
    expect(back.dueDate, t.dueDate);
    expect(back.estimatedSeconds, t.estimatedSeconds);
  });

  test(
    'fromApi sorts the time log, so `.last` really is the running entry',
    () {
      // Every running-state check in the stack is `.last`-based, and the
      // `is_running` Drift column is written from that same `.last`. The server
      // sorts on save; this keeps the invariant true for anything else that
      // reaches the domain model.
      final t = Task.fromApi(
        api({
          'time_log': jsonEncode([
            [300, 0, '', true],
            [100, 200, '', true],
          ]),
        }),
      );
      expect(t.timeLog.first.start!.millisecondsSinceEpoch, 100 * 1000);
      expect(t.timeLog.last.isRunning, isTrue);
      expect(t.isRunning, isTrue);
    },
  );

  test('billableDuration counts worked time only, never a booking', () {
    final now = DateTime.now();
    final future = now.add(const Duration(hours: 2));
    final t = Task.fromApi(
      api({
        'time_log': jsonEncode([
          [
            now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/
                1000,
            now.millisecondsSinceEpoch ~/ 1000,
            '',
            true,
          ],
          [
            future.millisecondsSinceEpoch ~/ 1000,
            future.add(const Duration(hours: 3)).millisecondsSinceEpoch ~/ 1000,
            '',
            true,
          ],
        ]),
      }),
    );
    // One worked hour; the three booked hours are a plan, not a quantity.
    expect(t.billableDuration(now).inMinutes, closeTo(60, 1));
    // `loggedDuration` is the same worked figure — it is what every duration
    // surface displays, and a booking is not time anyone has put in. The
    // billable/non-billable split against `billableDuration` is what it draws.
    expect(t.loggedDuration(now).inMinutes, closeTo(60, 1));
    expect(t.bookedTime(now).inMinutes, closeTo(180, 1));
  });
}
