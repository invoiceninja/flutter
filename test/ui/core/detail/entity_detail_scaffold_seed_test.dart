import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';
import 'package:admin/ui/core/list/master_detail_nav_scope.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';

import '../../../_localization_helper.dart';

/// The row-to-row swap in the master-detail pane.
///
/// The router re-keys the detail subtree per `:id`, so clicking a different row
/// builds a fresh screen State and a fresh VM whose item is null until Drift's
/// first — asynchronous — emission. That gap used to paint a full-pane spinner
/// and drop the header's action cluster (collapsing the header's height and
/// re-growing it), i.e. the pane visibly blinked on every click.
///
/// The fix is a synchronous seed: `EntityDetailScaffold` reads the clicked row
/// straight out of the list's last snapshot via `MasterDetailNavController`.
///
/// **These tests assert on a single `pump`.** That discipline *is* the
/// assertion — `pumpAndSettle` would let the stream emit and hide the very
/// frame the bug lived in. Do not relax it.

Future<void> _pump(
  WidgetTester tester, {
  required GenericDetailViewModel<String> vm,
  required String id,
  MasterDetailNavController? controller,
  Future<void> Function()? hydrate,
  Widget Function(BuildContext, String)? actionsForItem,
}) {
  final scaffold = EntityDetailScaffold<String>(
    id: id,
    vm: vm,
    hydrate: hydrate,
    actionsForItem: actionsForItem,
    emptyTitle: 'Not found',
    bodyBuilder: (context, item) => Text(item),
  );
  return tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: controller == null
          ? scaffold
          : MasterDetailNavScope(controller: controller, child: scaffold),
    ),
  );
}

MasterDetailNavController _listShowing(List<String> ids, {String? selected}) =>
    MasterDetailNavController()..update(
      selectedId: selected,
      itemIds: ids,
      items: [for (final id in ids) id.toUpperCase()],
    );

void main() {
  testWidgets('paints the clicked row on the FIRST frame, with no spinner', (
    tester,
  ) async {
    // A VM that never emits: everything on screen must come from the seed.
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);

    await _pump(
      tester,
      vm: vm,
      id: 'b',
      controller: _listShowing(['a', 'b'], selected: 'b'),
      hydrate: () => Completer<void>().future, // never completes
    );

    expect(find.text('B'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('keeps the header action cluster mounted on the first frame', (
    tester,
  ) async {
    // The other half of the blink: `hasHeaderContent` is gated on a non-null
    // item, so without a seed the actions row is replaced by a zero-height
    // Spacer and the header collapses, then re-grows when the stream lands.
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);

    await _pump(
      tester,
      vm: vm,
      id: 'b',
      controller: _listShowing(['a', 'b'], selected: 'b'),
      hydrate: () => Completer<void>().future,
      actionsForItem: (context, item) =>
          SizedBox(height: 40, child: Text('actions:$item')),
    );

    expect(find.text('actions:B'), findsOneWidget);
  });

  testWidgets('a record that resolves to null falls through to the empty '
      'state — the seed must not resurrect it', (tester) async {
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);

    await _pump(
      tester,
      vm: vm,
      id: 'b',
      controller: _listShowing(['a', 'b'], selected: 'b'),
      hydrate: () async {},
    );
    expect(find.text('B'), findsOneWidget);

    // Deleted server-side between the list render and the watch resolving.
    rows.add(null);
    await tester.pump();
    await tester.pump();

    expect(find.text('B'), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('the live value wins over the seed once it arrives', (
    tester,
  ) async {
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);

    await _pump(
      tester,
      vm: vm,
      id: 'b',
      controller: _listShowing(['a', 'b'], selected: 'b'),
    );
    expect(find.text('B'), findsOneWidget);

    rows.add('B (renamed)');
    await tester.pump();

    expect(find.text('B (renamed)'), findsOneWidget);
    expect(find.text('B'), findsNothing);
  });

  testWidgets('a row the list never rendered keeps the spinner (deep link, '
      'command palette, cold start)', (tester) async {
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);

    await _pump(
      tester,
      vm: vm,
      id: 'zz', // not in the list snapshot
      controller: _listShowing(['a', 'b'], selected: 'zz'),
      hydrate: () => Completer<void>().future,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('no MasterDetailNavScope at all keeps the spinner (the '
      'settings-hosted detail screens)', (tester) async {
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);

    await _pump(
      tester,
      vm: vm,
      id: 'b',
      hydrate: () => Completer<void>().future,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a watch stream that errors drops the seed instead of freezing '
      'the pane on it', (tester) async {
    // The seed raised the stakes on `bindStream` having no `onError`: a stuck
    // `isResolving` used to mean a visible spinner, but would now mean a
    // plausible frozen record that never updates for the rest of the session.
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);

    await _pump(
      tester,
      vm: vm,
      id: 'b',
      controller: _listShowing(['a', 'b'], selected: 'b'),
      hydrate: () async {},
    );
    expect(find.text('B'), findsOneWidget);

    rows.addError(StateError('bad row'));
    await tester.pump();
    await tester.pump();

    expect(find.text('B'), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
  });

  testWidgets('a new vm for the same id drops the seed', (tester) async {
    // The seed is valid only for a vm's FIRST resolving cycle. Latent today
    // (the router re-keys per `:id`), but it is the condition that actually
    // matters, so `didUpdateWidget` guards it.
    final first = StreamController<String?>();
    final second = StreamController<String?>();
    addTearDown(first.close);
    addTearDown(second.close);
    final vm1 = GenericDetailViewModel<String>.bound(first.stream);
    final vm2 = GenericDetailViewModel<String>.bound(second.stream);
    addTearDown(vm1.dispose);
    addTearDown(vm2.dispose);
    final controller = _listShowing(['a', 'b'], selected: 'b');

    await _pump(tester, vm: vm1, id: 'b', controller: controller);
    expect(find.text('B'), findsOneWidget);

    await _pump(tester, vm: vm2, id: 'b', controller: controller);
    await tester.pump();

    expect(find.text('B'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a seed of the wrong type is ignored rather than thrown on', (
    tester,
  ) async {
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);

    final controller = MasterDetailNavController()
      ..update(selectedId: 'b', itemIds: ['b'], items: [42]);

    await _pump(
      tester,
      vm: vm,
      id: 'b',
      controller: controller,
      hydrate: () => Completer<void>().future,
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
