import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/features/expenses/widgets/expense_actions.dart';

import '../../shell/_shell_test_helpers.dart';

/// Who is offered what on an expense, and which of it earns a tile on the
/// record screen. `expense_actions_test.dart` covers what each action needs
/// of the *expense*; this covers what it needs of the *user*, and the
/// record-screen strip built from the same items.
///
/// `can()` short-circuits true for an admin or owner, so every permission
/// case here is a non-admin with explicit tokens.
Expense _expense({
  String id = 'exp1',
  String invoiceId = '',
  String clientId = 'cl1',
  String vendorId = '',
  bool isDeleted = false,
  int archivedAt = 0,
}) => Expense.fromApi(
  ExpenseApi(
    id: id,
    invoiceId: invoiceId,
    clientId: clientId,
    vendorId: vendorId,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
  ),
);

void main() {
  /// Runs [read] with a context under a company with [permissions].
  Future<T> resolve<T>(
    WidgetTester tester,
    T Function(BuildContext context) read, {
    String? permissions,
    int enabledModules = 32767,
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(
          id: 'co1',
          name: 'Co',
          enabledModules: enabledModules,
          isOwner: permissions == null,
          isAdmin: permissions == null,
          permissions: permissions ?? '',
        ),
      ],
    );
    addTearDown(fixture.dispose);
    late T result;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            result = read(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return result;
  }

  Future<Set<ExpenseAction>> kinds(
    WidgetTester tester,
    Expense expense, {
    String? permissions,
    int enabledModules = 32767,
  }) async {
    final items = await resolve(
      tester,
      (context) => ExpenseActions.itemsFor(context, expense, (_) {}),
      permissions: permissions,
      enabledModules: enabledModules,
    );
    return {for (final i in flattenActionItems(items)) i.kind};
  }

  Future<List<EntityQuickAction<ExpenseAction>>> tiles(
    WidgetTester tester,
    Expense expense, {
    String? permissions,
  }) async {
    final priority = await resolve(
      tester,
      (context) => ExpenseActions.quickItemsFor(context, expense, (_) {}),
      permissions: permissions,
    );
    return pickQuickActions(priority, max: 6);
  }

  group('the lifecycle actions need edit_expense', () {
    // The server authorizes archive, restore and delete through the edit
    // policy. Ungated, a view-only user was offered Restore — one tap from
    // the record's state banner — for a mutation the server refuses.
    testWidgets('a view-only user is offered none of them', (tester) async {
      final live = await kinds(tester, _expense(), permissions: 'view_expense');
      expect(live, isNot(contains(ExpenseAction.archive)));
      expect(live, isNot(contains(ExpenseAction.delete)));
    });

    testWidgets('…including Restore on an archived expense', (tester) async {
      final archived = await kinds(
        tester,
        _expense(archivedAt: 1700000000),
        permissions: 'view_expense',
      );
      expect(archived, isNot(contains(ExpenseAction.restore)));
    });

    testWidgets('an editor is offered them', (tester) async {
      final live = await kinds(tester, _expense(), permissions: 'edit_expense');
      expect(live, contains(ExpenseAction.archive));
      expect(live, contains(ExpenseAction.delete));
    });
  });

  group('an action that makes a new record needs create_<entity>', () {
    testWidgets('edit rights alone offer no clone and no invoice', (
      tester,
    ) async {
      final got = await kinds(tester, _expense(), permissions: 'edit_expense');
      expect(got, isNot(contains(ExpenseAction.clone)));
      expect(got, isNot(contains(ExpenseAction.cloneToRecurring)));
      expect(got, isNot(contains(ExpenseAction.invoiceExpense)));
    });

    testWidgets('each create permission unlocks its own action', (
      tester,
    ) async {
      expect(
        await kinds(tester, _expense(), permissions: 'create_expense'),
        allOf(
          contains(ExpenseAction.clone),
          isNot(contains(ExpenseAction.cloneToRecurring)),
          isNot(contains(ExpenseAction.invoiceExpense)),
        ),
      );
    });

    testWidgets('clone to recurring needs create_recurring_expense', (
      tester,
    ) async {
      expect(
        await kinds(
          tester,
          _expense(),
          permissions: 'create_recurring_expense',
        ),
        contains(ExpenseAction.cloneToRecurring),
      );
    });

    testWidgets('invoice expense needs create_invoice — and whoever may '
        'create an invoice may own one to add to', (tester) async {
      // Add To Invoice edits an invoice that exists, and the server lets an
      // invoice's creator edit it without `edit_invoice`
      // (`EntityPolicy::edit`). Which invoice is not known until it is
      // picked, so a user who creates invoices is offered the action; gated
      // on `edit_invoice` alone, they lost it.
      final creator = await kinds(
        tester,
        _expense(),
        permissions: 'create_invoice',
      );
      expect(creator, contains(ExpenseAction.invoiceExpense));
      expect(creator, contains(ExpenseAction.addToInvoice));
    });

    testWidgets('…and with neither, neither is offered', (tester) async {
      final viewer = await kinds(
        tester,
        _expense(),
        permissions: 'view_invoice,view_expense',
      );
      expect(viewer, isNot(contains(ExpenseAction.invoiceExpense)));
      expect(viewer, isNot(contains(ExpenseAction.addToInvoice)));
    });

    testWidgets('…and edit_invoice offers add to invoice, not a new one', (
      tester,
    ) async {
      final editor = await kinds(
        tester,
        _expense(),
        permissions: 'edit_invoice',
      );
      expect(editor, contains(ExpenseAction.addToInvoice));
      expect(editor, isNot(contains(ExpenseAction.invoiceExpense)));
    });
  });

  testWidgets('a deleted expense offers its link, its vendor and Restore — '
      'nothing that changes, copies or bills it', (tester) async {
    final got = await kinds(tester, _expense(isDeleted: true, vendorId: 'v1'));
    expect(got, {
      ExpenseAction.viewVendor,
      ExpenseAction.copyLink,
      ExpenseAction.restore,
    });
  });

  group('the record screen\'s tiles', () {
    List<ExpenseAction> order(List<EntityQuickAction<ExpenseAction>> t) => [
      for (final q in t) q.item.kind,
    ];

    testWidgets('an unbilled expense with a client leads with billing it', (
      tester,
    ) async {
      final t = await tiles(tester, _expense());
      expect(order(t), [
        ExpenseAction.invoiceExpense,
        ExpenseAction.addToInvoice,
        ExpenseAction.clone,
        ExpenseAction.cloneToRecurring,
        ExpenseAction.runTemplate,
      ]);
      // Labels short enough for a tile.
      expect(t.first.shortLabel, '+ Invoice');
      expect(t[2].shortLabel, 'Clone');
    });

    testWidgets('no client: nothing to add it to', (tester) async {
      final t = await tiles(tester, _expense(clientId: ''));
      expect(order(t), isNot(contains(ExpenseAction.addToInvoice)));
      expect(order(t).first, ExpenseAction.invoiceExpense);
    });

    testWidgets('once billed, the billing tiles yield their place', (
      tester,
    ) async {
      final t = await tiles(tester, _expense(invoiceId: 'inv1'));
      expect(order(t), [
        ExpenseAction.clone,
        ExpenseAction.cloneToRecurring,
        ExpenseAction.runTemplate,
      ]);
    });

    testWidgets('a deleted expense has none', (tester) async {
      expect(await tiles(tester, _expense(isDeleted: true)), isEmpty);
    });

    testWidgets('an unsynced expense has none — every one would answer '
        '"sync first"', (tester) async {
      expect(await tiles(tester, _expense(id: 'tmp_abc')), isEmpty);
    });

    testWidgets('a tile is never offered for an action the menu does not '
        'have', (tester) async {
      final t = await tiles(tester, _expense(), permissions: 'view_expense');
      // Run Template needs nothing but a synced expense.
      expect(order(t), [ExpenseAction.runTemplate]);
    });
  });
}
