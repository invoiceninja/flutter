import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';

import '../../../_localization_helper.dart';

class _Option {
  const _Option(this.id, this.name);
  final String id;
  final String name;
}

const _items = [
  _Option('1', 'Apple'),
  _Option('2', 'Apricot'),
  _Option('3', 'Banana'),
  _Option('4', 'Cherry'),
];

/// Standard scaffold for a single picker. [sink] adds a second field to tap
/// when a test needs to steal focus — pushed to the bottom of the viewport so
/// the picker's open popover can't swallow the tap meant for it.
Widget _host(Widget field, {bool sink = false}) => MaterialApp(
  theme: buildInTheme(InTheme.light),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  home: Scaffold(
    body: Column(
      children: [
        SizedBox(width: 360, child: field),
        if (sink) ...[const Spacer(), const TextField(key: ValueKey('sink'))],
      ],
    ),
  ),
);

Future<_Option?> _pump(
  WidgetTester tester, {
  List<_Option> items = _items,
  _Option? initial,
  String? emptyHintKey,
}) async {
  _Option? captured = initial;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            child: SearchableDropdownField<_Option>(
              label: 'Fruit',
              items: items,
              initialValue: initial,
              displayString: (o) => o.name,
              idOf: (o) => o.id,
              emptyHintKey: emptyHintKey,
              onChanged: (o) => captured = o,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  // Trampoline closure — caller reads the latest `captured` after interaction.
  return captured;
}

void main() {
  testWidgets('renders initial value as field text', (tester) async {
    await _pump(tester, initial: _items[2]); // Banana
    expect(find.widgetWithText(TextField, 'Banana'), findsOneWidget);
  });

  testWidgets('filters options by query and selects a match', (tester) async {
    await _pump(tester);
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ap');
    await tester.pumpAndSettle();
    // Apple + Apricot both contain "ap"; Banana / Cherry should be hidden.
    expect(find.text('Apple'), findsOneWidget);
    expect(find.text('Apricot'), findsOneWidget);
    expect(find.text('Banana'), findsNothing);

    await tester.tap(find.text('Apricot'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Apricot'), findsOneWidget);
  });

  testWidgets('onChanged fires the selected item', (tester) async {
    _Option? captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SearchableDropdownField<_Option>(
                label: 'Fruit',
                items: _items,
                initialValue: null,
                displayString: (o) => o.name,
                idOf: (o) => o.id,
                onChanged: (o) => captured = o,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'cher');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cherry'));
    await tester.pumpAndSettle();
    expect(captured?.id, '4');
  });

  testWidgets('clear button empties the field and fires null', (tester) async {
    _Option? captured = _items[0];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SearchableDropdownField<_Option>(
                label: 'Fruit',
                items: _items,
                initialValue: _items[0],
                displayString: (o) => o.name,
                idOf: (o) => o.id,
                onChanged: (o) => captured = o,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Clear button only appears once the field has text — initial value
    // already populated it.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(captured, isNull);
    expect(find.widgetWithText(TextField, 'Apple'), findsNothing);
  });

  testWidgets('blur snaps text back to the committed item', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: Column(
              children: [
                SizedBox(
                  width: 360,
                  child: SearchableDropdownField<_Option>(
                    label: 'Fruit',
                    items: _items,
                    initialValue: _items[0], // Apple committed
                    displayString: (o) => o.name,
                    idOf: (o) => o.id,
                    onChanged: (_) {},
                  ),
                ),
                // Tappable elsewhere to steal focus.
                const TextField(key: ValueKey('sink')),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextField, 'Apple'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Apple'), 'xyzzy');
    await tester.pumpAndSettle();
    // Move focus to the sink field — blur should snap text back to Apple.
    await tester.tap(find.byKey(const ValueKey('sink')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Apple'), findsOneWidget);
    expect(find.text('xyzzy'), findsNothing);
  });

  testWidgets('arrow-down + enter selects the highlighted option', (
    tester,
  ) async {
    _Option? captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SearchableDropdownField<_Option>(
                label: 'Fruit',
                items: _items,
                initialValue: null,
                displayString: (o) => o.name,
                idOf: (o) => o.id,
                onChanged: (o) => captured = o,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'ap');
    await tester.pumpAndSettle();
    // Filtered to Apple, Apricot. Two down arrows lands on Apricot (index 1).
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(captured?.id, '2');
    expect(find.widgetWithText(TextField, 'Apricot'), findsOneWidget);
  });

  testWidgets('empty items renders disabled placeholder', (tester) async {
    await _pump(tester, items: const []);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    // Default empty hint key is 'loading'; localization helper resolves it.
    expect(field.decoration?.hintText, isNotNull);
  });

  // invoiceninja/flutter#34: the text of an untouched picker is the selected
  // item's own name, so filtering by it used to offer only the value the user
  // already had — the ✕ (which also cleared the value) was the only way to see
  // the alternatives.
  group('opening a picker that already has a value', () {
    Finder inOptions(String text) =>
        find.descendant(of: find.byType(ListView), matching: find.text(text));

    testWidgets('tapping it offers every option', (tester) async {
      await _pump(tester, initial: _items[2]); // Banana
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(inOptions('Apple'), findsOneWidget);
      expect(inOptions('Apricot'), findsOneWidget);
      expect(inOptions('Cherry'), findsOneWidget);
    });

    testWidgets('the current value leads the list and is checked', (
      tester,
    ) async {
      await _pump(tester, initial: _items[2]); // Banana
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      // Ahead of Apple, which sorts first in `items` — so the default keyboard
      // highlight (row 0) lands on the value the user already has.
      expect(
        tester.getTopLeft(inOptions('Banana')).dy,
        lessThan(tester.getTopLeft(inOptions('Apple')).dy),
      );
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('no check mark when nothing is committed', (tester) async {
      await _pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('opening it fires nothing at all', (tester) async {
      // Recorded as a list, not a last-value: seeding a `captured` with the
      // initial item can't tell "never fired" from "fired with the same item",
      // and "never fired" is the guarantee.
      final calls = <_Option?>[];
      await tester.pumpWidget(
        _host(
          SearchableDropdownField<_Option>(
            label: 'Fruit',
            items: _items,
            initialValue: _items[2], // Banana
            displayString: (o) => o.name,
            idOf: (o) => o.id,
            onChanged: calls.add,
          ),
          sink: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      // Walk away without picking anything.
      await tester.tap(find.byKey(const ValueKey('sink')));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.widgetWithText(TextField, 'Banana'), findsOneWidget);
    });

    testWidgets('typing after opening still filters', (tester) async {
      await _pump(tester, initial: _items[2]); // Banana
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();
      expect(inOptions('Apple'), findsOneWidget);
      expect(inOptions('Banana'), findsNothing);
    });

    // The popover reopens only on a TEXT change, so after a selection a second
    // tap used to do nothing at all.
    testWidgets('tapping again after a pick reopens the list', (tester) async {
      await _pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'cher');
      await tester.pumpAndSettle();
      await tester.tap(inOptions('Cherry'));
      await tester.pumpAndSettle();
      expect(inOptions('Apple'), findsNothing);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(inOptions('Apple'), findsOneWidget);
    });

    testWidgets('blur then refocus shows the whole list, not the self-match', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SearchableDropdownField<_Option>(
            label: 'Fruit',
            items: _items,
            initialValue: _items[2], // Banana
            displayString: (o) => o.name,
            idOf: (o) => o.id,
            onChanged: (_) {},
          ),
          sink: true,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sink')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField).first);
      await tester.pumpAndSettle();
      expect(inOptions('Apple'), findsOneWidget);
    });

    // Enter / Android's soft-keyboard "Done" means "I'm finished", so on the
    // value the field already holds it dismisses and fires nothing —
    // deliberately unlike a *tap* on that row, which is an explicit choice.
    testWidgets('Done on an untouched field dismisses and fires nothing', (
      tester,
    ) async {
      final calls = <_Option?>[];
      await tester.pumpWidget(
        _host(
          SearchableDropdownField<_Option>(
            label: 'Fruit',
            items: _items,
            initialValue: _items[2], // Banana
            displayString: (o) => o.name,
            idOf: (o) => o.id,
            onChanged: calls.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(inOptions('Apple'), findsOneWidget);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.widgetWithText(TextField, 'Banana'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    // With no options on screen there is nothing for Enter to act on, so it
    // must commit nothing — in particular not the committed row, which
    // `_visibleOptions` still holds from the last render. (The field blurs and
    // the text snaps back either way: `EditableText._finalizeEditing`
    // unfocuses before it calls `onSubmitted`.)
    testWidgets('Enter on a non-matching query commits nothing', (
      tester,
    ) async {
      final calls = <_Option?>[];
      await tester.pumpWidget(
        _host(
          SearchableDropdownField<_Option>(
            label: 'Fruit',
            items: _items,
            initialValue: _items[2], // Banana
            displayString: (o) => o.name,
            idOf: (o) => o.id,
            onChanged: calls.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing); // nothing matched

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    // A tap on the checked row is an explicit choice, so it re-commits and
    // closes. It must NOT go through `RawAutocomplete._select`, which
    // early-returns on an unchanged selection *before* hiding the overlay —
    // that would be a dead tap under a popover that stays open, and callers
    // that treat a re-pick as a command (re-seed an amount, re-bind a stream,
    // re-add a deleted chip) would never hear about it.
    testWidgets('tapping the checked row re-commits and closes', (
      tester,
    ) async {
      final calls = <_Option?>[];
      await tester.pumpWidget(
        _host(
          SearchableDropdownField<_Option>(
            label: 'Fruit',
            items: _items,
            initialValue: _items[2], // Banana
            displayString: (o) => o.name,
            idOf: (o) => o.id,
            onChanged: calls.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(inOptions('Banana'));
      await tester.pumpAndSettle();
      expect(calls.map((o) => o?.id), ['3']);
      expect(find.byType(ListView), findsNothing);
      expect(find.widgetWithText(TextField, 'Banana'), findsOneWidget);
    });

    // The chip adders pass `initialValue: null` forever, so `_committed` keeps
    // pointing at the last item added. Deleting its chip puts it back in
    // `items`, and it must stay addable.
    testWidgets('an item whose chip was deleted can be added again', (
      tester,
    ) async {
      final calls = <_Option?>[];
      Widget build(List<_Option> items) => _host(
        SearchableDropdownField<_Option>(
          label: 'Fruit',
          items: items,
          initialValue: null,
          displayString: (o) => o.name,
          idOf: (o) => o.id,
          onChanged: calls.add,
        ),
      );
      final withoutBanana = _items
          .where((o) => o.id != '3')
          .toList(growable: false);

      await tester.pumpWidget(build(_items));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ban');
      await tester.pumpAndSettle();
      await tester.tap(inOptions('Banana'));
      await tester.pumpAndSettle();
      // Added: the parent drops it from `items`.
      await tester.pumpWidget(build(withoutBanana));
      await tester.pumpAndSettle();
      // Chip deleted: it comes back.
      await tester.pumpWidget(build(_items));
      await tester.pumpAndSettle();

      calls.clear();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(inOptions('Banana'));
      await tester.pumpAndSettle();
      expect(calls.map((o) => o?.id), ['3']);
    });

    // `T` can be `String`, and a picker whose "unset" option is the empty
    // string (dropdown custom fields) has a non-null committed value with
    // nothing to clear.
    testWidgets('no clear button when the committed value renders empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SearchableDropdownField<String>(
            label: 'Grade',
            items: const ['', 'Gold', 'Silver'],
            initialValue: '',
            displayString: (o) => o,
            idOf: (o) => o,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });

    // The "add to a chip list" callers keep `initialValue: null` forever and
    // drop the picked item out of `items`; `_committed` is never reset, so
    // without a guard the idle list would re-offer what was just added.
    testWidgets('an adder is not re-offered the item it just added', (
      tester,
    ) async {
      Widget build(List<_Option> items) => _host(
        SearchableDropdownField<_Option>(
          label: 'Fruit',
          items: items,
          initialValue: null,
          displayString: (o) => o.name,
          idOf: (o) => o.id,
          onChanged: (_) {},
        ),
      );
      await tester.pumpWidget(build(_items));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ban');
      await tester.pumpAndSettle();
      await tester.tap(inOptions('Banana'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(build(_items.where((o) => o.id != '3').toList()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(inOptions('Apple'), findsOneWidget);
      expect(inOptions('Banana'), findsNothing);
    });

    testWidgets('long option labels ellipsize instead of overflowing', (
      tester,
    ) async {
      const long = _Option(
        '9',
        'A fruit with a preposterously long name that '
            'could never fit inside the popover on any screen',
      );
      await _pump(tester, items: const [long, ..._items], initial: long);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final label = tester.widget<Text>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.text(long.name),
        ),
      );
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
    });

    testWidgets('the field carries a dropdown arrow', (tester) async {
      await _pump(tester, initial: _items[2]);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      // …alongside the clear affordance, which stays reachable.
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    // Left at `OptionsViewOpenDirection.down`, a picker low on a phone screen
    // gets only the space beneath it — floored at a 48px sliver. And an `Align`
    // of our own inside `optionsViewBuilder` would expand to fill the SDK's
    // bounding box, leaving its alignment nothing to move, so the flipped
    // popover would detach and render at the top of the screen.
    testWidgets('the popover flips above a field low on a short screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                const Spacer(),
                SizedBox(
                  width: 360,
                  child: SearchableDropdownField<_Option>(
                    label: 'Fruit',
                    items: _items,
                    initialValue: _items[2],
                    displayString: (o) => o.name,
                    idOf: (o) => o.id,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      final fieldTop = tester.getTopLeft(find.byType(TextField)).dy;
      final options = find.byType(ListView);
      expect(options, findsOneWidget);
      // Above the field…
      expect(tester.getTopLeft(options).dy, lessThan(fieldTop));
      // …and anchored to it, not stranded at the top of the screen.
      expect(tester.getBottomLeft(options).dy, closeTo(fieldTop, 8));
    });
  });

  // Pins the two limitations that make this widget unusable for inline
  // "create new <entity>" affordances, so a future refactor doesn't try to
  // fold `ClientPickerField` (lib/ui/core/widgets/client_picker_field.dart)
  // back into it. Both fail silently rather than throwing.
  group('why inline-create needs a different widget', () {
    testWidgets('footerBuilder is unreachable when nothing matches', (
      tester,
    ) async {
      var footerBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: SearchableDropdownField<_Option>(
                  label: 'Fruit',
                  items: _items,
                  initialValue: null,
                  displayString: (o) => o.name,
                  idOf: (o) => o.id,
                  onChanged: (_) {},
                  footerBuilder: (_) {
                    footerBuilds++;
                    return const Text('+ New fruit');
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // A partial match shows the popover, so the footer renders.
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();
      expect(find.text('+ New fruit'), findsOneWidget);
      expect(footerBuilds, greaterThan(0));

      // Type a name that matches nothing — RawAutocomplete only mounts its
      // options overlay while the option list is non-empty
      // (`_canShowOptionsView`), so the footer vanishes exactly when the user
      // most needs "create this new thing".
      final before = footerBuilds;
      await tester.enterText(find.byType(TextField), 'Dragonfruit');
      await tester.pumpAndSettle();
      expect(find.text('+ New fruit'), findsNothing);
      expect(footerBuilds, before);
    });
  });
}
