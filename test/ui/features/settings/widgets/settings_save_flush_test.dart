import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/settings_page_scaffold.dart';

import '../../../../_localization_helper.dart';

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

void main() {
  // U5: a settings markdown field (OverridableMarkdownField → MarkdownTextField)
  // emits on a 300ms debounce and flushes synchronously on blur, but clicking
  // Save / pressing Enter doesn't blur the editor — so a value typed in the last
  // debounce window is dropped from the saved payload. runSettingsSave must
  // unfocus the active editor before reading the draft; the blur triggers the
  // field's flush. A tap on the Save button does NOT blur a SuperEditor (only
  // an explicit unfocus does — see markdown_text_field_test), so the editor
  // reverting from SuperEditor back to SuperReader during save is proof the
  // pre-save unfocus ran.
  testWidgets('runSettingsSave blurs the focused markdown editor before saving '
      '(flushes the debounce)', (tester) async {
    final host = _FakeHost();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const SizedBox(
                  width: 320,
                  child: MarkdownTextField(
                    label: 'Terms',
                    initialValue: 'hello',
                    height: 80,
                    onChanged: _noop,
                  ),
                ),
                ElevatedButton(
                  onPressed: () => runSettingsSave(context, host),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Promote the reader to an editing SuperEditor (focus the field).
    await tester.tap(find.byType(MarkdownTextField));
    await tester.pump(); // post-frame _enterEditing
    await tester.pump(); // rebuild with the editor
    expect(find.byType(SuperEditor), findsOneWidget, reason: 'editor focused');

    // Save. Without the pre-save unfocus the tap leaves the editor focused
    // (a button tap doesn't blur a SuperEditor), so the debounce never flushes.
    await tester.tap(find.text('Save'));
    await tester.pump(); // runSettingsSave: unfocus + schedule revert + timer
    await tester.pump(const Duration(milliseconds: 50)); // timer → save()
    await tester.pump(); // settle the reader revert

    expect(
      find.byType(SuperEditor),
      findsNothing,
      reason:
          'save must blur the editor (flushing its debounce) — it should '
          'have reverted to a read-only SuperReader',
    );
    expect(find.byType(SuperReader), findsOneWidget);
  });
}

void _noop(String _) {}
