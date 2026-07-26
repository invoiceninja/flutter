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
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(id: 'co1', name: 'Co', enabledModules: enabledModules),
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
}
