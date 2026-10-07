import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/settings_page_scaffold.dart';

import '../../../_html_table_fixtures.dart';
import '../../../_localization_helper.dart';

/// Minimal host — `runSettingsSave` only calls `save()` + reads `submitError`.
class _FakeHost extends SettingsDraftHost {
  @override
  Future<Object?> save() async => 1; // non-null ⇒ success
  @override
  CompanySettings get settings => const CompanySettings();
  @override
  CompanySettings get draftSettings => const CompanySettings();
  @override
  Company? get draft => Company();
  @override
  Map<String, List<String>> get fieldErrors => const {};
  @override
  void updateSettings(CompanySettings Function(CompanySettings) edit) {}
  @override
  bool get isLoaded => true;
  @override
  bool get isDirty => true;
  @override
  bool get isSaving => false;
  @override
  String? get loadError => null;
  @override
  String? get submitError => null;
  @override
  void reset() {}
  @override
  Future<void> load() async {}
}

/// `MarkdownTextField`'s HTML source mode (invoiceninja/flutter#174): a value
/// the document cannot hold — a table, or anything the fold would delete text
/// from — is shown as its own HTML, verbatim, and any other field can be
/// switched to its source and back.

const _notice =
    "Shown as HTML because the rich text editor can't display this content "
    'without changing it.';

class _Harness {
  final toasts = ToastController();
  final emitted = <String>[];
  final editing = <bool>[];
  final flush = MarkdownFieldController();
}

Widget _app(_Harness h, Widget child) =>
    ChangeNotifierProvider<ToastController>.value(
      value: h.toasts,
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(body: child),
      ),
    );

Widget _field(
  _Harness h,
  String value, {
  String? defaultValue,
  Object? externalValueKey,
  bool enabled = true,
  bool readOnly = false,
  bool expand = false,
  bool showLabel = true,
  double height = 120,
  TemplateVariableScope? templateVariables,
}) => MarkdownTextField(
  label: 'Footer',
  initialValue: value,
  defaultValue: defaultValue,
  externalValueKey: externalValueKey,
  enabled: enabled,
  readOnly: readOnly,
  expand: expand,
  showLabel: showLabel,
  height: height,
  templateVariables: templateVariables,
  controller: h.flush,
  onEditing: h.editing.add,
  onChanged: h.emitted.add,
);

