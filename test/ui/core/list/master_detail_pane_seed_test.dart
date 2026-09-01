// End-to-end guard for the row-to-row swap in the master-detail pane.
//
// `entity_detail_scaffold_seed_test.dart` proves the scaffold renders a seed;
// this proves the seed is actually THERE when the pane mounts — i.e. that the
// list has published its snapshot before the router inflates the new detail
// subtree.
//
// The ordering argument is that the controller retains the PREVIOUS frame's
// snapshot, and the row being opened was necessarily in it (the user clicked
// it), so it holds regardless of which subtree Flutter rebuilds first. That is
// reasoning, not proof — hence this test, with a real GoRouter, a real
// `MasterDetailLayout`, and a list that writes to the controller exactly the
// way `EntityListScreenScaffold` does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';

import '../../../_localization_helper.dart';

/// A VM that never emits — everything the pane shows must come from the seed.
class _NeverResolves extends GenericDetailViewModel<String> {
  _NeverResolves() : super.bound(const Stream<String?>.empty());
}

/// Stands in for `EntityListScreenScaffold`: publishes ids + row objects to
/// the layout's controller on every build, and routes a tap to the record.
class _FakeList extends StatelessWidget {
  const _FakeList({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    final controller = MasterDetailNavScope.maybeOf(context);
    final selectedId = GoRouterState.of(context).pathParameters['id'];
    controller?.update(
      selectedId: selectedId,
      itemIds: rows.keys.toList(),
      items: rows.values.toList(),
    );
    return Scaffold(
      body: Column(
        children: [
          for (final id in rows.keys)
            TextButton(
              onPressed: () => GoRouter.of(context).go('/products/$id'),
              child: Text('row-$id'),
            ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('opening a second row paints it immediately — no spinner frame', (
    tester,
  ) async {
    // Wide enough for the slide-over branch (Breakpoints.slideOver == 1024).
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final vms = <String, _NeverResolves>{};
    addTearDown(() {
      for (final vm in vms.values) {
        vm.dispose();
      }
    });

    final router = GoRouter(
      initialLocation: '/products',
      routes: [
        ShellRoute(
          pageBuilder: (context, state, child) => NoTransitionPage<void>(
            key: const ValueKey('master_detail:/products'),
            child: Builder(
              builder: (ctx) => MasterDetailLayout(
                basePath: '/products',
                list: const _FakeList(rows: {'a': 'Widget A', 'b': 'Widget B'}),
                rightPane: child,
                hasPane: state.matchedLocation != '/products',
                viewMode: state.uri.queryParameters['view'],
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: '/products',
              builder: (_, _) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/products/:id',
              // Mirrors `buildEntityRouteBlock`: the detail subtree is re-keyed
              // per `:id`, so every row change is a full teardown + rebuild.
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return KeyedSubtree(
                  key: ValueKey('detail:/products:$id'),
                  child: EntityDetailScaffold<String>(
                    id: id,
                    vm: vms.putIfAbsent(id, _NeverResolves.new),
                    emptyTitle: 'Not found',
                    bodyBuilder: (context, item) => Text('detail:$item'),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    // Open the first row — the pane docks.
    await tester.tap(find.text('row-a'));
    await tester.pumpAndSettle();
    expect(find.text('detail:Widget A'), findsOneWidget);

    // Now the case that used to blink: swap to a different row. A single pump
    // after the tap, so the assertion lands on the first frame of the new
    // subtree — `pumpAndSettle` here would hide the bug entirely.
    await tester.tap(find.text('row-b'));
    await tester.pump();

    expect(find.text('detail:Widget B'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('detail:Widget A'), findsNothing);
  });
}
