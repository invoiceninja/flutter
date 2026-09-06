// Regression: every entity picker in the app resolved its selection by scanning
// the list it happened to be showing — a `watchPage(loadedPages: 100)` window,
// not the catalogue. A document referencing a record outside that window
// rendered a **blank field on a form that has a value**, with no error and
// nothing to click; and a `tmp_` id went blank the moment an offline-created
// record round-tripped, because the swap deletes the tmp row.
//
// `EntityPickerField` resolves by id through a second stream instead. It needs
// no `Services` — it takes stream builders — so these drive it directly.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';

import '../../../_localization_helper.dart';

class _Rec {
  const _Rec(this.id, this.name);
  final String id;
  final String name;
}

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String selectedId,
    required Stream<List<_Rec>> items,
    required Stream<_Rec?> Function(String) watchById,
    ValueChanged<_Rec?>? onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: EntityPickerField<_Rec>(
              label: 'Vendor',
              selectedId: selectedId,
              itemsStream: () => items,
              watchById: watchById,
              displayString: (r) => r.name.isEmpty ? r.id : r.name,
              idOf: (r) => r.id,
              onChanged: onChanged ?? (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders a selection that is NOT in the loaded window', (
    tester,
  ) async {
    // The bug: `items` is page 1 and the document points at something on page 3.
    await pump(
      tester,
      selectedId: 'far',
      items: Stream.value(const [_Rec('a', 'Acme'), _Rec('b', 'Bravo')]),
      watchById: (id) =>
          Stream.value(id == 'far' ? const _Rec('far', 'Far Supply') : null),
    );
    await tester.pump();

    expect(find.text('Far Supply'), findsOneWidget);
  });

  testWidgets('a tmp_ selection survives the create swap', (tester) async {
    // `repo.watch` routes a tmp id through id_remap and re-subscribes when the
    // alias lands, so the second emission carries the real row under the same
    // requested id. The field must not blank in between.
    final byId = StreamController<_Rec?>.broadcast(sync: true);
    final items = StreamController<List<_Rec>>.broadcast(sync: true);
    addTearDown(byId.close);
    addTearDown(items.close);

    await pump(
      tester,
      selectedId: 'tmp_1f3c',
      items: items.stream,
      watchById: (_) => byId.stream,
    );

    items.add(const [_Rec('tmp_1f3c', 'Acme')]);
    byId.add(const _Rec('tmp_1f3c', 'Acme'));
    await tester.pump();
    expect(find.text('Acme'), findsOneWidget);

    // The drain: the tmp row is gone from the list, the real one is in, and the
    // form still holds the tmp id.
    items.add(const [_Rec('real9', 'Acme')]);
    byId.add(const _Rec('real9', 'Acme'));
    await tester.pump();

    // No `findsNothing` for 'tmp_' here: `displayString` belongs to the caller,
    // so this widget can never put a raw id on screen — the assertion would
    // hold for any implementation, including one that resolves nothing.
    expect(find.text('Acme'), findsOneWidget);

    // ...and the FILTERED option list must not carry it twice. Matching `items`
    // on the stored id missed the real row already in there and spliced a
    // second copy in.
    //
    // It has to be a *typed* query: `_idleOptions`' committed-item hoist
    // filters every row sharing the committed id, so the idle list masks the
    // duplicate. `_optionsFor` does no such filtering, so this is where it
    // surfaces — and it is why asserting on the field's text, or on the idle
    // popover, proves nothing.
    await tester.enterText(find.byType(TextField), 'Ac');
    await tester.pumpAndSettle();
    expect(
      find.text('Acme'),
      findsOneWidget,
      reason: 'one option row; the field now holds the query, not the name',
    );
  });

  testWidgets('resolution is sticky — a null emission never blanks the field', (
    tester,
  ) async {
    final byId = StreamController<_Rec?>.broadcast(sync: true);
    addTearDown(byId.close);

    await pump(
      tester,
      selectedId: 'far',
      items: Stream.value(const <_Rec>[]),
      watchById: (_) => byId.stream,
    );

    byId.add(const _Rec('far', 'Far Supply'));
    await tester.pump();
    expect(find.text('Far Supply'), findsOneWidget);

    // A table-grained Drift watch can re-emit nothing mid-session; that must not
    // wipe a field the user can see a value in.
    byId.add(null);
    await tester.pump();
    expect(find.text('Far Supply'), findsOneWidget);
  });

  testWidgets('a cacheKey change does NOT blank a selection whose id is '
      'unchanged', (tester) async {
    // The project pickers re-arm on `(companyId, clientId)`, and picking a
    // client deliberately KEEPS the project ("surprise-clearing is annoying").
    // Clearing `_resolved` unconditionally on that re-arm handed
    // SearchableDropdownField a null `initialValue`, which clears its own
    // `_committed` and text — a blank Project field on a form that holds one.
    var streams = 0;
    // Broadcast and NOT replaying: a late listener gets nothing. That is what
    // lets this test fail — a `Stream.value` re-answers the instant the watch
    // re-arms, so `pumpAndSettle` papers over the blank. A real Drift query
    // behaves like this too: the re-arm costs at least a frame.
    final byId = StreamController<_Rec?>.broadcast();
    addTearDown(byId.close);

    Widget build(String clientId, List<_Rec> items) => MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: EntityPickerField<_Rec>(
            label: 'Project',
            cacheKey: ('co1', clientId),
            selectedId: 'p1',
            itemsStream: () {
              streams++;
              return Stream.value(items);
            },
            watchById: (_) => byId.stream,
            displayString: (r) => r.name,
            idOf: (r) => r.id,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(build('c1', const [_Rec('p1', 'Rebuild')]));
    byId.add(const _Rec('p1', 'Rebuild'));
    await tester.pumpAndSettle();
    expect(find.text('Rebuild'), findsOneWidget);
    expect(streams, 1);

    // A parent rebuild with an unchanged key must not re-query.
    await tester.pumpWidget(build('c1', const [_Rec('p1', 'Rebuild')]));
    await tester.pumpAndSettle();
    expect(streams, 1, reason: 'WatchBuilder holds the stream across rebuilds');

    // Now the client changes and the new client has no projects — the id is
    // untouched, so the field must keep showing the project.
    // No further `byId.add` — the re-armed watch answers nothing, exactly as a
    // real one would for at least a frame.
    await tester.pumpWidget(build('c2', const []));
    await tester.pumpAndSettle();
    expect(streams, 2, reason: 'a changed cacheKey re-creates the stream');
    expect(find.text('Rebuild'), findsOneWidget);
  });

  testWidgets('changing the selected id drops the stale name', (tester) async {
    // The sticky rule must NOT outlive the id it belongs to.
    Widget build(String id) => MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: EntityPickerField<_Rec>(
            label: 'Vendor',
            selectedId: id,
            itemsStream: () => Stream.value(const <_Rec>[]),
            watchById: (i) =>
                Stream.value(i == 'a' ? const _Rec('a', 'Acme') : null),
            displayString: (r) => r.name.isEmpty ? r.id : r.name,
            idOf: (r) => r.id,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpWidget(build('a'));
    await tester.pump();
    expect(find.text('Acme'), findsOneWidget);

    await tester.pumpWidget(build('b'));
    await tester.pump();
    expect(find.text('Acme'), findsNothing);
  });
}
