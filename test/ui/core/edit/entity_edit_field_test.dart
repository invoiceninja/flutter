import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';

import '../../../_localization_helper.dart';

/// `EntityEditField` is the app's most-used input (110+ call sites) and had no
/// test of its own. These cover the input affordances it gained so the whole
/// call-site sweep is verifiable without a device: a soft keyboard never
/// renders under `flutter test`, but the properties handed to the underlying
/// `TextField` are readable, and that is what the platform acts on.
void main() {
  Future<void> pump(WidgetTester tester, Widget field) => tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(body: field),
    ),
  );

  TextField inner(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField));

  EntityEditField build({
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    Iterable<String>? autofillHints,
    bool autocorrect = true,
    bool obscureText = false,
  }) => EntityEditField(
    label: 'Field',
    initial: 'value',
    onChanged: (_) {},
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    autofillHints: autofillHints,
    autocorrect: autocorrect,
    obscureText: obscureText,
  );

  group('defaults reproduce Flutter', () {
    testWidgets('an unconfigured field changes nothing', (tester) async {
      await pump(tester, build());
      final f = inner(tester);
      expect(f.textCapitalization, TextCapitalization.none);
      expect(f.autofillHints, isNull);
      expect(f.autocorrect, isTrue);
      expect(f.enableSuggestions, isTrue);
      expect(f.obscureText, isFalse);
    });

    testWidgets('a single-line field falls through to the text keyboard', (
      tester,
    ) async {
      await pump(tester, build());
      expect(inner(tester).keyboardType, TextInputType.text);
    });

    testWidgets('a multi-line field derives the multiline keyboard', (
      tester,
    ) async {
      // `TextField`'s constructor does this — `keyboardType ?? (maxLines == 1
      // ? text : multiline)`. It is why ~35 notes / terms / description
      // fields correctly need no `keyboardType` of their own, and why adding
      // `TextInputType.multiline` at those call sites would be dead code.
      await pump(
        tester,
        EntityEditField(
          label: 'Notes',
          initial: '',
          onChanged: (_) {},
          minLines: 3,
          maxLines: 5,
        ),
      );
      expect(inner(tester).keyboardType, TextInputType.multiline);
      expect(inner(tester).textInputAction, TextInputAction.newline);
    });
  });

  group('parameters reach the TextField', () {
    testWidgets('keyboardType carries its arguments', (tester) async {
      await pump(
        tester,
        build(
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
      );
      // `signed` is what puts a minus key on the iOS pad; `decimal` alone
      // renders UIKeyboardTypeDecimalPad, which has none.
      expect(inner(tester).keyboardType.signed, isTrue);
      expect(inner(tester).keyboardType.decimal, isTrue);
    });

    testWidgets('textCapitalization is forwarded', (tester) async {
      await pump(
        tester,
        build(textCapitalization: TextCapitalization.characters),
      );
      expect(inner(tester).textCapitalization, TextCapitalization.characters);
    });

    testWidgets('autofillHints is forwarded', (tester) async {
      await pump(tester, build(autofillHints: const [AutofillHints.email]));
      expect(inner(tester).autofillHints, contains(AutofillHints.email));
    });

    testWidgets('autofillHints stays null when unset — an empty list would '
        'NOT opt out, Flutter gates on null', (tester) async {
      await pump(tester, build());
      expect(inner(tester).autofillHints, isNull);
    });

    testWidgets('autocorrect also drives enableSuggestions', (tester) async {
      await pump(tester, build(autocorrect: false));
      expect(inner(tester).autocorrect, isFalse);
      expect(inner(tester).enableSuggestions, isFalse);
    });
  });

  group('obscureText', () {
    testWidgets('renders obscured with a reveal toggle', (tester) async {
      await pump(tester, build(obscureText: true));
      expect(inner(tester).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('the toggle reveals and re-hides', (tester) async {
      await pump(tester, build(obscureText: true));

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(inner(tester).obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(inner(tester).obscureText, isTrue);
    });

    testWidgets('an obscured field never autocorrects, even when asked', (
      tester,
    ) async {
      // Whatever the call site passes, a credential must not be learned by
      // the IME. The client / vendor portal password relies on this.
      await pump(tester, build(obscureText: true, autocorrect: true));
      expect(inner(tester).autocorrect, isFalse);
      expect(inner(tester).enableSuggestions, isFalse);
    });

    testWidgets('autocorrect stays off across a reveal', (tester) async {
      // Revealing a secret does not make it stop being a secret. Keying this
      // on the live reveal state instead of the declaration is what let the
      // four Email Settings service secrets — which pass `obscureToggle` and
      // a visiblePassword keyboard but no `autocorrect: false` — hand a
      // revealed API credential to the IME the moment the user edited it.
      await pump(tester, build(obscureText: true, autocorrect: true));
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(inner(tester).obscureText, isFalse, reason: 'now revealed');
      expect(inner(tester).autocorrect, isFalse);
      expect(inner(tester).enableSuggestions, isFalse);
    });

    testWidgets('the mask re-arms if obscureText flips on a live element', (
      tester,
    ) async {
      // `_obscured` is State, so without a didUpdateWidget guard it keeps the
      // value it was seeded with and the field renders a credential in the
      // clear while its call site believes it is masked.
      await pump(tester, build());
      expect(inner(tester).obscureText, isFalse);
      await pump(tester, build(obscureText: true));
      expect(inner(tester).obscureText, isTrue);
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('the mask re-arms when the bound row is reassigned', (
      tester,
    ) async {
      // Unsaved contacts are keyed positionally, so deleting one re-points a
      // surviving element at a different contact. Without re-arming, a
      // password revealed on the old contact keeps rendering in the clear
      // under the new contact's row.
      Widget field(String initial) => EntityEditField(
        label: 'Password',
        initial: initial,
        onChanged: (_) {},
        obscureText: true,
      );
      await pump(tester, field('alpha'));
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(inner(tester).obscureText, isFalse, reason: 'revealed');

      await pump(tester, field('bravo'));
      expect(inner(tester).obscureText, isTrue, reason: 'new row, re-masked');
    });

    testWidgets('no toggle is rendered when not obscured', (tester) async {
      await pump(tester, build());
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
    });

    testWidgets('a multi-line obscured field is rejected', (tester) async {
      // Flutter asserts the same thing one layer down; failing at the call
      // site names the field instead of the framework.
      expect(
        () => EntityEditField(
          label: 'Field',
          initial: '',
          onChanged: (_) {},
          obscureText: true,
          maxLines: 3,
        ),
        throwsAssertionError,
      );
    });
  });

  testWidgets('typing still reaches onChanged with the new parameters set', (
    tester,
  ) async {
    final seen = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: EntityEditField(
            label: 'City',
            initial: '',
            onChanged: seen.add,
            textCapitalization: TextCapitalization.words,
            autocorrect: false,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Berlin');
    expect(seen, ['Berlin']);
  });
}
