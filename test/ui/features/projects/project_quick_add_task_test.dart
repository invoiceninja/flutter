import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/task_status_api_model.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/ui/features/projects/view_models/project_edit_view_model.dart'
    show emptyProject;
import 'package:admin/ui/features/projects/widgets/detail/project_quick_add_task.dart';

import '../shell/_shell_test_helpers.dart';

/// Quick task creation at the head of the project's Tasks tab
/// (invoiceninja/ui#3383). That the new task then shows in the list under the
/// field is covered where the list is — `project_detail_screen_test.dart`.
void main() {
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('Enter creates a task on the project, seeded with the first '
      'status, and keeps the field focused for the next one', (tester) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    final services = fixture.services;
    await tester.runAsync(
      () => services.taskStatuses.applyBundle(
        companyId: 'co1',
        bundle: const [
          TaskStatusApi(id: 'st2', name: 'Doing', statusOrder: 2),
          TaskStatusApi(id: 'st1', name: 'Backlog', statusOrder: 1),
        ],
      ),
    );
    final project = emptyProject().copyWith(
      id: 'p1',
      name: 'Site',
      clientId: 'cl1',
      taskRate: Decimal.fromInt(80),
    );

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapWithShell(
        services,
        Scaffold(
          body: SingleChildScrollView(
            child: ProjectQuickAddTask(project: project, companyId: 'co1'),
          ),
        ),
      ),
    );
    await settle(tester);

    final field = find.byKey(const Key('project_quick_add_task'));
    await tester.tap(field);
    await tester.enterText(field, 'Design homepage');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    final tasks = await tester.runAsync(
      () => services.tasks
          .watchForProject(companyId: 'co1', projectId: 'p1')
          .first,
    );
    final task = tasks!.single;
    expect(task.description, 'Design homepage');
    expect(task.clientId, 'cl1');
    expect(task.rate, Decimal.fromInt(80));
    // Board order, never blank — a blank status is in no kanban column.
    expect(task.statusId, 'st1');

    final input = tester.widget<TextField>(field);
    expect(input.controller!.text, isEmpty);
    expect(input.focusNode!.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  test('offered only where a task could be created on the project', () {
    final project = emptyProject().copyWith(id: 'p1', name: 'Site');
    bool applies(Project p, {bool can = true}) =>
        ProjectQuickAddTask.appliesTo(p, canCreateTask: can);
    expect(applies(project), isTrue);
    expect(applies(project, can: false), isFalse);
    expect(applies(project.copyWith(isDeleted: true)), isFalse);
    expect(
      applies(project.copyWith(archivedAt: DateTime.utc(2026, 5, 1))),
      isFalse,
    );
    // The server has never seen it: a task pointing at it could not sync.
    expect(applies(project.copyWith(id: 'tmp_1')), isFalse);
  });
}
