import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/edit_action_filter.dart';

enum _Action { edit, enterPayment, viewClient, sendEmail, archive }

EntityActionItem<_Action> _item(
  _Action kind, {
  bool isPrimary = false,
  bool isEdit = false,
  bool isNavigationOnly = false,
  bool isLifecycle = false,
}) => EntityActionItem(
  kind: kind,
  icon: Icons.circle,
  label: kind.name,
  enabled: true,
  isPrimary: isPrimary,
  isEdit: isEdit,
  isNavigationOnly: isNavigationOnly,
  isLifecycle: isLifecycle,
);

bool _isLifecycle(_Action a) => a == _Action.archive;

void main() {
  final items = [
    _item(_Action.edit, isPrimary: true, isEdit: true),
    _item(_Action.viewClient, isNavigationOnly: true),
    _item(_Action.sendEmail),
    _item(_Action.archive, isLifecycle: true),
  ];

  /// The one that would otherwise ship an unrequested save.
  ///
  /// `EntityEditScaffold._onAction` treats any action with no `saveParamFor`
  /// entry as an *after-save* action, so on a dirty form it calls `_runSave`
  /// **before** dispatching — and in create mode it creates the record outright,
  /// then races its own "saved" toast + detail redirect against the action's own
  /// navigation. A verb that only navigates must never be able to trigger that,
  /// so it never reaches the edit screen at all.
  test('a navigation-only action is dropped on edit AND on create', () {
    for (final isCreate in [false, true]) {
      final kept = filterForEditScreen(
        items,
        isCreate: isCreate,
        isLifecycle: _isLifecycle,
      ).map((i) => i.kind);
      expect(
        kept,
        isNot(contains(_Action.viewClient)),
        reason: 'isCreate: $isCreate',
      );
    }
  });

  test('the other two rules still hold', () {
    final onEdit = filterForEditScreen(
      items,
      isCreate: false,
      isLifecycle: _isLifecycle,
    ).map((i) => i.kind);
    // Edit is pointless on the screen that IS the editor.
    expect(onEdit, isNot(contains(_Action.edit)));
    // Lifecycle survives on an existing record...
    expect(onEdit, contains(_Action.archive));
    expect(onEdit, contains(_Action.sendEmail));

    final onCreate = filterForEditScreen(
      items,
      isCreate: true,
      isLifecycle: _isLifecycle,
    ).map((i) => i.kind);
    // ...but not on a brand-new one.
    expect(onCreate, isNot(contains(_Action.archive)));
    expect(onCreate, contains(_Action.sendEmail));
  });

  // A sent invoice's primary is Enter Payment, with Edit demoted beside it.
  // Dropping "the primary" hid Enter Payment from the editor and kept Edit.
  test('drops Edit, not whichever action is primary', () {
    final kept = filterForEditScreen(
      [
        _item(_Action.enterPayment, isPrimary: true),
        _item(_Action.edit, isEdit: true),
        _item(_Action.sendEmail),
      ],
      isCreate: false,
      isLifecycle: _isLifecycle,
    ).map((i) => i.kind);
    expect(kept, [_Action.enterPayment, _Action.sendEmail]);
  });
}
