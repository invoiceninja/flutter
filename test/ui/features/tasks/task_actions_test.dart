import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
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
  group('Start vs Resume (flutter#149)', () {
    // "Resume" claims previously-worked time. Offering it on a task whose log
    // is a booking — which `timeLog.isNotEmpty` and `hasStoppedEntries` both
    // answer yes to — was the issue's opening complaint. Exercised through
    // `itemsFor` rather than by grepping for a token, which cannot tell this
    // gate from any other use of the same enum.
    TimeEntry blockAt(DateTime start, Duration length) =>
        TimeEntry(start: start, stop: start.add(length));

    Future<Set<TaskAction>> kindsFor(WidgetTester tester, Task task) async {
      late List<EntityActionItem<TaskAction>> items;
      await tester.pumpWidget(
        wrapWithShell(
          (await buildFixture(
            companies: [const FakeCompany(id: 'co1', name: 'Co')],
          )).services,
          Builder(
            builder: (context) {
              items = TaskActions.itemsFor(context, task, (_) {});
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pump();
      return items.map((i) => i.kind).toSet();
    }

    testWidgets('a task booked ahead offers Start, never Resume', (
      tester,
    ) async {
      final kinds = await kindsFor(
        tester,
        _task(
          log: [
            blockAt(
              DateTime.now().add(const Duration(hours: 3)),
              const Duration(hours: 2),
            ),
          ],
        ),
      );
      expect(kinds, contains(TaskAction.start));
      expect(kinds, isNot(contains(TaskAction.resume)));
    });

    testWidgets('a task with real worked time still offers Resume', (
      tester,
    ) async {
      final kinds = await kindsFor(
        tester,
        _task(
          log: [
            blockAt(
              DateTime.now().subtract(const Duration(hours: 3)),
              const Duration(hours: 1),
            ),
          ],
        ),
      );
      expect(kinds, contains(TaskAction.resume));
      expect(kinds, isNot(contains(TaskAction.start)));
    });

    testWidgets('a task with no log at all offers Start', (tester) async {
      final kinds = await kindsFor(tester, _task());
      expect(kinds, contains(TaskAction.start));
    });
  });

  group('the quick-action strip', () {
    final worked = [
      TimeEntry(
        start: DateTime.utc(2026, 1, 1, 9),
        stop: DateTime.utc(2026, 1, 1, 10),
      ),
    ];

    Future<List<EntityQuickAction<TaskAction>>> quick(
      WidgetTester tester,
      Task task, {
      ValueListenable<bool>? busy,
      FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
    }) async {
      final fixture = await buildFixture(companies: [company]);
      addTearDown(fixture.dispose);
      late List<EntityQuickAction<TaskAction>> tiles;
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          Builder(
            builder: (context) {
              tiles = TaskActions.quickItemsFor(
                context,
                task,
                (_) {},
                timerBusy: busy,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return tiles;
    }

    List<TaskAction> picked(List<EntityQuickAction<TaskAction>> priority) => [
      for (final q in pickQuickActions(priority, max: kQuickActionsNarrowMax))
        q.item.kind,
    ];

    testWidgets('the timer leads, then the ways to bill the time', (
      tester,
    ) async {
      expect(picked(await quick(tester, _task(log: worked))), [
        TaskAction.resume,
        TaskAction.newInvoice,
        TaskAction.addToInvoice,
        TaskAction.clone,
      ]);
    });

    testWidgets('nothing to bill yet: the billing tiles yield their slots', (
      tester,
    ) async {
      expect(picked(await quick(tester, _task())), [
        TaskAction.start,
        TaskAction.clone,
      ]);
    });

    testWidgets('an estimate is something to bill, before any work', (
      tester,
    ) async {
      // A task booked from a quote line and invoiced ahead of the visit is
      // billed at its estimate (`taskBillableHours`).
      final tiles = await quick(
        tester,
        _task().copyWith(estimatedSeconds: 7200),
      );
      expect(picked(tiles), contains(TaskAction.newInvoice));
    });

    testWidgets('a running task offers Stop, and is not billed mid-timer', (
      tester,
    ) async {
      final tiles = await quick(
        tester,
        _task(log: [TimeEntry(start: DateTime.utc(2026, 1, 1, 9), stop: null)]),
      );
      expect(picked(tiles), [TaskAction.stop, TaskAction.clone]);
    });

    testWidgets('only the timer tile carries the busy state', (tester) async {
      final busy = ValueNotifier<bool>(false);
      addTearDown(busy.dispose);
      final tiles = await quick(tester, _task(log: worked), busy: busy);
      for (final q in tiles) {
        expect(
          q.busy,
          TaskActions.isTimerAction(q.item.kind) ? same(busy) : isNull,
          reason: '${q.item.kind}',
        );
      }
      expect(tiles.where((q) => q.busy != null), hasLength(1));
    });

    testWidgets('an invoiced task has no timer and nothing left to bill', (
      tester,
    ) async {
      final tiles = await quick(tester, _task(invoiceId: 'inv1', log: worked));
      expect(picked(tiles), [TaskAction.clone]);
    });

    testWidgets('none for a deleted or an unsynced task', (tester) async {
      expect(
        await quick(tester, _task(log: worked).copyWith(isDeleted: true)),
        isEmpty,
      );
      expect(await quick(tester, _task(id: 'tmp_1', log: worked)), isEmpty);
    });

    testWidgets('billing and cloning need their own permissions', (
      tester,
    ) async {
      final tiles = await quick(
        tester,
        _task(log: worked),
        company: const FakeCompany(
          id: 'co1',
          name: 'Co',
          isAdmin: false,
          isOwner: false,
          permissions: 'view_task,edit_task',
        ),
      );
      // Edit rights never imply create — of a task (Clone) or of an invoice.
      expect(picked(tiles), [TaskAction.resume]);
    });
  });

  testWidgets('a deleted task offers only what does not change it', (
    tester,
  ) async {
    final items = await resolveItems(
      tester,
      task: _task().copyWith(isDeleted: true),
    );
    final offered = [
      for (final i in items)
        if (i.isVisible) i.kind,
    ];
    expect(offered, [
      TaskAction.viewClient,
      TaskAction.copyLink,
      TaskAction.restore,
    ]);
    // Edit is still in the list, disabled: hidden from every menu, but what
    // a wide list row draws as its greyed pencil so the row's `⋮` keeps its
    // place.
    final edit = items.singleWhere((i) => i.kind == TaskAction.edit);
    expect(edit.isPrimary, isTrue);
    expect(edit.enabled, isFalse);
  });

  group('lifecycle actions need edit_task', () {
    Future<List<TaskAction>> kinds(
      WidgetTester tester,
      Task task,
      String permissions,
    ) async {
      final fixture = await buildFixture(
        companies: [
          FakeCompany(
            id: 'co1',
            name: 'Co',
            isAdmin: false,
            isOwner: false,
            permissions: permissions,
          ),
        ],
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
      return [for (final i in items) i.kind];
    }

    testWidgets('a viewer is offered none of them', (tester) async {
      // The server authorizes all three through the edit policy; ungated,
      // the record's state banner offered a viewer a Restore it would refuse.
      final active = await kinds(tester, _task(), 'view_task');
      expect(active, isNot(contains(TaskAction.archive)));
      expect(active, isNot(contains(TaskAction.delete)));
    });

    testWidgets('an editor is', (tester) async {
      final active = await kinds(tester, _task(), 'edit_task');
      expect(active, containsAll([TaskAction.archive, TaskAction.delete]));
      // …and still may not clone: that is a create.
      expect(active, isNot(contains(TaskAction.clone)));
    });

    testWidgets('Restore follows the same rule', (tester) async {
      final archived = _task().copyWith(archivedAt: DateTime.utc(2026, 5, 1));
      expect(
        await kinds(tester, archived, 'view_task'),
        isNot(contains(TaskAction.restore)),
      );
    });
  });
}