Future<_Harness> _pump(
  WidgetTester tester,
  String value, {
  String? defaultValue,
  bool enabled = true,
  bool readOnly = false,
  double height = 120,
  TemplateVariableScope? templateVariables,
}) async {
  final h = _Harness();
  addTearDown(h.toasts.dispose);
  await tester.pumpWidget(
    _app(
      h,
      Center(
        child: SizedBox(
          width: 480,
          child: _field(
            h,
            value,
            defaultValue: defaultValue,
            enabled: enabled,
            readOnly: readOnly,
            height: height,
            templateVariables: templateVariables,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return h;
}

/// The source box's text, read off the widget the user is looking at.
String _source(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

Future<void> _blur(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.pump();
}

/// Promote a rich field to its editor, then press the toolbar's `</>`.
Future<void> _switchToSource(WidgetTester tester) async {
  // Tap inside the reader's own box: the field's Column is taller than the
  // frame, so its centre can land on nothing.
  final host = tester.getRect(
    find.descendant(
      of: find.byType(MarkdownTextField),
      matching: find.byType(CustomScrollView),
    ),
  );
  await tester.tapAt(host.bottomLeft + const Offset(24, -12));
  await tester.pump(); // `_enterEditing`'s post-frame callback
  await tester.pump(); // the editor mounts, with its toolbar
  await tester.pump(); // and takes focus
  await tester.tap(find.byTooltip('Source Code'));
  await tester.pump(); // the swap
  await tester.pump(); // focus lands on the box
}

const _debounce = Duration(milliseconds: 400);

void main() {
  testWidgets('a table is shown as its own HTML, verbatim, and opening it '
      'emits nothing', (tester) async {
    final h = await _pump(tester, kTipTapTable);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(SuperReader), findsNothing);
    expect(find.byType(SuperEditor), findsNothing);
    // The stored string, not the document's flattened re-serialization.
    expect(_source(tester), kTipTapTable);
    expect(find.text(_notice), findsOneWidget);

    await tester.pump(_debounce);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await _blur(tester);
    await tester.pump(_debounce);

    expect(h.emitted, isEmpty);
    expect(h.editing, isEmpty);
    // Nothing to flush, so the caller keeps its own (stored) copy — this is
    // what "Save as default" hands to company settings.
    expect(h.flush.flush(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the footers that used to come out BLANK are shown, not '
      'emptied', (tester) async {
    // The report's "appears empty": each cell opens with a tag the fold
    // refuses, the deserializer deletes the line, and the user is looking at
    // an empty box that their first keystroke saves over the table.
    for (final table in kBlankingTables) {
      final h = await _pump(tester, table);
      expect(find.byType(SuperReader), findsNothing, reason: table);
      expect(_source(tester), table, reason: table);
      expect(h.emitted, isEmpty, reason: table);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('text the fold would delete forces source without any table', (
    tester,
  ) async {
    await _pump(tester, '<p hidden>Gone</p><p>Kept</p>');
    expect(_source(tester), '<p hidden>Gone</p><p>Kept</p>');
    expect(find.text(_notice), findsOneWidget);
  });

  testWidgets('an edit emits the table intact, with no newline in it', (
    tester,
  ) async {
    final h = await _pump(tester, kTinyMceTable);
    expect(_source(tester), kTinyMceTable, reason: 'shown as stored');

    await tester.enterText(
      find.byType(TextField),
      kTinyMceTable.replaceFirst('Company GmbH', 'Company AG'),
    );
    expect(h.emitted, isEmpty, reason: 'still inside the debounce');
    await tester.pump(_debounce);

    expect(h.emitted, hasLength(1));
    final emitted = h.emitted.single;
    // `nl2br()` on the server's PDF path would print each one as a blank line.
    expect(emitted, isNot(contains('\n')));
    expect(emitted, isNot(contains('\r')));
    expect(emitted, contains('<td>Company AG</td><td>Bank: ACME</td>'));
    expect(emitted, startsWith('<table style="border-collapse: collapse;'));
    expect(emitted, endsWith('</tr></tbody></table>'));
    expect(h.editing, [true, false]);
    // The box keeps showing what was typed, line breaks and all.
    expect(_source(tester), contains('\n<td>Company AG</td>\n'));
    expect(h.flush.flush(), emitted);
  });

  testWidgets('typing and taking it back emits nothing and ends clean', (
    tester,
  ) async {
    final h = await _pump(tester, kTipTapTable);
    await tester.enterText(find.byType(TextField), '${kTipTapTable}x');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), kTipTapTable);
    await tester.pump(_debounce);

    expect(h.emitted, isEmpty);
    // Both edges: a host latching on the true one would stay dirty for ever.
    expect(h.editing, [true, false]);
    expect(h.flush.flush(), isNull);
  });

  testWidgets('a blur flushes the pending edit at once', (tester) async {
    final h = await _pump(tester, kTipTapTable);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField),
      kTipTapTable.replaceFirst('VAT: DE123', 'VAT: DE999'),
    );
    await _blur(tester);
    expect(h.emitted.single, contains('<p>VAT: DE999</p>'));
  });

  testWidgets('a key bump with the SAME value does not reseed the box', (
    tester,
  ) async {
    // The baseline is the stored string. Against the document's canonical form
    // a table "differs" on every rebuild, and the reseed that followed
    // replaced the box's text under the caret.
    final h = _Harness();
    addTearDown(h.toasts.dispose);
    Widget build(Object key) => _app(
      h,
      Center(
        child: SizedBox(
          width: 480,
          child: _field(h, kTipTapTable, externalValueKey: key),
        ),
      ),
    );
    await tester.pumpWidget(build('k1'));
    await tester.pump();

    final typed = kTipTapTable.replaceFirst('Bank: ACME', 'Bank: OTHER');
    await tester.enterText(find.byType(TextField), typed);
    await tester.pumpWidget(build('k2'));
    await tester.pump();

    expect(_source(tester), typed);
    await tester.pump(_debounce);
    expect(h.emitted.single, typed);
  });

  testWidgets('a key bump with a NEW value does reseed it', (tester) async {
    final h = _Harness();
    addTearDown(h.toasts.dispose);
    Widget build(String value) => _app(
      h,
      Center(
        child: SizedBox(
          width: 480,
          child: _field(h, value, externalValueKey: value),
        ),
      ),
    );
    await tester.pumpWidget(build(kTipTapTable));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);

    // To another table: the box follows.
    await tester.pumpWidget(build(kTinyMceTable));
    await tester.pump();
    expect(_source(tester), kTinyMceTable);

    // To something the document can hold: back to the reader, by itself.
    await tester.pumpWidget(build('<p>Thanks</p>'));
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SuperReader), findsOneWidget);
    expect(h.emitted, isEmpty);
  });

  testWidgets('any field can be switched to its source and back, and the '
      'round trip changes nothing', (tester) async {
    // Stored with a span the document drops. The source must show the STORED
    // string — the document's own serialization has already lost the colour.
    const stored = '<p><span style="color: red">Hi</span> Bob</p>';
    final h = await _pump(tester, stored);
    expect(find.byType(SuperReader), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await _switchToSource(tester);
    expect(find.byType(SuperEditor), findsNothing);
    expect(_source(tester), stored);
    // Not forced: the way back is offered, and no reason is given for staying.
    expect(find.text('Rich text'), findsOneWidget);
    expect(find.text(_notice), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
      isTrue,
      reason: 'the user was typing; the box takes the focus over',
    );

    await tester.tap(find.text('Rich text'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(SuperReader), findsOneWidget);

    await tester.pump(_debounce);
    expect(h.emitted, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the way back closes when a table is typed and reopens when it '
      'is deleted', (tester) async {
    final h = await _pump(tester, '<p>Thanks</p>');
    await _switchToSource(tester);
    expect(find.text('Rich text'), findsOneWidget);

    await tester.enterText(find.byType(TextField), kTipTapTable);
    await tester.pump(_debounce);
    expect(find.text('Rich text'), findsNothing);
    expect(find.text(_notice), findsOneWidget);

    await tester.enterText(find.byType(TextField), '<p>No table</p>');
    await tester.pump(_debounce);
    expect(find.text(_notice), findsNothing);

    await tester.tap(find.text('Rich text'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SuperReader), findsOneWidget);
    expect(h.emitted.last, '<p>No table</p>');
  });

  testWidgets('a default template with a table is source too, and an edit '
      'back to it clears the override', (tester) async {
    // The Send Email body: an empty value over a default. One edited word in
    // the document used to send the flattened table.
    final h = await _pump(tester, '', defaultValue: kTipTapTable);
    expect(_source(tester), kTipTapTable);
    expect(find.text('Default'), findsOneWidget);
    expect(h.emitted, isEmpty);

    final edited = kTipTapTable.replaceFirst('Company GmbH', 'Company AG');
    await tester.enterText(find.byType(TextField), edited);
    await tester.pump(_debounce);
    expect(h.emitted, [edited]);
    expect(find.text('Default'), findsNothing);

    await tester.enterText(find.byType(TextField), kTipTapTable);
    await tester.pump(_debounce);
    expect(h.emitted.last, '');
    expect(find.text('Default'), findsOneWidget);
  });

  testWidgets('a default that lands mid-typing waits for the blur', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.toasts.dispose);
    Widget build(String? defaultValue) => _app(
      h,
      Center(
        child: SizedBox(
          width: 480,
          child: _field(
            h,
            '',
            defaultValue: defaultValue,
            externalValueKey: defaultValue,
          ),
        ),
      ),
    );
    await tester.pumpWidget(build(null));
    await tester.pump();
    await _switchToSource(tester);

    await tester.enterText(find.byType(TextField), '<p>My own');
    await tester.pumpWidget(build(kTipTapTable));
    await tester.pump();
    expect(
      _source(tester),
      '<p>My own',
      reason: 'not replaced under the caret',
    );
  });

  testWidgets('expand mode with no label row hosts the box without a layout '
      'error, in both modes', (tester) async {
    // The billing notes tabs: `showLabel: false, expand: true`. Everything the
    // mode adds lives inside the frame, because a label-row action here would
    // put an `Expanded` frame into an unbounded Column.
    for (final value in ['<p>Thanks</p>', kTipTapTable]) {
      final h = _Harness();
      addTearDown(h.toasts.dispose);
      await tester.pumpWidget(
        _app(
          h,
          Center(
            child: SizedBox(
              width: 480,
              height: 300,
              child: _field(h, value, expand: true, showLabel: false),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: value);
      expect(
        tester.getSize(find.byType(MarkdownTextField)).height,
        300,
        reason: value,
      );
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the box keeps the height floor and grows to the ceiling', (
    tester,
  ) async {
    await _pump(tester, '<table><tr><td>a</td></tr></table>', height: 200);
    final short = tester.getSize(find.byType(TextField)).height;
    expect(short, 200);
    // A second pump of the same widget type would reuse the State — and with
    // no `externalValueKey` to bump, the first value with it.
    await tester.pumpWidget(const SizedBox());

    final tall = [
      for (var i = 0; i < 80; i++) '<tr><td>row $i</td></tr>',
    ].join('\n');
    await _pump(tester, '<table>\n$tall\n</table>', height: 200);
    final grown = tester.getSize(find.byType(TextField)).height;
    expect(grown, greaterThan(200));
    expect(grown, lessThanOrEqualTo(480));
  });

  for (final (name, enabled, readOnly) in [
    ('disabled', false, false),
    ('read-only', true, true),
  ]) {
    testWidgets('a $name source box still scrolls and takes no edit', (
      tester,
    ) async {
      // `enabled: false` on a TextField wraps it in an IgnorePointer and takes
      // its scrolling with it — invoiceninja/flutter#107 again.
      final tall = [
        for (var i = 0; i < 200; i++) '<tr><td>row $i</td></tr>',
      ].join('\n');
      final h = await _pump(
        tester,
        '<table>\n$tall\n</table>',
        enabled: enabled,
        readOnly: readOnly,
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.readOnly, isTrue);
      expect(field.enabled, isNot(false));
      // No way back is offered from a field the user cannot edit.
      expect(find.text('Rich text'), findsNothing);

      final scrollable = find.descendant(
        of: find.byType(TextField),
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      expect(position.maxScrollExtent, greaterThan(0));

      final center = tester.getCenter(find.byType(TextField));
      final pointer = TestPointer(1, PointerDeviceKind.mouse)..hover(center);
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
      await tester.pump();
      expect(position.pixels, greaterThan(0));
      expect(h.emitted, isEmpty);
    });
  }

  testWidgets('Insert variable writes the raw token at the caret', (
    tester,
  ) async {
    const stored = '<table><tr><td>Total: </td></tr></table>';
    final h = await _pump(
      tester,
      stored,
      templateVariables: TemplateVariableScope.invoice,
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    const caret = '<table><tr><td>Total: '.length;
    tester.widget<TextField>(find.byType(TextField)).controller!.selection =
        const TextSelection.collapsed(offset: caret);
    await tester.pump();

    await tester.tap(find.widgetWithText(TextButton, 'Insert variable'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();
    await tester.pump(_debounce);

    // The token is the text: there are no chips in source.
    expect(
      _source(tester),
      r'<table><tr><td>Total: $balance</td></tr></table>',
    );
    expect(h.emitted.last, r'<table><tr><td>Total: $balance</td></tr></table>');
  });

  testWidgets('the box turns every text-assist feature off', (tester) async {
    await _pump(tester, kTipTapTable);
    final field = tester.widget<TextField>(find.byType(TextField));
    // iOS smart quotes turn `style="…"` into the curly-quoted shape the fold
    // refuses — the one that blanks the field.
    expect(field.smartQuotesType, SmartQuotesType.disabled);
    expect(field.smartDashesType, SmartDashesType.disabled);
    expect(field.autocorrect, isFalse);
    expect(field.enableSuggestions, isFalse);
    expect(field.textCapitalization, TextCapitalization.none);
    expect(field.spellCheckConfiguration?.spellCheckEnabled, isFalse);
    expect(field.maxLines, isNull);
    expect(field.style?.fontFamily, kMonoFontFamily);
  });

  testWidgets('an embedded image is a placeholder in the box and intact on '
      'the wire', (tester) async {
    final logo = 'iVBORw0KGgo${'A' * 4000}=';
    final stored =
        '<table><tr><td><img src="data:image/png;base64,$logo"></td>'
        '<td>Company</td></tr></table>';
    final h = await _pump(tester, stored);
    expect(_source(tester), isNot(contains(logo)));
    expect(_source(tester), contains('[base64-data-1-3KB]'));
    await tester.pump(_debounce);
    expect(h.emitted, isEmpty, reason: 'a placeholder is not an edit');

    await tester.enterText(
      find.byType(TextField),
      _source(tester).replaceFirst('Company', 'Company AG'),
    );
    await tester.pump(_debounce);
    expect(h.emitted.single, stored.replaceFirst('Company', 'Company AG'));
  });

  testWidgets('a pending edit is not lost when the field is torn down', (
    tester,
  ) async {
    final h = await _pump(tester, kTipTapTable);
    final edited = kTipTapTable.replaceFirst('Company GmbH', 'Company AG');
    await tester.enterText(find.byType(TextField), edited);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(h.emitted, [edited]);
  });

  testWidgets('runSettingsSave flushes a pending source edit before saving', (
    tester,
  ) async {
    // Save does not blur a text field on its own; the settings save unfocuses
    // first, and the blur is what flushes the debounce.
    final h = _Harness();
    addTearDown(h.toasts.dispose);
    final host = _FakeHost();
    await tester.pumpWidget(
      _app(
        h,
        Builder(
          builder: (context) => Column(
            children: [
              SizedBox(width: 480, child: _field(h, kTipTapTable)),
              ElevatedButton(
                onPressed: () => runSettingsSave(context, host),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    final edited = kTipTapTable.replaceFirst('Bank: ACME', 'Bank: OTHER');
    await tester.enterText(find.byType(TextField), edited);
    expect(h.emitted, isEmpty);

    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(h.emitted, [edited]);
    // Let the "Saved" toast's own timer run out.
    await tester.pump(const Duration(seconds: 4));
  });
}
