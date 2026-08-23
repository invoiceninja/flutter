// Regression test for the discard-confirmation *timing* on pane close in
// `MasterDetailLayout` (`lib/ui/core/list/master_detail_layout.dart`).
//
// The bug: closing a dirty edit/create pane with the X ran the slide-out
// animation FIRST and only then navigated, so the route's `onExit` discard
// guard fired AFTER the form had already slid off-screen. The "Discard
// changes?" prompt was useless — and "Keep editing" left the user staring at
// an empty, slid-away pane (the pane was never restored).
//
// The fix runs the same guard the router uses up-front, BEFORE the animation,
// gated to the same edit/create routes the router guards. Read-only detail
// panes (no `onExit` guard) must therefore still close without ever prompting,
// even when an unrelated editor elsewhere is dirty.
//
// The route block mirrors `buildEntityRouteBlock`: `/products` is a slide-over
// entity so the URL stays clean (no `?view=full`). The pane bodies render the
// real pane chrome (the X published by `_PaneRoot` via `MasterDetailPaneScope`)
// so the test taps the actual Close button.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

/// Minimal Services — the close path and the route's `onExit` guard only touch
/// `unsavedChangesGuard`.
class _FakeServices implements Services {
  _FakeServices(this.unsavedChangesGuard);
  @override
  final UnsavedChangesGuard unsavedChangesGuard;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Plain full-width list stub. Carries a top-left "deselect" button (clear of
/// the right-pinned pane) that fires the same `closePane` path a list tile uses
/// when the already-open row is clicked — so a test can prove that gesture
/// still collapses to the list, even from an edit route.
class _Stub extends StatelessWidget {
  const _Stub(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        Center(child: Text(label)),
        Positioned(
          top: 0,
          left: 0,
          child: TextButton(
            key: const ValueKey('deselect'),
            onPressed: () => MasterDetailNavScope.requestClose(
              context,
              basePath: '/products',
            ),
            child: const Text('deselect'),
          ),
        ),
      ],
    ),
  );
}

/// Pane body that renders the real pane chrome (the X / full-screen actions
/// published by `_PaneRoot`) so the test can tap the actual Close button, plus
/// a [label] to assert whether the pane is still mounted / on-screen.
class _PaneBody extends StatelessWidget {
  const _PaneBody(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    // Wide publishes the trailing actions row (X / full-screen); narrow
    // publishes a leading back arrow. Render whichever is present so the test
    // can tap the real chrome in either layout.
    final actions = MasterDetailPaneScope.paneActionsOf(context);
    final leading = MasterDetailPaneScope.paneLeadingOf(context);
    return Scaffold(
      body: Column(
        children: [
          if (leading != null) leading,
          if (actions != null) actions,
          Text(label),
        ],
      ),
    );
  }
}

