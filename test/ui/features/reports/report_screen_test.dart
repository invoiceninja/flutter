import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/domain/schedule.dart';
import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/saved_views_repository.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_measures.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/reports/views/report_screen.dart';
import 'package:admin/ui/features/reports/views/reports_gallery_screen.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/ui/features/reports/widgets/charts/report_bar_list.dart';
import 'package:admin/ui/features/reports/widgets/report_document_view.dart';
import 'package:admin/ui/features/reports/widgets/report_states.dart';
import 'package:admin/ui/features/reports/widgets/report_summary_card.dart';

import '_report_screen_harness.dart';

ReportStringCell _text(String v) => ReportStringCell(value: v, displayValue: v);

/// Clients as the server answers them by default: no date column at all.
ReportPreview _clientsFixture({bool withCreatedAt = false}) => ReportPreview(
  columns: [
    reportTestColumn('client.name', 'Name'),
    reportTestColumn('client.balance', 'Balance'),
    reportTestColumn('client.paid_to_date', 'Paid to Date'),
    if (withCreatedAt) reportTestColumn('client.created_at', 'texts.'),
  ],
  rows: [
    for (var i = 0; i < 6; i++)
      ReportRow(
        cells: [
          _text('Client $i'),
          ReportNumberCell(
            value: Decimal.fromInt(100 * (i + 1)),
            isMoney: true,
          ),
          ReportNumberCell(value: Decimal.fromInt(10 * i), isMoney: true),
          if (withCreatedAt)
            ReportDateTimeCell(value: DateTime.utc(2026, 1 + i, 12, 12)),
        ],
      ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadReportTestFonts);

  group('the gallery', () {
    testWidgets('lists the reports by purpose, invoices first', (tester) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports',
      );
      expect(find.byType(ReportsGalleryScreen), findsOneWidget);
      final invoices = find.byKey(const Key('report-card-invoice'));
      final credits = find.byKey(const Key('report-card-credit'));
      expect(invoices, findsOneWidget);
      expect(credits, findsOneWidget);
      // A page a person scans, not a lookup table: the registry's own order
      // put Credits ahead of Invoices.
      final a = tester.getTopLeft(invoices);
      final b = tester.getTopLeft(credits);
      expect(a.dy < b.dy || (a.dy == b.dy && a.dx < b.dx), isTrue);
      // Named as the lists they are.
      expect(
        find.descendant(of: invoices, matching: find.text('Invoices')),
        findsOneWidget,
      );
    }, variant: kDesktop);

    testWidgets('search narrows it, and says so when nothing matches', (
      tester,
    ) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports',
      );
      await tester.enterText(
        find.byKey(const Key('reports-gallery-search')),
        'quote',
      );
      await tester.pump();
      expect(find.byKey(const Key('report-card-quote')), findsOneWidget);
      expect(find.byKey(const Key('report-card-invoice')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('reports-gallery-search')),
        'zzzz',
      );
      await tester.pump();
      expect(find.text('No report matches that search.'), findsOneWidget);
    }, variant: kDesktop);

    testWidgets('a starter view lands on the report already cut that way', (
      tester,
    ) async {
      final h = await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports',
      );
      final card = find.byKey(const Key('report-card-invoice'));
      await tester.tap(
        find.descendant(of: card, matching: find.text('By Client')),
      );
      await settleReports(tester);

      expect(find.byType(ReportScreen), findsOneWidget);
      expect(h.vm.reportIdentifier, 'invoice');
      expect(h.vm.group, 'client.name');
      // Applied once, on arrival — not left on the address to be applied
      // again over whatever the reader does next.
      expect(
        h.router.routerDelegate.currentConfiguration.uri.toString(),
        '/reports/invoice',
      );
    }, variant: kDesktop);

    testWidgets('fits a phone', (tester) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports',
        size: const Size(380, 800),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('report-card-invoice')), findsOneWidget);
    }, variant: kPhone);
  });

  group('opening a report', () {
    testWidgets('runs it — there is no Run to press', (tester) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      expect(h.repo.requests, isNotEmpty);
      expect(find.byKey(const Key('report-row-search')), findsOneWidget);
      expect(find.byType(ReportSummaryCard), findsOneWidget);
      // Opens on its first starter view: by month.
      expect(h.vm.group, 'invoice.date');
      expect(h.vm.subgroup, ReportSubgroup.month);
    }, variant: kDesktop);

    testWidgets('refresh runs it again', (tester) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      final before = h.repo.requests.length;
      await tester.tap(find.byKey(const Key('report-refresh')));
      await settleReports(tester);
      expect(h.repo.requests.length, greaterThan(before));
    }, variant: kDesktop);

    testWidgets(
      'a failed refresh keeps the result and says what happened',
      (tester) async {
        final h = await pumpReports(tester, preview: invoiceReportFixture());
        h.repo.error = const ReportError(
          kind: ReportErrorKind.serverError,
          message: '',
        );
        await tester.tap(find.byKey(const Key('report-refresh')));
        await settleReports(tester);

        // The figures are still there…
        expect(find.byType(ReportSummaryCard), findsOneWidget);
        // …under a notice that offers the way forward, and never a blank
        // message: the server's was `""`.
        expect(find.byType(ReportNotice), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.textContaining('An error occurred'), findsOneWidget);
      },
      variant: kDesktop,
    );

    testWidgets('a report the server only makes as a file says so', (
      tester,
    ) async {
      final h = await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports/tax_period_report',
      );
      expect(h.repo.requests, isEmpty, reason: 'there is no preview to run');
      expect(find.textContaining('produced as a file'), findsOneWidget);
      expect(find.text('Export'), findsWidgets);
    }, variant: kDesktop);
  });

  testWidgets('activity: a date the server wrote as display text is shown '
      'as written, not as an unreadable date', (tester) async {
    final preview = ReportPreview(
      columns: [
        reportTestColumn('date', 'Date'),
        reportTestColumn('activity', 'Activity'),
        reportTestColumn('address', 'Address'),
      ],
      rows: [
        for (var i = 0; i < 3; i++)
          ReportRow(
            cells: [
              // What the decoder makes of `08/Oct/2026` under a column it
              // took for a date: no value, only the text.
              const ReportDateCell(value: null, displayValue: '08/Oct/2026'),
              _text('Someone updated invoice 000$i'),
              _text('127.0.0.1'),
            ],
          ),
      ],
    );
    expect(preview.columns.first.type, ReportColumnType.date);
    final h = await pumpReports(
      tester,
      preview: preview,
      location: '/reports/activity',
    );
    expect(h.vm.run.preview!.columns.first.type, ReportColumnType.string);
    expect(find.text('08/Oct/2026'), findsNWidgets(3));
    expect(find.text('Someone updated invoice 0001'), findsOneWidget);
    // Three text columns: nothing to chart, and no crash for it.
    expect(tester.takeException(), isNull);
  }, variant: kDesktop);

  group('a report the server only writes as a file', () {
    testWidgets('is read back and shown, with what the file lacks', (
      tester,
    ) async {
      final h = await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports/aged_receivable_summary_report',
        configure: (repo) => repo.exportCsv = reportFileFixture('ar_summary'),
      );
      expect(h.repo.exports, 1);
      expect(h.repo.requests, isEmpty, reason: 'it has no JSON preview');
      expect(find.byType(ReportDocumentView), findsOneWidget);
      // The server's own lines…
      expect(find.text('Bradtke, Vandervort and Rodriguez'), findsOneWidget);
      // …a total under each column of amounts, which the file does not
      // carry, in that table's own currency…
      expect(find.text('£17,358.00'), findsWidgets);
      expect(find.text('€4.926,00'), findsWidgets);
      // …and the spread across how late it is, bucket by bucket in words.
      expect(find.text('Current'), findsWidgets);
      expect(find.text('120+ Days'), findsWidgets);
    }, variant: kDesktop);

    testWidgets('refresh fetches the file again', (tester) async {
      final h = await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports/profitloss',
        configure: (repo) =>
            repo.exportCsv = reportFileFixture('profit_and_loss'),
      );
      expect(find.text('Total Profit'), findsOneWidget);
      expect(find.text(r'$70,109.10'), findsOneWidget);
      final before = h.repo.exports;
      await tester.tap(find.byKey(const Key('report-refresh')));
      await settleReports(tester);
      expect(h.repo.exports, before + 1);
    }, variant: kDesktop);

    testWidgets('a file that cannot be read falls back to the download', (
      tester,
    ) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports/client_sales_report',
        configure: (repo) =>
            repo.exportCsv = '<html><body>Server Error</body></html>',
      );
      expect(find.byType(ReportDocumentView), findsNothing);
      expect(find.textContaining('produced as a file'), findsOneWidget);
    }, variant: kDesktop);

    testWidgets('a file in a format it does not read falls back too', (
      tester,
    ) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports/client_sales_report',
        configure: (repo) => repo
          ..exportCsv = reportFileFixture('client_sales')
          ..exportFormat = ReportExportFormat.xlsx,
      );
      expect(find.byType(ReportDocumentView), findsNothing);
      expect(find.textContaining('produced as a file'), findsOneWidget);
    }, variant: kDesktop);

    testWidgets('one the server emailed instead says so, and is not asked '
        'for again behind the reader\'s back', (tester) async {
      final h = await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports/tax_summary_report',
        configure: (repo) => repo.error = const ReportError(
          kind: ReportErrorKind.emailedInstead,
        ),
      );
      expect(h.repo.exports, 1);
      expect(find.textContaining('by email'), findsOneWidget);
      // Each retry would be another email.
      expect(find.text('Retry'), findsNothing);

      // Away and back: the same request is not made again on its own…
      h.router.go('/reports');
      await settleReports(tester);
      h.router.go('/reports/tax_summary_report');
      await settleReports(tester);
      expect(h.repo.exports, 1);

      // …but the reader asking is the reader asking.
      await tester.tap(find.byKey(const Key('report-refresh')));
      await settleReports(tester);
      expect(h.repo.exports, 2);
    }, variant: kDesktop);

    testWidgets('a failed fetch says so and offers the retry', (tester) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports/user_sales_report',
        // No file configured: the export fails.
      );
      expect(find.byType(ReportNotice), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    }, variant: kDesktop);

    for (final (id, file) in [
      ('aged_receivable_detailed_report', 'ar_detail'),
      ('client_balance_report', 'client_balance'),
      ('client_sales_report', 'client_sales'),
      ('tax_summary_report', 'tax_summary'),
      ('user_sales_report', 'user_sales'),
      ('product_sales', 'product_sales'),
      ('profitloss', 'profit_and_loss'),
    ]) {
      testWidgets('$id draws on a phone and on a desktop', (tester) async {
        for (final size in const [Size(390, 800), Size(1280, 900)]) {
          await pumpReports(
            tester,
            preview: invoiceReportFixture(),
            location: '/reports/$id',
            size: size,
            configure: (repo) => repo.exportCsv = reportFileFixture(file),
          );
          expect(find.byType(ReportDocumentView), findsOneWidget);
          expect(tester.takeException(), isNull, reason: '$id at $size');
        }
      });
    }
  });

  group('a report that is already scheduled', () {
    Schedule emailReport(String id, String reportName) =>
        Schedule.empty().copyWith(
          id: id,
          template: kScheduleTemplateEmailReport,
          parameters: {'report_name': reportName},
        );

    testWidgets('says so, and leads to the schedule', (tester) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        services: (s) => s.schedules.held = [
          emailReport('s1', 'invoice'),
          // Another report's schedule is not this one's.
          emailReport('s2', 'quote'),
        ],
      );
      expect(find.byKey(const Key('report-scheduled')), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
    }, variant: kDesktop);

    testWidgets('and a report with none says nothing', (tester) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        services: (s) => s.schedules.held = [emailReport('s2', 'quote')],
      );
      expect(find.byKey(const Key('report-scheduled')), findsNothing);
    }, variant: kDesktop);
  });

  group('the control bar', () {
    testWidgets('names the column the date range filters', (tester) async {
      await pumpReports(tester, preview: invoiceReportFixture());
      expect(find.byKey(const Key('report-range')), findsOneWidget);
      expect(find.text('Filtered by Date'), findsOneWidget);
    }, variant: kDesktop);

    testWidgets('granularity is offered for a date grouping and a period '
        'split, and for nothing else', (tester) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      expect(find.byKey(const Key('report-granularity')), findsOneWidget);

      h.vm.groupBy('client.name');
      await tester.pump();
      expect(find.byKey(const Key('report-granularity')), findsNothing);
      // …where a split by period is offered instead, the range's own date
      // first.
      expect(find.byKey(const Key('report-split')), findsOneWidget);
      expect(h.vm.periodCandidates.first.identifier, 'invoice.date');

      h.vm.splitByPeriod('invoice.date');
      await tester.pump();
      expect(
        h.vm.subgroup,
        ReportSubgroup.month,
        reason:
            'a split starts '
            'by month',
      );
      expect(find.byKey(const Key('report-granularity')), findsOneWidget);

      h.vm.groupBy('');
      await tester.pump();
      expect(find.byKey(const Key('report-granularity')), findsNothing);
      expect(find.byKey(const Key('report-split')), findsNothing);
    }, variant: kDesktop);

    testWidgets('no split is offered when the result has no date and the '
        'report cannot fetch one', (tester) async {
      final preview = ReportPreview(
        columns: [
          reportTestColumn('invoice.number', 'Number'),
          reportTestColumn('invoice.status', 'Status'),
          reportTestColumn('invoice.amount', 'Amount'),
        ],
        rows: [
          for (var i = 0; i < 4; i++)
            ReportRow(
              cells: [
                _text('INV-$i'),
                _text(i.isEven ? 'Paid' : 'Sent'),
                ReportNumberCell(
                  value: Decimal.fromInt(100 + i),
                  isMoney: true,
                ),
              ],
            ),
        ],
      );
      final h = await pumpReports(tester, preview: preview);
      h.vm.groupBy('invoice.status');
      await tester.pump();
      expect(find.byKey(const Key('report-split')), findsNothing);
    }, variant: kDesktop);

    testWidgets(
      'the currency control appears only when there is a choice',
      (tester) async {
        await pumpReports(tester, preview: invoiceReportFixture());
        expect(find.byKey(const Key('report-currency')), findsNothing);
      },
      variant: kDesktop,
    );

    testWidgets(
      'with two currencies, figures are read in one and say which',
      (tester) async {
        final h = await pumpReports(
          tester,
          preview: invoiceReportFixture(twoCurrencies: true),
        );
        expect(find.byKey(const Key('report-currency')), findsOneWidget);
        // The company's own currency, not the first one met.
        final view = h.vm.buildView(companyCurrencyId: '1');
        expect(view.currencyId, '1');
        expect(reportCurrencies(view), ['1', '3']);
        expect(find.text('Total · USD'), findsOneWidget);
        // The count is of every row, whatever it is in — the same number the
        // table states.
        expect(find.text('214'), findsOneWidget);
        expect(find.text('214 rows'), findsOneWidget);
      },
      variant: kDesktop,
    );

    testWidgets('the date-created column is offered, and asking for it asks '
        'the server', (tester) async {
      final h = await pumpReports(
        tester,
        preview: _clientsFixture(),
        location: '/reports/client',
      );
      expect(h.vm.offerableDateColumnId, 'client.created_at');
      final before = h.repo.requests.length;

      await tester.tap(find.byKey(const Key('report-group-by')));
      await tester.pumpAndSettle();
      // Offered by the name the range is already known by, marked as
      // something that has to be fetched.
      final option = find.widgetWithText(ListTile, 'Date Created');
      expect(option, findsOneWidget);
      h.repo.preview = _clientsFixture(withCreatedAt: true);
      await tester.tap(option);
      await settleReports(tester);

      expect(h.repo.requests.length, greaterThan(before));
      expect(h.repo.requests.last, contains('client.created_at'));
      expect(h.vm.group, 'client.created_at');
      expect(h.vm.subgroup, ReportSubgroup.month);
      // Counting, not summing: "new clients per month" is a how-many.
      expect(defaultReportMeasureId(h.vm), kReportCountSeriesId);
    }, variant: kDesktop);
  });

  group('the summary', () {
    testWidgets('leads with the row count and the report\'s headlines; only '
        'figures are offered', (tester) async {
      await pumpReports(tester, preview: invoiceReportFixture());
      final card = find.byType(ReportSummaryCard);
      for (final label in ['INVOICES', 'AMOUNT', 'BALANCE', 'PAID TO DATE']) {
        expect(
          find.descendant(of: card, matching: find.text(label)),
          findsOneWidget,
          reason: label,
        );
      }
      // A status, a number and a date are not figures.
      for (final label in ['STATUS', 'NUMBER', 'DATE']) {
        expect(
          find.descendant(of: card, matching: find.text(label)),
          findsNothing,
          reason: label,
        );
      }
    }, variant: kDesktop);

    testWidgets('a figure is the chart\'s measure picker', (tester) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      expect(find.text('Amount by Month'), findsOneWidget);
      // The table has a BALANCE header too; this is the figure tab.
      await tester.tap(
        find.descendant(
          of: find.byType(ReportSummaryCard),
          matching: find.text('BALANCE'),
        ),
      );
      await tester.pump();
      expect(h.vm.chartColumn, 'invoice.balance');
      expect(find.text('Balance by Month'), findsOneWidget);
    }, variant: kDesktop);

    testWidgets('by date it is a trend, in order, with periods named — never '
        'raw keys', (tester) async {
      await pumpReports(tester, preview: invoiceReportFixture());
      expect(find.byType(BarChart), findsOneWidget);
      // Group lines and the peak caption are words…
      expect(find.text('January 2026'), findsOneWidget);
      expect(find.textContaining('2026-01-01'), findsNothing);
      // …and the axis is short enough to label every month, the year said
      // once.
      expect(find.text('Jan 2026'), findsOneWidget);
      expect(find.text('Feb'), findsOneWidget);
      final jan = tester.getCenter(find.text('January 2026')).dy;
      final feb = tester.getCenter(find.text('February 2026')).dy;
      expect(jan, lessThan(feb));
    }, variant: kDesktop);

    testWidgets(
      'by a category it is a ranking, and the table agrees with it',
      (tester) async {
        final h = await pumpReports(tester, preview: invoiceReportFixture());
        h.vm.groupBy('client.name');
        await tester.pump();
        expect(find.byType(BarChart), findsNothing);
        expect(find.byType(ReportBarList), findsOneWidget);
        expect(find.text('Amount by Client'), findsOneWidget);

        // The table is in the chart's order, as an ordinary sort the header
        // shows — not a second, alphabetical list of the same clients.
        expect(h.vm.sortField, 'invoice.amount');
        expect(h.vm.sortAscending, isFalse);
        final view = h.vm.buildView(companyCurrencyId: '1');
        final totals = [
          for (final g in view.groups) g.numericTotals['invoice.amount']!['1']!,
        ];
        expect(totals, [...totals]..sort((a, b) => b.compareTo(a)));

        // Back to months: the ranking goes, because months belong in order.
        h.vm.groupBy('invoice.date');
        await tester.pump();
        expect(h.vm.sortField, isNull);
      },
      variant: kDesktop,
    );

    testWidgets('a ranking the reader re-sorted is theirs to keep', (
      tester,
    ) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      h.vm.groupBy('client.name');
      h.vm.setSort('client.name');
      h.vm.groupBy('invoice.status');
      await tester.pump();
      expect(h.vm.sortField, 'client.name');
    }, variant: kDesktop);

    testWidgets(
      'ungrouped it still shows its largest rows, each told apart',
      (tester) async {
        final h = await pumpReports(tester, preview: invoiceReportFixture());
        h.vm.groupBy('');
        await tester.pump();
        expect(find.text('Top 10 by Amount'), findsOneWidget);
        // Client and number: ten invoices of one client are not ten identical
        // lines.
        expect(find.textContaining('Acme Industrial · INV-'), findsWidgets);
        // And the ways to cut it are one tap away.
        final card = find.byType(ReportSummaryCard);
        expect(
          find.descendant(of: card, matching: find.text('Client')),
          findsOneWidget,
        );
      },
      variant: kDesktop,
    );

    testWidgets('a figure that is zero throughout says so in the chart\'s '
        'place', (tester) async {
      final preview = ReportPreview(
        columns: [
          reportTestColumn('client.name', 'Client'),
          reportTestColumn('invoice.amount', 'Amount'),
        ],
        rows: [
          for (var i = 0; i < 3; i++)
            ReportRow(
              cells: [
                _text('Client $i'),
                ReportNumberCell(value: Decimal.zero, isMoney: true),
              ],
            ),
        ],
      );
      final h = await pumpReports(tester, preview: preview);
      h.vm.groupBy('client.name');
      await tester.pump();
      expect(find.byType(BarChart), findsNothing);
      expect(find.byType(ReportBarList), findsNothing);
      expect(
        find.text('No numeric values to chart — pick a different column.'),
        findsOneWidget,
      );
    }, variant: kDesktop);
  });

  group('compared with the period before', () {
    DateTime october8() => DateTime(2026, 10, 8, 12);

    testWidgets('it asks for the same span of the period before — like with '
        'like, not a part-year against a whole one', (tester) async {
      final h = await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        now: october8,
        configure: (repo) =>
            repo.comparePreview = invoiceReportFixture(year: 2025, rows: 150),
      );
      expect(find.byKey(const Key('report-compare')), findsOneWidget);
      expect(h.repo.compareRequests, isEmpty, reason: 'it is opt-in');

      await tester.tap(find.byKey(const Key('report-compare')));
      await settleReports(tester);

      expect(h.vm.compare, isTrue);
      final asked = h.repo.compareRequests.single;
      // "This year" on 8 October is compared with last year to 8 October.
      expect(asked.startDate?.toIso(), '2025-01-01');
      expect(asked.endDate?.toIso(), '2025-10-08');
      // Every figure says how it moved…
      expect(
        find.descendant(
          of: find.byType(ReportSummaryCard),
          matching: find.byType(DeltaChip),
        ),
        findsNWidgets(4),
      );
      // …and the chart names the two things it now draws.
      expect(find.textContaining('Previous Period'), findsWidgets);
    }, variant: kDesktop);

    testWidgets('a ranking says how each line moved', (tester) async {
      final h = await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        now: october8,
        configure: (repo) =>
            repo.comparePreview = invoiceReportFixture(year: 2025, rows: 150),
      );
      h.vm.groupBy('client.name');
      h.vm.setCompare(true);
      await settleReports(tester);
      expect(
        find.descendant(
          of: find.byType(ReportBarList),
          matching: find.byType(DeltaChip),
        ),
        findsWidgets,
      );
    }, variant: kDesktop);

    testWidgets('there is nothing before "all time" to compare with', (
      tester,
    ) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      h.vm.setPayload(
        h.vm.payload.copyWith(datePreset: ReportDatePreset.allTime),
      );
      await settleReports(tester);
      expect(h.vm.canCompare, isFalse);
      expect(find.byKey(const Key('report-compare')), findsNothing);
    }, variant: kDesktop);

    testWidgets('turning it off takes the comparison away', (tester) async {
      final h = await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        now: october8,
        configure: (repo) =>
            repo.comparePreview = invoiceReportFixture(year: 2025, rows: 150),
      );
      h.vm.setCompare(true);
      await settleReports(tester);
      expect(find.byType(DeltaChip), findsWidgets);
      h.vm.setCompare(false);
      await tester.pump();
      expect(find.byType(DeltaChip), findsNothing);
    }, variant: kDesktop);
  });

  group('saved views', () {
    testWidgets('the report as it stands can be saved under a name, and '
        'opened that way again', (tester) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      h.vm.groupBy('client.name');
      h.vm.setChartColumn('invoice.balance');
      await tester.pump();

      await tester.tap(find.byKey(const Key('report-views')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('report-save-view')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('report-view-name')),
        'Owed by client',
      );
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      final services = reportTestServicesOf(
        tester.element(find.byType(ReportScreen)),
      );
      final saved = services.savedViews.views.single;
      expect(saved.name, 'Owed by client');
      expect(saved.reportIdentifier, 'invoice');
      expect(h.vm.viewId, saved.id);
      // Not yet changed since it was saved.
      expect(find.byKey(const Key('report-view-changed')), findsNothing);

      // Change it: the button says so, without nagging.
      h.vm.groupBy('invoice.status');
      await tester.pump();
      expect(find.byKey(const Key('report-view-changed')), findsOneWidget);

      // And picking the view puts it back.
      await tester.tap(find.byKey(const Key('report-views')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Owed by client'));
      await settleReports(tester);
      expect(h.vm.group, 'client.name');
      expect(h.vm.chartColumn, 'invoice.balance');
      expect(find.byKey(const Key('report-view-changed')), findsNothing);
    }, variant: kDesktop);

    testWidgets('they are listed in the gallery and open the report already '
        'arranged', (tester) async {
      late final FakeReportServices services;
      final h = await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        location: '/reports',
        services: (s) {
          services = s;
          s.savedViews.views.add(
            const SavedReportView(
              id: 'v1',
              name: 'Unpaid by client',
              reportIdentifier: 'invoice',
              state: {'group': 'client.name', 'chartColumn': 'invoice.balance'},
              updatedAt: 0,
            ),
          );
        },
      );
      expect(services.savedViews.views, hasLength(1));
      final entry = find.byKey(const Key('report-saved-view-v1'));
      expect(entry, findsOneWidget);
      expect(find.textContaining('Unpaid by client'), findsOneWidget);

      await tester.tap(entry);
      await settleReports(tester);
      expect(find.byType(ReportScreen), findsOneWidget);
      expect(h.vm.reportIdentifier, 'invoice');
      expect(h.vm.group, 'client.name');
      expect(h.vm.chartColumn, 'invoice.balance');
      expect(h.vm.viewId, 'v1');
      // Applied once; not left on the address.
      expect(
        h.router.routerDelegate.currentConfiguration.uri.toString(),
        '/reports/invoice',
      );
    }, variant: kDesktop);

    testWidgets('a view of another report is not offered on this one', (
      tester,
    ) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        services: (s) => s.savedViews.views.add(
          const SavedReportView(
            id: 'q1',
            name: 'Quotes by month',
            reportIdentifier: 'quote',
            state: {},
            updatedAt: 0,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('report-views')));
      await tester.pumpAndSettle();
      expect(find.text('Quotes by month'), findsNothing);
      expect(find.byKey(const Key('report-save-view')), findsOneWidget);
    }, variant: kDesktop);
  });

  group('the table', () {
    testWidgets('each cell sits under its own header, whatever the order', (
      tester,
    ) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      h.vm.groupBy('');
      h.vm.setVisibleColumns(
        {'client.name', 'invoice.number', 'invoice.status'},
        order: ['invoice.status', 'client.name', 'invoice.number'],
      );
      await tester.pump();
      double left(Finder f) => tester.getTopLeft(f.first).dx;
      // Cells keep the server's order; only the columns moved. A cell read
      // by position would put the client under STATUS.
      expect(
        left(find.text('INV-1000')),
        closeTo(left(find.text('NUMBER')), 1),
      );
      expect(
        left(find.text('Acme Industrial')),
        closeTo(left(find.text('CLIENT')), 1),
      );
    }, variant: kDesktop);

    testWidgets('a row opens its record', (tester) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      h.vm.groupBy('');
      await tester.pump();
      await tester.tap(find.text('INV-1000'));
      await tester.pumpAndSettle();
      expect(find.text('record /invoices/i0'), findsOneWidget);
    }, variant: kDesktop);

    testWidgets('searching rows narrows them and counts what is left', (
      tester,
    ) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      h.vm.groupBy('');
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('report-row-search')),
        'INV-1000',
      );
      await tester.pump();
      expect(h.vm.search, 'INV-1000');
      expect(find.text('1 of 214 rows'), findsOneWidget);
    }, variant: kDesktop);

    testWidgets('a column filter is a chip, and a chip comes off', (
      tester,
    ) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      h.vm.setColumnFilter('invoice.status', reportOneOfFilter(['Paid']));
      await tester.pump();
      expect(find.text('Status: Paid'), findsOneWidget);
      expect(find.byKey(const Key('report-clear-filters')), findsOneWidget);

      await tester.tap(find.byKey(const Key('report-clear-filters')));
      // Clearing also resets the server filters, which is a run.
      await settleReports(tester);
      expect(h.vm.columnFilters, isEmpty);
      expect(find.text('Status: Paid'), findsNothing);
    }, variant: kDesktop);

    testWidgets('filters that leave nothing offer the way back', (
      tester,
    ) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      h.vm.setSearch('no such invoice');
      await tester.pump();
      expect(find.textContaining('No rows match'), findsOneWidget);
      await tester.tap(find.text('Clear Filters'));
      await tester.pump();
      expect(h.vm.search, isEmpty);
    }, variant: kDesktop);

    testWidgets('a client billed only in euros shows euros, not a blank', (
      tester,
    ) async {
      final h = await pumpReports(
        tester,
        preview: invoiceReportFixture(twoCurrencies: true),
        size: const Size(1200, 1600),
      );
      h.vm.groupBy('client.name');
      await tester.pump();
      final view = h.vm.buildView(companyCurrencyId: '1');
      final euro = view.groups.firstWhere(
        (g) => g.numericTotals['invoice.amount']!.keys.single == '3',
      );
      // Ranked after every dollar client: €53,000 is not "between" $65,000
      // and $50,000.
      final firstEuro = view.groups.indexOf(euro);
      expect(
        view.groups
            .skip(firstEuro)
            .every((g) => !g.numericTotals['invoice.amount']!.containsKey('1')),
        isTrue,
      );
      // And its own line carries its own total, in its own notation.
      final amount = euro.numericTotals['invoice.amount']!['3']!;
      expect(amount > Decimal.zero, isTrue);
      expect(find.textContaining('€'), findsWidgets);
    }, variant: kDesktop);
  });

  group('the keyboard', () {
    testWidgets('`/` is aimed at the row search', (tester) async {
      await pumpReports(tester, preview: invoiceReportFixture());
      final context = tester.element(find.byType(ReportScreen));
      final registry = reportTestServicesOf(context).searchFocus;
      final field = tester.widget<TextField>(
        find.byKey(const Key('report-row-search')),
      );
      expect(registry.current, same(field.focusNode));
    }, variant: kDesktop);

    testWidgets('R refreshes without a click first', (tester) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      final before = h.repo.requests.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
      await settleReports(tester);
      expect(h.repo.requests.length, greaterThan(before));
    }, variant: kDesktop);

    testWidgets('Esc steps back out of a drill', (tester) async {
      final h = await pumpReports(tester, preview: invoiceReportFixture());
      h.vm.setSelectedGroup('2026-03-01');
      await tester.pump();
      expect(find.text('Date: March 2026'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(h.vm.selectedGroup, isNull);
    }, variant: kDesktop);
  });

  group('it fits', () {
    for (final width in [420.0, 760.0, 1400.0]) {
      testWidgets('at $width px', (tester) async {
        final h = await pumpReports(
          tester,
          preview: invoiceReportFixture(twoCurrencies: true),
          size: Size(width, 900),
        );
        expect(tester.takeException(), isNull);
        h.vm.groupBy('client.name');
        h.vm.splitByPeriod('invoice.date');
        await tester.pump();
        expect(tester.takeException(), isNull);
        h.vm.groupBy('');
        await tester.pump();
        expect(tester.takeException(), isNull);
      }, variant: width < 600 ? kPhone : kDesktop);
    }

    testWidgets('at a phone width with large text, right to left', (
      tester,
    ) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        size: const Size(400, 860),
        textScale: 1.4,
        direction: TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    }, variant: kPhone);

    testWidgets('on a phone each group line carries its total', (tester) async {
      await pumpReports(
        tester,
        preview: invoiceReportFixture(),
        size: const Size(400, 1400),
      );
      // "January 2026 … $18,116.00" on one line, inside the pane.
      final label = find.text('January 2026');
      final total = find.text(r'$18,116.00');
      expect(label, findsOneWidget);
      expect(total, findsOneWidget);
      expect(
        tester.getCenter(total).dy,
        closeTo(tester.getCenter(label).dy, 2),
      );
      expect(tester.getTopRight(total).dx, lessThanOrEqualTo(400));
      // The range and the grouping are on the page, not behind an icon.
      expect(find.byKey(const Key('report-range')), findsOneWidget);
      expect(find.byKey(const Key('report-group-by')), findsOneWidget);
    }, variant: kPhone);
  });
}
