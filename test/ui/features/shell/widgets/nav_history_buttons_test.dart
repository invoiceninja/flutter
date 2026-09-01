import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/nav_history_controller.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/features/shell/widgets/nav_history_buttons.dart';
import 'package:admin/app/native_window.dart';

/// Targets the visible affordances for [NavHistoryController] — the sidebar
/// back/forward buttons and the mouse thumb-button listener. The controller
/// itself is covered by `test/app/nav_history_controller_test.dart`; here we
/// drive it through the same fake-router seam and assert the widgets.

class _FakeRouter extends ChangeNotifier {
  String path = '/';
  void go(String next) {
    path = next;
    notifyListeners();
  }
}

AuthSession _session() => AuthSession(
  baseUrl: 'https://example.com',
  isHosted: true,
  accountId: 'acc',
  companies: const [],
  currentCompanyId: 'co_1',
);

ThemeData _theme() => ThemeData.light().copyWith(
  extensions: <ThemeExtension<dynamic>>[InTheme.light],
);

void main() {
  late _FakeRouter router;
  late ValueNotifier<AuthSession?> session;
  late NavHistoryController history;

  setUp(() {
    router = _FakeRouter();
    session = ValueNotifier<AuthSession?>(_session());
    history = NavHistoryController(
      changes: router,
      currentPath: () => router.path,
      navigate: router.go,
      session: session,
    );
  });

  tearDown(() {
    history.dispose();
    session.dispose();
  });

  Widget wrap(Widget child, {GlobalKey<ScaffoldState>? scaffoldKey}) {
    return ChangeNotifierProvider<NavHistoryController>.value(
      value: history,
      child: MaterialApp(
        theme: _theme(),
        home: Scaffold(key: scaffoldKey, body: child),
      ),
    );
  }

  IconButton buttonWith(WidgetTester tester, IconData icon) =>
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));

  testWidgets('both arrows are disabled with an empty history', (tester) async {
    await tester.pumpWidget(wrap(const NavHistoryButtons()));

    expect(buttonWith(tester, Icons.arrow_back).onPressed, isNull);
    expect(buttonWith(tester, Icons.arrow_forward).onPressed, isNull);
  });

  testWidgets('compact pair fits the 64-px collapsed rail', (tester) async {
    await tester.pumpWidget(
      wrap(const SizedBox(width: 64, child: NavHistoryButtons(compact: true))),
    );
    // Two 32-px buttons fill the rail exactly; a RenderFlex overflow here
    // would throw and fail the test.
    expect(find.byType(IconButton), findsNWidgets(2));
  });

  // The macOS window-caption row hosts the pair beside the traffic lights, and
  // AppKit centres those in a 28-px titlebar. The pair therefore has to *fit*
  // 28 — at its own sizing it measures 32 and grows the band, which drops it
  // 2 px below the buttons it is supposed to sit level with.
  testWidgets('an explicit height is pinned, not merely floored', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(const NavHistoryButtons(height: kFallbackCaptionHeight)),
    );

    for (final icon in [Icons.arrow_back, Icons.arrow_forward]) {
      final size = tester.getSize(find.widgetWithIcon(IconButton, icon));
      // 28, not the 32 the default `minimumSize` would otherwise win.
      expect(size.height, kFallbackCaptionHeight);
      // Width is unchanged — only the band constrains the height.
      expect(size.width, 32);
    }
  });

  group('touch density (issue #11)', () {
    testWidgets('touch grows both arrows to the touch target', (tester) async {
      await tester.pumpWidget(wrap(const NavHistoryButtons(touch: true)));

      for (final icon in [Icons.arrow_back, Icons.arrow_forward]) {
        final size = tester.getSize(find.widgetWithIcon(IconButton, icon));
        expect(size.height, greaterThanOrEqualTo(InSizes.touchTarget));
        expect(size.width, greaterThanOrEqualTo(InSizes.touchTarget));
      }
    });

    testWidgets('compact + touch grows height only — 2x44 wide would overflow '
        'the 64-px collapsed rail', (tester) async {
      await tester.pumpWidget(
        wrap(
          const SizedBox(
            width: 64,
            child: NavHistoryButtons(compact: true, touch: true),
          ),
        ),
      );
      // An overflow here throws and fails the test.
      for (final icon in [Icons.arrow_back, Icons.arrow_forward]) {
        final size = tester.getSize(find.widgetWithIcon(IconButton, icon));
        expect(size.height, greaterThanOrEqualTo(InSizes.touchTarget));
        expect(size.width, 32);
      }
    });
  });

  testWidgets('back walks to the previous location, forward returns', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const NavHistoryButtons()));

    router.go('/invoices/i_1');
    // An in-cell client link navigates with `?view=full`. History records it
    // normalized (`stripTransientQuery`) — the full-screen pane flag is a
    // display mode, never a place — so walking forward lands on the bare path.
    router.go('/clients/c_1?view=full');
    await tester.pump();

    expect(buttonWith(tester, Icons.arrow_back).onPressed, isNotNull);
    expect(buttonWith(tester, Icons.arrow_forward).onPressed, isNull);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
    await tester.pump();
    expect(router.path, '/invoices/i_1');
    expect(buttonWith(tester, Icons.arrow_back).onPressed, isNull);
    expect(buttonWith(tester, Icons.arrow_forward).onPressed, isNotNull);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_forward));
    await tester.pump();
    expect(router.path, '/clients/c_1');
  });

  testWidgets('popDrawerFirst dismisses the drawer, then navigates', (
    tester,
  ) async {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<NavHistoryController>.value(
        value: history,
        child: MaterialApp(
          theme: _theme(),
          home: Scaffold(
            key: scaffoldKey,
            drawer: const Drawer(
              child: NavHistoryButtons(popDrawerFirst: true),
            ),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );

    router.go('/invoices/i_1');
    router.go('/clients/c_1');
    scaffoldKey.currentState!.openDrawer();
    await tester.pumpAndSettle();
    expect(scaffoldKey.currentState!.isDrawerOpen, isTrue);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(scaffoldKey.currentState!.isDrawerOpen, isFalse);
    expect(router.path, '/invoices/i_1');
  });

  testWidgets('mouse thumb buttons drive back and forward', (tester) async {
    await tester.pumpWidget(
      wrap(const NavHistoryMouseListener(child: SizedBox.expand())),
    );

    router.go('/invoices/i_1');
    router.go('/clients/c_1');
    await tester.pump();

    final target = tester.getCenter(find.byType(SizedBox));

    // Thumb "back" (button 4).
    final back = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    await back.down(target);
    await back.up();
    await back.removePointer();
    await tester.pump();
    expect(router.path, '/invoices/i_1');

    // Thumb "forward" (button 5).
    final forward = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kForwardMouseButton,
    );
    await forward.down(target);
    await forward.up();
    await forward.removePointer();
    await tester.pump();
    expect(router.path, '/clients/c_1');
  });

  testWidgets('touch taps never trigger history navigation', (tester) async {
    await tester.pumpWidget(
      wrap(const NavHistoryMouseListener(child: SizedBox.expand())),
    );

    router.go('/invoices/i_1');
    router.go('/clients/c_1');
    await tester.pump();

    final touch = await tester.createGesture(kind: PointerDeviceKind.touch);
    await touch.down(tester.getCenter(find.byType(NavHistoryMouseListener)));
    await touch.up();
    await touch.removePointer();
    await tester.pump();
    expect(router.path, '/clients/c_1');
  });

  // The buttons are the ONLY history affordance that works without a hardware
  // keyboard (`Cmd/Alt+←/→`) or a multi-button mouse (`NavHistoryMouseListener`),
  // so on a tablet/phone they're the difference between "go back" existing and
  // not. They were briefly unmounted from the sidebar; this pins them there.
  //
  // A source scan rather than a pump: `InSidebar` needs the whole `Services`
  // graph, and the property under test is simply "still wired up".
  test('NavHistoryButtons stays mounted in the sidebar', () {
    final sidebar = File(
      'lib/ui/features/shell/widgets/in_sidebar.dart',
    ).readAsStringSync();
    expect(
      sidebar.contains('NavHistoryButtons('),
      isTrue,
      reason:
          'in_sidebar.dart must render NavHistoryButtons — without it there is '
          'no pointer-reachable back/forward on touch platforms.',
    );
  });
}
