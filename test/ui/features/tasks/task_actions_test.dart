import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';

import '../shell/_shell_test_helpers.dart';

/// H1 gating coverage for `TaskActions.itemsFor`. The single-task billing
/// actions (`newInvoice` / `addToInvoice`) must be disabled for a RUNNING task
/// (billing a live-timer snapshot) and an already-INVOICED task (double-bill +
/// lock), matching admin-portal / React.
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Task _task({
  String id = 't1',
  String invoiceId = '',
  List<TimeEntry> log = const [],
}) => Task(
  id: id,
  number: '',
  description: id,
  rate: Decimal.zero,
  invoiceId: invoiceId,
  clientId: 'c1',
  projectId: 'p1',
  statusId: 's1',
  statusOrder: 0,
  assignedUserId: 'u1',
  timeLog: log,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: _epoch,
  createdAt: _epoch,
  archivedAt: null,
  isDeleted: false,
);

void main() {
  Future<List<EntityActionItem<TaskAction>>> resolveItems(
    WidgetTester tester, {
    required Task task,
  }) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);

    late List<EntityActionItem<TaskAction>> items;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            items = TaskActions.itemsFor(context, task, (_) {});
            return const SizedBox();
          },
        ),
      ),
    );
    return items;
  }

  bool enabledOf(List<EntityActionItem<TaskAction>> items, TaskAction kind) =>
      items.firstWhere((i) => i.kind == kind).enabled;

  testWidgets('billing actions enabled for a stopped, un-invoiced task', (
    tester,
  ) async {
    final items = await resolveItems(
      tester,
      task: _task(
        log: [
          TimeEntry(
            start: DateTime.utc(2026, 1, 1, 9),
            stop: DateTime.utc(2026, 1, 1, 10),
          ),
        ],
      ),
    );
    expect(enabledOf(items, TaskAction.newInvoice), isTrue);
    expect(enabledOf(items, TaskAction.addToInvoice), isTrue);
  });

  testWidgets('billing actions disabled for a RUNNING task', (tester) async {
    final items = await resolveItems(
      tester,
      task: _task(
        // Last entry has no stop → task.isRunning == true.
        log: [TimeEntry(start: DateTime.utc(2026, 1, 1, 9), stop: null)],
      ),
    );
    expect(enabledOf(items, TaskAction.newInvoice), isFalse);
    expect(enabledOf(items, TaskAction.addToInvoice), isFalse);
  });

  testWidgets('newInvoice disabled for an already-invoiced task', (
    tester,
  ) async {
    final items = await resolveItems(
      tester,
      task: _task(
        invoiceId: 'inv1',
        log: [
          TimeEntry(
            start: DateTime.utc(2026, 1, 1, 9),
            stop: DateTime.utc(2026, 1, 1, 10),
          ),
        ],
      ),
    );
    expect(enabledOf(items, TaskAction.newInvoice), isFalse);
  });

  testWidgets('addToInvoice label carries no :placeholder (flutter#35)', (
    tester,
  ) async {
    final items = await resolveItems(tester, task: _task());
    final label = items
        .firstWhere((i) => i.kind == TaskAction.addToInvoice)
        .label;
    // The generic `add_to_invoice` string is "Add to invoice :invoice" and
    // this menu fires before an invoice is picked, so it must resolve the
    // dedicated placeholder-free `action_add_to_invoice` instead. Blanking
    // the token is not an acceptable substitute — de/ja put it mid-string.
    expect(label, 'Add To Invoice');
    expect(label, isNot(contains(':')));
  });
}
