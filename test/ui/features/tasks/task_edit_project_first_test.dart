// The task form's Project picker works before a Client is picked — the old
// app's order, and the one users reach for (beta feedback: "the client has to
// be selected before you are able to select a project … just says loading").
//
// Picking a project sets the client from it (`TaskEditViewModel.selectProject`)
// and locks the Client field behind `project_drives_client`. Against a real
// `Services` graph and local database; the harness is
// `test/_support/record_screen_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/ui/core/widgets/locked_entity_field_row.dart';
import 'package:admin/ui/features/tasks/views/task_edit_screen.dart';

import '../../../_support/record_screen_harness.dart';

Future<void> _seed(Services services) async {
  for (final c in const [
    ClientApi(
      id: 'c1',
      name: 'Acme Corporation',
      displayName: 'Acme Corporation',
      updatedAt: 1710000000,
      createdAt: 1700000000,
    ),
    ClientApi(
      id: 'c2',
      name: 'Globex',
      displayName: 'Globex',
      updatedAt: 1710000000,
      createdAt: 1700000000,
    ),
  ]) {
    await services.clients.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: c,
    );
  }
  for (final p in const [
    ProjectApi(
      id: 'p1',
      name: 'Window Replacement',
      clientId: 'c1',
      updatedAt: 1710000000,
      createdAt: 1700000000,
    ),
    ProjectApi(
      id: 'p2',
      name: 'Roof Repair',
      clientId: 'c2',
      updatedAt: 1710000000,
      createdAt: 1700000000,
    ),
  ]) {
    await services.projects.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: p,
    );
  }
}

Finder _projectField() => find.widgetWithText(TextField, 'Project');

void main() {
  recordScreenTest(
    'a project can be picked first, and it fills in the client',
    seed: _seed,
    screen: () => const TaskEditScreen(),
    ready: _projectField,
    body: (tester, screen) async {
      expect(find.text('Select a client first'), findsNothing);

      // Every client's projects are offered while no client is picked. (Let
      // the list's first emission land: until then the picker is a disabled
      // placeholder, and a tap on it opens nothing.)
      await screen.quiet();
      await tester.tap(_projectField());
      await screen.untilFound(find.text('Roof Repair'), 'the project options');
      expect(find.text('Window Replacement'), findsOneWidget);

      await tester.tap(find.text('Window Replacement'));
      await screen.untilFound(
        find.byType(LockedClientFieldRow),
        'the client to follow the project',
      );
      await screen.untilFound(
        find.text('Acme Corporation'),
        'the project\'s client by name',
      );
    },
  );

  recordScreenTest(
    'a picked client narrows the projects to its own',
    seed: _seed,
    screen: () => const TaskEditScreen(),
    ready: _projectField,
    body: (tester, screen) async {
      await screen.quiet();
      await tester.tap(find.widgetWithText(TextField, 'Client'));
      await screen.untilFound(find.text('Globex'), 'the client options');
      await tester.tap(find.text('Globex'));
      await screen.quiet();

      await tester.tap(_projectField());
      await screen.untilFound(find.text('Roof Repair'), 'Globex\'s project');
      expect(find.text('Window Replacement'), findsNothing);
    },
  );
}
