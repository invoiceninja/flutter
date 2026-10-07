import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_actions.dart';

import '../shell/_shell_test_helpers.dart';

/// Who is offered what on a recurring expense, and which of it earns a tile
/// on the record screen.
///
/// `can()` short-circuits true for an admin or owner, so every permission
/// case here is a non-admin with explicit tokens.
RecurringExpense _recurring({
  String id = 'r1',
  String? statusId = '2',
  String lastSentDate = '2026-10-01',
  String vendorId = '',
  bool isDeleted = false,
  int archivedAt = 0,
}) => RecurringExpense.fromApi(
  RecurringExpenseApi(
    id: id,
    statusId: statusId,
    lastSentDate: lastSentDate,
    vendorId: vendorId,
    isDeleted: isDeleted,
    archivedAt: archivedAt,
  ),
);

void main() {
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

  Future<Set<RecurringExpenseAction>> kinds(
    WidgetTester tester,
    RecurringExpense recurring, {
    String? permissions,
  }) async {
    final items = await resolve(
      tester,
      (context) => RecurringExpenseActions.itemsFor(context, recurring, (_) {}),
      permissions: permissions,
    );
    return {for (final i in flattenActionItems(items)) i.kind};
  }

  Future<List<RecurringExpenseAction>> tiles(
    WidgetTester tester,
    RecurringExpense recurring, {
    String? permissions,
  }) async {
    final priority = await resolve(
      tester,
      (context) =>
          RecurringExpenseActions.quickItemsFor(context, recurring, (_) {}),
      permissions: permissions,
    );
    return [for (final q in pickQuickActions(priority, max: 6)) q.item.kind];
  }

  group('start and stop follow the schedule\'s state', () {
    testWidgets('a running schedule can be stopped, not started', (
      tester,
    ) async {
      final got = await kinds(tester, _recurring());
      expect(got, contains(RecurringExpenseAction.stop));
      expect(got, isNot(contains(RecurringExpenseAction.start)));
    });

    testWidgets('a draft can be started, not stopped', (tester) async {
      final got = await kinds(
        tester,
        _recurring(statusId: '1', lastSentDate: ''),
      );
      expect(got, contains(RecurringExpenseAction.start));
      expect(got, isNot(contains(RecurringExpenseAction.stop)));
    });
  });

  group('permissions', () {
    testWidgets('a view-only user can neither stop it nor archive it', (
      tester,
    ) async {
      final got = await kinds(
        tester,
        _recurring(),
        permissions: 'view_recurring_expense',
      );
      expect(got, isNot(contains(RecurringExpenseAction.stop)));
      expect(got, isNot(contains(RecurringExpenseAction.archive)));
      expect(got, isNot(contains(RecurringExpenseAction.delete)));
      expect(got, isNot(contains(RecurringExpenseAction.clone)));
    });

    testWidgets('…nor restore an archived one', (tester) async {
      final got = await kinds(
        tester,
        _recurring(archivedAt: 1700000000),
        permissions: 'view_recurring_expense',
      );
      expect(got, isNot(contains(RecurringExpenseAction.restore)));
    });

    testWidgets('an editor can stop and archive it, but a clone is a create', (
      tester,
    ) async {
      final got = await kinds(
        tester,
        _recurring(),
        permissions: 'edit_recurring_expense',
      );
      expect(got, contains(RecurringExpenseAction.stop));
      expect(got, contains(RecurringExpenseAction.archive));
      expect(got, isNot(contains(RecurringExpenseAction.clone)));
      expect(got, isNot(contains(RecurringExpenseAction.cloneToExpense)));
    });

    testWidgets('each clone needs the create permission for what it makes', (
      tester,
    ) async {
      expect(
        await kinds(
          tester,
          _recurring(),
          permissions: 'create_recurring_expense',
        ),
        allOf(
          contains(RecurringExpenseAction.clone),
          isNot(contains(RecurringExpenseAction.cloneToExpense)),
        ),
      );
    });

    testWidgets('…a one-off copy needs create_expense', (tester) async {
      expect(
        await kinds(tester, _recurring(), permissions: 'create_expense'),
        contains(RecurringExpenseAction.cloneToExpense),
      );
    });
  });

  testWidgets('a deleted schedule offers its link, its vendor and Restore — '
      'nothing that changes, runs or copies it', (tester) async {
    final got = await kinds(
      tester,
      _recurring(isDeleted: true, vendorId: 'v1'),
    );
    expect(got, {
      RecurringExpenseAction.viewVendor,
      RecurringExpenseAction.copyLink,
      RecurringExpenseAction.restore,
    });
  });

  group('the record screen\'s tiles', () {
    testWidgets('lead with the one thing that can be done to the schedule', (
      tester,
    ) async {
      expect(await tiles(tester, _recurring()), [
        RecurringExpenseAction.stop,
        RecurringExpenseAction.clone,
        RecurringExpenseAction.cloneToExpense,
      ]);
      expect(await tiles(tester, _recurring(statusId: '1', lastSentDate: '')), [
        RecurringExpenseAction.start,
        RecurringExpenseAction.clone,
        RecurringExpenseAction.cloneToExpense,
      ]);
    });

    testWidgets('a deleted or unsynced schedule has none', (tester) async {
      expect(await tiles(tester, _recurring(isDeleted: true)), isEmpty);
      expect(await tiles(tester, _recurring(id: 'tmp_abc')), isEmpty);
    });

    testWidgets('a view-only user has none', (tester) async {
      expect(
        await tiles(
          tester,
          _recurring(),
          permissions: 'view_recurring_expense',
        ),
        isEmpty,
      );
    });
  });
}
