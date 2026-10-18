// The Daily view's `+` was gated on `create_task`, but two more of its
// controls create tasks too: Log time (`TaskDailyActions.logTime` opens a
// new-task draft — in the header and on an empty day) and Duplicate yesterday
// (`duplicateYesterday` clones yesterday's tasks). A view-only user was handed
// both, and the server would refuse the save.
//
// Mounts the real screen against a real `Services` graph, like
// `entity_list_fab_clearance_test.dart` does for the list view; the empty day
// is the point, since it is where the third Log time lives.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/tasks/views/task_daily_screen.dart';

import '../shell/_shell_test_helpers.dart';

void main() {
  const admin = FakeCompany(id: 'co1', name: 'Acme');
  const viewOnly = FakeCompany(
    id: 'co1',
    name: 'Acme',
    isAdmin: false,
    isOwner: false,
    permissions: 'view_task',
  );

  Future<void> pumpDaily(
    WidgetTester tester, {
    required FakeCompany company,
    required Size window,
  }) async {
    // `tester.view`, not `setSurfaceSize`: the latter leaves `MediaQuery` at
    // 800x600, and the header's wide / narrow branch is the thing measured.
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = await buildFixture(companies: [company]);
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const TaskDailyScreen()),
    );
    await _pumpFrames(tester);
  }

  for (final (label, window) in const [
    ('narrow', Size(400, 800)),
    ('wide', Size(1400, 900)),
  ]) {
    group('on a $label Daily view (an empty today)', () {
      testWidgets('a view_task-only user gets no Log time and no Duplicate '
          'yesterday', (tester) async {
        await pumpDaily(tester, company: viewOnly, window: window);

        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Log Time'), findsNothing);
        expect(find.byTooltip('Log Time'), findsNothing);
        expect(find.byTooltip('Duplicate Yesterday'), findsNothing);
        await _disposeTree(tester);
      });

      testWidgets('(control) an admin gets both', (tester) async {
        await pumpDaily(tester, company: admin, window: window);

        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byTooltip('Duplicate Yesterday'), findsOneWidget);
        // The empty day's button, plus the header's: a labelled button when
        // wide, an icon-only one (named by its tooltip) when narrow.
        if (label == 'wide') {
          expect(find.text('Log Time'), findsNWidgets(2));
        } else {
          expect(find.text('Log Time'), findsOneWidget);
          expect(find.byTooltip('Log Time'), findsOneWidget);
        }
        await _disposeTree(tester);
      });
    });
  }
}

/// `pumpAndSettle` never returns here: the view model holds a live Drift
/// watch over the tasks table, so the tree is never "settled".
Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Tear the subtree down inside the test body so the Drift watches' close
/// timers fire before the binding's end-of-test `!timersPending` check.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
