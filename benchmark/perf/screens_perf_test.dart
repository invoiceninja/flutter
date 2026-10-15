// Screens — the frame work of opening, scrolling and resizing real screens,
// mounted over the real `Services` graph and an in-memory database.
//
// What a widget test can time is build + layout + paint *recording*, in a
// debug (JIT, asserts on) build; rasterising is not part of it. So read these
// as "how much Dart work a frame does", which is what a code change moves.
//
// docs/performance-tracking.md. Run through `dart tools/perf/main.dart run`.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/clients/views/client_detail_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_edit_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_list_screen.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_list_tile.dart';

import '../../test/_localization_helper.dart';
import '../../test/_support/record_screen_harness.dart' show seedUsd;
import '../../test/ui/features/shell/_shell_test_helpers.dart';
import '../workloads.dart';
import '_perf.dart';

const _co = 'co1';
const _wide = Size(1440, 1000);

/// A phone in portrait — `flutter_test` reports Android, so touch layout too.
const _phone = Size(390, 844);

/// The mounted app around one screen, and the waits a sample needs.
class _Screen {
  _Screen(this.tester, this.fixture);

  final WidgetTester tester;
  final ShellFixture fixture;

  Services get services => fixture.services;

  Widget app(Widget screen) => Provider<Services>.value(
    value: services,
    child: MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: screen,
    ),
  );

  /// Lets Drift (real async) answer, untimed.
  Future<void> settleData() => tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 5)),
  );

  /// Pumps — timing only the frames — until [finder] matches.
  ///
  /// The timed frames move no fake time. How many rounds Drift needs before
  /// the rows land varies with the machine; a frame that also advanced the
  /// clock would fire whatever debounce came due inside it, and the figure
  /// would jump with the round count. With the clock still, an extra round is
  /// one idle frame, and the timers fire in [unmount], untimed.
  Future<void> openUntil(PerfTimer timer, Widget screen, Finder finder) async {
    await timer.time(() => tester.pumpWidget(app(screen)));
    for (var i = 0; i < 200; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await settleData();
      await timer.time(() => tester.pump());
    }
    fail('the screen never showed $finder');
  }

  Future<void> unmount() async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Let the debounce timers a list arms on dispose fire, untimed — and a
    // toast's (6 s), which outlives the screen on the global host.
    await tester.pump(const Duration(seconds: 10));
  }

  Future<void> dispose() async {
    await unmount();
    await tester.runAsync(
      () => fixture.dispose().timeout(const Duration(seconds: 30)),
    );
  }
}

Future<_Screen> _mount(WidgetTester tester, {Size size = _wide}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late ShellFixture fixture;
  await tester.runAsync(() async {
    fixture = await buildFixture(
      companies: const [FakeCompany(id: _co, name: 'Acme Ltd')],
      currentCompanyId: _co,
      closeStreamsSynchronously: true,
    );
    await seedUsd(fixture.services, companyId: _co);
    await _seed(fixture.services);
  });
  return _current = _Screen(tester, fixture);
}

/// The screen [_mount] built for the benchmark now running — null once
/// released, so a benchmark whose setUp threw does not tear down the one
/// before it and bury its own error under that one's.
_Screen? _current;

Future<void> _release(WidgetTester tester) async {
  final screen = _current;
  _current = null;
  await screen?.dispose();
}

/// The invoice the editor benchmarks open: 50 lines.
const _bigInvoiceId = 'inv_9000';

/// 600 invoices across 200 clients, plus one 50-line invoice, written the way
/// a sync writes them.
Future<void> _seed(Services services) async {
  await services.invoices.applyUpdateResponse(
    companyId: _co,
    serverResponse: InvoiceApi.fromJson(invoiceJson(9000, lines: 50)),
  );
  for (var i = 0; i < 200; i++) {
    await services.clients.applyUpdateResponse(
      companyId: _co,
      serverResponse: ClientApi.fromJson(clientJson(i)),
    );
  }
  for (var i = 0; i < 600; i++) {
    await services.invoices.applyUpdateResponse(
      companyId: _co,
      serverResponse: InvoiceApi.fromJson(invoiceJson(i)),
    );
  }
}

