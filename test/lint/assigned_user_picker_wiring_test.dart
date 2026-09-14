import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The two task pickers must stay on their shared leaves, and the invoiced-task
/// lock must stay wrapped around them.
///
/// Structural, and it has to be. `AssignedUserPickerField` and
/// `TaskStatusPickerField` have their own suites, which prove the *mechanism*
/// (archived rows dropped, selection resolved by id, no `emptyHintKey`); what
/// is left to protect is the **wiring**, and there is no widget test for
/// `task_edit_layout.dart` anywhere in `test/` — pumping it needs a whole
/// `TaskEditViewModel` plus a `noSuchMethod` `Services` stub with five fake
/// repositories, to assert something a grep can see. Same trade
/// `task_filter_bar_wiring_test.dart` and `sidebar_menu_wiring_test.dart` make.
///
/// Three regressions this catches, all of which compile, run and look right:
///
/// 1. **The window scan comes back.** Both hosts used to resolve the selection
///    out of `services.user.watchPage(loadedPages: 100)` / `taskStatuses
///    .watchAll` with a linear scan — so archiving the assigned user (or the
///    status) dropped the row from `items`,
///    `SearchableDropdownField.didUpdateWidget` blanked the field **without**
///    firing `onChanged`, and the form silently lost a value it still held.
/// 2. **The lock is dropped.** `_Lockable` is what stops a keyboard user
///    editing an invoiced task's status or assignee — `IgnorePointer` alone
///    only overrides hit testing, so Tab still reaches a picker that can then
///    be driven entirely from the keyboard.
/// 3. **The sheet's pickers stop reaching the saved draft.** A picker whose
///    value never lands in `_seed()` is decorative, and nothing about the
///    screen would look wrong.
void main() {
  String codeOf(String path) {
    final src = File(path).readAsStringSync();
    // `//` tails stripped — the prose in both files names every token these
    // rules match.
    return src
        .split('\n')
        .map((l) {
          final i = l.indexOf('//');
          return i == -1 ? l : l.substring(0, i);
        })
        .join('\n');
  }

  const editLayout = 'lib/ui/features/tasks/widgets/edit/task_edit_layout.dart';
  const sheet =
      'lib/ui/features/tasks/widgets/create_task_from_line_item_sheet.dart';

  late final String edit = codeOf(editLayout);
  late final String sheetCode = codeOf(sheet);

  test('both hosts use the shared pickers', () {
    for (final entry in {editLayout: edit, sheet: sheetCode}.entries) {
      for (final widget in const [
        'AssignedUserPickerField(',
        'TaskStatusPickerField(',
      ]) {
        expect(
          entry.value.contains(widget),
          isTrue,
          reason:
              'Expected `$widget` in ${entry.key} — the roster and status '
              'queries live in one leaf each so their call sites cannot drift.',
        );
      }
    }
  });

  test('neither host hand-rolls a user or status dropdown', () {
    for (final entry in {editLayout: edit, sheet: sheetCode}.entries) {
      for (final banned in const [
        'SearchableDropdownField<User>',
        'SearchableDropdownField<TaskStatus>',
      ]) {
        expect(
          entry.value.contains(banned),
          isFalse,
          reason:
              'A raw $banned in ${entry.key} means the selection is being '
              'resolved by scanning the loaded window again — archive the '
              'selected record and the field blanks while the draft keeps it.',
        );
      }
      // Dense, not raw: `dart format` splits a long receiver across lines
      // (`services.user` / newline / `.watchPage(`), which a raw `contains`
      // would sail straight past — the same failure this file's own
      // `_Lockable` assertion avoids by matching on `_dense`.
      expect(
        _dense(entry.value).contains('user.watchPage('),
        isFalse,
        reason:
            '${entry.key}: `watchPage` is a paged entity read. It offers only '
            'what page 1 of the login prefetch left in Drift, and decodes '
            'every row to do it.',
      );
    }
  });

  /// Argument-list matched, not substring matched: a literal
  /// `_Lockable(locked:locked,child:TaskStatusPickerField(` pins the *order* of
  /// two named arguments, so swapping them would turn this red with a message
  /// about a missing keyboard lock. `tasks_view_wiring_test.dart` was burned by
  /// exactly that and answered it with an `_argsOf` helper; this is the
  /// all-occurrences form of it.
  test('the invoiced-task lock still wraps both pickers', () {
    final wrapped = _argListsOf(_dense(edit), '_Lockable(');
    for (final picker in const [
      'TaskStatusPickerField(',
      'AssignedUserPickerField(',
    ]) {
      expect(
        wrapped.any((args) => args.contains('child:$picker')),
        isTrue,
        reason:
            'Expected a `_Lockable` whose child is $picker. Without it a '
            'keyboard user can Tab into the picker on an invoiced task and '
            'edit a record the server will reject — `IgnorePointer` alone only '
            'overrides hit testing.',
      );
    }
  });

  test("the sheet's pickers reach the saved draft", () {
    final dense = _dense(sheetCode);
    for (final field in const [
      'statusId:_statusId',
      'assignedUserId:_assignedUserId',
    ]) {
      expect(
        dense.contains(field),
        isTrue,
        reason:
            'Expected `$field` in the sheet\'s `_seed()`. A picker whose value '
            'never reaches the created task is decorative, and nothing on '
            'screen would look wrong.',
      );
    }
  });
}

String _dense(String source) => source.replaceAll(RegExp(r'\s+'), '');

/// Every argument list passed to [ctor] in [dense], parens balanced so a nested
/// call cannot end the match early.
List<String> _argListsOf(String dense, String ctor) {
  final out = <String>[];
  var from = 0;
  while (true) {
    final start = dense.indexOf(ctor, from);
    if (start < 0) return out;
    var depth = 0;
    var i = start + ctor.length - 1;
    for (; i < dense.length; i++) {
      if (dense[i] == '(') depth++;
      if (dense[i] == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    out.add(dense.substring(start + ctor.length, i));
    from = start + ctor.length;
  }
}
