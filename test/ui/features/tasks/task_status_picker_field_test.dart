// The task-status picker, shared by the task edit form and the
// create-task-from-line-item sheet so the two cannot drift.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/task_status_api_model.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/ui/features/tasks/widgets/task_status_picker_field.dart';

import '../../../_localization_helper.dart';

/// `Stream.multi`, not `Stream.value`: `EntityPickerField` re-subscribes to
/// `watchById` on every `selectedId` change, and a single-subscription stream
/// throws the second time — the finding `_task_filter_doubles.dart` records.
Stream<T> _oneShot<T>(T value) => Stream<T>.multi((c) {
  c.add(value);
  c.close();
});

TaskStatus _status(String id, String name, {int order = 0}) =>
    TaskStatus.fromApi(TaskStatusApi(id: id, name: name, statusOrder: order));

class _FakeStatuses implements TaskStatusRepository {
  _FakeStatuses(this.all, {this.byId = const <String, TaskStatus>{}});

  final List<TaskStatus> all;

  /// Separate from [all], because `watchAll` is active-only: an archived
  /// status must still resolve for a task that sits on one.
  final Map<String, TaskStatus> byId;

  @override
  Stream<List<TaskStatus>> watchAll({required String companyId}) =>
      _oneShot(all);

  @override
  Stream<TaskStatus?> watch({required String companyId, required String id}) =>
      _oneShot(byId[id] ?? all.where((s) => s.id == id).firstOrNull);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.taskStatuses);

  @override
  final TaskStatusRepository taskStatuses;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

final Finder _dots = find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.decoration is BoxDecoration &&
      (w.decoration! as BoxDecoration).shape == BoxShape.circle,
);

void main() {
  late List<String> changes;

  Future<void> pump(
    WidgetTester tester, {
    required List<TaskStatus> all,
    String selectedId = '',
    Map<String, TaskStatus> byId = const <String, TaskStatus>{},
  }) async {
    changes = <String>[];
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(_FakeStatuses(all, byId: byId)),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: TaskStatusPickerField(
                companyId: 'co',
                selectedId: selectedId,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every option carries the status colour dot', (tester) async {
    await pump(
      tester,
      all: [_status('s1', 'Backlog'), _status('s2', 'In Progress', order: 1)],
    );
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('Backlog'), findsOneWidget);
    expect(_dots, findsNWidgets(2));
  });

  testWidgets('the committed status carries the dot as a field prefix', (
    tester,
  ) async {
    // `SearchableDropdownField` reuses `optionLeadingBuilder` for the field's
    // prefix, so the dot follows the selection out of the popover.
    await pump(tester, all: [_status('s1', 'Backlog')], selectedId: 's1');

    expect(find.text('Backlog'), findsOneWidget);
    expect(_dots, findsOneWidget);
  });

  testWidgets('a nameless status renders its id', (tester) async {
    await pump(tester, all: [_status('s9', '  ')]);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('s9'), findsWidgets);
  });

  testWidgets('an archived selection still renders', (tester) async {
    // `watchAll` excludes archived statuses, so a picker that scans the list
    // would blank the Status field of a task sitting on one.
    await pump(
      tester,
      all: [_status('s1', 'Backlog')],
      selectedId: 'old',
      byId: {'old': _status('old', 'Retired')},
    );

    expect(find.text('Retired'), findsOneWidget);
    expect(changes, isEmpty);
  });

  testWidgets('an empty list reads as loading, not as "no records"', (
    tester,
  ) async {
    // Statuses arrive bundled on `/refresh` and the server seeds four for
    // every new company, so empty is a loading state — hence no
    // `emptyHintKey`.
    await pump(tester, all: const <TaskStatus>[]);

    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('No records found'), findsNothing);
  });
}