void main() {
  perfCalibration();

  late _Screen screen;
  final tiles = find.byType(InvoiceListTile);

  widgetBenchmark(
    'screens.invoice_list_open',
    title: 'Invoices list — open it, until the first rows are drawn',
    setUp: (tester) async => screen = await _mount(tester),
    run: (tester, timer) async {
      await screen.openUntil(timer, const InvoiceListScreen(), tiles);
      await screen.unmount();
    },
    tearDown: _release,
    samples: 9,
  );

  var offset = 0.0;
  var down = true;
  widgetBenchmark(
    'screens.invoice_list_scroll',
    title: 'Invoices list — one frame of scrolling 240 px',
    setUp: (tester) async {
      screen = await _mount(tester);
      await screen.openUntil(PerfTimer(), const InvoiceListScreen(), tiles);
    },
    run: (tester, timer) async {
      final position = tester
          .state<ScrollableState>(
            find
                .ancestor(of: tiles.first, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      // Back and forth inside the loaded window and short of the list's
      // 600 px load-more threshold, so no sample starts a page fetch or
      // measures an emission from Drift.
      final max = position.maxScrollExtent - 700;
      expect(max, greaterThan(1000), reason: 'too few rows to scroll');
      offset += down ? 240 : -240;
      if (offset >= max) down = false;
      if (offset <= 0) down = true;
      position.jumpTo(offset.clamp(0, max));
      await timer.time(() => tester.pump());
    },
    tearDown: _release,
    warmup: 10,
    samples: 40,
  );

  var narrower = true;
  widgetBenchmark(
    'screens.invoice_list_resize',
    title: 'Invoices list — one frame of resizing the window by 80 px',
    setUp: (tester) async {
      screen = await _mount(tester);
      await screen.openUntil(PerfTimer(), const InvoiceListScreen(), tiles);
    },
    run: (tester, timer) async {
      final width = narrower ? _wide.width - 80 : _wide.width;
      narrower = !narrower;
      tester.view.physicalSize = Size(width, _wide.height);
      await timer.time(() => tester.pump());
    },
    tearDown: _release,
    warmup: 6,
    samples: 30,
  );

  // The first line's cost cell, found by the text the editor shows for it.
  final cost = Decimal.parse(
    '${((invoiceJson(9000, lines: 50)['line_items'] as List).first as Map)['cost']}',
  );
  final costText = cost.toString();
  final otherCostText = (cost + Decimal.one).toString();
  final firstCost = find.byWidgetPredicate(
    (w) => w is TextField && w.controller?.text == costText,
  );
  widgetBenchmark(
    'screens.invoice_edit_open',
    title: 'Invoice editor — open a 50-line invoice, until its lines are drawn',
    setUp: (tester) async => screen = await _mount(tester),
    run: (tester, timer) async {
      await screen.openUntil(
        timer,
        const InvoiceEditScreen(existingId: _bigInvoiceId),
        firstCost,
      );
      await screen.unmount();
    },
    tearDown: _release,
    samples: 9,
  );

  late Finder costCell;
  var typed = false;
  widgetBenchmark(
    'screens.invoice_edit_typing',
    title:
        'Invoice editor — one keystroke in a line of a 50-line invoice, '
        'through the totals recompute',
    setUp: (tester) async {
      screen = await _mount(tester);
      await screen.openUntil(
        PerfTimer(),
        const InvoiceEditScreen(existingId: _bigInvoiceId),
        firstCost,
      );
      // Pinned by position once found: the cell's text is what changes.
      expect(firstCost, findsOneWidget);
      final all = find.byType(TextField);
      final index = all.evaluate().toList().indexOf(
        firstCost.evaluate().single,
      );
      costCell = all.at(index);
    },
    run: (tester, timer) async {
      typed = !typed;
      await timer.time(() async {
        await tester.enterText(costCell, typed ? otherCostText : costText);
        // The keystroke's own frame, then the cell's 250 ms debounce landing
        // on the draft — which recomputes the totals — and its frame.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
      });
    },
    tearDown: _release,
    warmup: 4,
    samples: 20,
  );

  var phoneOffset = 0.0;
  var phoneDown = true;
  widgetBenchmark(
    'screens.invoice_list_scroll_phone',
    title: 'Invoices list on a phone — one frame of scrolling 240 px',
    setUp: (tester) async {
      screen = await _mount(tester, size: _phone);
      await screen.openUntil(PerfTimer(), const InvoiceListScreen(), tiles);
    },
    run: (tester, timer) async {
      final position = tester
          .state<ScrollableState>(
            find
                .ancestor(of: tiles.first, matching: find.byType(Scrollable))
                .first,
          )
          .position;
      expect(position.axis, Axis.vertical);
      // Inside the loaded window and short of the load-more threshold, as on
      // the wide list.
      final max = position.maxScrollExtent - 700;
      expect(max, greaterThan(1000), reason: 'too few rows to scroll');
      phoneOffset += phoneDown ? 240 : -240;
      if (phoneOffset >= max) phoneDown = false;
      if (phoneOffset <= 0) phoneDown = true;
      position.jumpTo(phoneOffset.clamp(0, max));
      await timer.time(() => tester.pump());
    },
    tearDown: _release,
    warmup: 10,
    samples: 40,
  );

  // On a phone the editor is tabbed and the lines are cards, built when the
  // Items tab opens — the moment a 50-line invoice makes a phone wait.
  final lineCards = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('line_item_'),
  );
  widgetBenchmark(
    'screens.invoice_edit_items_tab_phone',
    title:
        'Invoice editor on a phone — open the Items tab of a 50-line invoice',
    setUp: (tester) async {
      screen = await _mount(tester, size: _phone);
      await screen.openUntil(
        PerfTimer(),
        const InvoiceEditScreen(existingId: _bigInvoiceId),
        find.text('Items'),
      );
      // Let the record and the client land before the first sample.
      for (var i = 0; i < 10; i++) {
        await screen.settleData();
        await tester.pump(const Duration(milliseconds: 50));
      }
    },
    run: (tester, timer) async {
      await tester.tap(find.text('Items'));
      await timer.time(() async {
        await tester.pump();
        // The tab's slide, frame by frame.
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      });
      expect(lineCards, findsWidgets, reason: 'the Items tab drew no lines');
      // Back to Details, untimed, so the next sample builds the cards again.
      await tester.tap(find.text('Details'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    },
    tearDown: _release,
    warmup: 2,
    samples: 9,
  );

  widgetBenchmark(
    'screens.client_record_open',
    title: 'Client record — open it, until the standing card is drawn',
    setUp: (tester) async => screen = await _mount(tester, size: _wide),
    run: (tester, timer) async {
      await screen.openUntil(
        timer,
        const ClientDetailScreen(id: 'cl_7'),
        find.byType(StandingCard),
      );
      await screen.unmount();
    },
    tearDown: _release,
    samples: 9,
  );
}
