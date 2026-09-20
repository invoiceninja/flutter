import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/ui/core/widgets/field_action_button.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_field_shell.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_text_field.dart';

import '../../../../_localization_helper.dart';

/// `OverridableTextField` as a Templates & Reminders subject
/// (invoiceninja/flutter#139): chips at rest, the server's default template
/// shown for an empty value at company scope.

const _default = r'New invoice $number';
const _caption =
    'Showing the default template. Your first edit saves a custom copy.';

class _FakeHost extends SettingsDraftHost {
  _FakeHost(this._settings, {this.cascade = false});

  CompanySettings _settings;

  /// Group/client scope: no company draft.
  final bool cascade;

  /// Every value written to the subject.
  final writes = <String?>[];

  @override
  CompanySettings get settings => _settings;
  @override
  CompanySettings get draftSettings => _settings;
  @override
  Company? get draft => cascade ? null : const Company();
  @override
  Map<String, List<String>> get fieldErrors => const {};
  @override
  void updateSettings(CompanySettings Function(CompanySettings) edit) {
    _settings = edit(_settings);
    writes.add(_settings.emailSubjectInvoice);
    notifyListeners();
  }

  @override
  bool get isLoaded => true;
  @override
  bool get isDirty => false;
  @override
  bool get isSaving => false;
  @override
  String? get loadError => null;
  @override
  String? get submitError => null;
  @override
  void reset() {}
  @override
  Future<Object?> save() async => null;
  @override
  Future<void> load() async {}
}

Future<_FakeHost> _pump(
  WidgetTester tester, {
  String? value,
  bool clientScope = false,
}) async {
  final host = _FakeHost(
    CompanySettings(emailSubjectInvoice: value),
    cascade: clientScope,
  );
  final level = SettingsLevelController();
  if (clientScope) level.setLevel(SettingsLevel.client, targetId: 'c1');
  final toasts = ToastController();
  addTearDown(toasts.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ToastController>.value(value: toasts),
        ChangeNotifierProvider<SettingsLevelController>.value(value: level),
        ChangeNotifierProvider<SettingsDraftHost>.value(value: host),
      ],
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: const Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              child: OverridableTextField(
                label: 'Subject',
                apiKey: 'email_subject_invoice',
                templateVariables: TemplateVariableScope.invoice,
                defaultValue: _default,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return host;
}

/// Enter edit mode by tapping the rest view's text, clear of its chips.
Future<void> _startEditing(WidgetTester tester) async {
  final paragraph = find.byWidgetPredicate(
    (w) => w is RichText && w.text.toPlainText().startsWith('New'),
  );
  await tester.tapAt(tester.getTopLeft(paragraph) + const Offset(3, 8));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an empty value shows the default template, muted, and writes '
      'nothing', (tester) async {
    final host = await _pump(tester);
    expect(find.text('Invoice Number'), findsOneWidget);
    expect(find.text(_caption), findsOneWidget);
    final chip = tester.widget<TemplateVariableChip>(
      find.byType(TemplateVariableChip),
    );
    expect(chip.muted, isTrue);
    expect(find.byIcon(Icons.restart_alt), findsNothing);
    expect(host.writes, isEmpty);
  });

  testWidgets('a chip change on the default saves the whole subject; Reset '
      'to default empties it again', (tester) async {
    final host = await _pump(tester);
    await tester.tap(find.text('Invoice Number'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();
    expect(host.writes, [r'New invoice $balance']);
    expect(find.text(_caption), findsNothing);

    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pumpAndSettle();
    expect(host.writes.last, '');
    expect(find.text('Invoice Number'), findsOneWidget);
    expect(find.text(_caption), findsOneWidget);
    expect(find.byIcon(Icons.restart_alt), findsNothing);
    await tester.pump(const Duration(seconds: 30));
  });

  testWidgets('editing starts from a copy of the default; text equal to it '
      'writes an empty value', (tester) async {
    final host = await _pump(tester);
    await _startEditing(tester);
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).controller!.text, _default);
    expect(host.writes, isEmpty, reason: 'looking is not editing');

    await tester.enterText(field, r'Your invoice $number');
    expect(host.writes.last, r'Your invoice $number');
    await tester.enterText(field, _default);
    expect(host.writes.last, '');
  });

  testWidgets('an inherited subject renders its chips but stays inert, with '
      'no default in sight', (tester) async {
    final host = await _pump(
      tester,
      value: r'Invoice $number',
      clientScope: true,
    );
    expect(find.text('Invoice Number'), findsOneWidget);
    expect(find.text(_caption), findsNothing);
    expect(find.byIcon(Icons.arrow_drop_down), findsNothing);

    await tester.tapAt(tester.getCenter(find.text('Invoice Number')));
    await tester.pumpAndSettle();
    expect(find.text('Change variable'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(host.writes, isEmpty);
  });

  testWidgets('"Insert variable" is a labelled button above the field, not a '
      'bare + inside it', (tester) async {
    // A suffix glyph has no tooltip on touch, competed with "Reset to
    // default" for the one suffix slot, and sat on top of the chip row that a
    // long subject runs underneath.
    final host = await _pump(tester);
    final button = find.widgetWithText(FieldActionButton, 'Insert variable');
    expect(button, findsOneWidget);
    expect(
      tester.getCenter(button).dy,
      lessThan(tester.getCenter(find.byType(TemplateVariableFieldShell)).dy),
      reason: 'above the field',
    );
    expect(
      find.descendant(
        of: find.byType(TemplateVariableFieldShell),
        matching: find.byIcon(Icons.add),
      ),
      findsNothing,
      reason: 'and no longer a suffix inside it',
    );
    final shell = find.byType(TemplateVariableFieldShell);
    expect(
      tester.getCenter(button).dx,
      greaterThan(tester.getCenter(shell).dx),
      reason: 'right-aligned over the field it acts on',
    );
    expect(
      tester.getBottomRight(button).dx,
      closeTo(tester.getBottomRight(shell).dx, 1),
    );

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Balance'), findsOneWidget, reason: 'the picker opened');

    await tester.tap(find.text('Balance'));
    await tester.pumpAndSettle();
    expect(host.writes.last, contains(r'$balance'));
    await tester.pump(const Duration(seconds: 30));
  });
}
