import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/features/projects/view_models/project_edit_view_model.dart'
    show emptyProject;
import 'package:admin/ui/features/projects/widgets/project_actions.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart'
    show emptyTask;

import '../shell/_shell_test_helpers.dart';

/// `ProjectActions`: who is offered what in the menu, and which of those the
/// record screen's quick-action strip picks.
Project _project({
  String id = 'p1',
  String clientId = 'c1',
  bool isDeleted = false,
  DateTime? archivedAt,
}) => emptyProject().copyWith(
  id: id,
  name: 'Site',
  clientId: clientId,
  isDeleted: isDeleted,
  archivedAt: archivedAt,
);

final _hour = [
  TimeEntry(
    start: DateTime.utc(2026, 1, 1, 9),
    stop: DateTime.utc(2026, 1, 1, 10),
  ),
];

Task _task({
  String id = 't1',
  String invoiceId = '',
  List<TimeEntry>? log,
  bool isDeleted = false,
}) => emptyTask().copyWith(
  id: id,
  projectId: 'p1',
  invoiceId: invoiceId,
  timeLog: log ?? _hour,
  isDeleted: isDeleted,
);

void main() {
  /// Runs [read] with a context under a `Services` for [company].
  Future<T> withContext<T>(
    WidgetTester tester,
    T Function(BuildContext context) read, {
    FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
  }) async {
    final fixture = await buildFixture(companies: [company]);
    addTearDown(fixture.dispose);
    late T result;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            result = read(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  List<ProjectAction> kindsOf(List<EntityActionItem<ProjectAction>> items) => [
    for (final i in items) ...[
      i.kind,
      for (final c in i.children ?? const <EntityActionItem<ProjectAction>>[])
        c.kind,
    ],
  ];

  group('the quick-action strip', () {
    Future<List<EntityQuickAction<ProjectAction>>> quick(
      WidgetTester tester,
      Project project, {
      bool hasBillableWork = false,
      FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
    }) => withContext(
      tester,
      (context) => ProjectActions.quickItemsFor(
        context,
        project,
        (_) {},
        hasBillableWork: hasBillableWork,
      ),
      company: company,
    );

    List<ProjectAction> picked(
      List<EntityQuickAction<ProjectAction>> priority, {
      int max = kQuickActionsNarrowMax,
    }) => [for (final q in pickQuickActions(priority, max: max)) q.item.kind];

    testWidgets('ranks what is done most, and bills only when there is work '
        'to bill', (tester) async {
      final idle = await quick(tester, _project());
      expect(picked(idle), [
        ProjectAction.newTask,
        ProjectAction.newExpense,
        ProjectAction.newQuote,
        ProjectAction.clone,
      ]);

      final billable = await quick(tester, _project(), hasBillableWork: true);
      // Invoice takes the second slot; nothing else moves ahead of it.
      expect(picked(billable), [
        ProjectAction.newTask,
        ProjectAction.invoiceProject,
        ProjectAction.newExpense,
        ProjectAction.newQuote,
      ]);
      expect(picked(billable, max: kQuickActionsWideMax), [
        ProjectAction.newTask,
        ProjectAction.invoiceProject,
        ProjectAction.newExpense,
        ProjectAction.newQuote,
        ProjectAction.addToInvoice,
        ProjectAction.clone,
      ]);
    });

    testWidgets('a short label per tile, the menu label for the tooltip', (
      tester,
    ) async {
      final tiles = await quick(tester, _project(), hasBillableWork: true);
      final byKind = {for (final q in tiles) q.item.kind: q};
      expect(byKind[ProjectAction.newTask]!.shortLabel, '+ Task');
      expect(byKind[ProjectAction.newTask]!.item.label, 'New Task');
      expect(byKind[ProjectAction.invoiceProject]!.shortLabel, 'Invoice');
      expect(
        byKind[ProjectAction.invoiceProject]!.item.label,
        'Invoice Project',
      );
      // New Invoice would be a second tile with the same word on it.
      expect(byKind.containsKey(ProjectAction.newInvoice), isFalse);
    });

    testWidgets('Add To Invoice needs a client to pick an invoice from', (
      tester,
    ) async {
      final tiles = await quick(
        tester,
        _project(clientId: ''),
        hasBillableWork: true,
      );
      expect(
        picked(tiles, max: kQuickActionsWideMax),
        isNot(contains(ProjectAction.addToInvoice)),
      );
    });

    testWidgets('none for a deleted or an unsynced project', (tester) async {
      expect(await quick(tester, _project(isDeleted: true)), isEmpty);
      expect(await quick(tester, _project(id: 'tmp_1')), isEmpty);
    });

    testWidgets('a create tile needs the create permission, not just the '
        'module', (tester) async {
      final tiles = await quick(
        tester,
        _project(),
        hasBillableWork: true,
        company: const FakeCompany(
          id: 'co1',
          name: 'Co',
          isAdmin: false,
          isOwner: false,
          permissions: 'view_project,create_task',
        ),
      );
      expect(picked(tiles, max: kQuickActionsWideMax), [ProjectAction.newTask]);
    });
  });

  group('the menu', () {
    Future<List<ProjectAction>> kinds(
      WidgetTester tester,
      Project project,
      String permissions,
    ) async => kindsOf(
      await withContext(
        tester,
        (context) => ProjectActions.itemsFor(context, project, (_) {}),
        company: FakeCompany(
          id: 'co1',
          name: 'Co',
          isAdmin: false,
          isOwner: false,
          permissions: permissions,
        ),
      ),
    );

    testWidgets('archive, restore and delete need edit_project', (
      tester,
    ) async {
      // The server authorizes all three through the edit policy.
      final viewer = await kinds(tester, _project(), 'view_project');
      expect(viewer, isNot(contains(ProjectAction.archive)));
      expect(viewer, isNot(contains(ProjectAction.delete)));

      final editor = await kinds(tester, _project(), 'edit_project');
      expect(
        editor,
        containsAll([ProjectAction.archive, ProjectAction.delete]),
      );

      final archived = _project(archivedAt: DateTime.utc(2026, 5, 1));
      expect(
        await kinds(tester, archived, 'view_project'),
        isNot(contains(ProjectAction.restore)),
      );
      expect(
        await kinds(tester, archived, 'edit_project'),
        contains(ProjectAction.restore),
      );
    });

    testWidgets('each create is its own permission', (tester) async {
      final some = await kinds(
        tester,
        _project(),
        'edit_project,create_task,create_quote',
      );
      expect(
        some,
        containsAll([ProjectAction.newTask, ProjectAction.newQuote]),
      );
      // Edit rights never imply create.
      expect(some, isNot(contains(ProjectAction.newInvoice)));
      expect(some, isNot(contains(ProjectAction.invoiceProject)));
      expect(some, isNot(contains(ProjectAction.newExpense)));
      expect(some, isNot(contains(ProjectAction.clone)));

      final invoicer = await kinds(
        tester,
        _project(),
        'create_invoice,edit_invoice,create_project',
      );
      expect(
        invoicer,
        containsAll([
          ProjectAction.newInvoice,
          ProjectAction.invoiceProject,
          ProjectAction.addToInvoice,
          ProjectAction.clone,
        ]),
      );
    });
  });

  testWidgets('a deleted project offers only what does not change it', (
    tester,
  ) async {
    final items = await withContext(
      tester,
      (context) =>
          ProjectActions.itemsFor(context, _project(isDeleted: true), (_) {}),
    );
    final offered = [
      for (final i in items)
        if (i.isVisible) i.kind,
    ];
    expect(offered, [ProjectAction.copyLink, ProjectAction.restore]);
    // Edit is still in the list, disabled: hidden from every menu, but what
    // a wide list row draws as its greyed pencil so the row's `⋮` keeps its
    // place.
    final edit = items.singleWhere((i) => i.kind == ProjectAction.edit);
    expect(edit.isPrimary, isTrue);
    expect(edit.enabled, isFalse);
  });

  group('hasBillableTasks', () {
    test('time worked, stopped and not yet invoiced', () {
      expect(ProjectActions.hasBillableTasks([_task()]), isTrue);
      expect(ProjectActions.hasBillableTasks(const []), isFalse);
    });

    test('not what the Invoice action would skip', () {
      final running = _task(
        log: [TimeEntry(start: DateTime.utc(2026, 1, 1, 9), stop: null)],
      );
      final nonBillable = _task(
        log: [
          TimeEntry(
            start: DateTime.utc(2026, 1, 1, 9),
            stop: DateTime.utc(2026, 1, 1, 10),
            billable: false,
          ),
        ],
      );
      for (final t in [
        _task(invoiceId: 'inv1'),
        _task(id: 'tmp_1'),
        _task(isDeleted: true),
        _task(log: const []),
        running,
        nonBillable,
      ]) {
        expect(ProjectActions.hasBillableTasks([t]), isFalse, reason: '$t');
      }
    });
  });
}
