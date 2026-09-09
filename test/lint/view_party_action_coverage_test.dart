import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: every entity whose record belongs to a client or a vendor offers
/// **View client** / **View vendor** in its actions menu, and dispatches it.
///
/// This is the replacement home for the shortcut invoiceninja/flutter#128
/// removed from the narrow list row, so an entity that loses it has no path to
/// the party from the list at all.
///
/// It needs a build-time check because only *half* of the wiring is
/// compiler-enforced. Each `dispatch` is an exhaustive switch over its action
/// enum, so adding the enum value forces the `case` — but nothing forces the
/// `itemsFor` entry. Add the value and the case, forget the item, and the
/// entity ships a dead action with a green suite. Same asymmetry
/// `entity_copy_link_coverage_test.dart` exists for.
void main() {
  /// path → the action name that file must carry.
  const expected = {
    'lib/ui/features/invoices/widgets/invoice_actions.dart': 'viewClient',
    'lib/ui/features/quotes/widgets/quote_actions.dart': 'viewClient',
    'lib/ui/features/credits/widgets/credit_actions.dart': 'viewClient',
    'lib/ui/features/recurring_invoices/widgets/recurring_invoice_actions.dart':
        'viewClient',
    'lib/ui/features/payments/widgets/payment_actions.dart': 'viewClient',
    'lib/ui/features/tasks/widgets/task_actions.dart': 'viewClient',
    'lib/ui/features/purchase_orders/widgets/purchase_order_actions.dart':
        'viewVendor',
    'lib/ui/features/expenses/widgets/expense_actions.dart': 'viewVendor',
    'lib/ui/features/recurring_expenses/widgets/recurring_expense_actions.dart':
        'viewVendor',
  };

  test('every party-bearing entity offers and dispatches View client/vendor', () {
    final missingItem = <String>[];
    final missingCase = <String>[];
    final missingFlag = <String>[];
    final missingGate = <String>[];

    for (final entry in expected.entries) {
      final file = File(entry.key);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'actions file moved — update this lint: ${entry.key}',
      );
      final src = file.readAsStringSync();
      final action = entry.value;
      final name = file.uri.pathSegments.last;

      if (!src.contains('kind: ') || !src.contains('.$action,')) {
        missingItem.add(name);
      }
      if (!src.contains('case ') || !src.contains('.$action:')) {
        missingCase.add(name);
      }
      // The item must never reach the edit screen: `_onAction` there treats an
      // action with no `saveParamFor` entry as an after-save action and saves
      // the dirty form (or creates the record) before dispatching it.
      if (!src.contains('isNavigationOnly: true')) {
        missingFlag.add(name);
      }
      // A labelled "go to the client" affordance is permission-gated, the way
      // `EntityLinkCard`'s `permissionKey:` is on the detail grids.
      final perm = action == 'viewClient' ? 'view_client' : 'view_vendor';
      if (!src.contains("can('$perm')")) {
        missingGate.add(name);
      }
    }

    expect(
      missingItem,
      isEmpty,
      reason:
          'no `kind: <X>Action.view(Client|Vendor)` menu item — the enum value '
          'and the dispatch case compile without it, so the action is dead:\n'
          '  ${missingItem.join('\n  ')}',
    );
    expect(
      missingCase,
      isEmpty,
      reason: 'no dispatch case:\n  ${missingCase.join('\n  ')}',
    );
    expect(
      missingFlag,
      isEmpty,
      reason:
          'the item needs `isNavigationOnly: true` or the edit screen will '
          'save (or create) the record when it is tapped:\n'
          '  ${missingFlag.join('\n  ')}',
    );
    expect(
      missingGate,
      isEmpty,
      reason:
          'gate the item on `me?.can(...)`, matching EntityLinkCard:\n'
          '  ${missingGate.join('\n  ')}',
    );
  });
}
