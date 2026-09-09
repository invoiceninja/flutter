import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/features/expenses/widgets/expense_actions.dart';

import '../../shell/_shell_test_helpers.dart';

/// Gating coverage for `ExpenseActions.itemsFor`, mirroring the harness in
/// `purchase_order_actions_test.dart`. Expenses were one of three feature
/// areas with no `test/ui/features/<name>/` directory at all.
///
/// Rules the source documents:
///   - **invoice-expense is once-only** — it disables as soon as `invoiceId`
///     is set, so an already-billed expense can't be billed twice;
///   - **add-to-invoice** needs the same un-invoiced state *plus* a client to
///     hang the invoice off (admin-portal parity);
///   - anything requiring a server round-trip (invoice, add-to-invoice, run
///     template) is disabled while the expense is still a `tmp_` offline
///     create.
Expense _expense({
  String id = 'exp1',
  String invoiceId = '',
  String clientId = 'cl1',
  bool isDeleted = false,
  int archivedAt = 0,
}) => Expense.fromApi(
  ExpenseApi(
    id: id,
    invoiceId: invoiceId,
    clientId: clientId,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
  ),
);

void main() {
  Future<List<EntityActionItem<ExpenseAction>>> resolveItems(
    WidgetTester tester,
    Expense expense, {
    int enabledModules = 32767,
    bool isOwner = true,
    bool isAdmin = true,
    String permissions = '',
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(
          id: 'co1',
          name: 'Co',
          enabledModules: enabledModules,
          isOwner: isOwner,
          isAdmin: isAdmin,
          permissions: permissions,
        ),
      ],
    );
    addTearDown(fixture.dispose);

    late List<EntityActionItem<ExpenseAction>> items;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            items = ExpenseActions.itemsFor(context, expense, (_) {});
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return items;
  }

  bool enabled(
    List<EntityActionItem<ExpenseAction>> items,
    ExpenseAction kind,
  ) {
    final match = flattenActionItems(items).where((i) => i.kind == kind);
    return match.isNotEmpty && match.first.enabled;
  }

  bool present(
    List<EntityActionItem<ExpenseAction>> items,
    ExpenseAction kind,
  ) => flattenActionItems(items).any((i) => i.kind == kind);

  group('invoice expense — once only', () {
    testWidgets('enabled on an un-invoiced expense', (tester) async {
      final items = await resolveItems(tester, _expense());

      expect(enabled(items, ExpenseAction.invoiceExpense), isTrue);
    });

    testWidgets('disabled once an invoice is linked', (tester) async {
      final items = await resolveItems(tester, _expense(invoiceId: 'inv1'));

      expect(
        enabled(items, ExpenseAction.invoiceExpense),
        isFalse,
        reason: 'an already-billed expense must not be billable twice',
      );
    });

    testWidgets('disabled while still an offline tmp_ create', (tester) async {
      final items = await resolveItems(tester, _expense(id: 'tmp_abc'));

      expect(enabled(items, ExpenseAction.invoiceExpense), isFalse);
    });
  });

  group('add to invoice — un-invoiced AND has a client', () {
    testWidgets('enabled with a client and no invoice', (tester) async {
      final items = await resolveItems(tester, _expense());

      expect(enabled(items, ExpenseAction.addToInvoice), isTrue);
    });

    testWidgets('disabled without a client', (tester) async {
      final items = await resolveItems(tester, _expense(clientId: ''));

      expect(
        enabled(items, ExpenseAction.addToInvoice),
        isFalse,
        reason: 'there is no client whose invoices we could append to',
      );
    });

    testWidgets('disabled once invoiced', (tester) async {
      final items = await resolveItems(tester, _expense(invoiceId: 'inv1'));

      expect(enabled(items, ExpenseAction.addToInvoice), isFalse);
    });

    testWidgets('disabled while still an offline tmp_ create', (tester) async {
      final items = await resolveItems(tester, _expense(id: 'tmp_abc'));

      expect(enabled(items, ExpenseAction.addToInvoice), isFalse);
    });
  });

  group('module gating', () {
    testWidgets('both invoice actions vanish when the module is off', (
      tester,
    ) async {
      final items = await resolveItems(tester, _expense(), enabledModules: 0);

      expect(present(items, ExpenseAction.invoiceExpense), isFalse);
      expect(present(items, ExpenseAction.addToInvoice), isFalse);
    });

    testWidgets('clone and comment survive with all modules off', (
      tester,
    ) async {
      final items = await resolveItems(tester, _expense(), enabledModules: 0);

      expect(enabled(items, ExpenseAction.clone), isTrue);
      expect(enabled(items, ExpenseAction.addComment), isTrue);
      expect(enabled(items, ExpenseAction.logCall), isTrue);
    });
  });

  group('run template needs a synced expense', () {
    testWidgets('enabled on a real id', (tester) async {
      final items = await resolveItems(tester, _expense());

      expect(enabled(items, ExpenseAction.runTemplate), isTrue);
    });

    testWidgets('disabled on a tmp_ id', (tester) async {
      final items = await resolveItems(tester, _expense(id: 'tmp_abc'));

      expect(enabled(items, ExpenseAction.runTemplate), isFalse);
    });
  });

  group('lifecycle actions reflect entity state', () {
    testWidgets('a live expense offers archive and delete, not restore', (
      tester,
    ) async {
      final items = await resolveItems(tester, _expense());

      expect(present(items, ExpenseAction.archive), isTrue);
      expect(present(items, ExpenseAction.delete), isTrue);
      expect(present(items, ExpenseAction.restore), isFalse);
    });

    testWidgets('an archived expense offers restore, not archive', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _expense(archivedAt: 1700000000),
      );

      expect(present(items, ExpenseAction.restore), isTrue);
      expect(present(items, ExpenseAction.archive), isFalse);
    });

    testWidgets('a deleted expense offers restore but not delete', (
      tester,
    ) async {
      final items = await resolveItems(tester, _expense(isDeleted: true));

      expect(present(items, ExpenseAction.restore), isTrue);
      expect(present(items, ExpenseAction.delete), isFalse);
    });
  });

  testWidgets('clone-to-recurring is always available', (tester) async {
    final items = await resolveItems(tester, _expense(invoiceId: 'inv1'));

    expect(enabled(items, ExpenseAction.cloneToRecurring), isTrue);
  });

  /// The "View vendor" item is the replacement home for the shortcut
  /// invoiceninja/flutter#128 removed from the narrow row, so it has to be
  /// present — and it is a *labelled* "go to the vendor" affordance, so it is
  /// permission-gated the way `EntityLinkCard`'s `permissionKey:` is on the
  /// detail grids. `can()` short-circuits true for an admin or owner, so a
  /// non-admin with explicit permissions is the only way to see the gate.
  group('view vendor', () {
    testWidgets('present for an admin on an expense with a vendor', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _expense().copyWith(vendorId: 'v1'),
      );

      expect(present(items, ExpenseAction.viewVendor), isTrue);
    });

    testWidgets('absent when the expense has no vendor', (tester) async {
      final items = await resolveItems(tester, _expense());

      expect(present(items, ExpenseAction.viewVendor), isFalse);
    });

    testWidgets('absent for a user without view_vendor', (tester) async {
      final items = await resolveItems(
        tester,
        _expense().copyWith(vendorId: 'v1'),
        isOwner: false,
        isAdmin: false,
        permissions: 'view_expense',
      );

      expect(
        present(items, ExpenseAction.viewVendor),
        isFalse,
        reason: 'a labelled menu item makes a promise a table cell does not',
      );
    });

    testWidgets('present for a non-admin who does hold view_vendor', (
      tester,
    ) async {
      final items = await resolveItems(
        tester,
        _expense().copyWith(vendorId: 'v1'),
        isOwner: false,
        isAdmin: false,
        permissions: 'view_expense,view_vendor',
      );

      expect(present(items, ExpenseAction.viewVendor), isTrue);
    });

    testWidgets('never reaches an edit screen', (tester) async {
      // `EntityEditScaffold._onAction` would save the dirty form (or create the
      // record) before dispatching it, so `filterForEditScreen` drops it.
      final items = await resolveItems(
        tester,
        _expense().copyWith(vendorId: 'v1'),
      );
      final item = flattenActionItems(
        items,
      ).firstWhere((i) => i.kind == ExpenseAction.viewVendor);

      expect(item.isNavigationOnly, isTrue);
    });
  });
}
