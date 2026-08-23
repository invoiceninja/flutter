// Regression test for the full-width-editor auto-promotion redirect in
// `MasterDetailLayout` (`lib/ui/core/list/master_detail_layout.dart`).
//
// The bug: the redirect that rewrites `/x/:id/edit` → `/x/:id/edit?view=full`
// for entities that default to full-width was deduped by an instance field
// (`_lastRedirectKey`) that was never cleared when the pane closed. Re-opening
// the *same* edit URL (edit a row, close, edit it again) found the key still
// equal and skipped the promotion, dropping the user into the narrow
// slide-over instead of the full-width editor.
//
// The route block is reproduced inline (the production `buildEntityRouteBlock`
// attaches an `onExit` guard that reads a `Services` provider — irrelevant to
// the redirect logic under test). The ShellRoute → MasterDetailLayout wiring
// mirrors `buildEntityRouteBlock` exactly: hasPane = matched != basePath,
// viewMode = `?view`, id from path params.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../_localization_helper.dart';

void main() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));

  // Last `state.extra` observed by the edit builder. Each `pumpApp` resets it.
  // Used by the extras-preservation tests to assert that the auto-promote
  // redirect (and the F-key toggle) propagated `state.extra` through their
  // internal `go(...)` calls. The detail builder writes only when state.extra
  // is non-null so an initial null-extra navigation doesn't clobber a prior
  // sentinel during the redirect's first frame.
  Object? lastEditExtra;

  ShellRoute block(String basePath) {
    return ShellRoute(
      pageBuilder: (context, state, child) => NoTransitionPage<void>(
        key: ValueKey('master_detail:$basePath'),
        child: Builder(
          builder: (ctx) {
            final hasPane = state.matchedLocation != basePath;
            return MasterDetailLayout(
              basePath: basePath,
              list: stub('${basePath}_LIST'),
              rightPane: child,
              hasPane: hasPane,
              viewMode: state.uri.queryParameters['view'],
            );
          },
        ),
      ),
      routes: [
        GoRoute(path: basePath, builder: (_, _) => const SizedBox.shrink()),
        GoRoute(
          path: '$basePath/:id',
          builder: (_, _) => stub('${basePath}_DETAIL'),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, state) {
                lastEditExtra = state.extra;
                return stub('${basePath}_EDIT');
              },
            ),
          ],
        ),
      ],
    );
  }

  // `MasterDetailLayout` only engages the slide-over / redirect machinery on
  // wide (>= Breakpoints.slideOver == 1024) viewports.
  Future<GoRouter> pumpApp(WidgetTester tester) async {
    lastEditExtra = null;
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/things',
      routes: [
        block('/things'),
        // `/products` is in `_kEditDefaultsToSlide` — its edit must stay
        // slide-over (never promoted to `?view=full`).
        block('/products'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String currentUri(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets(
    'full-default entity: edit URL is promoted to ?view=full every time it '
    'is re-opened (the regression)',
    (tester) async {
      final router = await pumpApp(tester);

      // 1st open — promoted.
      router.go('/things/1/edit');
      await tester.pumpAndSettle();
      expect(currentUri(router), '/things/1/edit?view=full');

      // Close back to the bare list (pane gone).
      router.go('/things');
      await tester.pumpAndSettle();
      expect(currentUri(router), '/things');

      // Re-open the SAME edit URL — must be promoted again, not deduped
      // into the slide-over.
      router.go('/things/1/edit');
      await tester.pumpAndSettle();
      expect(currentUri(router), '/things/1/edit?view=full');

      // A different row also promotes.
      router.go('/things');
      await tester.pumpAndSettle();
      router.go('/things/2/edit');
      await tester.pumpAndSettle();
      expect(currentUri(router), '/things/2/edit?view=full');
    },
  );

  testWidgets('full-default entity: detail stays slide-over (no ?view=full)', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    router.go('/things/1');
    await tester.pumpAndSettle();
    expect(currentUri(router), '/things/1');
  });

  testWidgets('slide-over-default entity (/products): edit is never promoted, '
      'on first or subsequent opens', (tester) async {
    final router = await pumpApp(tester);

    router.go('/products');
    await tester.pumpAndSettle();

    router.go('/products/1/edit');
    await tester.pumpAndSettle();
    expect(currentUri(router), '/products/1/edit');

    router.go('/products');
    await tester.pumpAndSettle();
    router.go('/products/1/edit');
    await tester.pumpAndSettle();
    expect(currentUri(router), '/products/1/edit');
  });

  // Regression guards for the seed-extra propagation through the auto-promote
  // redirect (`_toggleFullScreenInUrl`) — every cross-entity / clone "new X"
  // navigation passes its draft via `state.extra`, and a stripping redirect
  // silently empties the form.
  testWidgets(
    'auto-promote redirect preserves state.extra (seed draft survives ?view=full)',
    (tester) async {
      final router = await pumpApp(tester);

      router.go('/things/1/edit', extra: 'sentinel');
      await tester.pumpAndSettle();

      expect(currentUri(router), '/things/1/edit?view=full');
      expect(
        lastEditExtra,
        'sentinel',
        reason:
            'auto-promote re-issued go() must propagate state.extra so the '
            'seed draft is not stripped on its way into the full-width editor',
      );
    },
  );

  testWidgets(
    'F-key toggle preserves state.extra (full → slide keeps the seed)',
    (tester) async {
      final router = await pumpApp(tester);

      router.go('/things/1/edit', extra: 'sentinel');
      await tester.pumpAndSettle();
      expect(currentUri(router), '/things/1/edit?view=full');
      expect(lastEditExtra, 'sentinel');

      // The pane autofocuses inside `_PaneRoot`; F triggers
      // `_PaneToggleFullScreenIntent` → `_toggleFullScreenInUrl`.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.pumpAndSettle();

      expect(currentUri(router), '/things/1/edit');
      expect(
        lastEditExtra,
        'sentinel',
        reason: 'F-toggle must propagate state.extra through its go() call',
      );
    },
  );

  testWidgets('F-key toggle to slide does not infinite-re-promote', (
    tester,
  ) async {
    final router = await pumpApp(tester);

    router.go('/things/1/edit');
    await tester.pumpAndSettle();
    expect(currentUri(router), '/things/1/edit?view=full');

    // User explicitly de-promotes via F. The dedup `_lastRedirectKey` must
    // keep the auto-promote from re-firing on the rebuilt slide-mode URL,
    // or the user would be fighting the layout to leave full-screen.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(currentUri(router), '/things/1/edit');

    // A few extra frames in case any addPostFrameCallback is scheduled.
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
    expect(
      currentUri(router),
      '/things/1/edit',
      reason: 'auto-promote must not re-fire after a user-initiated F-toggle',
    );
  });
}
