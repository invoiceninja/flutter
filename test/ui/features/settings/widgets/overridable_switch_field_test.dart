import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';

import '../../../../_localization_helper.dart';

/// Minimal company-scope host — mirrors `overridable_number_field_test.dart`.
/// At company level `OverridableField.bind` renders the child unwrapped, so
/// `isOverridden` / `setOverride` are never reached.
class _FakeHost extends SettingsDraftHost {
  _FakeHost(this._settings);
  CompanySettings _settings;

  @override
  CompanySettings get settings => _settings;
  @override
  CompanySettings get draftSettings => _settings;
  @override
  Company? get draft => const Company();
  @override
  Map<String, List<String>> get fieldErrors => const {};
  @override
  void updateSettings(CompanySettings Function(CompanySettings) edit) {
    _settings = edit(_settings);
    notifyListeners();
  }

  // Lifecycle surface — inert for this isolated field test.
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

Future<void> _pump(
  WidgetTester tester,
  _FakeHost host, {
  required String apiKey,
  bool? defaultValue,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsLevelController>.value(
              value: SettingsLevelController(),
            ),
            ChangeNotifierProvider<SettingsDraftHost>.value(value: host),
          ],
          child: SizedBox(
            width: 360,
            child: defaultValue == null
                ? OverridableSwitchField(label: 'Toggle', apiKey: apiKey)
                : OverridableSwitchField(
                    label: 'Toggle',
                    apiKey: apiKey,
                    defaultValue: defaultValue,
                  ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _switchValue(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

void main() {
  testWidgets('an unset setting reads off when defaultValue is omitted', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeHost(const CompanySettings()),
      apiKey: 'auto_email_invoice',
    );
    expect(_switchValue(tester), isFalse);
  });

  testWidgets('an unset setting reads on when defaultValue is true', (
    tester,
  ) async {
    // The regression this guards: `documents_public_by_default` is unset on
    // every company until the server writes it, but the server's behavior for
    // an unset key is *public*. Rendering `false` there would be a toggle that
    // misreports what uploads actually do.
    await _pump(
      tester,
      _FakeHost(const CompanySettings()),
      apiKey: 'documents_public_by_default',
      defaultValue: true,
    );
    expect(_switchValue(tester), isTrue);
  });

  testWidgets('an explicit false wins over defaultValue: true', (tester) async {
    await _pump(
      tester,
      _FakeHost(const CompanySettings(documentsPublicByDefault: false)),
      apiKey: 'documents_public_by_default',
      defaultValue: true,
    );
    expect(_switchValue(tester), isFalse);
  });

  testWidgets('toggling writes an explicit value through the binding', (
    tester,
  ) async {
    final host = _FakeHost(const CompanySettings());
    await _pump(
      tester,
      host,
      apiKey: 'documents_public_by_default',
      defaultValue: true,
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(host.settings.documentsPublicByDefault, isFalse);
    expect(_switchValue(tester), isFalse);
  });
}
