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
