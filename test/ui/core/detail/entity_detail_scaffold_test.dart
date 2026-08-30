import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/theme.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';

import '../../../_localization_helper.dart';

/// The uncached-record path.
///
/// `GenericDetailViewModel` clears `isResolving` on the FIRST Drift emission,
/// and for a record that isn't cached that emission is `null` — so without
/// `hydrate`'s own in-flight flag the screen shows "not found" for the length
/// of the network fetch and then flips to content. A deep-link recipient hits
/// that every time, since the whole premise is that they have never opened the
/// record.

Future<void> _pump(
  WidgetTester tester, {
  required GenericDetailViewModel<String> vm,
  Future<void> Function()? hydrate,
  Widget? emptyAction,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: EntityDetailScaffold<String>(
      vm: vm,
      hydrate: hydrate,
      emptyAction: emptyAction,
      emptyTitle: 'Not found',
      bodyBuilder: (context, item) => Text(item),
    ),
  ),
);

void main() {
  testWidgets('shows the spinner, not the empty state, while a hydrate for an '
      'uncached record is in flight', (tester) async {
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);
    final fetch = Completer<void>();

    await _pump(tester, vm: vm, hydrate: () => fetch.future);
    // Drift answers first, and for an uncached row it answers `null`.
    rows.add(null);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);

    // The fetch lands and the row arrives.
    fetch.complete();
    rows.add('Acme');
    await tester.pump();
    await tester.pump();
    expect(find.text('Acme'), findsOneWidget);
  });

  testWidgets('falls through to the empty state once the hydrate completes '
      'with the record still absent', (tester) async {
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);

    await _pump(
      tester,
      vm: vm,
      hydrate: () async {},
      emptyAction: const Text('Clients'),
    );
    rows.add(null);
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(EmptyState), findsOneWidget);
    // A dead link must not be a dead end.
    expect(find.text('Clients'), findsOneWidget);
  });

  testWidgets('no hydrate: unchanged behaviour', (tester) async {
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);

    await _pump(tester, vm: vm);
    rows.add(null);
    await tester.pump();

    expect(find.byType(EmptyState), findsOneWidget);
  });
}
