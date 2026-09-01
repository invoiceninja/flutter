import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/overridable_markdown_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';

import '../../../../_localization_helper.dart';

/// At client/group scope `OverridableField` dims a field the user hasn't
/// overridden and makes it inert. For every other variant that means an
/// `IgnorePointer`, which is right — a `TextField` has nothing to interact
/// with when it's read-only. The markdown editor owns an internal scroll view,
/// so the same wrapper made a long inherited Terms unreadable: the
/// invoiceninja/flutter#107 defect, reappearing in the settings cascade.

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

Future<void> _pumpAtClientScope(WidgetTester tester, Widget child) async {
  final level = SettingsLevelController()
    ..setLevel(SettingsLevel.client, targetId: 'c1');
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsLevelController>.value(value: level),
            ChangeNotifierProvider<SettingsDraftHost>.value(
              value: _FakeHost(
                CompanySettings(
                  invoiceTerms: [
                    for (var i = 0; i < 40; i++) 'line $i',
                  ].join('\n\n'),
                ),
              ),
            ),
          ],
          child: SizedBox(width: 360, child: child),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('an inherited markdown value can still be scrolled and read', (
    tester,
  ) async {
    await _pumpAtClientScope(
      tester,
      const OverridableMarkdownField(label: 'Terms', apiKey: 'invoice_terms'),
    );

    // Inherited, so no override checkbox is ticked and the editor is inert to
    // editing — but the document must stay reachable.
    expect(find.byType(SuperReader), findsOneWidget);
    expect(find.byType(SuperEditor), findsNothing);

    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    // Drag the field, not the reader — SuperReader is a sliver here and has no
    // RenderBox for the test to target.
    await tester.drag(find.byType(MarkdownTextField), const Offset(0, -60));
    await tester.pump();
    expect(position.pixels, greaterThan(0));
    // Retire SuperReader's double-tap countdown, started by the pointer down.
    // That it exists at all is the point: the reader's recognizers are live.
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('other variants stay pointer-blocked when not overridden', (
    tester,
  ) async {
    // The opt-out is per-variant: only the markdown editor asks for it, and
    // nothing else may quietly become interactive at cascade scope.
    await _pumpAtClientScope(
      tester,
      const OverridableSwitchField(
        label: 'Toggle',
        apiKey: 'auto_email_invoice',
      ),
    );

    final ignoring = tester
        .widgetList<IgnorePointer>(
          find.ancestor(
            of: find.byType(SwitchListTile),
            matching: find.byType(IgnorePointer),
          ),
        )
        .any((w) => w.ignoring);
    expect(ignoring, isTrue);
  });
}
