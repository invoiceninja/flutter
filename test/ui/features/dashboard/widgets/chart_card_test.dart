import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_chart_series.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/chart_card.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

/// #23 — the Revenue chart shows all four series by default, so the card has
/// to render four curves and a tooltip that identifies each of them.
void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;

  /// Bumped to rebuild the card alone, the way the dashboard's own
  /// `ListenableBuilder` does. Re-pumping the whole `MaterialApp` would not
  /// do: a new `ThemeData` starts `AnimatedTheme`'s tween, which is an
  /// animation too.
  late ValueNotifier<int> rebuild;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    rebuild = ValueNotifier(0);
    vm = DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
      // Toggling a series or the grouping schedules a debounced nav_state
      // write; the default 500 ms outlives the pump and trips "a Timer is
      // still pending".
      persistDebounce: const Duration(milliseconds: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
    rebuild.dispose();
    await db.close();
  });

  /// Three daily buckets on the "all currencies" key (999), one non-zero
  /// point per series so every curve has a distinct height.
  Map<String, dynamic> seriesJson() => {
    'start_date': '2026-04-01',
    'end_date': '2026-04-03',
    '999': {
      'invoices': [
        {'date': '2026-04-01', 'total': '400', 'currency': '1'},
        {'date': '2026-04-02', 'total': '410', 'currency': '1'},
      ],
      'payments': [
        {'date': '2026-04-01', 'total': '300', 'currency': '1'},
        {'date': '2026-04-02', 'total': '310', 'currency': '1'},
      ],
      'outstanding': [
        {'date': '2026-04-01', 'total': '200', 'currency': '1'},
        {'date': '2026-04-02', 'total': '210', 'currency': '1'},
      ],
      'expenses': [
        {'date': '2026-04-01', 'total': '100', 'currency': '1'},
        {'date': '2026-04-02', 'total': '110', 'currency': '1'},
      ],
    },
  };

  /// The card under a builder that hands it a new `ChartCard` and a new
  /// `Formatter` on every [rebuild] tick — what a parent rebuild looks like.
  Widget host() => MaterialApp(
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    theme: buildInTheme(InTheme.light),
    home: Scaffold(
      body: SizedBox(
        width: 800,
        child: ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (context, _, _) => ChartCard(
            vm: vm,
            formatter: Formatter(
              settings: CompanyFormatSettings.fallback,
              // `money()` returns '' for an unresolvable currency, so the
              // company currency has to be present for the tooltip to hold
              // anything worth asserting on.
              currencies: {
                '1': Currency(
                  id: '1',
                  name: 'USD',
                  code: 'USD',
                  symbol: r'$',
                  precision: 2,
                  thousandSeparator: ',',
                  decimalSeparator: '.',
                  swapCurrencySymbol: false,
                  exchangeRate: Decimal.one,
                ),
              },
              countries: const {},
              dateFormats: const {},
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> pump(WidgetTester tester) async {
    repo.chart.add(DashboardChartSeries.fromJson(seriesJson()));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('renders one line per series — four by default', (tester) async {
    await pump(tester);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.length, 4);
    // Enum order, so the legend colours and the curves line up.
    expect(chart.data.lineBarsData.map((b) => b.spots.map((s) => s.y).first), [
      400.0,
      300.0,
      200.0,
      100.0,
    ]);
    // The legend labels every series, in the same order — it and the curves
    // share `_labelFor` / `_colorFor`, so a fifth series can't reach one
    // without the other. The third is "Unpaid", not "Outstanding": it is what
    // invoices dated in this period still owe, and the figure above the chart
    // that is called Outstanding is everything owed today.
    for (final label in ['Invoices', 'Payments', 'Unpaid', 'Expenses']) {
      expect(find.text(label), findsOneWidget, reason: '$label legend chip');
    }
    expect(find.text('Outstanding'), findsNothing);
  });

  testWidgets('has no headline figure of its own', (tester) async {
    await pump(tester);

    // It used to lead with the period's paid revenue — the Payments figure
    // directly above it, again — under a caption that described that number
    // and not the four lines beneath.
    expect(find.text('Overview'), findsOneWidget);
    expect(find.byType(DeltaChip), findsNothing);
    expect(find.textContaining('paid invoices'), findsNothing);
  });

  testWidgets('a legend entry is a real toggle', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Expenses'));
    // The screen mounts the card under the view model's chart listenable;
    // this host rebuilds on its own tick.
    rebuild.value++;
    await tester.pump(const Duration(milliseconds: 400));

    expect(vm.visibleChartSeries, isNot(contains(ChartSeriesId.expenses)));
    expect(
      tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.length,
      3,
    );
    // A screen reader hears a switch, not a bare label.
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.text('Expenses')),
      isSemantics(label: 'Expenses', isToggled: false, hasTapAction: true),
    );
    handle.dispose();
  });

  // The series colours mean the same thing wherever the app uses them, and
  // none is the user's own accent — a green or red accent collided with
  // Payments or read as "overdue". Unpaid is amber: owed is not an alarm.
  testWidgets('series use fixed tones, never the accent or the overdue red', (
    tester,
  ) async {
    await pump(tester);

    final colors = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .lineBarsData
        .map((b) => b.color)
        .toList();
    const t = InTheme.light;
    // Blue, green, amber, grey — the status pills' own pairs.
    expect(colors, [t.partial, t.paid, t.sent, t.ink3]);
    expect(colors, isNot(contains(t.accent)));
    expect(colors, isNot(contains(t.overdue)));
  });

  group('states', () {
    testWidgets(
      'before the series answers it is a placeholder, not "no data"',
      (tester) async {
        await tester.pumpWidget(host());
        await tester.pump(const Duration(milliseconds: 10));

        expect(find.byType(LineChart), findsNothing);
        expect(find.text('No data for this period.'), findsNothing);
      },
    );

    testWidgets('a failed fetch with nothing cached offers a retry', (
      tester,
    ) async {
      repo.refreshAllErrors = {DashboardKind.chart: Exception('x')};
      await vm.refresh();
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.text("Couldn't load"), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
      expect(find.text('No data for this period.'), findsNothing);
    });
  });

  testWidgets('a series that loaded with nothing in it says so', (
    tester,
  ) async {
    repo.chart.add(
      DashboardChartSeries.fromJson({
        'start_date': '2026-04-01',
        'end_date': '2026-04-30',
      }),
    );
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 10));

    // The positive control for the two `findsNothing` above: this is the
    // string, and only a loaded, empty series earns it.
    expect(find.byType(LineChart), findsNothing);
    expect(find.text('No data for this period.'), findsOneWidget);
  });

  // A phone drawing one month by week had six full dates in ~250 px, printed
  // over one another. The axis labels as many as fit, in the company's own
  // date format, and never fewer than two.
  group('date labels', () {
    Future<double> intervalAt(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repo.chart.add(
        DashboardChartSeries.fromJson({
          ...seriesJson(),
          'start_date': '2026-04-01',
          'end_date': '2026-04-30',
        }),
      );
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChartCard(
                vm: vm,
                formatter: Formatter(
                  settings: CompanyFormatSettings.fallback,
                  currencies: const {},
                  countries: const {},
                  dateFormats: const {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(data.lineBarsData.first.spots.length, greaterThanOrEqualTo(5));
      return data.titlesData.bottomTitles.sideTitles.interval!;
    }

    testWidgets('a wide plot labels every bucket', (tester) async {
      expect(await intervalAt(tester, 1000), 1);
    });

    testWidgets('a phone-width plot skips labels rather than overlap them', (
      tester,
    ) async {
      expect(await intervalAt(tester, 320), greaterThan(1));
    });
  });

  group('grouping', () {
    Set<ChartGrouping> selected(WidgetTester tester) => tester
        .widget<SegmentedButton<ChartGrouping>>(
          find.byType(SegmentedButton<ChartGrouping>),
        )
        .selected;
    Map<ChartGrouping, bool> enabled(WidgetTester tester) => {
      for (final s
          in tester
              .widget<SegmentedButton<ChartGrouping>>(
                find.byType(SegmentedButton<ChartGrouping>),
              )
              .segments)
        s.value: s.enabled,
    };

    // The default range under the default grouping: one month by month is two
    // boundaries, which plots as a single straight line.
    testWidgets('a range too short for its grouping is drawn finer, and the '
        'control says so', (tester) async {
      vm.setChartGrouping(ChartGrouping.month);
      repo.chart.add(
        DashboardChartSeries.fromJson({
          ...seriesJson(),
          'start_date': '2026-04-01',
          'end_date': '2026-04-30',
        }),
      );
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 400));

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.spots.length, greaterThan(3));
      expect(selected(tester), {ChartGrouping.week});
      expect(enabled(tester)[ChartGrouping.month], isFalse);
      expect(enabled(tester)[ChartGrouping.day], isTrue);
    });

    testWidgets('a grouping the range supports is drawn as asked', (
      tester,
    ) async {
      vm.setChartGrouping(ChartGrouping.month);
      repo.chart.add(
        DashboardChartSeries.fromJson({
          ...seriesJson(),
          'start_date': '2026-01-01',
          'end_date': '2026-12-31',
        }),
      );
      await tester.pump(const Duration(milliseconds: 10));
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 400));

      expect(selected(tester), {ChartGrouping.month});
      expect(enabled(tester).values, everyElement(isTrue));
    });
  });

  // Beside the activity feed the two cards must end on one line with their
  // contents, not just their borders: the plot takes the height the row
  // settles on.
  //
  // Pumped inside the very arrangement the screen uses — `IntrinsicHeight`
  // around a stretched `Row` — because that is where it broke: fl_chart's plot
  // is a `LayoutBuilder`, which throws when asked for an intrinsic size, and
  // the row then painted nothing at all. A test that handed the card a tight
  // box passed while the dashboard showed a blank band.
  testWidgets('fillHeight: beside a taller card, the plot stretches to it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo.chart.add(DashboardChartSeries.fromJson(seriesJson()));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 17,
                    child: ChartCard(
                      vm: vm,
                      formatter: Formatter(
                        settings: CompanyFormatSettings.fallback,
                        currencies: const {},
                        countries: const {},
                        dateFormats: const {},
                      ),
                      fillHeight: true,
                    ),
                  ),
                  const Expanded(
                    flex: 10,
                    child: SizedBox(key: ValueKey('neighbour'), height: 520),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ChartCard)).height, 520);
    // A 2.4 aspect ratio at this width would be under 320; filling, the plot
    // takes what the card has left.
    expect(tester.getSize(find.byType(LineChart)).height, greaterThan(360));
  });

  testWidgets('fillHeight: beside a shorter card, the plot keeps its floor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo.chart.add(DashboardChartSeries.fromJson(seriesJson()));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 17,
                    child: ChartCard(
                      vm: vm,
                      formatter: Formatter(
                        settings: CompanyFormatSettings.fallback,
                        currencies: const {},
                        countries: const {},
                        dateFormats: const {},
                      ),
                      fillHeight: true,
                    ),
                  ),
                  const Expanded(flex: 10, child: SizedBox(height: 60)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(LineChart)).height,
      greaterThanOrEqualTo(kChartMinPlotHeight),
    );
  });

  // Asserts the getTooltipItems *contract*, not the painted tooltip. Driving
  // the real paint from a widget test was tried and abandoned: tests report
  // defaultTargetPlatform == android, where fl_chart treats FlTapUpEvent as
  // "not interested" and clears the tooltip (fl_touch_event.dart
  // isInterestedForInteractions → line_chart.dart _handleBuiltInTouch), and a
  // held pointer didn't produce a hit either — verified by truncating the
  // returned list, which left the paint-path assertion green while this
  // group's length check went red. An assertion that can't fail is worse than
  // none, so it's gone; these checks do catch a wrong-length or wrong-colour
  // list.
  testWidgets('builds one tooltip row per series, each in its own colour', (
    tester,
  ) async {
    await pump(tester);

    final chart = find.byType(LineChart);
    final data = tester.widget<LineChart>(chart).data;
    final spots = [
      for (var i = 0; i < data.lineBarsData.length; i++)
        LineBarSpot(data.lineBarsData[i], i, data.lineBarsData[i].spots.first),
    ];
    final items = data.lineTouchData.touchTooltipData.getTooltipItems(spots);
    expect(items.length, spots.length);
    for (var i = 0; i < items.length; i++) {
      expect(
        items[i]!.textStyle.color,
        data.lineBarsData[i].color,
        reason: 'row $i must carry its own series colour',
      );
    }
    // The first row leads with the bucket's date; every row names its series
    // (fl_chart re-sorts the rows by value on every move, so a coloured dot
    // was all that said which number was which) and carries its value on the
    // high-contrast surface colour.
    String flat(LineTooltipItem item) =>
        item.children!.map((c) => c.toPlainText()).join();
    expect(flat(items.first!), contains('2026-04-01'));
    expect(flat(items.first!), contains('Invoices'));
    expect(flat(items.first!), contains('400'));
    expect(flat(items[1]!), contains('Payments'));
    expect(flat(items[1]!), isNot(contains('2026-04-01')));
    expect(flat(items.last!), contains('Expenses'));
  });

  // `LineChart` is implicitly animated and restarts its tween whenever the new
  // `LineChartData` is not equal to the old — and that equality includes every
  // callback. The card rebuilds several times while the dashboard loads, so
  // callbacks minted in `build` meant a 250 ms tween per rebuild with nothing
  // different on screen.
  group('an unchanged rebuild', () {
    /// One rebuild, run to rest. fl_chart always animates the FIRST update
    /// after mount, whatever it is handed: its initial tween ends on the raw
    /// data, while every later target is that data with the axis bounds and
    /// the touch callback filled in, so the two never compare equal. Only
    /// from the second update on does equal data mean no tween — which is
    /// where these tests have to start.
    Future<void> firstUpdate(WidgetTester tester) async {
      rebuild.value++;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.binding.transientCallbackCount, 0, reason: 'settled');
    }

    testWidgets('does not restart the chart animation', (tester) async {
      await pump(tester);
      await firstUpdate(tester);
      final before = tester.widget<LineChart>(find.byType(LineChart)).data;

      rebuild.value++;
      await tester.pump();

      final after = tester.widget<LineChart>(find.byType(LineChart)).data;
      expect(after, isNot(same(before)), reason: 'the card did rebuild');
      expect(after, before, reason: 'and built equal chart data');
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'equal data starts no tween',
      );
    });

    // The control for the test above: the same sequence with one callback
    // built inline. If this ever stops animating, `transientCallbackCount == 0`
    // above proves nothing — fl_chart changed what it compares.
    testWidgets('re-animates when a callback is rebuilt inline (control)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 200,
            child: ValueListenableBuilder<int>(
              valueListenable: rebuild,
              builder: (context, _, _) => LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(spots: const [FlSpot(0, 1), FlSpot(1, 2)]),
                  ],
                  gridData: FlGridData(
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(strokeWidth: 1),
                  ),
                ),
                duration: const Duration(milliseconds: 250),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await firstUpdate(tester);

      rebuild.value++;
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('still animates when the data really changed', (tester) async {
      await pump(tester);
      await firstUpdate(tester);

      vm.toggleChartSeries(ChartSeriesId.expenses);
      rebuild.value++;
      await tester.pump();

      expect(
        tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData,
        hasLength(3),
      );
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      // Past the tween and the view model's 500 ms persist debounce.
      await tester.pump(const Duration(milliseconds: 600));
    });
  });
}
