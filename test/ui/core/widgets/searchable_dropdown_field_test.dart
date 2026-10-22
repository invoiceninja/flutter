import 'dart:async';

import 'package:flutter/foundation.dart';
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
///
/// [away] adds a plain, keyboard-free target for the *other* kind of test: one
/// that must prove the popover closes because of `onTapOutside`, not because
/// focus moved somewhere else. All three of its properties are load-bearing.
/// It is a `ColoredBox`, so it hit-tests at all (`HitTestBehavior.opaque` — a
/// bare `SizedBox` registers nothing and the tap never reaches
/// `RenderTapRegionSurface`). Nothing in it can take focus, so a passing test
/// can only be the hook firing. And it is **not** a `TextField`: every text
/// field shares the `EditableText` tap-region group, so tapping [sink] is
/// "inside" that group, fires no `onTapOutside` at all, and closes the popover
/// by plain focus transfer — a dismissal test written against it passes with
/// the fix reverted.
Widget _host(
  Widget field, {
  bool sink = false,
  bool away = false,
}) => MaterialApp(
  theme: buildInTheme(InTheme.light),
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  home: Scaffold(
    body: Column(
      children: [
        SizedBox(width: 360, child: field),
        if (sink) ...[const Spacer(), const TextField(key: ValueKey('sink'))],
        if (away) ...[
          const Spacer(),
          const SizedBox(
            key: ValueKey('away'),
            height: 120,
            width: double.infinity,
            child: ColoredBox(color: Color(0xFFEEEEEE)),
          ),
        ],
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

/// [_pump] at an explicit width and text scale, for the geometry cases. The
/// app-wide text scale is a real user setting (Device Settings), and
/// `InSizes.touchTarget` does **not** scale with it — so the suffix stays 96 px
/// while everything around it grows, which is what makes a narrow field the
/// case worth pinning.
Future<void> _pumpAt(
  WidgetTester tester, {
  required double width,
  required double textScale,
  _Option? initial,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SearchableDropdownField<_Option>(
              label: 'Assigned User',
              items: _items,
              initialValue: initial,
              displayString: (o) => o.name,
              idOf: (o) => o.id,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

  /// The property assertion above is what let an **invisible** placeholder ship.
  /// `InputDecorator` hands the hint's slot to a label that has not withdrawn,
  /// and on a DISABLED, EMPTY field it can never withdraw on its own
  /// (`_labelShouldWithdraw` is `!isEmpty || (isFocused && enabled)`) — so
  /// `showHint` was false and the hint got wrapped in
  /// `AnimatedOpacity(opacity: 0)`, leaving an outlined box with no ✕, no ▾ and
  /// nothing saying why it was dead.
  ///
  /// **`find.text` cannot see this** — the `Text` is in the tree either way,
  /// just painted at zero alpha; a finder-based test passes with the fix
  /// reverted (checked by experiment). Assert the opacity the decorator
  /// actually computed.
  testWidgets('the empty placeholder is actually visible', (tester) async {
    await _pump(tester, items: const [], emptyHintKey: 'no_records_found');
    final hint = find.text('No records found');
    expect(hint, findsOneWidget);

    final fade = tester.widget<AnimatedOpacity>(
      find.ancestor(of: hint, matching: find.byType(AnimatedOpacity)).first,
    );
    expect(
      fade.opacity,
      1.0,
      reason:
          'the placeholder must be painted, not hidden behind an inline label',
    );
    // The label survives, floated above the hint rather than occupying its slot.
    expect(find.text('Fruit'), findsOneWidget);
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
  // Why inline create is `onCreateRequested` (the `inline create` group
  // below) and never a "+ New…" `footerBuilder`.
  group('why a footer cannot carry inline create', () {
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

  // invoiceninja/flutter#130: on native touch the popover had no dismissal
  // path at all. `_canShowOptionsView` is `hasFocus && options.isNotEmpty`, so
  // it closes only on a pick, on Escape (a hardware keyboard) or on focus
  // loss — and Flutter's `_EditableTextTapOutsideAction` deliberately does not
  // drop focus for a touch tap outside on android/iOS. Our option list is
  // never empty, so the list stayed up until the user picked something.
  //
  // These tests reproduce the real thing rather than approximating it:
  // `flutter test` runs as `TargetPlatform.android` and `tester.tap` sends a
  // `PointerDeviceKind.touch` — the exact pair the SDK refuses to unfocus for.
  group('dismissing the popover', () {
    Finder inOptions(String text) =>
        find.descendant(of: find.byType(ListView), matching: find.text(text));

    /// Settle, then pump one more frame. `token_search_field.dart` records a
    /// real in-repo hazard where a programmatic `unfocus()` was followed by the
    /// FocusManager re-routing focus back to the field on the NEXT frame,
    /// re-opening the menu. Asserting on the settled frame alone would miss it.
    Future<void> settleAndOneMore(WidgetTester tester) async {
      await tester.pumpAndSettle();
      await tester.pump();
    }

    testWidgets('tapping away closes the list, and the field still works', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SearchableDropdownField<_Option>(
            label: 'Fruit',
            items: _items,
            initialValue: _items[2], // Banana — the reported shape
            displayString: (o) => o.name,
            idOf: (o) => o.id,
            onChanged: (_) {},
          ),
          away: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(inOptions('Apple'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('away')));
      await settleAndOneMore(tester);
      expect(find.byType(ListView), findsNothing);

      // Not wedged: the picker is still usable afterwards.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(inOptions('Apple'), findsOneWidget);
    });

    testWidgets('clearing a committed value closes the list, not opens it', (
      tester,
    ) async {
      final calls = <_Option?>[];
      await tester.pumpWidget(
        _host(
          SearchableDropdownField<_Option>(
            label: 'Fruit',
            items: _items,
            // The parent NAMES the selection — a single-select picker, which is
            // the shape #130 was reported against. That is what makes clearing
            // a commit; see the adder case below for the other half.
            initialValue: _items[2], // Banana
            displayString: (o) => o.name,
            idOf: (o) => o.id,
            onChanged: calls.add,
          ),
          away: true,
        ),
      );
      await tester.pumpAndSettle();

      // Open it first, so the field is focused when ✕ is tapped — that is the
      // state that makes `clear()` re-open the list.
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await settleAndOneMore(tester);
      expect(calls, [isNull]);
      expect(
        find.byType(ListView),
        findsNothing,
        reason: 'the ✕ means "unset", not "show me everything"',
      );
    });

    // The other half of the ✕ rule. A chip-adder keeps `initialValue: null`
    // forever and drops the picked item OUT of `items`, so after an add the
    // field holds a label the parent never agreed to and `onChanged(null)` is
    // discarded by the caller. Clearing there is not a commit — it just wipes
    // the leftover label — so focus must stay, or every subsequent add costs an
    // extra tap and the keyboard. `MultiEntityPicker` is the Type picker on the
    // Activity filter sheet, i.e. the very screen #130 came from.
    testWidgets("clearing a chip-adder's leftover label keeps the list open", (
      tester,
    ) async {
      final calls = <_Option?>[];
      final available = [..._items];
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (context, setLocalState) =>
                SearchableDropdownField<_Option>(
                  label: 'Fruit',
                  items: available,
                  initialValue: null,
                  displayString: (o) => o.name,
                  idOf: (o) => o.id,
                  onChanged: (o) {
                    calls.add(o);
                    if (o != null) setLocalState(() => available.remove(o));
                  },
                ),
          ),
          away: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(inOptions('Cherry'));
      await tester.pumpAndSettle();
      expect(calls.single?.id, '4');

      await tester.tap(find.byIcon(Icons.close));
      await settleAndOneMore(tester);
      expect(calls, [isNotNull, isNull]);
      expect(
        find.byType(ListView),
        findsOneWidget,
        reason: 'the next item must still be one tap away',
      );
    });

    testWidgets('clearing a half-typed query leaves the field open to retype', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SearchableDropdownField<_Option>(
            label: 'Fruit',
            items: _items,
            initialValue: null,
            displayString: (o) => o.name,
            idOf: (o) => o.id,
            onChanged: (_) {},
          ),
          away: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();
      expect(inOptions('Banana'), findsNothing);

      await tester.tap(find.byIcon(Icons.close));
      await settleAndOneMore(tester);
      // Focus kept and the idle list back: here the ✕ means "erase and let me
      // retype", so dropping the keyboard would be the wrong answer.
      expect(inOptions('Banana'), findsOneWidget);
    });

    // A keyboard-less picker (<= 6 options on touch) has no caret to place, so
    // its field IS the dropdown button and a tap on an open one means "close".
    testWidgets('tapping a keyboard-less field toggles its list shut', (
      tester,
    ) async {
      await _pump(tester, initial: _items[2]);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await settleAndOneMore(tester);
      expect(find.byType(ListView), findsNothing);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
    });

    // `TextField.onTap` arrives via `TextSelectionGestureDetectorBuilder`, whose
    // `_handleTapUp` calls it only on the FIRST tap of a series — so without
    // `onTapAlwaysCalled` an impatient second tap is swallowed entirely and the
    // toggle above is intermittent. `pump()` advances fake time by ZERO, which
    // keeps both taps in one series; the `pumpAndSettle` used everywhere else
    // in this group would step past `kDoubleTapTimeout` and hide the bug.
    testWidgets('the toggle survives a fast second tap', (tester) async {
      await _pump(tester, initial: _items[2]);
      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ListView), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ListView), findsNothing);
    });

    // The other half of that gate. Past the keyboard-suppression threshold the
    // field is a real text input, so a tap is the user placing a caret in it —
    // stealing that for "close" would make a long picker untypable.
    testWidgets('tapping a typable field does NOT toggle its list shut', (
      tester,
    ) async {
      final many = [for (var i = 0; i < 9; i++) _Option('$i', 'Fruit $i')];
      await _pump(tester, items: many);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);

      await tester.tap(find.byType(TextField));
      await settleAndOneMore(tester);
      expect(find.byType(ListView), findsOneWidget);
    });

    /// …which is exactly why the ▾ is a button. `_reopenOptions` gates its close
    /// branch on `_suppressKeyboard`, so above six options NOTHING in the field
    /// could shut the popover — the arrow was a bare `Icon` whose taps fell
    /// through to the field and only ever re-opened. On the Tasks filter bar
    /// that left the Client and Project pickers with no tap-to-close at all
    /// (invoiceninja/flutter#134). Locate it on the `IconButton`, not the icon:
    /// `find.byIcon` alone would also match the glyph before it was a button.
    testWidgets('the ▾ toggles a typable picker shut, and open again', (
      tester,
    ) async {
      final many = [for (var i = 0; i < 9; i++) _Option('$i', 'Fruit $i')];
      await _pump(tester, items: many);
      final arrow = find.widgetWithIcon(IconButton, Icons.arrow_drop_down);
      expect(arrow, findsOneWidget);

      await tester.tap(arrow);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);

      await tester.tap(arrow);
      await settleAndOneMore(tester);
      expect(
        find.byType(ListView),
        findsNothing,
        reason: 'the arrow must close a picker the field itself cannot',
      );

      await tester.tap(arrow);
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);
    });

    /// The arrow does not steal the field's tap: an `IconButton` in the suffix
    /// wins its own, so `TextField.onTap: _reopenOptions` never doubles up and
    /// re-opens what the button just closed. A regression here would show as
    /// the popover flickering shut and straight back open.
    testWidgets('the ▾ closes a keyboard-less picker too', (tester) async {
      await _pump(tester, initial: _items[2]);
      final arrow = find.widgetWithIcon(IconButton, Icons.arrow_drop_down);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsOneWidget);

      await tester.tap(arrow);
      await settleAndOneMore(tester);
      expect(find.byType(ListView), findsNothing);
    });

    /// The ✕ and the ▾ share the suffix `Row`, and on touch both are
    /// `InSizes.touchTarget` wide — 88 px of suffix on a populated field. The
    /// field is 360 px here, the width `SearchableDropdownField` is used at on
    /// the narrowest surfaces, so this is the case that would overflow first.
    testWidgets('the ✕ and ▾ both fit inside the narrowest real host', (
      tester,
    ) async {
      // Both targets are `InSizes.touchTarget` on touch, so a populated field
      // carries 96 px of suffix where it used to carry ~72 — headroom shrank
      // 24 px at every call site. `_pump`'s 360 px could never overflow
      // whatever the suffix did, so assert the width the widget is actually
      // squeezed to.
      //
      // 136 px is derived, not picked: `payment_allocations_section.dart`'s
      // allocation row is the tightest host in `lib/` — an `Expanded` picker in
      // a `Row` beside a 12 px gap, a `SizedBox(width: 140)` amount field and a
      // trailing `IconButton` (~48 on touch), inside a card padded
      // `InSpacing.lg` (12 a side, narrow). On a 360 px phone that leaves the
      // picker 360 − 24 − 12 − 140 − 48 = 136.
      await _pumpAt(tester, width: 136, textScale: 1.4, initial: _items[2]);
      // Assert containment, NOT `takeException`. `_RenderDecoration` clamps
      // (`inputWidth = max(0, maxWidth - accessoryInsets)`) instead of
      // overflowing, and a `TextField` scrolls rather than ellipsizing — so an
      // oversized suffix is **silent**: no RenderFlex banner, no exception,
      // just a value the user cannot read. `takeException` is also near-useless
      // on its own, since flutter_test already fails on a pending exception.
      final field = tester.getRect(find.byType(TextField));
      final clear = tester.getRect(
        find.widgetWithIcon(IconButton, Icons.close),
      );
      final arrow = tester.getRect(
        find.widgetWithIcon(IconButton, Icons.arrow_drop_down),
      );
      expect(
        arrow.right,
        lessThanOrEqualTo(field.right + precisionErrorTolerance),
        reason: 'the ▾ must not extend past the field it sits in',
      );
      expect(
        clear.left,
        greaterThanOrEqualTo(field.left),
        reason: 'and the ✕ must not be pushed off the leading edge',
      );
      expect(
        clear.width + arrow.width,
        lessThan(field.width),
        reason:
            'the two targets plus their gap must leave room for the value — '
            'they are a fixed 96 px and do not scale with text size, so this '
            'is the assertion that fails first if either grows',
      );
    });
  });

  // Inline create (the `_CreateOpt` row). The routing rules these pin are the
  // ones `docs/pickers.md` says fail silently: a create row that goes dead
  // after one cancel, Enter on a dismissed popover, Tab creating by accident.
  group('inline create', () {
    /// Pumps a picker with [onCreate] wired; [created] records every query the
    /// create callback was handed, and [changed] the last `onChanged` value.
    Future<void> pumpCreate(
      WidgetTester tester, {
      required Future<_Option?> Function(String query) onCreate,
      List<_Option> items = _items,
      _Option? initial,
      void Function(_Option?)? onChanged,
      bool sink = false,
    }) async {
      await tester.pumpWidget(
        _host(
          SearchableDropdownField<_Option>(
            label: 'Fruit',
            items: items,
            initialValue: initial,
            displayString: (o) => o.name,
            idOf: (o) => o.id,
            onChanged: onChanged ?? (_) {},
            createLabelKey: 'new_vendor',
            onCreateRequested: (_, query) => onCreate(query),
          ),
          sink: sink,
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder createRow(String query) => find.text('Create "$query"');

    testWidgets('a query that matches nothing offers to create it', (
      tester,
    ) async {
      final queries = <String>[];
      _Option? changed;
      await pumpCreate(
        tester,
        onCreate: (q) async {
          queries.add(q);
          return const _Option('tmp_1', 'Dragonfruit');
        },
        onChanged: (o) => changed = o,
      );
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Dragonfruit');
      await tester.pumpAndSettle();
      expect(createRow('Dragonfruit'), findsOneWidget);

      await tester.tap(createRow('Dragonfruit'));
      await tester.pumpAndSettle();
      expect(queries, ['Dragonfruit']);
      expect(changed?.id, 'tmp_1');
      // The field shows the created record, and the popover is gone.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Dragonfruit',
      );
      expect(createRow('Dragonfruit'), findsNothing);
    });

    testWidgets('an exact match is not offered as a create', (tester) async {
      await pumpCreate(tester, onCreate: (_) async => null);
      await tester.tap(find.byType(TextField));
      // Different case and an accent: the fold makes it the same name.
      await tester.enterText(find.byType(TextField), 'bánana');
      await tester.pumpAndSettle();
      expect(createRow('bánana'), findsNothing);
      expect(find.text('Banana'), findsOneWidget);
    });

    testWidgets('a partial match still offers the create, pinned below', (
      tester,
    ) async {
      await pumpCreate(tester, onCreate: (_) async => null);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();
      expect(find.text('Apple'), findsOneWidget);
      expect(createRow('ap'), findsOneWidget);
      // Outside the scrolling list, so a long list can't bury it.
      expect(
        find.descendant(of: find.byType(ListView), matching: createRow('ap')),
        findsNothing,
      );
    });

    testWidgets('an untouched field offers the plain "New …" row', (
      tester,
    ) async {
      final queries = <String>[];
      await pumpCreate(
        tester,
        initial: _items[2],
        onCreate: (q) async {
          queries.add(q);
          return null;
        },
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      // Not "Create «Banana»" — the field's own value is not a query.
      expect(createRow('Banana'), findsNothing);
      expect(find.text('New Vendor'), findsOneWidget);

      await tester.tap(find.text('New Vendor'));
      await tester.pumpAndSettle();
      expect(queries, ['']);
    });

    testWidgets('an empty list is a live field that can still create', (
      tester,
    ) async {
      await pumpCreate(tester, items: const [], onCreate: (_) async => null);
      expect(
        tester.widget<TextField>(find.byType(TextField)).enabled,
        isNot(false),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.text('New Vendor'), findsOneWidget);
    });

    testWidgets('the create row still works after a cancelled create', (
      tester,
    ) async {
      var calls = 0;
      await pumpCreate(
        tester,
        onCreate: (_) async {
          calls++;
          return null;
        },
      );
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Dragonfruit');
      await tester.pumpAndSettle();
      await tester.tap(createRow('Dragonfruit'));
      await tester.pumpAndSettle();
      expect(calls, 1);

      // Cancel restored the query and refocused, so the row is back — and
      // must not be dead (the `_select` latch `docs/pickers.md` warns about).
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Dragonfruit',
      );
      expect(createRow('Dragonfruit'), findsOneWidget);
      await tester.tap(createRow('Dragonfruit'));
      await tester.pumpAndSettle();
      expect(calls, 2);
    });

    testWidgets('Enter on a highlighted create row creates', (tester) async {
      final queries = <String>[];
      await pumpCreate(
        tester,
        onCreate: (q) async {
          queries.add(q);
          return null;
        },
      );
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Dragonfruit');
      await tester.pumpAndSettle();
      // The create row is the only option, so it is the default highlight.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(queries, ['Dragonfruit']);
    });

    testWidgets('Enter on a real match picks it, not the create row', (
      tester,
    ) async {
      var calls = 0;
      _Option? changed;
      await pumpCreate(
        tester,
        onCreate: (_) async {
          calls++;
          return null;
        },
        onChanged: (o) => changed = o,
      );
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Cher');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(changed?.name, 'Cherry');
    });

    testWidgets('Tab moves on without creating', (tester) async {
      var calls = 0;
      await pumpCreate(
        tester,
        sink: true,
        onCreate: (_) async {
          calls++;
          return null;
        },
      );
      await tester.tap(find.byType(TextField).first);
      await tester.enterText(find.byType(TextField).first, 'Dragonfruit');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(calls, 0);
    });

    testWidgets('an exact match past the first 50 partial matches leads', (
      tester,
    ) async {
      // 60 names containing "al" that sort first, then the one named exactly
      // "Al". It used to be cut off by `maxResults` while still hiding the
      // create row — neither listed nor creatable.
      final items = [
        for (var i = 0; i < 60; i++) _Option('$i', 'Alpha $i'),
        const _Option('exact', 'Al'),
      ];
      await pumpCreate(tester, items: items, onCreate: (_) async => null);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'al');
      await tester.pumpAndSettle();
      expect(find.text('Al'), findsOneWidget);
      expect(createRow('al'), findsNothing);
    });

    testWidgets('the field is locked while a create is in flight', (
      tester,
    ) async {
      // Ten items, so the field is typable on touch too (≤ 6 suppresses the
      // keyboard and a tap toggles instead) — the race needs typing.
      final items = [for (var i = 0; i < 10; i++) _Option('$i', 'Item $i')];
      final pending = Completer<_Option?>();
      final changes = <_Option?>[];
      await pumpCreate(
        tester,
        items: items,
        onCreate: (_) => pending.future,
        onChanged: changes.add,
      );
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Dragonfruit');
      await tester.pumpAndSettle();
      await tester.tap(createRow('Dragonfruit'));
      await tester.pump();

      // Mid-create the user tries to pick something else. The field takes no
      // focus and offers nothing, so there is no pick for the create to
      // silently overwrite when it resolves.
      await tester.tap(find.byType(TextField), warnIfMissed: false);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Item 3');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isFalse,
      );
      expect(find.text('Item 3'), findsNothing);

      pending.complete(const _Option('tmp_1', 'Dragonfruit'));
      await tester.pumpAndSettle();
      expect(changes.map((o) => o?.id), ['tmp_1']);
    });

    testWidgets('cancelling the plain "New …" row does not reopen the list', (
      tester,
    ) async {
      await pumpCreate(tester, initial: _items[2], onCreate: (_) async => null);
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Vendor'));
      await tester.pumpAndSettle();
      expect(find.byType(ListView), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Banana',
      );
    });

    testWidgets('after an Enter-started create the list is not stale', (
      tester,
    ) async {
      // Enter leaves the field already holding the created name, and
      // RawAutocomplete recomputes only on a text CHANGE — so without a forced
      // recompute, reopening offered `Create "Dragonfruit"` for the record just
      // created.
      await pumpCreate(tester, onCreate: (q) async => _Option('tmp_1', q));
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Dragonfruit');
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Focus the way Tab does — no tap, so no reopen bounce to recompute.
      tester
          .widget<TextField>(find.byType(TextField))
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();
      expect(createRow('Dragonfruit'), findsNothing);
    });

    testWidgets('no callback, no create row', (tester) async {
      await _pump(tester);
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'ap');
      await tester.pumpAndSettle();
      expect(createRow('ap'), findsNothing);
    });
  });
}
