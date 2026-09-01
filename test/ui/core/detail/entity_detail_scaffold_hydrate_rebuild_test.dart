import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';

import '../../../_localization_helper.dart';

/// `hydrate`'s completion used to `setState` unconditionally. `_hydrating` is
/// read by the spinner gate ONLY while the item is null, so once content has
/// painted that rebuild changes nothing visible — but it re-runs the whole
/// body, and every descendant that builds a Drift stream inside `build` then
/// re-subscribes and blanks itself back to `AsyncSnapshot.nothing()`. That is
/// the "fields flicker a second time, after the record has already appeared"
/// half of the bug.

void main() {
  testWidgets('a hydrate completing after the body has painted does not '
      'rebuild it', (tester) async {
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);
    final fetch = Completer<void>();
    var builds = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: EntityDetailScaffold<String>(
          id: 'x',
          vm: vm,
          hydrate: () => fetch.future,
          emptyTitle: 'Not found',
          bodyBuilder: (context, item) {
            builds++;
            return Text(item);
          },
        ),
      ),
    );

    // Drift wins the race: the record paints while the fetch is still open.
    rows.add('Acme');
    await tester.pump();
    expect(find.text('Acme'), findsOneWidget);
    final buildsAfterPaint = builds;
    expect(buildsAfterPaint, greaterThan(0));

    fetch.complete();
    await tester.pump();
    await tester.pump();

    expect(
      builds,
      buildsAfterPaint,
      reason:
          'hydrate completion repainted an '
          'already-resolved body',
    );
  });

  testWidgets('a hydrate completing while the record is still absent DOES '
      'rebuild, so the spinner can give way to the empty state', (
    tester,
  ) async {
    final rows = StreamController<String?>();
    addTearDown(rows.close);
    final vm = GenericDetailViewModel<String>.bound(rows.stream);
    addTearDown(vm.dispose);
    final fetch = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: EntityDetailScaffold<String>(
          id: 'x',
          vm: vm,
          hydrate: () => fetch.future,
          emptyTitle: 'Not found',
          bodyBuilder: (context, item) => Text(item),
        ),
      ),
    );
    rows.add(null);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    fetch.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Not found'), findsOneWidget);
  });
}
