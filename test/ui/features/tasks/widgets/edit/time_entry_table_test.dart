import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/services/tasks_api.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/in_time_field.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/edit/time_entry_table.dart';

import '../../../../../_responsive_helper.dart';

class _FakeTasksApi implements TasksApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Guards the row keying in [TimeEntryTable]. A running entry is keyed by its
/// running-sequence rank rather than a constant, so a task whose `timeLog`
/// carries TWO open (`stop == null`) entries — which the app never validates
/// out of server / legacy / imported data — renders without a Flutter
/// duplicate-key crash. (A constant `running-entry` key collided and crashed
/// the task editor on open.)
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  TimeEntry running(int hour) =>
      TimeEntry(start: DateTime(2026, 6, 5, hour), stop: null);
  TimeEntry stopped(int hour) => TimeEntry(
    start: DateTime(2026, 6, 5, hour),
    stop: DateTime(2026, 6, 5, hour + 1),
  );

  TaskEditViewModel vmWith(List<TimeEntry> log) => TaskEditViewModel(
    repo: TaskRepository(db: db, api: _FakeTasksApi()),
    companyId: 'co',
    now: () => DateTime.utc(2026, 6, 5, 12),
    existing: emptyTask().copyWith(id: 't1', timeLog: log),
  );

  Future<void> pumpTable(WidgetTester tester, TaskEditViewModel vm) => pumpAt(
    tester,
    900, // wide → the table layout (not the phone row fallback)
    TimeEntryTable(vm: vm, locked: false, onAddEntry: () {}),
  );

  /// Drain any captured exceptions and assert none is a duplicate-key error
  /// (the regression under test). A benign RenderFlex overflow from the
  /// running-duration ticker inside the constrained test viewport is
  /// tolerated — it's pre-existing and unrelated to the row keying.
  void expectNoDuplicateKey(WidgetTester tester) {
    for (
      Object? ex = tester.takeException();
      ex != null;
      ex = tester.takeException()
    ) {
      expect(
        ex.toString(),
        isNot(contains('Duplicate keys')),
        reason: 'two running entries collided on the same widget key',
      );
    }
  }

  testWidgets('renders two running entries without a duplicate-key crash', (
    tester,
  ) async {
    await pumpTable(tester, vmWith([stopped(8), running(9), running(10)]));

    expectNoDuplicateKey(tester);
    expect(find.byType(TimeEntryTable), findsOneWidget);

    // Tear down the running entries' live-ticking duration timers.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('renders the normal single-running log fine', (tester) async {
    await pumpTable(tester, vmWith([stopped(8), running(9)]));

    expectNoDuplicateKey(tester);
    expect(find.byType(TimeEntryTable), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  // The editable cells were pinned with `SizedBox(height: 36)` while the
  // fields inside want 49 px at normal text size and 57 px at the app's
  // 1.4x setting — so every time-log row shipped visibly sliced. A tight
  // `SizedBox` throws nothing, so `expectNoOverflow` never caught it; the
  // check has to compare rendered height against intrinsic height.
  group('editable cells are not vertically crushed', () {
    for (final scale in const [1.0, kTextScaleMax]) {
      testWidgets('@ ${scale}x text scale', (tester) async {
        await pumpAt(
          tester,
          900, // wide → the table layout, not the phone row fallback
          TimeEntryTable(
            vm: vmWith([stopped(8)]),
            locked: false,
            onAddEntry: () {},
          ),
          textScale: scale,
        );

        expectNotVerticallyCrushed(tester, find.byType(InDateField));
        for (final f in find.byType(InTimeField).evaluate()) {
          expectNotVerticallyCrushed(
            tester,
            find.byElementPredicate((e) => e == f),
          );
        }

        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
