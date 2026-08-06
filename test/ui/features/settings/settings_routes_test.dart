import 'package:admin/app/entity_modules.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/settings/settings_routes.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Structural guards on the `/settings` route tree.
///
/// go_router emits one `Page` per matched route in the chain, so nesting is
/// what defines the back stack. Issue #8: the Integrations destinations hung
/// off a top-level `/settings/integrations` route whose own page was an orphan
/// (its sidebar section had been removed), so backing out of Analytics landed
/// on a screen the user had never visited. These assertions are cheap and
/// catch a re-introduction without booting the app.
GoRoute? _find(List<RouteBase> routes, String path) {
  for (final r in routes) {
    if (r is GoRoute && r.path == path) return r;
  }
  return null;
}

/// Every path pattern registered under `/settings`, with parent and child
/// segments joined the way go_router does — e.g.
/// `/settings/tags/:id/edit`.
Set<String> _registeredPatterns(List<RouteBase> routes, String prefix) {
  final out = <String>{};
  for (final r in routes) {
    if (r is! GoRoute) continue;
    final full = '$prefix/${r.path}';
    out.add(full);
    out.addAll(_registeredPatterns(r.routes, full));
  }
  return out;
}

void main() {
  group('settings route tree', () {
    test('no top-level `integrations` route — it would be a phantom page', () {
      expect(_find(settingsRoutes, 'integrations'), isNull);
    });

    test('Integrations destinations are children of the account management '
        'shell, so back returns to the tab they were opened from', () {
      final hub = _find(settingsRoutes, 'account_management/integrations');
      expect(
        hub,
        isNotNull,
        reason: 'the Integrations tab must own its sub-routes',
      );
      expect(
        hub!.routes.whereType<GoRoute>().map((r) => r.path),
        containsAll(<String>[
          'api_tokens',
          'api_webhooks',
          'analytics',
          'quickbooks',
        ]),
      );
      // The shell page has to be buildable — a builder-less parent would
      // contribute no page and back would skip to the settings list.
      expect(hub.pageBuilder ?? hub.builder, isNotNull);
    });

    test('the `:tab` pattern excludes slugs that own sub-routes, so each URL '
        'matches exactly one route', () {
      final tabRoute = settingsRoutes
          .whereType<GoRoute>()
          .where((r) => r.path.startsWith('account_management/:tab'))
          .single;
      expect(tabRoute.path, isNot(contains('integrations')));
      expect(tabRoute.path, contains('overview'));
    });

    test('`account_management/plan` is a redirect-only heal route', () {
      // `plan` is the shell's empty-slug default tab, so the URL matches no
      // page. Callers still reach for it, and nav_state_persister would then
      // save the dead location and re-open the route-error view every launch.
      final plan = _find(settingsRoutes, 'account_management/plan');
      expect(plan, isNotNull);
      expect(plan!.redirect, isNotNull);
      expect(
        plan.pageBuilder ?? plan.builder,
        isNull,
        reason: 'a redirect-only route must contribute no page',
      );
    });

    // Settings entity blocks invert the entity-branch shape: `:id` IS the edit
    // form, so nothing lives at `:id/edit`. But `entityRecordPath`
    // (router.dart), the outbox row "Open" action, and the sync listener's
    // validation / conflict actions all append `/edit` for a detail-less
    // entity. Without the `_editAlias` redirect those links land on the
    // route-error view — which is exactly what nine wired entities did.
    test('every settings entity with an `:id` route also answers `:id/edit`', () {
      // Edited outside the router, so they have no record route at all:
      // `user` (the handler's routePath has no route; the outbox points these
      // rows at /settings/user_details) and `design` (a modal — custom_designs
      // is only an Invoice Design tab slug). Both are special-cased in
      // `outbox_screen._destinationFor`.
      const editedOutsideTheRouter = {EntityType.user, EntityType.design};

      final patterns = _registeredPatterns(settingsRoutes, '/settings');
      final missing = <String>[];
      final checked = <String>[];

      // Disabled-but-routed entities (tax_rate, design) count too: they still
      // resolve through the registry, so the outbox / sync listener can still
      // build a record URL for them.
      for (final spec in [...kWiredEntityModules, ...kDisabledEntityModules]) {
        if (!spec.routePath.startsWith('/settings/')) continue;
        if (editedOutsideTheRouter.contains(spec.type)) continue;
        if (!patterns.contains('${spec.routePath}/:id')) continue;
        checked.add(spec.type.name);
        if (!patterns.contains('${spec.routePath}/:id/edit')) {
          missing.add('${spec.type.name} → ${spec.routePath}/:id/edit');
        }
      }

      // Guards against the assertion below going vacuous if the walker or the
      // routePath shape ever drifts — these nine are the entities the missing
      // alias actually stranded.
      expect(
        checked,
        containsAll(<String>[
          'token',
          'webhook',
          'tag',
          'taxRate',
          'taskStatus',
          'paymentTerm',
          'schedule',
          'group',
          'transactionRule',
        ]),
      );

      expect(
        missing,
        isEmpty,
        reason:
            'these entities generate a `<root>/<id>/edit` URL with no matching '
            'route — attach `_editAlias()` to their `:id` route',
      );
    });
  });

  // The tree shape above is only half the story: what the user feels is the
  // page stack go_router synthesizes from it. These drive the real
  // `tabbedSettingsRoutePair` output with a stub shell.
  group('tabbedSettingsRoutePair sub-routes', () {
    late GoRouter router;

    setUp(() {
      _StubShell.mountCount = 0;
      router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Text('settings-list'),
            routes: tabbedSettingsRoutePair(
              path: 'account_management',
              pageKey: 'account_management_shell',
              tabSlugs: const ['overview', 'integrations'],
              shellBuilder: (initialTab) => _StubShell(initialTab: initialTab),
              tabSubRoutes: {
                'integrations': [
                  GoRoute(
                    path: 'analytics',
                    builder: (_, _) => const Text('analytics'),
                  ),
                ],
              },
            ),
          ),
        ],
      );
    });

    tearDown(() => router.dispose());

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => SettingsLevelController(),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    int stackDepth() =>
        router.routerDelegate.currentConfiguration.matches.length;

    // Covered pages keep `maintainState: true`, so `find.text` still matches
    // them — assert on the resolved location, which can't be ambiguous.
    String location() => router.routerDelegate.currentConfiguration.uri.path;

    testWidgets('a sub-route stacks on the shell, and back returns to it with '
        'the owning tab still selected', (tester) async {
      await pump(tester);

      router.go('/settings/account_management/integrations');
      await tester.pumpAndSettle();
      expect(find.text('shell:integrations'), findsOneWidget);
      expect(stackDepth(), 2, reason: '/settings + shell');

      router.go('/settings/account_management/integrations/analytics');
      await tester.pumpAndSettle();
      expect(find.text('analytics'), findsOneWidget);
      expect(stackDepth(), 3, reason: '/settings + shell + analytics');

      router.pop();
      await tester.pumpAndSettle();
      // The regression: this used to land on an orphan `/settings/integrations`
      // page instead of the tab the user opened Analytics from.
      expect(location(), '/settings/account_management/integrations');
      expect(stackDepth(), 2);
      expect(find.text('shell:integrations'), findsOneWidget);
    });

    testWidgets('the shell is never remounted, so the tab state survives the '
        'round trip', (tester) async {
      await pump(tester);

      router.go('/settings/account_management');
      await tester.pumpAndSettle();
      expect(_StubShell.mountCount, 1);

      // Bare pair route -> explicit sub-route parent -> child -> back.
      for (final loc in [
        '/settings/account_management/integrations',
        '/settings/account_management/integrations/analytics',
      ]) {
        router.go(loc);
        await tester.pumpAndSettle();
      }
      router.pop();
      await tester.pumpAndSettle();

      expect(
        _StubShell.mountCount,
        1,
        reason: 'the shared page key must keep one shell Element alive',
      );
    });

    testWidgets('sibling tabs still resolve through the :tab pattern', (
      tester,
    ) async {
      await pump(tester);

      router.go('/settings/account_management/overview');
      await tester.pumpAndSettle();
      expect(location(), '/settings/account_management/overview');
      expect(find.text('shell:overview'), findsOneWidget);
      expect(stackDepth(), 2);
    });

    testWidgets('the `:tab` route is dropped when every slug owns sub-routes', (
      tester,
    ) async {
      // An empty `:tab()` alternation is not a parse error — go_router's
      // patternToRegExp needs a character inside the parens, so `:tab`
      // degrades to a bare parameter and `()` becomes a literal, leaving a
      // route that silently matches nothing. Emit nothing instead.
      final routes = tabbedSettingsRoutePair(
        path: 'only_tab',
        pageKey: 'only_tab_shell',
        tabSlugs: const ['solo'],
        shellBuilder: (initialTab) => _StubShell(initialTab: initialTab),
        tabSubRoutes: {
          'solo': [
            GoRoute(path: 'child', builder: (_, _) => const Text('child')),
          ],
        },
      );

      expect(routes.whereType<GoRoute>().map((r) => r.path), [
        'only_tab',
        'only_tab/solo',
      ]);
    });
  });

  // The structural test above proves the alias is attached in the real tree;
  // this proves the construction actually resolves — a redirect-only child of
  // `:id` must land on the edit screen without adding a page of its own.
  group('`:id/edit` alias', () {
    testWidgets('redirects onto the :id screen and adds no page', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Text('settings-list'),
            routes: [
              GoRoute(
                path: 'tags',
                builder: (_, _) => const Text('tag-list'),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) =>
                        Text('tag-edit:${state.pathParameters['id']}'),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        redirect: (_, state) => stripEditSuffix(state.uri),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.go('/settings/tags/tag1/edit');
      await tester.pumpAndSettle();

      final config = router.routerDelegate.currentConfiguration;
      expect(config.uri.path, '/settings/tags/tag1');
      expect(find.text('tag-edit:tag1'), findsOneWidget);
      expect(
        config.matches.length,
        3,
        reason: '/settings + tags + :id — the alias contributes no page',
      );
    });
  });

  group('stripEditSuffix', () {
    test('strips a trailing /edit', () {
      expect(
        stripEditSuffix(Uri.parse('/settings/tags/tag1/edit')),
        '/settings/tags/tag1',
      );
    });

    test('preserves the query string', () {
      expect(
        stripEditSuffix(Uri.parse('/settings/tags/tag1/edit?view=full')),
        '/settings/tags/tag1?view=full',
      );
    });

    test('leaves a location without the suffix untouched', () {
      expect(
        stripEditSuffix(Uri.parse('/settings/tags/tag1')),
        '/settings/tags/tag1',
      );
    });

    test('only matches a whole trailing segment', () {
      // Substring matching would mangle an id that merely ends in "edit".
      expect(
        stripEditSuffix(Uri.parse('/settings/tags/edited')),
        '/settings/tags/edited',
      );
    });
  });
}

/// Stands in for a tabbed settings shell: renders the tab it was handed and
/// counts mounts so a test can prove the Element was reused.
class _StubShell extends StatefulWidget {
  const _StubShell({this.initialTab});

  final String? initialTab;

  static int mountCount = 0;

  @override
  State<_StubShell> createState() => _StubShellState();
}

class _StubShellState extends State<_StubShell> {
  @override
  void initState() {
    super.initState();
    _StubShell.mountCount++;
  }

  @override
  Widget build(BuildContext context) =>
      Text('shell:${widget.initialTab ?? 'plan'}');
}
