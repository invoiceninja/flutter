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
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/chart_card.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

/// #23 — the Revenue chart shows all four series by default, so the card has
/// to render four curves and a tooltip that identifies each of them.
void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    vm = DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
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

  Future<void> pump(WidgetTester tester) async {
    repo.chart.add(DashboardChartSeries.fromJson(seriesJson()));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: SizedBox(
            width: 800,
            child: ChartCard(
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
    // without the other.
    for (final label in ['Invoices', 'Payments', 'Outstanding', 'Expenses']) {
      expect(find.text(label), findsOneWidget, reason: '$label legend chip');
    }
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
    // The value rides in a child span so it keeps the high-contrast surface
    // colour against the dark tooltip fill.
    expect(items.first!.children!.single.text, contains('400'));
  });
}
