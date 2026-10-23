import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/charts/report_series_plot.dart';

/// fl_chart 1.3 reports a right-click (`FlSecondaryTapUpEvent`); the plot
/// turns it into the period under the pointer, for the report's context menu.
/// A click still drills, and neither fires on touch.
void main() {
  final taps = <int>[];
  final menus = <(int, Offset)>[];

  setUp(() {
    taps.clear();
    menus.clear();
  });

  Future<void> pumpPlot(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              child: ReportSeriesPlot(
                labels: const ['January', 'February', 'March'],
                // Equal and tall, so the middle bar fills the plot's centre.
                series: const [
                  ReportPlotSeries(
                    name: 'Amount',
                    color: Colors.blue,
                    values: [100, 100, 100],
                  ),
                ],
                style: ReportTimeChartStyle.columns,
                axisText: (v) => '$v',
                valueText: (v) => '$v',
                semanticsLabel: 'Amount by month',
                onTapIndex: taps.add,
                onSecondaryTapIndex: (i, position) => menus.add((i, position)),
              ),
            ),
          ),
        ),
      ),
    );
    // Past the chart's entry tween.
    await tester.pumpAndSettle();
  }

  /// Inside the middle of the three bars. They are spread symmetrically, so
  /// it sits at the centre of the plot — the chart less its value axis on the
  /// right (52 at this text scale) and the period labels below (20).
  Offset middleBar(WidgetTester tester) {
    final chart = tester.getRect(find.byType(BarChart));
    return Offset(
      chart.left + (chart.width - 52) / 2,
      chart.top + (chart.height - 20) * 0.6,
    );
  }

  testWidgets('a right-click names the period under the pointer', (
    tester,
  ) async {
    await pumpPlot(tester);
    final at = middleBar(tester);
    await tester.tapAt(at, buttons: kSecondaryButton);
    await tester.pump();

    expect(menus, hasLength(1));
    expect(menus.single.$1, 1);
    expect(menus.single.$2, at);
    expect(taps, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a click still drills, and asks for no menu', (tester) async {
    await pumpPlot(tester);
    await tester.tapAt(middleBar(tester));
    await tester.pump();

    expect(taps, [1]);
    expect(menus, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('on touch neither fires — a tap only opens the tooltip', (
    tester,
  ) async {
    await pumpPlot(tester);
    final at = middleBar(tester);
    await tester.tapAt(at);
    await tester.tapAt(at, buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(taps, isEmpty);
    expect(menus, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
