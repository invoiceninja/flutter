import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/entity_edit_scaffold.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';

import '../../../_localization_helper.dart';

/// Minimal Services — `EntityEditScaffold` → `UnsavedChangesScope` only
/// touches `unsavedChangesGuard`.
class _FakeServices implements Services {
  _FakeServices(this.unsavedChangesGuard);
  @override
  final UnsavedChangesGuard unsavedChangesGuard;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Fake edit VM. `original == null` ⇒ create mode; passing the same value
/// for initialDraft + original ⇒ existing & not dirty. Records whether
/// performSave ran and what save-query it consumed (mirrors the real
/// billing-doc `performSave`).
class _FakeVM extends GenericEditViewModel<String> {
  _FakeVM({required super.initialDraft, super.original});

  bool saveCalled = false;
  Map<String, String>? consumedQuery;

  @override
  Future<SaveResult<String>> performSave() async {
    saveCalled = true;
    consumedQuery = consumeSaveQuery();
    return SaveResult(entity: draft, outboxRowId: 1);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _FakeVM vm,
  required bool canSave,
  required List<EntityActionItem<String>> Function(void Function(Object)) items,
  Map<String, String>? Function(Object)? saveParamFor,
  Future<void> Function(BuildContext, String, Object)? onAfterSaveAction,
  Future<bool> Function(BuildContext, String, Object)?
  onAfterSaveActionOnCreate,
  void Function(BuildContext, String)? onSaved,
  Size surface = const Size(800, 600),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Provider<Services>.value(
        value: _FakeServices(UnsavedChangesGuard()),
        child: EntityEditScaffold<String>(
          vm: vm,
          canSave: canSave,
          titleBuilder: (_) => 'A Fairly Long Edit Screen Title Here',
          bodyBuilder: (_) => const SizedBox.shrink(),
          resetToEmpty: () {},
          onSaved: (ctx, saved) => onSaved?.call(ctx, saved),
          actionsBuilder: (context, onTap, saveButton) =>
              EntityOverflowActionBar<String>(
                leading: saveButton,
                items: items(onTap),
              ),
          saveParamFor: saveParamFor,
          onAfterSaveAction: onAfterSaveAction,
          onAfterSaveActionOnCreate: onAfterSaveActionOnCreate,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('H1: at a narrow width the header shows Save + a compact ⋮ (no '
      'RenderFlex overflow, even with a long title) and the Save button '
      'carries no Tooltip (regression: a Tooltip/OverlayPortal measured in '
      'OverflowView\'s layout callback corrupts the element tree)', (
    tester,
  ) async {
    final vm = _FakeVM(initialDraft: 'd', original: 'd');
    await _pump(
      tester,
      vm: vm,
      canSave: true,
      surface: const Size(360, 640),
      items: (onTap) => [
        for (var i = 0; i < 6; i++)
          EntityActionItem(
            kind: 'a$i',
            icon: Icons.bolt_outlined,
            label: 'Action number $i',
            enabled: true,
            onTap: () => onTap('a$i'),
          ),
      ],
    );

    // The title yields room to the fixed Save + ⋮ cluster, so the header lays
    // out without a RenderFlex overflow (the long title ellipsises instead).
    expect(tester.takeException(), isNull);
    // Mobile matches the detail header: Save + a label-less ⋮ IconButton
    // holding every action — never the labeled "More" button. Both triggers
    // carry `Icons.more_vert`, so the widget is what tells them apart.
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.more_vert), findsOneWidget);
    expect(find.widgetWithIcon(OutlinedButton, Icons.more_vert), findsNothing);
    expect(find.text('More'), findsNothing);
    // Save is a plain Row child here (not measured inside OverflowView), so it
    // still carries no Tooltip ancestor.
    expect(
      find.ancestor(
        of: find.byType(FilledButton),
        matching: find.byType(Tooltip),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'H1: title is left-aligned and the Save + action cluster hugs the '
    'right edge of the header',
    (tester) async {
      final vm = _FakeVM(initialDraft: 'd', original: 'd');
      await _pump(
        tester,
        vm: vm,
        canSave: true,
        surface: const Size(1000, 640),
        items: (onTap) => [
          for (var i = 0; i < 2; i++)
            EntityActionItem(
              kind: 'a$i',
              icon: Icons.bolt_outlined,
              label: 'Action $i',
              enabled: true,
              onTap: () => onTap('a$i'),
            ),
        ],
      );

      final appBar = tester.getRect(find.byType(AppBar));
      final title = tester.getRect(
        find.text('A Fairly Long Edit Screen Title Here'),
      );
      final saveFinder = find.byType(FilledButton);
      final save = tester.getRect(saveFinder);

      // Save is the bar's plain leading child — a FilledButton with NO
      // Tooltip ancestor (a Tooltip mounts an OverlayPortal, which is
      // illegal as a measured OverflowView child and corrupts the element
      // tree — the regression this guards).
      expect(saveFinder, findsOneWidget);
      expect(
        find.ancestor(of: saveFinder, matching: find.byType(Tooltip)),
        findsNothing,
      );
      // Title hugs the left.
      expect(title.left, lessThan(appBar.left + appBar.width * 0.5));
      // Save (leftmost of the right-aligned cluster) sits in the right
      // half, clear of the title.
      expect(save.left, greaterThan(appBar.left + appBar.width * 0.5));
      expect(save.left, greaterThan(title.right));
      // The trailing action cluster ends near the right edge.
      final lastAction = tester.getRect(find.text('Action 1'));
      expect(lastAction.right, greaterThan(appBar.right - 64));
    },
  );

  testWidgets('H2: SAVE-PARAM fires on an unchanged existing record even when '
      'canSave is false (dirty-gated screens)', (tester) async {
    // Existing + not dirty; canSave:false simulates a screen whose
    // canSave folds in `isDirty`.
    final vm = _FakeVM(initialDraft: 'd', original: 'd');
    expect(vm.isCreate, isFalse);
    expect(vm.isDirty, isFalse);

    await _pump(
      tester,
      vm: vm,
      canSave: false,
      items: (onTap) => [
        EntityActionItem(
          kind: 'mark_sent',
          icon: Icons.send_outlined,
          label: 'Mark Sent',
          enabled: true,
          onTap: () => onTap('mark_sent'),
        ),
      ],
      saveParamFor: (a) =>
          a == 'mark_sent' ? const {'mark_sent': 'true'} : null,
    );

    await tester.tap(find.text('Mark Sent'));
    await tester.pumpAndSettle();

    expect(vm.saveCalled, isTrue);
    expect(vm.consumedQuery, {'mark_sent': 'true'});
  });

  testWidgets('H2: SAVE-PARAM is still blocked in create mode when the form is '
      'invalid (canSave false)', (tester) async {
    final vm = _FakeVM(initialDraft: 'd'); // original null ⇒ create
    expect(vm.isCreate, isTrue);

    await _pump(
      tester,
      vm: vm,
      canSave: false,
      items: (onTap) => [
        EntityActionItem(
          kind: 'mark_sent',
          icon: Icons.send_outlined,
          label: 'Mark Sent',
          enabled: true,
          onTap: () => onTap('mark_sent'),
        ),
      ],
      saveParamFor: (a) =>
          a == 'mark_sent' ? const {'mark_sent': 'true'} : null,
    );

    await tester.tap(find.text('Mark Sent'));
    await tester.pumpAndSettle();

    expect(vm.saveCalled, isFalse);
  });

  testWidgets('H3: create + after-save action that owns navigation ⇒ save '
      'runs but onSaved (the detail redirect) is skipped', (tester) async {
    final vm = _FakeVM(initialDraft: 'd'); // original null ⇒ create
    expect(vm.isCreate, isTrue);
    var onSavedCalled = false;
    var dispatched = false;

    await _pump(
      tester,
      vm: vm,
      canSave: true,
      items: (onTap) => [
        EntityActionItem(
          kind: 'send_email',
          icon: Icons.mail_outlined,
          label: 'Send Email',
          enabled: true,
          onTap: () => onTap('send_email'),
        ),
      ],
      onSaved: (_, _) => onSavedCalled = true,
      onAfterSaveActionOnCreate: (_, _, _) async {
        dispatched = true;
        return true; // the action navigated; scaffold must not override
      },
    );

    await tester.tap(find.text('Send Email'));
    await tester.pumpAndSettle();

    expect(vm.saveCalled, isTrue); // saved first to mint the row
    expect(dispatched, isTrue); // create handler ran
    expect(onSavedCalled, isFalse); // detail redirect suppressed
  });

  testWidgets('H3: create + after-save action that did NOT navigate '
      '(offline / tmp fallback) ⇒ onSaved still runs', (tester) async {
    final vm = _FakeVM(initialDraft: 'd');
    var onSavedCalled = false;

    await _pump(
      tester,
      vm: vm,
      canSave: true,
      items: (onTap) => [
        EntityActionItem(
          kind: 'send_email',
          icon: Icons.mail_outlined,
          label: 'Send Email',
          enabled: true,
          onTap: () => onTap('send_email'),
        ),
      ],
      onSaved: (_, _) => onSavedCalled = true,
      onAfterSaveActionOnCreate: (_, _, _) async => false, // never navigated
    );

    await tester.tap(find.text('Send Email'));
    await tester.pumpAndSettle();

    expect(vm.saveCalled, isTrue);
    expect(onSavedCalled, isTrue); // falls back to the detail screen
  });

  testWidgets('H3: edit mode ignores the create-only handler and never calls '
      'onSaved (the action owns its own navigation)', (tester) async {
    final vm = _FakeVM(initialDraft: 'd2', original: 'd'); // existing + dirty
    expect(vm.isCreate, isFalse);
    expect(vm.isDirty, isTrue);
    var onSavedCalled = false;
    var createHandlerCalled = false;
    var editDispatched = false;

    await _pump(
      tester,
      vm: vm,
      canSave: true,
      items: (onTap) => [
        EntityActionItem(
          kind: 'send_email',
          icon: Icons.mail_outlined,
          label: 'Send Email',
          enabled: true,
          onTap: () => onTap('send_email'),
        ),
      ],
      onSaved: (_, _) => onSavedCalled = true,
      onAfterSaveAction: (_, _, _) async {
        editDispatched = true;
      },
      onAfterSaveActionOnCreate: (_, _, _) async {
        createHandlerCalled = true;
        return true;
      },
    );

    await tester.tap(find.text('Send Email'));
    await tester.pumpAndSettle();

    expect(vm.saveCalled, isTrue);
    expect(editDispatched, isTrue); // edit path uses onAfterSaveAction
    expect(createHandlerCalled, isFalse); // create-only handler unused in edit
    expect(onSavedCalled, isFalse); // edit path never auto-navigates
  });
}
