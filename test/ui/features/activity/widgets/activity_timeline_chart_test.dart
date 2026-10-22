import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/activity/activity_timeline.dart';
import 'package:admin/ui/features/activity/widgets/activity_timeline_chart.dart';
import '../../../../_localization_helper.dart';

ActivityTimeline _days(int n, {DateTime? from}) {
  final start = from ?? DateTime(2026, 1, 1);
  return ActivityTimeline(
    size: TimelineBucketSize.day,
    buckets: [
      for (var i = 0; i < n; i++)
        TimelineBucket(
          start: start.add(Duration(days: i)),
          end: start.add(Duration(days: i + 1)),
          count: 1,
        ),
    ],
  );
}

Widget _host(ActivityTimeline timeline, List<(DateTime, DateTime)> picks) =>
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 520,
          child: ActivityTimelineChart(
            timeline: timeline,
            from: null,
            until: null,
            oldestAt: null,
            selectionCount: 0,
            formatter: null,
            onSelect: (from, until) => picks.add((from, until)),
            onClear: () {},
          ),
        ),
      ),
    );

void main() {
  // A refresh can re-bucket the window while a drag is held. The drag's
  // indices belonged to the old bars, and reading them against the new list
  // ran past its end.
  testWidgets('a re-bucketed timeline mid-drag drops the drag', (tester) async {
    final picks = <(DateTime, DateTime)>[];
    await tester.pumpWidget(_host(_days(52), picks));
    final chart = find.byType(GestureDetector).last;
    final box = tester.getRect(chart);

    final gesture = await tester.startGesture(
      Offset(box.right - 4, box.center.dy),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();

    await tester.pumpWidget(_host(_days(21), picks));
    await gesture.moveBy(const Offset(-10, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(picks, isEmpty, reason: 'the old drag selects nothing new');
  });

  testWidgets('an equal timeline keeps the drag', (tester) async {
    final picks = <(DateTime, DateTime)>[];
    await tester.pumpWidget(_host(_days(52), picks));
    final chart = find.byType(GestureDetector).last;
    final box = tester.getRect(chart);

    final gesture = await tester.startGesture(
      Offset(box.right - 4, box.center.dy),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    await tester.pumpWidget(_host(_days(52), picks));
    await gesture.moveBy(const Offset(-10, 0));
    await gesture.up();
    await tester.pump();

    expect(picks, hasLength(1));
  });
}
