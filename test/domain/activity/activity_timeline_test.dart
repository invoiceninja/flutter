import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/domain/activity/activity_timeline.dart';
import 'package:admin/domain/activity/activity_tones.dart';

/// Fixtures are built in **local** time: the unit under test buckets by the
/// device's calendar, so a local wall-clock fixture lands in the same bucket
/// in every zone. Midday keeps a DST jump from crossing midnight.
DashboardActivity _at(
  DateTime at, {
  String id = 'a',
  int type = 5,
  String? userId = 'u1',
  String? invoiceId = 'inv1',
}) => DashboardActivity.fromJson(<String, dynamic>{
  'id': id,
  'activity_type_id': type,
  'created_at': at.millisecondsSinceEpoch ~/ 1000,
  'notes': '',
  if (userId != null) 'user': {'label': 'User', 'hashed_id': userId},
  if (invoiceId != null) 'invoice': {'label': '0001', 'hashed_id': invoiceId},
});

String? _target(DashboardActivity a) =>
    a.invoiceId == null ? null : '/invoices/${a.invoiceId}';

void main() {
  group('bucketSizeFor', () {
    test('widens with the window so the bar count stays readable', () {
      expect(bucketSizeFor(const Duration(hours: 5)), TimelineBucketSize.hour);
      expect(bucketSizeFor(const Duration(days: 2)), TimelineBucketSize.hour);
      expect(bucketSizeFor(const Duration(days: 3)), TimelineBucketSize.day);
      expect(bucketSizeFor(const Duration(days: 62)), TimelineBucketSize.day);
      expect(bucketSizeFor(const Duration(days: 133)), TimelineBucketSize.week);
      expect(
        bucketSizeFor(const Duration(days: 700)),
        TimelineBucketSize.month,
      );
      expect(
        bucketSizeFor(const Duration(days: 365 * 8)),
        TimelineBucketSize.year,
      );
    });
  });

  group('bucketize', () {
    test('keeps empty periods as zero bars, contiguous to now', () {
      final now = DateTime(2026, 6, 20, 12);
      final rows = [
        _at(DateTime(2026, 6, 10, 12), id: 'a'),
        _at(DateTime(2026, 6, 10, 15), id: 'b'),
        _at(DateTime(2026, 6, 13, 12), id: 'c'),
      ];
      final t = bucketize(rows, now: now, spanOf: rows);

      expect(t.size, TimelineBucketSize.day);
      // 10 Jun … 20 Jun inclusive.
      expect(t.buckets, hasLength(11));
      expect(t.buckets.first.start, DateTime(2026, 6, 10));
      expect(t.buckets.last.start, DateTime(2026, 6, 20));
      expect(
        [for (final b in t.buckets) b.count],
        [
          2, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, //
        ],
      );
      expect(t.maxCount, 2);
      for (var i = 1; i < t.buckets.length; i++) {
        expect(t.buckets[i].start, t.buckets[i - 1].end);
      }
    });

    test('the axis comes from spanOf, so a filter cannot rescale it', () {
      final now = DateTime(2026, 6, 20, 12);
      final all = [
        _at(DateTime(2026, 6, 1, 12), id: 'old'),
        _at(DateTime(2026, 6, 19, 12), id: 'new'),
      ];
      final t = bucketize([all.last], now: now, spanOf: all);
      expect(t.buckets.first.start, DateTime(2026, 6, 1));
      expect(t.buckets.fold<int>(0, (s, b) => s + b.count), 1);
    });

    test('week bars start on the configured first day of the week', () {
      final now = DateTime(2026, 9, 30, 12); // a Wednesday
      final rows = [_at(DateTime(2026, 6, 10, 12))]; // a Wednesday
      final monday = bucketize(rows, now: now, spanOf: rows);
      expect(monday.size, TimelineBucketSize.week);
      expect(monday.buckets.first.start, DateTime(2026, 6, 8));
      expect(monday.buckets.first.start.weekday, DateTime.monday);

      final sunday = bucketize(
        rows,
        now: now,
        spanOf: rows,
        firstDayOfWeek: DateTime.sunday,
      );
      expect(sunday.buckets.first.start, DateTime(2026, 6, 7));
      expect(sunday.buckets.first.start.weekday, DateTime.sunday);
    });

    test('a row stamped after now still lands in a bar', () {
      final now = DateTime(2026, 6, 20, 12);
      final rows = [
        _at(DateTime(2026, 6, 19, 12), id: 'a'),
        _at(DateTime(2026, 6, 21, 12), id: 'skewed'),
      ];
      final t = bucketize(rows, now: now, spanOf: rows);
      expect(t.buckets.fold<int>(0, (s, b) => s + b.count), 2);
    });

    test('an empty window has no bars', () {
      final t = bucketize(const [], now: DateTime(2026), spanOf: const []);
      expect(t.buckets, isEmpty);
    });
  });

  group('activityCategoryFor', () {
    test('a comment is a comment, whatever the tone map says', () {
      expect(
        activityCategoryFor(_at(DateTime(2026), type: 141)),
        ActivityCategory.comment,
      );
    });

    test('every toned type lands in its tone category', () {
      for (final e in kActivityTones.entries) {
        final category = activityCategoryFor(_at(DateTime(2026), type: e.key));
        expect(toneForCategory(category), e.value, reason: 'type ${e.key}');
      }
    });

    test('an untoned type is other', () {
      expect(
        activityCategoryFor(_at(DateTime(2026), type: 8)),
        ActivityCategory.other,
      );
    });
  });

  group('collapseRuns', () {
    final day = DateTime(2026, 6, 10, 12);

    test('folds consecutive rows saying the same thing about one record', () {
      final rows = [
        _at(day.add(const Duration(minutes: 3)), id: 'a'),
        _at(day.add(const Duration(minutes: 2)), id: 'b'),
        _at(day.add(const Duration(minutes: 1)), id: 'c'),
      ];
      final runs = collapseRuns(rows, targetOf: _target);
      expect(runs, hasLength(1));
      expect([for (final a in runs.single) a.id], ['a', 'b', 'c']);
    });

    test('a different actor, type or record breaks the run', () {
      final rows = [
        _at(day, id: 'a'),
        _at(day, id: 'b', userId: 'u2'),
        _at(day, id: 'c', type: 4),
        _at(day, id: 'd', invoiceId: 'inv2'),
      ];
      expect(collapseRuns(rows, targetOf: _target), hasLength(4));
    });

    test('a run never crosses midnight', () {
      final rows = [
        _at(DateTime(2026, 6, 11, 12), id: 'a'),
        _at(DateTime(2026, 6, 10, 12), id: 'b'),
      ];
      expect(collapseRuns(rows, targetOf: _target), hasLength(2));
    });

    test('rows with no record never fold — same verb is not same event', () {
      final rows = [
        _at(day, id: 'a', invoiceId: null),
        _at(day, id: 'b', invoiceId: null),
      ];
      expect(collapseRuns(rows, targetOf: _target), hasLength(2));
    });

    test('comments never fold — each one is different text', () {
      final rows = [_at(day, id: 'a', type: 141), _at(day, id: 'b', type: 141)];
      expect(collapseRuns(rows, targetOf: _target), hasLength(2));
    });

    test('only consecutive rows fold', () {
      final rows = [
        _at(day, id: 'a'),
        _at(day, id: 'x', invoiceId: 'other'),
        _at(day, id: 'b'),
      ];
      expect(collapseRuns(rows, targetOf: _target), hasLength(3));
    });
  });
}
