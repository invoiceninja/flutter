import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';
import 'package:admin/ui/core/widgets/template_variables/markdown_template_variables.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

import '../../../_localization_helper.dart';

/// A `MarkdownTextField` as an email-template body (invoiceninja/flutter#139):
/// its `$variables` are chips.

const _caption =
    'Showing the default template. Your first edit saves a custom copy.';

class _Harness {
  final toasts = ToastController();
  final emitted = <String>[];
}

Future<_Harness> _pump(
  WidgetTester tester,
  String value, {
  String? defaultValue,
  bool enabled = true,
  bool readOnly = false,
}) async {
  final h = _Harness();
  addTearDown(h.toasts.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<ToastController>.value(
      value: h.toasts,
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              child: MarkdownTextField(
                label: 'Body',
                initialValue: value,
                defaultValue: defaultValue,
                enabled: enabled,
                readOnly: readOnly,
                templateVariables: TemplateVariableScope.invoice,
                onChanged: h.emitted.add,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return h;
}

/// A chip at rest: the reader is pointer-blocked, so the tap reaches the
/// field's own tap layer, which hit-tests it. `tapAt`, since the chip itself
/// is (deliberately) not hit-testable.
Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.tapAt(tester.getCenter(find.text(label)));
  await tester.pumpAndSettle();
}

/// Promote the reader to the editor with a tap well below the text — away
/// from any chip. Pumped frame by frame: a focused editor's caret blinks, so
/// `pumpAndSettle` would never settle.
Future<void> _startEditing(WidgetTester tester) async {
  final host = tester.getRect(
    find.descendant(
      of: find.byType(MarkdownTextField),
      matching: find.byType(CustomScrollView),
    ),
  );
  await tester.tapAt(host.bottomLeft + const Offset(24, -12));
  await tester.pump(); // `_enterEditing`'s post-frame callback
  await tester.pump(); // the editor mounts
  await tester.pump(); // and takes focus
}

Editor _liveEditor(WidgetTester tester) =>
    tester.widget<SuperEditor>(find.byType(SuperEditor)).editor;

void main() {
  testWidgets('recognised tokens render as chips, and seeding writes nothing', (
    tester,
  ) async {
    final h = await _pump(tester, r'Pay $amount now, then $balance or $nope');
    expect(find.byType(TemplateVariableChip), findsNWidgets(2));
    expect(find.text('Amount'), findsOneWidget);
    expect(find.text('Balance'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.emitted, isEmpty);
  });

  testWidgets('a chip at rest opens the picker; the pick is written at once, '
      'and Undo puts the old token back', (tester) async {
    final h = await _pump(tester, r'Pay $amount now');
    await _tapChip(tester, 'Amount');
    expect(find.text('Change variable'), findsOneWidget);

    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();
    // The emitted value is HTML (these fields are HTML on the wire); what
    // matters here is that the `$token` crossed the serializer untouched.
    expect(h.emitted, [r'<p>Pay $balance now</p>']);
    expect(find.text('Balance'), findsOneWidget);
    expect(find.byType(SuperEditor), findsNothing, reason: 'still at rest');
    expect(h.toasts.toasts.last.message, 'Updated');

    h.toasts.toasts.last.action!.onPressed();
    // Undo is an edit like any other, so it rides the debounce.
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.emitted.last, r'<p>Pay $amount now</p>');
    expect(find.text('Amount'), findsOneWidget);
    // Let the toast's auto-dismiss timer run out.
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('Remove takes the chip out', (tester) async {
    final h = await _pump(tester, r'Pay $amount now');
    await _tapChip(tester, 'Amount');
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(h.emitted, ['<p>Pay  now</p>']);
    expect(find.byType(TemplateVariableChip), findsNothing);
    expect(h.toasts.toasts.last.message, 'Removed');
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('Insert variable appends a chip to a field at rest', (
    tester,
  ) async {
    final h = await _pump(tester, 'Pay now');
    await tester.tap(find.widgetWithText(TextButton, 'Insert variable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.emitted.last, r'<p>Pay now $balance</p>');
    expect(find.byType(TemplateVariableChip), findsOneWidget);
    expect(find.byType(SuperEditor), findsNothing);
  });

  testWidgets('a chip tapped in the live editor opens the picker too, and '
      'the caret comes back after it', (tester) async {
    final h = await _pump(tester, r'Pay $amount now');
    await _startEditing(tester);
    expect(find.byType(SuperEditor), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.text('Amount')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Change variable'), findsOneWidget);

    await tester.tap(find.text('Balance'));
    await tester.pump(const Duration(milliseconds: 500)); // the picker closes
    await tester.pump(); // `_enterEditing`'s post-frame callback
    await tester.pump(const Duration(milliseconds: 400)); // the debounce
    expect(h.emitted.last, r'<p>Pay $balance now</p>');
    expect(find.byType(SuperEditor), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
  });

  group('default template', () {
    testWidgets('an empty value shows the default, muted under a Default '
        'badge, and writes nothing', (tester) async {
      final h = await _pump(tester, '', defaultValue: r'Pay $amount now');
      expect(find.text('Default'), findsOneWidget);
      expect(find.text(_caption), findsOneWidget);
      final chip = tester.widget<TemplateVariableChip>(
        find.byType(TemplateVariableChip),
      );
      expect(chip.muted, isTrue);
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.emitted, isEmpty);
    });

    testWidgets('changing one of its chips writes the whole template, '
        'changed — and it stops being the default', (tester) async {
      final h = await _pump(tester, '', defaultValue: r'Pay $amount now');
      await _tapChip(tester, 'Amount');
      await tester.tap(find.text('Balance'));
      await tester.pumpAndSettle();
      expect(h.emitted, [r'<p>Pay $balance now</p>']);
      expect(find.text('Default'), findsNothing);
      expect(find.text(_caption), findsNothing);
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('the first keystroke into the default keeps the live editor — '
        'no remount, no lost focus — as its caption goes', (tester) async {
      final h = await _pump(tester, '', defaultValue: r'Pay $amount now');
      await _startEditing(tester);
      final editorState = tester.state(find.byType(SuperEditor));
      final focus = FocusManager.instance.primaryFocus;
      expect(find.text(_caption), findsOneWidget);

      _liveEditor(
        tester,
      ).execute([InsertCharacterAtCaretRequest(character: 'X')]);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(h.emitted.single, contains('X'));
      expect(find.text(_caption), findsNothing);
      expect(
        identical(tester.state(find.byType(SuperEditor)), editorState),
        isTrue,
      );
      expect(FocusManager.instance.primaryFocus, same(focus));
    });

    testWidgets('removing the last chip empties the body back to the default '
        '— shown, not a blank box — and Undo restores the body', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        r'$amount',
        defaultValue: r'Pay $amount now',
      );
      expect(find.text('Default'), findsNothing);
      await _tapChip(tester, 'Amount');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      // Empty is the server's default, and the field says so by showing it.
      expect(h.emitted, ['']);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text(_caption), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);

      h.toasts.toasts.last.action!.onPressed();
      await tester.pump();
      expect(h.emitted, ['', r'<p>$amount</p>']);
      expect(find.text('Default'), findsNothing);
      expect(find.text('Amount'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
    });

    testWidgets('a body emptied while editing shows the default again once '
        'focus leaves', (tester) async {
      final h = await _pump(
        tester,
        r'Custom $amount',
        defaultValue: r'Pay $amount now',
      );
      await _startEditing(tester);
      final editor = _liveEditor(tester);
      final node = editor.document.first as TextNode;
      // What select-all + Backspace does: the content goes, the caret stays.
      editor.execute([
        DeleteContentRequest(
          documentRange: DocumentRange(
            start: templateVariablePosition(node.id, 0),
            end: templateVariablePosition(node.id, node.text.length),
          ),
        ),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: templateVariablePosition(node.id, 0),
          ),
          SelectionChangeType.alteredContent,
          SelectionReason.userInteraction,
        ),
      ]);
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.emitted, ['']);
      // Still editing: the user may be about to type a new body.
      expect(find.byType(TemplateVariableChip), findsNothing);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(SuperEditor), findsNothing);
      expect(find.text('Default'), findsOneWidget);
      expect(find.text(_caption), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
      expect(h.emitted, [''], reason: 'showing the default writes nothing');
    });
  });

  for (final (name, enabled, readOnly) in [
    ('a read-only', true, true),
    ('a disabled', false, false),
  ]) {
    testWidgets('$name field shows its chips but keeps them inert', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        r'Pay $amount now',
        enabled: enabled,
        readOnly: readOnly,
      );
      expect(find.text('Amount'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
      expect(find.text('Insert variable'), findsNothing);

      await tester.tapAt(tester.getCenter(find.text('Amount')));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Change variable'), findsNothing);
      expect(find.byType(SuperEditor), findsNothing);
      expect(h.emitted, isEmpty);
    });
  }
}
