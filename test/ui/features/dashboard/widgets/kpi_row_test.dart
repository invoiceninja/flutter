import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/helpers/needs_attention.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_figures.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_row.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

/// The dashboard's figures: Outstanding (everything unpaid today) beside
/// Invoices · Payments · Expenses for the selected period.
///
/// What these tests hold in place:
///
/// * **Unknown is not zero.** The row this replaced formatted `amount ?? zero`,
///   so a figure that had not loaded — or could not be — read `$0.00`, which is
///   an answer.
/// * **Labels never bake in the range** (flutter#37 — "Paid this month" under a
///   quarter's figure).
/// * **Outstanding is not a period figure**: it reads its own section, carries
///   no trend, and a new date range does not blank it.
void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;

  final formatter = Formatter(
    settings: CompanyFormatSettings.fallback,
    // `money()` returns '' for a currency it cannot resolve, so the company
    // currency has to exist for a figure to render anything.
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
  );

  DashboardTotals totalsOf({
    String invoiced = '0',
    String paid = '0',
    String expenses = '0',
    String outstanding = '0',
    int unpaid = 0,
  }) => DashboardTotals.fromJson({
    'currencies': {'1': 'USD'},
    '1': {
      'invoices': {'invoiced_amount': invoiced, 'code': 'USD'},
      'revenue': {'paid_to_date': paid, 'code': 'USD'},
      'expenses': {'amount': expenses, 'code': 'USD'},
      'outstanding': {
        'amount': outstanding,
        'outstanding_count': unpaid,
        'code': 'USD',
      },
    },
  });

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
      // A range change schedules a debounced nav_state write; the default
      // 500 ms outlives the pump and trips "a Timer is still pending".
      persistDebounce: const Duration(milliseconds: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  /// The default 800 px test surface would clamp every width asked for below.
  void wideSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  int outstandingTaps = 0;
  int invoicesTaps = 0;
  int paidTaps = 0;
  setUp(() {
    outstandingTaps = 0;
    invoicesTaps = 0;
    paidTaps = 0;
  });

  /// `theme: buildInTheme(...)` is mandatory — `context.inTheme` null-checks
  /// without it. The figures land on per-section notifiers, so the host
  /// listens to those like the screen does.
  Future<void> pumpRow(
    WidgetTester tester, {
    double width = 1400,
    bool showExpenses = true,
    AttentionCount? pastDueCount,
  }) async {
    wideSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ListenableBuilder(
                listenable: Listenable.merge([vm, vm.kpiListenable]),
                builder: (context, _) => KpiRow(
                  vm: vm,
                  formatter: formatter,
                  showExpenses: showExpenses,
                  pastDueCount: pastDueCount,
                  onOutstandingTap: () => outstandingTaps++,
                  onInvoicesTap: () => invoicesTaps++,
                  onPaidTap: () => paidTaps++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Explicit durations, never pumpAndSettle — the VM holds a live watch
    // subscription per section.
    await tester.pump(const Duration(milliseconds: 10));
  }

  Future<void> land(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 10));

  group('unknown is not zero', () {
    testWidgets('before anything loads, no figure shows an amount', (
      tester,
    ) async {
      await pumpRow(tester);

      expect(find.byType(FigureSkeletonBar), findsNWidgets(4));
      expect(find.textContaining(r'$'), findsNothing);
      expect(find.byType(DeltaChip), findsNothing);
    });

    testWidgets('a failed fetch with nothing cached is a dash and a retry', (
      tester,
    ) async {
      repo.refreshAllErrors = {DashboardKind.totalsCurrent: Exception('x')};
      await vm.refresh();
      await pumpRow(tester);

      // The three period figures failed together and share one retry.
      expect(find.text('—'), findsNWidgets(3));
      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('a failed refresh over cached figures keeps them, marked', (
      tester,
    ) async {
      repo.totals.add(totalsOf(invoiced: '1200', paid: '900', expenses: '50'));
      // `pump`, never `Future.delayed`: a real delay never elapses inside
      // `testWidgets`' fake clock.
      await tester.pump(const Duration(milliseconds: 10));
      repo.refreshAllErrors = {DashboardKind.totalsCurrent: Exception('x')};
      await vm.refresh();
      await pumpRow(tester);

      expect(find.text(r'$1,200.00'), findsOneWidget);
      expect(find.byIcon(Icons.sync_problem), findsOneWidget);
      expect(find.text('—'), findsNothing);
    });

    testWidgets('a loaded zero is a zero', (tester) async {
      repo.totals.add(totalsOf());
      await pumpRow(tester);
      await land(tester);

      expect(find.text(r'$0.00'), findsNWidgets(3));
    });
  });

  group('the period figures', () {
    testWidgets('are Invoices, Payments and Expenses, whatever the range', (
      tester,
    ) async {
      repo.totals.add(totalsOf(invoiced: '1200', paid: '900', expenses: '50'));
      await pumpRow(tester);
      await land(tester);

      for (final label in ['INVOICES', 'PAYMENTS', 'EXPENSES']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text(r'$1,200.00'), findsOneWidget);
      expect(find.text(r'$900.00'), findsOneWidget);
      expect(find.text(r'$50.00'), findsOneWidget);

      await vm.setDateRange(
        const DashboardPresetRange(DashboardDatePreset.lastQuarter),
      );
      await land(tester);
      // The window is named once, in the row above the figures; a label that
      // baked it in could disagree with the number beneath it.
      expect(
        find.textContaining(RegExp('month|quarter', caseSensitive: false)),
        findsNothing,
      );
      for (final label in ['INVOICES', 'PAYMENTS', 'EXPENSES']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('Expenses is left out with the module off', (tester) async {
      repo.totals.add(totalsOf(invoiced: '1200', paid: '900', expenses: '50'));
      await pumpRow(tester, showExpenses: false);
      await land(tester);

      expect(find.text('EXPENSES'), findsNothing);
      expect(find.text(r'$50.00'), findsNothing);
    });

    testWidgets('a trend is drawn only with something to compare against', (
      tester,
    ) async {
      repo.totals.add(totalsOf(invoiced: '1200', paid: '900', expenses: '50'));
      await pumpRow(tester);
      await land(tester);
      expect(find.byType(DeltaChip), findsNothing);

      repo.totalsPrev.add(
        totalsOf(invoiced: '600', paid: '900', expenses: '100'),
      );
      await land(tester);
      expect(find.byType(DeltaChip), findsNWidgets(3));
    });

    testWidgets('Invoices and Payments open their lists; Expenses does not', (
      tester,
    ) async {
      repo.totals.add(totalsOf(invoiced: '1200', paid: '900', expenses: '50'));
      await pumpRow(tester);
      await land(tester);

      await tester.tap(find.text('INVOICES'));
      await tester.tap(find.text('PAYMENTS'));
      await tester.tap(find.text('EXPENSES'));
      await land(tester);

      expect(invoicesTaps, 1);
      expect(paidTaps, 1);
      // No chevron either: the expenses list has no date filter to show.
      expect(
        find.descendant(
          of: find.byType(PeriodFiguresCard),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('a figure that has not loaded is not a link', (tester) async {
      await pumpRow(tester);

      await tester.tap(find.text('INVOICES'));
      await land(tester);

      expect(invoicesTaps, 0);
    });
  });

  group('Outstanding', () {
    testWidgets('reads its own section, not the period totals', (tester) async {
      // The period's own "outstanding" is what invoices dated in the range
      // still owe; the card must not show it.
      repo.totals.add(totalsOf(outstanding: '300', unpaid: 1));
      repo.outstanding.add(totalsOf(outstanding: '12400', unpaid: 9));
      await pumpRow(tester, pastDueCount: const AttentionCount(4, exact: true));
      await land(tester);

      final card = find.byType(OutstandingFigureCard);
      expect(
        find.descendant(of: card, matching: find.text(r'$12,400.00')),
        findsOneWidget,
      );
      expect(find.text(r'$300.00'), findsNothing);
      expect(
        find.descendant(of: card, matching: find.text('9 unpaid · 4 past due')),
        findsOneWidget,
      );
      // A balance, not a flow: nothing to compare it with.
      expect(
        find.descendant(of: card, matching: find.byType(DeltaChip)),
        findsNothing,
      );
    });

    testWidgets('names no past-due count it does not have', (tester) async {
      repo.outstanding.add(totalsOf(outstanding: '12400', unpaid: 9));
      await pumpRow(tester);
      await land(tester);

      expect(find.text('9 unpaid'), findsOneWidget);
      expect(find.textContaining('past due'), findsNothing);
    });

    testWidgets('survives a new date range', (tester) async {
      repo.totals.add(totalsOf(invoiced: '1200'));
      repo.outstanding.add(totalsOf(outstanding: '12400', unpaid: 9));
      await pumpRow(tester);
      await land(tester);

      await vm.setDateRange(
        const DashboardPresetRange(DashboardDatePreset.lastQuarter),
      );
      await land(tester);

      // The period figures start over; the balance as of today does not.
      expect(find.text(r'$12,400.00'), findsOneWidget);
      expect(find.text(r'$1,200.00'), findsNothing);
    });

    testWidgets('opens the unpaid list', (tester) async {
      repo.outstanding.add(totalsOf(outstanding: '12400', unpaid: 9));
      await pumpRow(tester);
      await land(tester);

      await tester.tap(find.text('OUTSTANDING'));
      await land(tester);

      expect(outstandingTaps, 1);
    });
  });

  group('layout', () {
    double bottomOf(WidgetTester tester, Type type) =>
        tester.getBottomLeft(find.byType(type)).dy;
    double topOf(WidgetTester tester, Type type) =>
        tester.getTopLeft(find.byType(type)).dy;

    testWidgets('side by side, the two cards end on one line', (tester) async {
      repo.totals.add(totalsOf(invoiced: '1200', paid: '900', expenses: '50'));
      repo.outstanding.add(totalsOf(outstanding: '12400', unpaid: 9));
      await pumpRow(tester, width: 1000);
      await land(tester);

      expect(
        topOf(tester, OutstandingFigureCard),
        topOf(tester, PeriodFiguresCard),
      );
      expect(
        bottomOf(tester, OutstandingFigureCard),
        bottomOf(tester, PeriodFiguresCard),
      );
    });

    testWidgets('below the one-row width, Outstanding leads', (tester) async {
      repo.totals.add(totalsOf(invoiced: '1200', paid: '900', expenses: '50'));
      repo.outstanding.add(totalsOf(outstanding: '12400', unpaid: 9));
      await pumpRow(tester, width: kFiguresOneRowWidth - 1);
      await land(tester);

      expect(
        bottomOf(tester, OutstandingFigureCard),
        lessThan(topOf(tester, PeriodFiguresCard)),
      );
    });

    testWidgets('a large amount scales down; it is never cut off', (
      tester,
    ) async {
      repo.totals.add(
        totalsOf(
          invoiced: '123456789012.34',
          paid: '123456789012.34',
          expenses: '123456789012.34',
        ),
      );
      repo.outstanding.add(totalsOf(outstanding: '123456789012.34'));
      await pumpRow(tester, width: 900);
      await land(tester);

      expect(tester.takeException(), isNull);
      for (final text in tester.widgetList<Text>(
        find.text(r'$123,456,789,012.34'),
      )) {
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.softWrap, isFalse);
      }
      expect(find.text(r'$123,456,789,012.34'), findsNWidgets(4));
    });

    testWidgets('holds at 140% text', (tester) async {
      repo.totals.add(totalsOf(invoiced: '1200', paid: '900', expenses: '50'));
      repo.totalsPrev.add(
        totalsOf(invoiced: '600', paid: '450', expenses: '9'),
      );
      repo.outstanding.add(totalsOf(outstanding: '12400', unpaid: 9));
      wideSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.4)),
            child: child!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 900,
                child: ListenableBuilder(
                  listenable: Listenable.merge([vm, vm.kpiListenable]),
                  builder: (context, _) => KpiRow(
                    vm: vm,
                    formatter: formatter,
                    pastDueCount: const AttentionCount(4, exact: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await land(tester);

      expect(tester.takeException(), isNull);
      // A caption shrinks to fit, like the figure under it: "INVOI…" over a
      // number does not say what the number is.
      for (final label in ['OUTSTANDING', 'INVOICES', 'PAYMENTS', 'EXPENSES']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.overflow, isNot(TextOverflow.ellipsis), reason: label);
        expect(
          find.ancestor(of: find.text(label), matching: find.byType(FittedBox)),
          findsWidgets,
          reason: label,
        );
      }
      // Nothing clipped: the caption under the figure is fully inside its card.
      final card = tester.getRect(find.byType(OutstandingFigureCard));
      final caption = tester.getRect(find.text('9 unpaid · 4 past due'));
      expect(caption.bottom, lessThan(card.bottom));
    });
  });
}
