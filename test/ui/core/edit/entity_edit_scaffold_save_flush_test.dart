import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/ui/core/edit/entity_edit_scaffold.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';

import '../../../_localization_helper.dart';

/// Minimal Services — `EntityEditScaffold` → `UnsavedChangesScope` only
/// touches `unsavedChangesGuard`; `Notify.*` falls back to `Services.toasts`,
/// which `noSuchMethod` throws for (caught → silent no-op, no ToastHost).
class _FakeServices implements Services {
  _FakeServices(this.unsavedChangesGuard);
  @override
  final UnsavedChangesGuard unsavedChangesGuard;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Draft is the field's ISO date string. `performSave` snapshots the draft
/// AS SEEN AT SAVE TIME — the assertion target for "was the typed-but-
/// unblurred field committed before save read the draft?".
class _FakeVM extends GenericEditViewModel<String> {
  _FakeVM() : super(initialDraft: '', original: '');

  bool saveCalled = false;
  String? draftAtSave;

  // Public wrapper so the field's onChanged can write the draft from outside
  // the VM (updateDraft is @protected).
  void setDraft(String v) => updateDraft(v);

  @override
  Future<SaveResult<String>> performSave() async {
    saveCalled = true;
    draftAtSave = draft;
    return SaveResult(entity: draft, outboxRowId: 1);
  }
}

Future<_FakeVM> _pumpEditWithDateField(WidgetTester tester) async {
  final vm = _FakeVM();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Provider<Services>.value(
        value: _FakeServices(UnsavedChangesGuard()),
        child: EntityEditScaffold<String>(
          vm: vm,
          canSave: true,
          titleBuilder: (_) => 'Edit',
          bodyBuilder: (_) => InDateField(
            value: null,
            labelText: 'Date',
            // Commit → ISO yyyy-MM-dd into the draft (no formatter ⇒ the field
            // parses/renders ISO).
            onChanged: (d) => vm.setDraft(
              d == null
                  ? ''
                  : '${d.year.toString().padLeft(4, '0')}-'
                        '${d.month.toString().padLeft(2, '0')}-'
                        '${d.day.toString().padLeft(2, '0')}',
            ),
          ),
          resetToEmpty: () {},
          onSaved: (_, _) {},
          // Bare Save button — no overflow bar needed for this test.
          actionsBuilder: (context, onTap, saveButton) => saveButton,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return vm;
}

void main() {
  // #39/#43: InDateField / InTimeField / MarkdownTextField commit on blur or
  // Enter only. ⌘S and the Save button don't blur the active field, so before
  // the pre-save `unfocus()` flush in `EntityEditScaffold._runSave` a typed-
  // but-unblurred value was silently dropped. These lock in that the flush
  // commits it into the draft before `vm.save()` reads it.

  testWidgets('⌘S flushes a typed-but-unblurred InDateField into the draft '
      'before save reads it', (tester) async {
    final vm = await _pumpEditWithDateField(tester);

    // Type an ISO date and DO NOT blur/submit — commit-on-blur means the draft
    // the save will read is still empty at this point.
    await tester.enterText(find.byType(TextField), '2026-05-14');
    await tester.pump();
    expect(
      vm.draft,
      isEmpty,
      reason: 'commit-on-blur: typing alone must not commit',
    );

    // ⌘S with the field still focused — invokes the same handler as the Save
    // button. The pre-save unfocus is the only thing that can commit here.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    expect(vm.saveCalled, isTrue);
    expect(
      vm.draftAtSave,
      '2026-05-14',
      reason: 'the pre-save unfocus must flush the typed date into the draft',
    );
  });

  testWidgets('the Save button flushes a typed-but-unblurred InDateField into '
      'the draft before save reads it', (tester) async {
    final vm = await _pumpEditWithDateField(tester);

    await tester.enterText(find.byType(TextField), '2026-05-14');
    await tester.pump();
    expect(vm.draft, isEmpty);

    // A pointer tap on the button does not blur the focused field (the
    // scaffold's pre-save unfocus does).
    await tester.tap(find.byKey(const ValueKey('entity_edit_save')));
    await tester.pumpAndSettle();

    expect(vm.saveCalled, isTrue);
    expect(vm.draftAtSave, '2026-05-14');
  });
}
