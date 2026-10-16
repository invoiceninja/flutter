import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/settings/state/settings_reveal_controller.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// A settings search hit names a field; the page it opens scrolls to that
/// field and flashes it. `SettingsFormShell` does it for every settings page,
/// by finding the label's text — there is no anchor on any field.
void main() {
  /// A page far taller than the 600 px test window, so a field near the end
  /// starts well off-screen.
  Widget page() => SettingsFormShell(
    sections: [
      for (var i = 0; i < 40; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text('Field $i'),
        ),
    ],
  );

  ScrollPosition position(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  bool flashing(WidgetTester tester) => tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: find.byType(SettingsFormShell),
          matching: find.byType(CustomPaint),
        ),
      )
      .any((p) => p.foregroundPainter != null);

  Future<SettingsRevealController> pumpBare(WidgetTester tester) async {
    final reveal = SettingsRevealController();
    addTearDown(reveal.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        home: ChangeNotifierProvider<SettingsRevealController>.value(
          value: reveal,
          child: Scaffold(body: page()),
        ),
      ),
    );
    return reveal;
  }

  testWidgets('a requested field below the fold is scrolled to and flashed', (
    tester,
  ) async {
    final reveal = await pumpBare(tester);
    expect(position(tester).pixels, 0);
    expect(tester.getTopLeft(find.text('Field 30')).dy, greaterThan(600));

    reveal.reveal(route: '/settings/x', label: 'Field 30');
    // Found on one frame, confirmed still on the next two, then a 250 ms
    // scroll.
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(flashing(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 300));

    expect(position(tester).pixels, greaterThan(0));
    final y = tester.getTopLeft(find.text('Field 30')).dy;
    expect(y, inInclusiveRange(0, 600));
    expect(reveal.request, isNull, reason: 'a reveal is consumed once shown');

    // The flash runs its course and the painter stops drawing.
    await tester.pumpAndSettle();
  });

  testWidgets('a request made mid-search still waits for a still target', (
    tester,
  ) async {
    // A second request used to leave the first one's chain of post-frame
    // looks running beside its own: two looks a frame, the second always
    // "still" against the first, so the three-frame gate became one.
    final reveal = await pumpBare(tester);
    reveal.reveal(route: '/settings/x', label: 'Field 20');
    await tester.pump();
    reveal.reveal(route: '/settings/x', label: 'Field 30');

    // Found on the next frame, still on the two after, flashed from the
    // fourth (`_show` sets state; the painter is built a frame later). With
    // the old chain still running it painted a frame earlier.
    for (var i = 0; i < 3; i++) {
      await tester.pump();
    }
    expect(flashing(tester), isFalse, reason: 'two looks are not three');
    await tester.pump();
    expect(flashing(tester), isTrue);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Field 30')).dy,
      inInclusiveRange(0, 600),
    );
  });

  testWidgets('the flash lets go of its field once it has run', (tester) async {
    final reveal = await pumpBare(tester);
    reveal.reveal(route: '/settings/x', label: 'Field 30');
    await tester.pumpAndSettle();
    expect(flashing(tester), isFalse);
  });

  testWidgets('a label is matched whatever its case and trailing marker', (
    tester,
  ) async {
    final reveal = await pumpBare(tester);
    reveal.reveal(route: '/settings/x', label: '  field 35 ');
    await tester.pumpAndSettle();
    expect(position(tester).pixels, greaterThan(0));
  });

  testWidgets('a label the page does not render leaves it at the top', (
    tester,
  ) async {
    final reveal = await pumpBare(tester);
    reveal.reveal(route: '/settings/x', label: 'Nowhere To Be Found');

    // The page looks for a while — a tab body can arrive late — then gives
    // the request up, so it can't fire on some later visit.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(position(tester).pixels, 0);
    expect(flashing(tester), isFalse);
    expect(reveal.request, isNull);
  });

  testWidgets('a request for another page is left for that page', (
    tester,
  ) async {
    final reveal = SettingsRevealController();
    addTearDown(reveal.dispose);
    final router = GoRouter(
      initialLocation: '/settings/a',
      routes: [
        GoRoute(
          path: '/settings/a',
          builder: (_, _) => Scaffold(body: page()),
        ),
        GoRoute(
          path: '/settings/b',
          builder: (_, _) => Scaffold(body: page()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsRevealController>.value(
        value: reveal,
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    reveal.reveal(route: '/settings/b', label: 'Field 30');
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(position(tester).pixels, 0, reason: 'page a is not page b');
    expect(reveal.request, isNotNull, reason: 'still waiting for page b');

    // Navigating there is what the search does next — page b picks it up.
    router.go('/settings/b');
    await tester.pumpAndSettle();
    expect(position(tester).pixels, greaterThan(0));
    expect(reveal.request, isNull);
  });

  testWidgets('on a tabbed page only the tab the URL names flashes', (
    tester,
  ) async {
    // Both tabs render through `SettingsFormShell` and both carry the label;
    // a `TabBarView` keeps the outgoing tab built while the incoming one
    // slides in, and the stillness gate is what tells them apart.
    final reveal = SettingsRevealController();
    addTearDown(reveal.dispose);
    Widget tabBody(String tab) => SettingsFormShell(
      sections: [
        for (var i = 0; i < 40; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(i == (tab == 'a' ? 2 : 30) ? 'Common' : '$tab $i'),
          ),
      ],
    );
    // Siblings sharing one page key, as `tabbedSettingsRoutePair` registers
    // them, so a tab change keeps the same page (and its `TabController`).
    Page<void> page() =>
        NoTransitionPage(key: const ValueKey('s'), child: _Tabs(tabBody));
    final router = GoRouter(
      initialLocation: '/s',
      routes: [
        GoRoute(path: '/s', pageBuilder: (_, _) => page()),
        GoRoute(path: '/s/b', pageBuilder: (_, _) => page()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsRevealController>.value(
        value: reveal,
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Common'), findsOneWidget, reason: 'tab a is showing');

    // What a search hit does: ask, then go.
    reveal.reveal(route: '/s/b', label: 'Common');
    router.go('/s/b');
    await tester.pumpAndSettle();

    expect(find.text('b 0'), findsOneWidget, reason: 'tab b is showing');
    expect(position(tester).pixels, greaterThan(0));
    final y = tester.getTopLeft(find.text('Common')).dy;
    expect(y, inInclusiveRange(0, 600));
    expect(reveal.request, isNull);
  });

  test('a request nobody takes goes stale', () {
    var now = DateTime(2026, 1, 1, 12);
    final reveal = SettingsRevealController(now: () => now);
    addTearDown(reveal.dispose);
    reveal.reveal(route: '/settings/x', label: 'Field');
    expect(reveal.request, isNotNull);
    now = now.add(
      SettingsRevealController.lifetime + const Duration(seconds: 1),
    );
    expect(reveal.request, isNull);
  });

  test('every request is new, so the same field can be revealed twice', () {
    final reveal = SettingsRevealController();
    addTearDown(reveal.dispose);
    reveal.reveal(route: '/settings/x', label: 'Field');
    final first = reveal.request!.seq;
    reveal.consume(first);
    reveal.reveal(route: '/settings/x', label: 'Field');
    expect(reveal.request!.seq, greaterThan(first));
    // An old seq can't consume a newer request.
    reveal.consume(first);
    expect(reveal.request, isNotNull);
  });
}

/// A two-tab page that follows the URL the way `TabbedSettingsShell` does:
/// the tab is chosen from the path, and a later path change animates to the
/// new tab after the frame.
class _Tabs extends StatefulWidget {
  const _Tabs(this.body);
  final Widget Function(String tab) body;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final want = GoRouterState.of(context).uri.path.endsWith('/b') ? 1 : 0;
    if (want != _tabs.index) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabs.animateTo(want);
      });
    }
    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'A'),
            Tab(text: 'B'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [widget.body('a'), widget.body('b')],
      ),
    );
  }
}