void main() {
  String currentUri(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  // The pane's centre lies within the layout's rect only while it is docked;
  // once it has slid fully off the right edge the centre is past the screen.
  bool onScreen(WidgetTester tester, Finder f) => tester
      .getRect(find.byType(MasterDetailLayout))
      .contains(tester.getCenter(f));

  // `MasterDetailLayout` only engages the slide-over machinery on wide
  // (>= Breakpoints.slideOver == 1024) viewports.
  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required UnsavedChangesGuard guard,
    required ValueNotifier<bool> editDirty,
    Size size = const Size(1600, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget editPane() => UnsavedChangesScope(
      isDirty: () => editDirty.value,
      source: editDirty,
      onDiscard: () => editDirty.value = false,
      child: const _PaneBody('EDIT'),
    );

    // Mirrors `_confirmExitIfDirty` in router.dart — attached to edit/create
    // routes only.
    Future<bool> confirmExit(BuildContext context, GoRouterState state) =>
        context.read<Services>().unsavedChangesGuard.confirmIfDirty(context);

    final router = GoRouter(
      initialLocation: '/products',
      routes: [
        ShellRoute(
          pageBuilder: (context, state, child) => NoTransitionPage<void>(
            key: const ValueKey('master_detail:/products'),
            child: Builder(
              builder: (ctx) {
                final hasPane = state.matchedLocation != '/products';
                return MasterDetailLayout(
                  basePath: '/products',
                  list: const _Stub('LIST'),
                  rightPane: child,
                  hasPane: hasPane,
                  viewMode: state.uri.queryParameters['view'],
                );
              },
            ),
          ),
          routes: [
            GoRoute(
              path: '/products',
              builder: (_, _) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/products/new',
              builder: (_, _) => editPane(),
              onExit: confirmExit,
            ),
            GoRoute(
              path: '/products/:id',
              builder: (_, _) => const _PaneBody('DETAIL'),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, _) => editPane(),
                  onExit: confirmExit,
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(guard),
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets(
    'edit pane: a dirty close prompts BEFORE the slide-out — the form is still '
    'on-screen behind the dialog, and Keep editing leaves it open',
    (tester) async {
      final guard = UnsavedChangesGuard();
      final router = await pumpApp(
        tester,
        guard: guard,
        editDirty: ValueNotifier(true),
      );

      router.go('/products/1/edit');
      await tester.pumpAndSettle();
      expect(find.text('EDIT'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      // The prompt is up while the form is still docked on-screen. Pre-fix the
      // pane had already slid fully off-screen before this dialog appeared.
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(
        onScreen(tester, find.text('EDIT')),
        isTrue,
        reason: 'the edit form must still be on-screen when the prompt shows',
      );

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(currentUri(router), '/products/1/edit');
      expect(
        onScreen(tester, find.text('EDIT')),
        isTrue,
        reason: 'Keep editing must leave the form docked and usable',
      );
    },
  );

  testWidgets(
    'edit pane: Discard closes to the detail view (not the list) with no '
    'second prompt (the up-front discard resets the editor, so the onExit '
    're-check stays silent)',
    (tester) async {
      final guard = UnsavedChangesGuard();
      final router = await pumpApp(
        tester,
        guard: guard,
        editDirty: ValueNotifier(true),
      );

      router.go('/products/1/edit');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing); // no double prompt
      // Back from edit lands on the read-only detail, not the bare list.
      expect(currentUri(router), '/products/1');
      expect(find.text('DETAIL'), findsOneWidget);
      expect(find.text('EDIT'), findsNothing);
    },
  );

  testWidgets(
    'create pane (clone target /products/new): a dirty close prompts before '
    'the pane slides away',
    (tester) async {
      final guard = UnsavedChangesGuard();
      final router = await pumpApp(
        tester,
        guard: guard,
        editDirty: ValueNotifier(true),
      );

      router.go('/products/new');
      await tester.pumpAndSettle();
      expect(find.text('EDIT'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);
      expect(
        onScreen(tester, find.text('EDIT')),
        isTrue,
        reason: 'the create form must still be on-screen when the prompt shows',
      );
    },
  );

  testWidgets(
    'detail pane: closing never prompts, even when an unrelated editor is dirty '
    '(the close gate matches the routes that carry an onExit guard)',
    (tester) async {
      final guard = UnsavedChangesGuard();
      // Simulate a dirty editor preserved in another branch.
      final unregister = guard.register(
        isDirty: () => true,
        source: ValueNotifier(0),
        onDiscard: () {},
      );
      addTearDown(unregister);

      final router = await pumpApp(
        tester,
        guard: guard,
        editDirty: ValueNotifier(false),
      );

      router.go('/products/1'); // read-only detail — no onExit guard
      await tester.pumpAndSettle();
      expect(find.text('DETAIL'), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(currentUri(router), '/products');
      expect(find.text('DETAIL'), findsNothing);
    },
  );

  testWidgets(
    'edit pane (narrow): the back arrow closes to the detail view, not the list',
    (tester) async {
      final guard = UnsavedChangesGuard();
      final router = await pumpApp(
        tester,
        guard: guard,
        editDirty: ValueNotifier(false), // clean — no discard prompt
        size: const Size(800, 900), // < Breakpoints.slideOver (1024) → narrow
      );

      router.go('/products/1/edit');
      await tester.pumpAndSettle();
      expect(find.text('EDIT'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(currentUri(router), '/products/1');
      expect(find.text('DETAIL'), findsOneWidget);
      expect(find.text('EDIT'), findsNothing);
    },
  );

  testWidgets(
    'deselect (clicking the already-open row) still collapses to the list, '
    'even while editing — not to the detail like the pane X does',
    (tester) async {
      final guard = UnsavedChangesGuard();
      final router = await pumpApp(
        tester,
        guard: guard,
        editDirty: ValueNotifier(false), // clean — no discard prompt
      );

      router.go('/products/1/edit');
      await tester.pumpAndSettle();
      expect(find.text('EDIT'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('deselect')));
      await tester.pumpAndSettle();

      expect(currentUri(router), '/products');
      expect(find.text('EDIT'), findsNothing);
      expect(find.text('DETAIL'), findsNothing);
    },
  );
}
