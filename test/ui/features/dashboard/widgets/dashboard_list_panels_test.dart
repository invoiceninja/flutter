import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_panel_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_record_row.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card_skeleton.dart';
import 'package:admin/ui/features/dashboard/widgets/recent_payments_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_invoices_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_quotes_card.dart';
import 'package:admin/ui/features/dashboard/widgets/upcoming_recurring_invoices_card.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

const _today = Date(2026, 10, 14);

final _formatter = Formatter(
  settings: CompanyFormatSettings.fallback,
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

DashboardInvoiceRow _inv(String id, {Date? due, String balance = '100'}) =>
    DashboardInvoiceRow(
      id: id,
      number: id,
      clientId: 'c',
      clientName: 'Acme',
      dueDate: due,
      balance: Decimal.parse(balance),
      amount: Decimal.parse('999'),
      statusId: 2,
      currencyId: '',
    );

DashboardQuoteRow _quote(String id, {Date? validUntil}) => DashboardQuoteRow(
  id: id,
  number: id,
  clientId: 'c',
  clientName: 'Quote Co',
  date: const Date(2026, 9, 1),
  validUntil: validUntil,
  amount: Decimal.fromInt(50),
  statusId: 2,
  currencyId: '',
);

DashboardPaymentRow _payment(String id, {int status = 4}) =>
    DashboardPaymentRow(
      id: id,
      number: id,
      clientId: 'c',
      clientName: 'Payer',
      date: const Date(2026, 10, 9),
      amount: Decimal.fromInt(75),
      statusId: status,
      currencyId: '',
    );

/// The dashboard's list panels. They were six-column tables in which every
/// cell was its own tap target, the columns could not shrink into a half-width
/// card, and the last column was a `⋮` that opened no menu. Each row is now
/// one target — `number · client | when | amount | action` — drawn by the row
/// the needs-attention band uses.
void main() {
  Future<void> pumpCard(
    WidgetTester tester,
    Widget card, {
    double width = 520,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(body: SingleChildScrollView(child: card)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  Finder richText(String text) => find.textContaining(text, findRichText: true);

  group('Upcoming Invoices', () {
    UpcomingInvoicesCard card(
      List<DashboardInvoiceRow> rows, {
      int? total,
      bool compact = false,
      List<String>? opened,
      List<String>? paid,
      VoidCallback? onViewAll,
      Set<String> noPay = const {},
    }) => UpcomingInvoicesCard(
      section: AsyncSection.ready(DashboardRows(rows, total: total)),
      formatter: _formatter,
      today: _today,
      compact: compact,
      onInvoiceTap: (r) => opened?.add(r.id),
      onViewAll: onViewAll ?? () {},
      onRetry: () {},
      enterPayment: paid == null
          ? null
          : (r) => noPay.contains(r.id) ? null : () async => paid.add(r.id),
    );

    testWidgets('a row says when it falls due and what is still owed', (
      tester,
    ) async {
      await pumpCard(
        tester,
        card([
          _inv('0050', due: const Date(2026, 10, 17), balance: '80'),
          _inv('0051', due: _today),
        ]),
      );

      expect(richText('0050 · Acme'), findsOneWidget);
      expect(richText('due in 3 days'), findsOneWidget);
      expect(richText('due today'), findsOneWidget);
      // The balance, not the invoice's original amount: the column used to be
      // headed "Amount" over the balance.
      expect(find.text(r'$80.00'), findsOneWidget);
      expect(find.text(r'$999.00'), findsNothing);
    });

    // The server's "upcoming" includes a sent invoice with no due date at
    // all — every one of the demo account's is. A bare dash in an unlabelled
    // slot is a mark with no meaning; this one says what is true.
    testWidgets('an invoice with no due date says so in words', (tester) async {
      await pumpCard(tester, card([_inv('0052')]));

      expect(richText('No due date set'), findsOneWidget);
      expect(richText('—'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the row opens the record; Payment is a button on it', (
      tester,
    ) async {
      final opened = <String>[];
      final paid = <String>[];
      await pumpCard(
        tester,
        card(
          [_inv('0050', due: const Date(2026, 10, 17))],
          opened: opened,
          paid: paid,
        ),
      );

      await tester.tap(richText('0050 · Acme'));
      expect(opened, ['0050']);

      await tester.tap(find.byTooltip('Enter Payment'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(paid, ['0050']);
      expect(opened, ['0050'], reason: 'the button must not open the row');
    });

    testWidgets('no fake menu: with no action offered there is no button', (
      tester,
    ) async {
      await pumpCard(
        tester,
        card([_inv('0050', due: const Date(2026, 10, 17))]),
      );

      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(find.byIcon(Icons.more_horiz), findsNothing);
    });

    testWidgets('View all carries the server\'s count, not the page\'s', (
      tester,
    ) async {
      var taps = 0;
      await pumpCard(
        tester,
        card(
          [
            for (var i = 0; i < 8; i++)
              _inv('${100 + i}', due: const Date(2026, 10, 20)),
          ],
          total: 37,
          onViewAll: () => taps++,
        ),
      );

      // Five rows of the eight in hand, of the thirty-seven there are.
      expect(find.byType(DashboardRecordRow), findsNWidgets(5));
      await tester.tap(find.text('View All (37)'));
      expect(taps, 1);
    });

    testWidgets('with no total known the link claims no count', (tester) async {
      await pumpCard(
        tester,
        card([_inv('0050', due: const Date(2026, 10, 17))]),
      );

      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('compact stacks the row and still fits a phone', (
      tester,
    ) async {
      final paid = <String>[];
      await pumpCard(
        tester,
        card(
          [_inv('0050', due: const Date(2026, 10, 17), balance: '1234567.89')],
          compact: true,
          paid: paid,
        ),
        width: 320,
      );

      expect(tester.takeException(), isNull);
      // Two lines: the "when" sits under the identity, not beside it.
      expect(
        tester.getTopLeft(richText('due in 3 days')).dy,
        greaterThan(tester.getTopLeft(richText('0050 · Acme')).dy),
      );
    });
  });

  // Two panels sit side by side, and a row with a button must not be taller
  // than one without, or their rows drift out of step down the pair. Measured
  // on a pointer platform and on touch — the button's size differs.
  for (final platform in const [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets('a row with an action is as tall as one without ($platform)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        final row = _inv('0050', due: const Date(2026, 10, 17));
        UpcomingInvoicesCard card({required bool action}) =>
            UpcomingInvoicesCard(
              section: AsyncSection.ready([row]),
              formatter: _formatter,
              today: _today,
              compact: false,
              onInvoiceTap: (_) {},
              onViewAll: () {},
              onRetry: () {},
              enterPayment: action ? (r) => () async {} : null,
            );

        await pumpCard(tester, card(action: false));
        final plain = tester.getSize(find.byType(DashboardRecordRow)).height;
        await pumpCard(tester, card(action: true));
        final withButton = tester
            .getSize(find.byType(DashboardRecordRow))
            .height;

        expect(withButton, plain);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  // The form the needs-attention band's columns use on a wide screen:
  //
  //   0042 · Acme Ltd                    $1,200.00
  //   12 days late · viewed Oct 2           ✉ $
  group('the stacked row', () {
    DashboardRecordRow row({
      List<RecordRowAction> actions = const [],
      List<String>? log,
    }) => DashboardRecordRow(
      number: '0042',
      client: 'Acme Ltd',
      lead: '12 days late',
      leadIsLate: true,
      fact: 'viewed 2026-10-05',
      amount: r'$1,200.00',
      onTap: () => log?.add('open'),
      compact: false,
      stacked: true,
      actions: actions,
    );
    List<RecordRowAction> two(List<String> log) => [
      RecordRowAction(
        icon: Icons.mail_outline,
        tooltipKey: 'send_reminder_label',
        onRun: () async => log.add('remind'),
      ),
      RecordRowAction(
        icon: Icons.payments_outlined,
        tooltipKey: 'enter_payment',
        onRun: () async => log.add('pay'),
      ),
    ];

    testWidgets('the amount ends line one; every action sits under it', (
      tester,
    ) async {
      final log = <String>[];
      await pumpCard(tester, row(actions: two(log), log: log), width: 340);

      expect(tester.takeException(), isNull);
      final identity = tester.getRect(
        find.textContaining('0042 · Acme Ltd', findRichText: true),
      );
      final amount = tester.getRect(find.text(r'$1,200.00'));
      final status = tester.getRect(
        find.textContaining('12 days late', findRichText: true),
      );
      // Line one: identity then amount. Line two: status then the icons.
      expect(
        amount.center.dy,
        moreOrLessEquals(identity.center.dy, epsilon: 3),
      );
      expect(amount.left, greaterThan(identity.left));
      expect(status.top, greaterThanOrEqualTo(identity.bottom - 1));
      for (final tip in ['Send Reminder', 'Enter Payment']) {
        final button = tester.getRect(find.byTooltip(tip));
        expect(
          button.top,
          greaterThanOrEqualTo(amount.bottom - 2),
          reason: tip,
        );
        expect(
          button.center.dy,
          moreOrLessEquals(status.center.dy, epsilon: 3),
          reason: tip,
        );
      }

      // Both actions, not just the first — and neither opens the record.
      await tester.tap(find.byTooltip('Send Reminder'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byTooltip('Enter Payment'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(log, ['remind', 'pay']);
    });

    // Columns of the band sit side by side, some with actions and some
    // without; their hairlines only meet if a row is the same height in both.
    for (final platform in const [
      TargetPlatform.macOS,
      TargetPlatform.android,
    ]) {
      testWidgets('is as tall with actions as without ($platform)', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          final log = <String>[];
          await pumpCard(tester, row(), width: 340);
          final plain = tester.getSize(find.byType(DashboardRecordRow)).height;
          await pumpCard(tester, row(actions: two(log)), width: 340);
          final withButtons = tester
              .getSize(find.byType(DashboardRecordRow))
              .height;

          expect(withButtons, plain);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    testWidgets('holds at 300 px with a long name and a large amount', (
      tester,
    ) async {
      final log = <String>[];
      await pumpCard(
        tester,
        DashboardRecordRow(
          number: '0042',
          client: 'A Very Long Client Name That Will Not Fit Anywhere',
          lead: '120 days late',
          leadIsLate: true,
          fact: 'reminded 2026-10-01',
          amount: r'$123,456,789.12',
          onTap: () {},
          compact: false,
          stacked: true,
          actions: two(log),
        ),
        width: 300,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('states', () {
    UpcomingInvoicesCard card(
      AsyncSection<List<DashboardInvoiceRow>> section, {
      VoidCallback? onRetry,
    }) => UpcomingInvoicesCard(
      section: section,
      formatter: _formatter,
      today: _today,
      compact: false,
      onInvoiceTap: (_) {},
      onViewAll: () {},
      onRetry: onRetry ?? () {},
    );

    testWidgets('not loaded is a skeleton, never the empty message', (
      tester,
    ) async {
      await pumpCard(tester, card(const AsyncSection.idle()));

      expect(find.byType(ListCardSkeleton), findsOneWidget);
      expect(find.text('No invoices due soon'), findsNothing);
      expect(find.text('View All'), findsNothing);
    });

    testWidgets('loaded and empty is one line', (tester) async {
      await pumpCard(tester, card(const AsyncSection.ready([])));

      expect(find.text('No invoices due soon'), findsOneWidget);
      expect(
        tester.getSize(find.byType(UpcomingInvoicesCard)).height,
        lessThan(120),
      );
      // Nothing to view all of.
      expect(find.text('View All'), findsNothing);
    });

    testWidgets('failed with nothing cached is one line with a retry', (
      tester,
    ) async {
      var retries = 0;
      await pumpCard(
        tester,
        card(AsyncSection.error(Exception('x')), onRetry: () => retries++),
      );

      expect(find.text("Couldn't load"), findsOneWidget);
      expect(find.text('No invoices due soon'), findsNothing);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
      expect(
        tester.getSize(find.byType(UpcomingInvoicesCard)).height,
        lessThan(120),
      );
    });

    testWidgets('failed over cached rows keeps the rows', (tester) async {
      await pumpCard(
        tester,
        card(
          AsyncSection.error(
            Exception('x'),
            data: [_inv('0050', due: const Date(2026, 10, 17))],
          ),
        ),
      );

      expect(richText('0050 · Acme'), findsOneWidget);
      expect(find.text("Couldn't load"), findsNothing);
    });
  });

  // In the wide grid a card is stretched to its row-mate's height. A one-line
  // state then sat at the top of a hollow box; told it is in such a cell
  // (`DashboardPanelCell`, set by the grid) the card centres it instead.
  group('beside a taller card', () {
    Future<void> pumpPair(
      WidgetTester tester,
      AsyncSection<List<DashboardInvoiceRow>> section,
    ) async {
      tester.view.physicalSize = const Size(1100, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
          home: Scaffold(
            body: SingleChildScrollView(
              // The grid's own row, around the real card.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DashboardPanelCell(
                        stretched: true,
                        child: UpcomingInvoicesCard(
                          section: section,
                          formatter: _formatter,
                          today: _today,
                          compact: false,
                          onInvoiceTap: (_) {},
                          onViewAll: () {},
                          onRetry: () {},
                        ),
                      ),
                    ),
                    const Expanded(child: SizedBox(height: 420)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('an empty card centres its line', (tester) async {
      await pumpPair(tester, const AsyncSection.ready([]));

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(UpcomingInvoicesCard));
      expect(card.height, 420);
      final text = tester.getRect(find.text('No invoices due soon'));
      // Centred in the body — well below the header, not hard under it.
      expect(text.center.dy, greaterThan(card.top + 150));
      expect(text.center.dy, lessThan(card.bottom - 100));
    });

    testWidgets('a failed card centres its retry', (tester) async {
      await pumpPair(tester, AsyncSection.error(Exception('x')));

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byType(UpcomingInvoicesCard));
      expect(
        tester.getRect(find.text('Retry')).center.dy,
        greaterThan(card.top + 150),
      );
    });

    testWidgets('rows still start at the top', (tester) async {
      await pumpPair(
        tester,
        AsyncSection.ready([_inv('0050', due: const Date(2026, 10, 17))]),
      );

      final card = tester.getRect(find.byType(UpcomingInvoicesCard));
      expect(card.height, 420);
      expect(
        tester.getRect(find.byType(DashboardRecordRow)).top,
        lessThan(card.top + 80),
      );
    });
  });

  group('quotes', () {
    testWidgets('an upcoming quote says how long it has left, and can be '
        'reminded', (tester) async {
      final reminded = <String>[];
      await pumpCard(
        tester,
        UpcomingQuotesCard(
          section: AsyncSection.ready([
            _quote('Q-7', validUntil: const Date(2026, 10, 16)),
            _quote('Q-8'),
          ]),
          formatter: _formatter,
          today: _today,
          compact: false,
          onQuoteTap: (_) {},
          onViewAll: () {},
          onRetry: () {},
          remind: (q) =>
              () async => reminded.add(q.id),
        ),
      );

      expect(richText('expires in 2 days'), findsOneWidget);
      await tester.tap(find.byTooltip('Send Reminder').first);
      await tester.pump(const Duration(milliseconds: 10));
      expect(reminded, ['Q-7']);
    });

    // The column that used to show this read `valid_until`, a field the
    // server never sends, and so was a column of dashes.
    testWidgets('an expired quote says when it lapsed', (tester) async {
      await pumpCard(
        tester,
        ExpiredQuotesCard(
          section: AsyncSection.ready([
            _quote('Q-1', validUntil: const Date(2026, 10, 1)),
            _quote('Q-2'),
          ]),
          formatter: _formatter,
          compact: false,
          onQuoteTap: (_) {},
          onViewAll: () {},
          onRetry: () {},
        ),
      );

      expect(richText('Expired 2026-10-01'), findsOneWidget);
      // No date on the record: the bare word, not "Expired " and a gap.
      expect(find.text('Expired', findRichText: true), findsOneWidget);
      // Nothing can be done about a lapsed quote from here.
      expect(find.byType(IconButton), findsNothing);
    });
  });

  group('payments', () {
    testWidgets('only a payment that is not Completed names its status', (
      tester,
    ) async {
      await pumpCard(
        tester,
        RecentPaymentsCard(
          section: AsyncSection.ready([
            _payment('P-1'),
            _payment('P-2', status: 6),
          ]),
          formatter: _formatter,
          compact: false,
          onPaymentTap: (_) {},
          onViewAll: () {},
          onRetry: () {},
        ),
      );

      // A "Completed" pill on every row hid the one that was not.
      expect(richText('Completed'), findsNothing);
      expect(richText('2026-10-09 · Refunded'), findsOneWidget);
      expect(find.text(r'$75.00'), findsNWidgets(2));
    });
  });

  group('recurring', () {
    testWidgets('a row says when it next goes out', (tester) async {
      await pumpCard(
        tester,
        UpcomingRecurringInvoicesCard(
          section: AsyncSection.ready([
            DashboardRecurringInvoiceRow(
              id: 'r1',
              number: 'R-0001',
              clientId: 'c',
              clientName: 'Acme Recurring',
              nextSendDate: const Date(2026, 11, 1),
              amount: Decimal.fromInt(300),
              statusId: 2,
              currencyId: '',
              frequencyId: 5,
            ),
          ]),
          formatter: _formatter,
          compact: false,
          onRecurringTap: (_) {},
          onViewAll: () {},
          onRetry: () {},
        ),
      );

      expect(richText('R-0001 · Acme Recurring'), findsOneWidget);
      expect(richText('2026-11-01'), findsOneWidget);
      expect(find.text(r'$300.00'), findsOneWidget);
    });
  });
}
