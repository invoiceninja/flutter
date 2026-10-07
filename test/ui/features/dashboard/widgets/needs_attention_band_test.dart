import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/dashboard/helpers/needs_attention.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_record_row.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card_skeleton.dart';
import 'package:admin/ui/features/dashboard/widgets/needs_attention_band.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

/// A fixed "today", nowhere near a month edge so `addDays` reads plainly.
const _today = Date(2026, 10, 14);

final _formatter = Formatter(
  settings: CompanyFormatSettings.fallback,
  // `money()` returns '' for a currency it cannot resolve.
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

DashboardInvoiceRow _inv(
  String id, {
  required Date due,
  String balance = '100',
  String client = 'Acme',
  String currency = '',
  Date? viewed,
  Date? reminded,
  bool sent = false,
}) => DashboardInvoiceRow(
  id: id,
  number: id,
  clientId: 'c-$id',
  clientName: client,
  dueDate: due,
  balance: Decimal.parse(balance),
  amount: Decimal.parse(balance),
  statusId: 2,
  currencyId: currency,
  lastViewed: viewed,
  lastReminderDate: reminded,
  remindersSent: reminded == null ? 0 : 1,
  wasSent: sent,
);

DashboardQuoteRow _quote(String id, {required Date validUntil}) =>
    DashboardQuoteRow(
      id: id,
      number: id,
      clientId: 'c-$id',
      clientName: 'Quote Co',
      date: const Date(2026, 9, 1),
      validUntil: validUntil,
      amount: Decimal.fromInt(50),
      statusId: 2,
      currencyId: '',
    );

/// The needs-attention band, pumped directly: it takes values and callbacks,
/// no `Services`.
///
/// What is held in place here:
///
/// * on a wide surface the lists sit **side by side** — every one visible at
///   once, no tabs — and a single list runs its rows in two columns;
/// * where columns do not fit (a phone, a narrow pane) it is **tabs that
///   switch the rows in place**, never links out;
/// * the band **claims only what it knows** — a list with nothing has no
///   column and no tab, a capped count reads "50+", the sum appears only when
///   proven;
/// * a row is **one target**, and what else it can do is an icon button every
///   row of its list either has or holds the place of;
/// * a day with nothing to report costs **one line**.
void main() {
  NeedsAttention attention({
    List<DashboardInvoiceRow>? pastDue,
    int? pastDueTotal,
    List<DashboardInvoiceRow>? upcoming,
    List<DashboardQuoteRow>? quotes,
  }) => needsAttention(
    pastDue: pastDue == null
        ? null
        : DashboardRows(pastDue, total: pastDueTotal ?? pastDue.length),
    upcomingInvoices: upcoming,
    upcomingQuotes: quotes,
    today: _today,
    invoices: true,
    quotes: true,
    companyCurrencyId: '1',
  );

  final late1 = _inv('0042', due: const Date(2026, 10, 2), balance: '1200');
  final late2 = _inv('0043', due: const Date(2026, 10, 13), balance: '300');
  final soon = _inv('0050', due: const Date(2026, 10, 17), balance: '80');
  final soon2 = _inv('0051', due: const Date(2026, 10, 19), balance: '410');
  final later = _inv('0060', due: const Date(2026, 11, 20), balance: '10');
  final expiring = _quote('Q-7', validUntil: const Date(2026, 10, 16));
  final expiring2 = _quote('Q-8', validUntil: const Date(2026, 10, 18));

  final viewAll = <AttentionTab>[];
  final opened = <String>[];
  var retries = 0;
  var reviews = 0;
  setUp(() {
    viewAll.clear();
    opened.clear();
    retries = 0;
    reviews = 0;
  });

  /// [width] is the surface's — at the default the band is wide enough for
  /// three columns; `compact: true` (the phone body) always uses tabs.
  Future<void> pumpBand(
    WidgetTester tester, {
    required NeedsAttention attention,
    ListSectionState state = ListSectionState.rows,
    bool compact = false,
    AttentionActions actions = AttentionActions.none,
    int rowLimit = kAttentionRows,
    int failedSaves = 0,
    double width = 1160,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: NeedsAttentionBand(
              attention: attention,
              state: state,
              formatter: _formatter,
              today: _today,
              compact: compact,
              actions: actions,
              rowLimit: rowLimit,
              failedSaves: failedSaves,
              onReviewFailedSaves: () => reviews++,
              onInvoiceTap: (r) => opened.add('invoice:${r.id}'),
              onQuoteTap: (q) => opened.add('quote:${q.id}'),
              onViewAll: viewAll.add,
              onRetry: () => retries++,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  Finder richText(String text) => find.textContaining(text, findRichText: true);
  final tabRoles = find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.role == SemanticsRole.tab,
  );
  Rect rowRect(WidgetTester tester, String key) =>
      tester.getRect(find.byKey(ValueKey(key)));

  AttentionActions actionsFor({
    required List<String> log,
    Set<String> noRemind = const {},
    bool quotes = true,
    Completer<void>? gate,
  }) => AttentionActions(
    remindInvoice: (r) => noRemind.contains(r.id)
        ? null
        : () async {
            log.add('remind:${r.id}');
            if (gate != null) await gate.future;
          },
    enterPayment: (r) =>
        () async => log.add('pay:${r.id}'),
    remindQuote: (q) =>
        quotes ? () async => log.add('remind-quote:${q.id}') : null,
  );

  // On a wide screen the band was three short rows stretched across 1,160 px
  // — the Remind button 700 px from the name it acted on — under a tab strip
  // holding one chip. Side by side, every list is on screen at once.
  group('lists side by side', () {
    final three = attention(
      pastDue: [late1, late2],
      upcoming: [soon, soon2, later],
      quotes: [expiring, expiring2],
    );

    for (final width in const <double>[1160, 1000]) {
      testWidgets('@ ${width.toInt()}px every list is a column, all visible '
          'at once', (tester) async {
        await pumpBand(tester, attention: three, width: width);

        expect(tester.takeException(), isNull);
        expect(tabRoles, findsNothing, reason: 'no tabs to switch');
        // A row from each list, on screen together.
        for (final id in ['0042', '0050', 'Q-7']) {
          expect(richText(id), findsOneWidget, reason: id);
        }
        // Left to right in the order of urgency, on one line.
        final heads = [
          for (final label in ['Past Due', 'Due Soon', 'Quotes Expiring'])
            tester.getRect(find.text(label)),
        ];
        expect(heads[0].left, lessThan(heads[1].left));
        expect(heads[1].left, lessThan(heads[2].left));
        expect(heads[0].center.dy, moreOrLessEquals(heads[1].center.dy));
        expect(heads[1].center.dy, moreOrLessEquals(heads[2].center.dy));
      });
    }

    testWidgets('each list has its count and its own View all', (tester) async {
      await pumpBand(tester, attention: three);

      // 2 past due; 2 due within the week (the November one is not "soon");
      // 2 quotes about to lapse.
      expect(find.text('2'), findsNWidgets(3));
      final links = find.text('View All');
      expect(links, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        await tester.tap(links.at(i));
      }
      expect(viewAll, [
        AttentionTab.pastDue,
        AttentionTab.dueSoon,
        AttentionTab.quotesExpiring,
      ]);
      expect(opened, isEmpty);
    });

    // Two lists side by side whose rows do not line up read as a mistake. A
    // row is the same height whether or not its list has actions.
    // At the default text size the row's floor alone makes them equal; at a
    // larger one the first line outgrows it, and only a second line that is
    // the action box's height in *every* row keeps the columns in step.
    for (final scale in const [1.0, 1.4]) {
      testWidgets('rows line up across columns, with or without actions '
          '(text ×$scale)', (tester) async {
        final log = <String>[];
        await pumpBand(
          tester,
          attention: three,
          // Invoices can be acted on; quotes cannot.
          actions: actionsFor(log: log, quotes: false),
          textScale: scale,
        );

        expect(find.byTooltip('Send Reminder'), findsNWidgets(2));
        final first = [
          rowRect(tester, 'invoice:0042'),
          rowRect(tester, 'invoice:0050'),
          rowRect(tester, 'quote:Q-7'),
        ];
        final second = [
          rowRect(tester, 'invoice:0043'),
          rowRect(tester, 'invoice:0051'),
          rowRect(tester, 'quote:Q-8'),
        ];
        for (final rects in [first, second]) {
          expect(rects[0].top, rects[1].top);
          expect(rects[1].top, rects[2].top);
          expect(rects[0].height, rects[1].height);
          expect(rects[1].height, rects[2].height);
        }
        // Three equal columns.
        expect(first[0].width, moreOrLessEquals(first[1].width, epsilon: 1));
        expect(first[1].width, moreOrLessEquals(first[2].width, epsilon: 1));
      });
    }

    testWidgets('a column shows at most its row limit', (tester) async {
      await pumpBand(
        tester,
        attention: attention(
          pastDue: [
            for (var i = 0; i < 8; i++)
              _inv('${2000 + i}', due: const Date(2026, 10, 1)),
          ],
          upcoming: [soon],
          quotes: [expiring],
        ),
        rowLimit: 3,
      );

      // Three lists, a column each: three of the eight, and the count says
      // how many there are.
      expect(find.byType(DashboardRecordRow), findsNWidgets(5));
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('the proven sum sits in the Past Due header', (tester) async {
      await pumpBand(tester, attention: three);

      final sum = find.text(r'$1,500.00');
      expect(sum, findsOneWidget);
      expect(
        tester.getCenter(sum).dy,
        moreOrLessEquals(
          tester.getCenter(find.text('Past Due')).dy,
          epsilon: 6,
        ),
      );
      // No footer row at all in this arrangement.
      expect(richText('Past Due: '), findsNothing);
    });

    testWidgets('an unproven sum is not shown', (tester) async {
      final page = [
        for (var i = 0; i < 50; i++)
          _inv('${1000 + i}', due: const Date(2026, 10, 1)),
      ];
      await pumpBand(
        tester,
        // The server says 80 match; only the first 50 are in hand.
        attention: attention(pastDue: page, pastDueTotal: 80, upcoming: [soon]),
      );

      expect(find.text('80'), findsOneWidget);
      // 50 × $100 — a sum over the first fifty of eighty looks like a fact
      // and is not one.
      expect(find.text(r'$5,000.00'), findsNothing);
    });

    testWidgets('three lists in a pane too narrow for columns use tabs', (
      tester,
    ) async {
      await pumpBand(tester, attention: three, width: 700);

      expect(tester.takeException(), isNull);
      expect(tabRoles, findsNWidgets(3));
      // One list at a time.
      expect(richText('0042'), findsOneWidget);
      expect(richText('0050'), findsNothing);
    });
  });

  // Columns stay narrow. A list with more rows than fit one column takes a
  // second and a third of its own rows instead of the columns being widened —
  // widening is what put each row's buttons far from its name.
  group('a list takes the columns it can fill', () {
    List<DashboardQuoteRow> quotes(int n) => [
      for (var i = 0; i < n; i++)
        _quote('Q-$i', validUntil: const Date(2026, 10, 16)),
    ];
    List<Rect> quoteRects(WidgetTester tester, int n) => [
      for (var i = 0; i < n; i++) rowRect(tester, 'quote:Q-$i'),
    ];

    testWidgets('one list of eight runs three columns, most urgent on the '
        'left', (tester) async {
      await pumpBand(tester, attention: attention(quotes: quotes(10)));

      expect(tabRoles, findsNothing);
      // Nine where the single list showed three.
      expect(find.byType(DashboardRecordRow), findsNWidgets(9));
      final r = quoteRects(tester, 9);
      // Column by column: 0–2 down the left, 3–5 the middle, 6–8 the right.
      for (var c = 0; c < 3; c++) {
        expect(r[c * 3 + 1].top, greaterThan(r[c * 3].top));
        expect(r[c * 3 + 2].top, greaterThan(r[c * 3 + 1].top));
        expect(r[c * 3 + 1].left, r[c * 3].left);
      }
      expect(r[3].left, greaterThan(r[0].right - 1));
      expect(r[6].left, greaterThan(r[3].right - 1));
      for (var i = 0; i < 3; i++) {
        expect(r[i + 3].top, r[i].top, reason: 'row $i');
        expect(r[i + 6].top, r[i].top, reason: 'row $i');
      }
      // A column is a third of the band, not the whole of it.
      expect(r[0].width, lessThan(400));
    });

    testWidgets('one header spans the list\'s columns', (tester) async {
      await pumpBand(tester, attention: attention(quotes: quotes(8)));

      expect(find.text('Quotes Expiring'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.byType(DashboardRecordRow), findsNWidgets(8));
      await tester.tap(find.text('View All'));
      expect(viewAll, [AttentionTab.quotesExpiring]);
    });

    // Balanced: three down one column beside two empty ones is the emptiness
    // this replaced. Three rows are one line of three.
    testWidgets('three rows are one line of three', (tester) async {
      await pumpBand(tester, attention: attention(quotes: quotes(3)));

      final r = quoteRects(tester, 3);
      expect(r[1].top, r[0].top);
      expect(r[2].top, r[0].top);
      expect(r[1].left, greaterThan(r[0].right - 1));
      expect(r[2].left, greaterThan(r[1].right - 1));
    });

    testWidgets('a spare column goes to the list with rows to put in it', (
      tester,
    ) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1, late2], quotes: quotes(6)),
      );

      // Past Due keeps one column; the six quotes run two.
      expect(find.byType(DashboardRecordRow), findsNWidgets(8));
      final past = rowRect(tester, 'invoice:0042');
      final r = quoteRects(tester, 6);
      expect(r[0].left, greaterThan(past.right - 1));
      expect(r[3].left, greaterThan(r[0].right - 1));
      expect(r[3].top, r[0].top);
      expect(r[0].top, past.top);
      expect(r[0].width, moreOrLessEquals(past.width, epsilon: 1));
    });

    // One overdue invoice does not get the whole card to stretch across: its
    // buttons stay under its amount, a column's width from its name.
    testWidgets('a single row keeps one column\'s width', (tester) async {
      final log = <String>[];
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1]),
        actions: actionsFor(log: log),
      );

      final row = rowRect(tester, 'invoice:0042');
      expect(row.width, lessThan(400));
      expect(
        tester.getRect(find.byTooltip('Send Reminder')).right,
        lessThanOrEqualTo(row.right),
      );
    });

    testWidgets('a pane with room for two columns runs two', (tester) async {
      await pumpBand(
        tester,
        attention: attention(quotes: quotes(8)),
        width: 700,
      );

      expect(tester.takeException(), isNull);
      expect(tabRoles, findsNothing);
      expect(find.byType(DashboardRecordRow), findsNWidgets(6));
      final r = quoteRects(tester, 6);
      expect(r[3].left, greaterThan(r[0].right - 1));
      expect(r[3].top, r[0].top);
    });

    testWidgets('a pane too narrow for two columns is one tabbed list', (
      tester,
    ) async {
      await pumpBand(
        tester,
        attention: attention(quotes: quotes(8)),
        width: 560,
      );

      expect(tester.takeException(), isNull);
      expect(tabRoles, findsOneWidget);
      expect(find.byType(DashboardRecordRow), findsNWidgets(3));
      expect(find.text('View All (8)'), findsOneWidget);
    });
  });

  // The phone, and any pane too narrow for columns.
  group('tabs', () {
    testWidgets('one per list that has something, each with its count', (
      tester,
    ) async {
      await pumpBand(
        tester,
        attention: attention(
          pastDue: [late1, late2],
          upcoming: [soon, later],
          quotes: [expiring],
        ),
        compact: true,
        width: 390,
      );

      expect(tabRoles, findsNWidgets(3));
      expect(find.text('Past Due'), findsOneWidget);
      expect(find.text('Due Soon'), findsOneWidget);
      expect(find.text('Quotes Expiring'), findsOneWidget);
      // 2 past due; 1 due within the week; 1 quote about to lapse.
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2));
    });

    testWidgets('a list with nothing has no tab', (tester) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1]),
        compact: true,
        width: 390,
      );

      expect(find.text('Past Due'), findsOneWidget);
      expect(find.text('Due Soon'), findsNothing);
      expect(find.text('Quotes Expiring'), findsNothing);
    });

    testWidgets('a tab swaps the rows in place — it is not a link', (
      tester,
    ) async {
      await pumpBand(
        tester,
        attention: attention(
          pastDue: [late1],
          upcoming: [soon],
          quotes: [expiring],
        ),
        compact: true,
        width: 390,
      );
      expect(richText('0042'), findsOneWidget);
      expect(richText('0050'), findsNothing);

      await tester.tap(find.text('Due Soon'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(richText('0050'), findsOneWidget);
      expect(richText('0042'), findsNothing);
      expect(richText('due in 3 days'), findsOneWidget);

      await tester.tap(find.text('Quotes Expiring'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(richText('Q-7'), findsOneWidget);
      expect(richText('expires in 2 days'), findsOneWidget);

      expect(viewAll, isEmpty, reason: 'a tab must not navigate');
      expect(opened, isEmpty);
    });

    testWidgets('switching to a shorter tab does not move the page', (
      tester,
    ) async {
      await pumpBand(
        tester,
        attention: attention(
          pastDue: [
            late1,
            late2,
            _inv('0044', due: const Date(2026, 10, 12)),
          ],
          upcoming: [soon],
        ),
        compact: true,
        width: 390,
      );
      final before = tester.getSize(find.byType(NeedsAttentionBand)).height;

      await tester.tap(find.text('Due Soon'));
      await tester.pump(const Duration(milliseconds: 10));

      expect(tester.getSize(find.byType(NeedsAttentionBand)).height, before);
    });

    testWidgets('the selected tab says so to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1], upcoming: [soon]),
        compact: true,
        width: 390,
      );

      expect(
        tester.getSemantics(find.text('Past Due')),
        isSemantics(isSelected: true, hasTapAction: true),
      );
      expect(
        tester.getSemantics(find.text('Due Soon')),
        isSemantics(isSelected: false, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('a full page is "50+"… and its sum is withheld', (
      tester,
    ) async {
      final page = [
        for (var i = 0; i < 50; i++)
          _inv('${1000 + i}', due: const Date(2026, 10, 1)),
      ];
      await pumpBand(
        tester,
        attention: attention(pastDue: page, pastDueTotal: 80),
        compact: true,
        width: 390,
      );

      expect(find.text('80'), findsOneWidget);
      expect(find.text('View All (80)'), findsOneWidget);
      expect(richText('Past Due: '), findsNothing);
    });

    testWidgets('a complete, single-currency list shows what is late', (
      tester,
    ) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1, late2]),
        compact: true,
        width: 390,
      );

      expect(richText(r'Past Due: $1,500.00'), findsOneWidget);
      expect(find.text('View All (2)'), findsOneWidget);
    });

    testWidgets('mixed currencies have no single sum', (tester) async {
      await pumpBand(
        tester,
        attention: attention(
          pastDue: [
            late1,
            _inv('0099', due: const Date(2026, 10, 1), currency: '2'),
          ],
        ),
        compact: true,
        width: 390,
      );

      expect(richText('Past Due: '), findsNothing);
    });

    testWidgets('View all leads to the selected tab\'s list', (tester) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1], upcoming: [soon]),
        compact: true,
        width: 390,
      );

      await tester.tap(find.text('View All (1)'));
      await tester.tap(find.text('Due Soon'));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.text('View All (1)'));

      expect(viewAll, [AttentionTab.pastDue, AttentionTab.dueSoon]);
    });

    testWidgets('only the reserved number of rows is drawn', (tester) async {
      await pumpBand(
        tester,
        attention: attention(
          pastDue: [
            for (var i = 0; i < 8; i++)
              _inv('${2000 + i}', due: const Date(2026, 10, 1)),
          ],
        ),
        rowLimit: 3,
        compact: true,
        width: 390,
      );

      expect(find.byType(DashboardRecordRow), findsNWidgets(3));
      expect(find.text('View All (8)'), findsOneWidget);
    });

    testWidgets('one visible action a row', (tester) async {
      final log = <String>[];
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1]),
        actions: actionsFor(log: log),
        compact: true,
        width: 390,
      );

      expect(tester.takeException(), isNull);
      // The first action of the list is the one.
      expect(find.byTooltip('Send Reminder'), findsOneWidget);
      expect(find.byTooltip('Enter Payment'), findsNothing);

      await tester.tap(find.byTooltip('Send Reminder'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(log, ['remind:0042']);
    });
  });

  group('rows', () {
    testWidgets('say how late, and what the client has seen', (tester) async {
      await pumpBand(
        tester,
        attention: attention(
          pastDue: [
            _inv(
              '0042',
              due: const Date(2026, 10, 2),
              viewed: const Date(2026, 10, 5),
              sent: true,
            ),
            _inv('0043', due: const Date(2026, 10, 13), sent: true),
          ],
          upcoming: [soon],
        ),
      );

      expect(richText('12 days late · viewed 2026-10-05'), findsOneWidget);
      expect(richText('1 day late · not opened'), findsOneWidget);
    });

    testWidgets('a row is one target and opens its record', (tester) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1], quotes: [expiring]),
      );

      await tester.tap(richText('0042'));
      await tester.tap(richText('Q-7'));
      expect(opened, ['invoice:0042', 'quote:Q-7']);
    });
  });

  group('actions', () {
    testWidgets('past due offers Remind and Payment; due soon only Payment; '
        'quotes only Remind', (tester) async {
      final log = <String>[];
      await pumpBand(
        tester,
        attention: attention(
          pastDue: [late1],
          upcoming: [soon],
          quotes: [expiring],
        ),
        actions: actionsFor(log: log),
      );

      // All on screen at once: two reminders (invoice, quote), two payments
      // (past due, due soon).
      final remind = find.byTooltip('Send Reminder');
      final pay = find.byTooltip('Enter Payment');
      expect(remind, findsNWidgets(2));
      expect(pay, findsNWidgets(2));
      for (final f in [remind.at(0), pay.at(0), pay.at(1), remind.at(1)]) {
        await tester.tap(f);
        await tester.pump(const Duration(milliseconds: 10));
      }

      expect(log, ['remind:0042', 'pay:0042', 'pay:0050', 'remind-quote:Q-7']);
      // An action never also opens the record.
      expect(opened, isEmpty);
    });

    // The point of the columns: nothing a row can do is more than a column
    // away from the name it acts on. As one list it was ~700 px.
    testWidgets('an action sits under its row\'s amount, inside its column', (
      tester,
    ) async {
      final log = <String>[];
      await pumpBand(
        tester,
        attention: attention(
          pastDue: [late1],
          upcoming: [soon],
          quotes: [expiring],
        ),
        actions: actionsFor(log: log),
      );

      final row = rowRect(tester, 'invoice:0042');
      // The row's own amount — with one past-due invoice the header's proven
      // sum is the same figure.
      final amount = tester.getRect(
        find.descendant(
          of: find.byKey(const ValueKey('invoice:0042')),
          matching: find.text(r'$1,200.00'),
        ),
      );
      for (final tip in ['Send Reminder', 'Enter Payment']) {
        final button = tester.getRect(find.byTooltip(tip).first);
        expect(
          button.top,
          greaterThanOrEqualTo(amount.bottom - 2),
          reason: tip,
        );
        expect(button.left, greaterThanOrEqualTo(row.left), reason: tip);
        expect(button.right, lessThanOrEqualTo(row.right), reason: tip);
      }
      expect(row.width, lessThan(400));
    });

    testWidgets('with nothing offered, rows carry no buttons at all', (
      tester,
    ) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1, late2], upcoming: [soon]),
      );

      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    // A row that may not do what its neighbours can keeps the slot: the
    // button holds its place, invisible and inert, so the rest stays aligned.
    testWidgets('a row that may not remind keeps the slot, without a button', (
      tester,
    ) async {
      final log = <String>[];
      await pumpBand(
        tester,
        // Three lists, so the two past-due rows share one column.
        attention: attention(
          pastDue: [late1, late2],
          upcoming: [soon],
          quotes: [expiring],
        ),
        actions: actionsFor(log: log, noRemind: {'0043'}, quotes: false),
      );

      // One visible Remind (hit-testable); every invoice row has Payment.
      expect(find.byTooltip('Send Reminder').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Enter Payment').hitTestable(), findsNWidgets(3));
      final pays = find.byTooltip('Enter Payment');
      expect(
        tester.getRect(pays.at(0)).right,
        tester.getRect(pays.at(1)).right,
      );
      expect(
        tester.getTopRight(find.text(r'$1,200.00')).dx,
        tester.getTopRight(find.text(r'$300.00')).dx,
      );
    });

    testWidgets('a running action shows it, and cannot be fired twice', (
      tester,
    ) async {
      final log = <String>[];
      final gate = Completer<void>();
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1], upcoming: [soon]),
        actions: actionsFor(log: log, gate: gate),
      );

      await tester.tap(find.byTooltip('Send Reminder'));
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byTooltip('Send Reminder'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 10));
      expect(log, ['remind:0042']);

      gate.complete();
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('nothing to report', () {
    testWidgets('is one line, naming what comes next', (tester) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: const [], upcoming: [later]),
        state: ListSectionState.empty,
      );

      expect(find.text('Nothing past due'), findsOneWidget);
      expect(
        find.text('Next due: 0060 · Acme · due in 37 days'),
        findsOneWidget,
      );
      expect(find.text('Needs your attention'), findsNothing);
      expect(
        tester.getSize(find.byType(NeedsAttentionBand)).height,
        lessThan(72),
      );

      await tester.tap(find.textContaining('Next due'));
      expect(opened, ['invoice:0060']);
    });

    testWidgets('with nothing ahead either, it just says so', (tester) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: const []),
        state: ListSectionState.empty,
      );

      expect(find.text('Nothing past due'), findsOneWidget);
      expect(find.textContaining('Next due'), findsNothing);
    });
  });

  group('not loaded', () {
    testWidgets('a skeleton, never "Nothing past due"', (tester) async {
      await pumpBand(
        tester,
        attention: NeedsAttention.none,
        state: ListSectionState.loading,
      );

      expect(find.byType(ListCardSkeleton), findsOneWidget);
      expect(find.text('Nothing past due'), findsNothing);
    });

    testWidgets('a failed fetch says so and retries', (tester) async {
      await pumpBand(
        tester,
        attention: NeedsAttention.none,
        state: ListSectionState.failed,
      );

      expect(find.textContaining("Couldn't load"), findsOneWidget);
      expect(find.text('Nothing past due'), findsNothing);
      await tester.tap(find.text('Retry'));
      expect(retries, 1);
    });

    // The past-due fetch failed, but another list has rows: the failure is
    // said above the lists rather than hidden behind them.
    testWidgets('a failure beside a loaded list shows both', (tester) async {
      await pumpBand(
        tester,
        attention: attention(upcoming: [soon], quotes: [expiring]),
        state: ListSectionState.failed,
      );

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Due Soon'), findsOneWidget);
      expect(find.text('Quotes Expiring'), findsOneWidget);
      expect(find.text('Past Due'), findsNothing);
    });
  });

  group('changes that could not be saved', () {
    testWidgets('lead the band, counted, and open the review', (tester) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1], upcoming: [soon]),
        failedSaves: 2,
      );

      expect(find.text('2 changes could not be saved'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('2 changes could not be saved')).dy,
        lessThan(tester.getTopLeft(find.text('Past Due')).dy),
      );
      await tester.tap(find.text('Review'));
      expect(reviews, 1);
    });

    testWidgets('one is singular, and none draws nothing', (tester) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: [late1]),
        failedSaves: 1,
      );
      expect(find.text('1 change could not be saved'), findsOneWidget);

      await pumpBand(tester, attention: attention(pastDue: [late1]));
      expect(find.textContaining('could not be saved'), findsNothing);
    });

    testWidgets('sit over the quiet line too', (tester) async {
      await pumpBand(
        tester,
        attention: attention(pastDue: const []),
        state: ListSectionState.empty,
        failedSaves: 3,
      );

      expect(find.text('3 changes could not be saved'), findsOneWidget);
      expect(find.text('Nothing past due'), findsOneWidget);
    });
  });

  group('fits', () {
    final everything = attention(
      pastDue: [
        _inv(
          '0042',
          due: const Date(2026, 10, 2),
          balance: '123456789.12',
          client: 'A Very Long Client Name That Will Not Fit Anywhere',
          viewed: const Date(2026, 10, 5),
          sent: true,
        ),
        late2,
      ],
      upcoming: [soon, soon2],
      quotes: [expiring, expiring2],
    );
    final allActions = AttentionActions(
      remindInvoice: (r) => () async {},
      enterPayment: (r) => () async {},
      remindQuote: (q) => () async {},
    );

    for (final (width, compact, scale) in const [
      (320.0, true, 1.0),
      (390.0, true, 1.4),
      (700.0, false, 1.0),
      (900.0, false, 1.0),
      (900.0, false, 1.4),
      (1000.0, false, 1.0),
      (1000.0, false, 1.4),
      (1160.0, false, 1.4),
      (1600.0, false, 1.0),
    ]) {
      testWidgets('@ ${width.toInt()}px, text ×$scale, every list and action', (
        tester,
      ) async {
        await pumpBand(
          tester,
          attention: everything,
          actions: allActions,
          compact: compact,
          width: width,
          textScale: scale,
          failedSaves: 2,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('one list over two columns, a long name at large text', (
      tester,
    ) async {
      await pumpBand(
        tester,
        attention: attention(
          pastDue: [
            for (var i = 0; i < 6; i++)
              _inv(
                '${3000 + i}',
                due: const Date(2026, 10, 2),
                balance: '123456789.12',
                client: 'A Very Long Client Name That Will Not Fit Anywhere',
                sent: true,
              ),
          ],
        ),
        actions: allActions,
        width: 700,
        textScale: 1.4,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardRecordRow), findsNWidgets(6));
    });
  });
}
