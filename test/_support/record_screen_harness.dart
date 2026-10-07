// A record (detail) screen, assembled — the real `Services` graph, a real
// local database, and the network played by whatever `http.Client` the test
// hands over. Shared by every `<entity>_detail_screen_test.dart`.
//
// Real Drift streams, so no `pumpAndSettle` (it never settles over a watch).
// **Nothing here sleeps a fixed while and hopes.** A step that expects
// something to appear polls for it ([RecordScreen.until]); the only fixed
// waits ([RecordScreen.quiet]) stand in front of "nothing happened", which
// cannot be polled for and can only ever pass early.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';

import '../_localization_helper.dart';
import '../ui/features/shell/_shell_test_helpers.dart';

/// A mounted record screen and the ways a test waits on it.
class RecordScreen {
  RecordScreen(this.tester, this.fixture);

  final WidgetTester tester;
  final ShellFixture fixture;

  Services get services => fixture.services;

  /// One round: let real async (Drift, the mock server) run, then a frame
  /// that also moves the fake clock the debounce timers run on.
  Future<void> _round() async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 150));
  }

  /// Pumps until [done]. Fails, naming [what], rather than carrying on with a
  /// screen that never got there.
  Future<void> until(bool Function() done, String what) async {
    for (var i = 0; i < 80; i++) {
      if (done()) return;
      await _round();
    }
    fail('timed out waiting for $what');
  }

  Future<void> untilFound(Finder finder, String what) =>
      until(() => finder.evaluate().isNotEmpty, what);

  /// A stretch in which anything that was going to happen has: longer than
  /// the re-check delay plus the tab-counts debounce.
  Future<void> quiet() async {
    for (var i = 0; i < 16; i++) {
      await _round();
    }
  }

  /// Tears the screen and the fixture down.
  ///
  /// **Bounded.** A write still on its way through the outbox when the
  /// database is closed leaves `close()` waiting on it for ever, and a test
  /// run that never ends is the worst way to learn that — CI sits until its
  /// own timeout with nothing to say which test did it. So what is in flight
  /// is given a moment to land, and a close that still does not return fails
  /// the test by name.
  Future<void> dispose() async {
    for (var i = 0; i < 4; i++) {
      await _round();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));
    await tester.runAsync(
      () => fixture.dispose().timeout(
        const Duration(seconds: 30),
        onTimeout: () => fail(
          'the fixture did not close within 30 s — a write was probably still '
          'in the outbox. Call `screen.quiet()` after the last action that '
          'saves something.',
        ),
      ),
    );
  }
}

/// A JSON 200.
http.Response jsonOk(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

/// The server's answer to "you may not view this record" — a 401 that is a
/// permission denial, not a dead session.
http.Response permissionDenied() => http.Response(
  jsonEncode({'message': 'This action is unauthorized.'}),
  401,
  headers: {'content-type': 'application/json'},
);

/// A list response that carries only a paginator total — what a tab-count
/// request (`per_page=1`) is read for.
http.Response countOf(int total) => jsonOk({
  'data': <Object>[],
  'meta': {
    'pagination': {'total': total},
  },
});

/// Seeds the dollar so money renders: `Formatter.money` returns `''` for a
/// currency the statics do not hold.
Future<void> seedUsd(Services services, {String companyId = 'co1'}) async {
  await services.statics.applyStatic(<String, dynamic>{
    'currencies': [
      {
        'id': '1',
        'name': 'US Dollar',
        'code': 'USD',
        'symbol': r'$',
        'precision': 2,
        'thousand_separator': ',',
        'decimal_separator': '.',
        'swap_currency_symbol': false,
        'exchange_rate': 1,
      },
    ],
  });
  services.invalidateFormatter(companyId);
}

/// Mounts [screen] over a fixture seeded by [seed], waits for [ready], runs
/// [body], and tears down **whatever happens** — in the test body, not
/// `addTearDown`: an embedded list leaves a debounce timer pending and the
/// binding checks for those before any tear-down callback runs. Without the
/// `finally`, a failed `expect` also left the fixture open and a second,
/// misleading "Timer still pending" failure behind it.
///
/// The window is pane-wide and tall by default, so the tab strip and the
/// first rows of a list are on screen below the profile cards — most tests
/// tap tabs and read rows, and are not about scrolling.
void recordScreenTest(
  String description, {
  required Future<void> Function(Services services) seed,
  required Widget Function() screen,
  required Finder Function() ready,
  required Future<void> Function(WidgetTester tester, RecordScreen screen) body,
  http.Client? httpClient,
  bool online = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
  List<FakeCompany> otherCompanies = const [],
  Size size = const Size(480, 2000),
  Future<void> Function(WidgetTester tester, RecordScreen screen)? beforeSettle,
}) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late ShellFixture fixture;
    await tester.runAsync(() async {
      fixture = await buildFixture(
        companies: [company, ...otherCompanies],
        currentCompanyId: company.id,
        closeStreamsSynchronously: true,
        httpClient: httpClient,
        online: online,
      );
      await seedUsd(fixture.services, companyId: company.id);
      await seed(fixture.services);
    });
    final mounted = RecordScreen(tester, fixture);
    try {
      await tester.pumpWidget(
        Provider<Services>.value(
          value: fixture.services,
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: screen(),
          ),
        ),
      );
      // Before any fake time has passed — i.e. before the 300 ms re-check.
      await beforeSettle?.call(tester, mounted);
      await mounted.untilFound(ready(), 'the record');
      await body(tester, mounted);
    } finally {
      await mounted.dispose();
    }
  });
}
