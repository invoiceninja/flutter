import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/api/task_status_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart'
    show emptyTask;
import 'package:admin/ui/features/tasks/widgets/create_task_from_line_item_sheet.dart';

import '../../../_localization_helper.dart';
import '../shell/_shell_test_helpers.dart';
import 'widgets/_task_filter_doubles.dart';

/// Streams are `Stream.value(...)`, never a real Drift watch — `pumpAndSettle`
/// over a live watch stream never settles.
class _FakeTasks implements TaskRepository {
  _FakeTasks(this.existing);

  final List<Task> existing;
  final List<Task> created = <Task>[];

  @override
  Stream<List<Task>> watchAllActive({
    required String companyId,
    Set<EntityState> states = const {EntityState.active},
  }) => Stream.value(existing);

  @override
  Future<SaveResult<Task>> create({
    required String companyId,
    required Task draft,
    String? existingTempId,
  }) async {
    created.add(draft);
    return SaveResult(entity: draft, outboxRowId: 1);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

/// Every stream here is multi-subscription (`oneShot`, or `Stream.multi`
/// inline): `EntityPickerField` re-subscribes to `watchById` on every
/// `selectedId` change, and a single-subscription `Stream.value` throws the
/// second time — the finding `_task_filter_doubles.dart` records.
class _FakeTaskStatuses implements TaskStatusRepository {
  _FakeTaskStatuses(this.statuses);

  final List<TaskStatus> statuses;

  /// Lets a test push a *second* emission — a Drift table update — so the
  /// seeding latch can be exercised rather than assumed.
  final StreamController<List<TaskStatus>> _later =
      StreamController<List<TaskStatus>>.broadcast();

  void reemit() => _later.add(statuses);

  Future<void> close() => _later.close();

  @override
  Stream<List<TaskStatus>> watchAll({required String companyId}) =>
      Stream<List<TaskStatus>>.multi((c) {
        c.add(statuses);
        final sub = _later.stream.listen(c.add);
        c.onCancel = sub.cancel;
      });

  @override
  Stream<TaskStatus?> watch({required String companyId, required String id}) =>
      oneShot(statuses.where((s) => s.id == id).firstOrNull);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeCompany implements CompanyRepository {
  @override
  Stream<Company?> watchCompany(String companyId) =>
      Stream<Company?>.value(null);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.tasks, this.taskStatuses);

  @override
  final TaskRepository tasks;

  @override
  final TaskStatusRepository taskStatuses;

  @override
  final CompanyRepository company = _FakeCompany();

  @override
  final UserRepository user = FakeUserRepo();

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

/// A task occupying [from]..[to] local time on 2026-06-14.
Task _taskAt(String description, int fromHour, int toHour) =>
    emptyTask().copyWith(
      id: description,
      description: description,
      timeLog: [
        TimeEntry(
          start: DateTime(2026, 6, 14, fromHour),
          stop: DateTime(2026, 6, 14, toHour),
        ),
      ],
    );

/// The kanban board's column order — `TaskStatusDao.watchAll` sorts by
/// `status_order`, so `first` is the leftmost column.
TaskStatus _status(String id, String name, int order) =>
    TaskStatus.fromApi(TaskStatusApi(id: id, name: name, statusOrder: order));

final List<TaskStatus> _kStatuses = [
  _status('s1', 'Backlog', 0),
  _status('s2', 'In Progress', 1),
];

/// Label-anchored, not `find.byType(TextField).at(n)`. The Status and Assigned
/// User pickers went in *after* the Rate row, so the existing indices happened
/// to survive — which is the point: a positional index silently retargets an
/// assertion at whatever moves into that slot, and nothing about the next
/// insertion would look wrong.
Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  late _FakeTasks tasks;
  late _FakeTaskStatuses statusRepo;

  Future<void> open(
    WidgetTester tester, {
    required LineItem item,
    List<Task> existing = const <Task>[],
    List<TaskStatus>? statuses,
    Size size = const Size(900, 900),
  }) async {
    tasks = _FakeTasks(existing);
    statusRepo = _FakeTaskStatuses(statuses ?? _kStatuses);
    addTearDown(statusRepo.close);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      // Provider above MaterialApp, as `main.dart` has it — `showDialog` pushes
      // onto the root navigator, whose overlay sits above `home:`.
      Provider<Services>.value(
        value: _FakeServices(tasks, statusRepo),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showCreateTaskFromLineItemSheet(
                    context,
                    companyId: 'co',
                    item: item,
                    clientId: 'client-1',
                    projectId: 'project-1',
                    documentDate: Date(2026, 6, 14),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  LineItem line({
    String productKey = 'SVC-01',
    String notes = 'Boiler service',
    String quantity = '2',
    String cost = '150',
  }) => emptyLineItem().copyWith(
    productKey: productKey,
    notes: notes,
    quantity: Decimal.parse(quantity),
    cost: Decimal.parse(cost),
  );

  testWidgets('seeds description, duration and rate from the line item', (
    tester,
  ) async {
    await open(tester, item: line());

    expect(find.text('Create Task'), findsOneWidget);
    expect(find.text('SVC-01\n\nBoiler service'), findsOneWidget);
    // quantity 2 -> a 2 hour block.
    expect(find.text('2:00'), findsOneWidget);
    expect(find.text('150'), findsOneWidget);
  });

  testWidgets('Save creates one task carrying the seeded time log', (
    tester,
  ) async {
    await open(tester, item: line());

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tasks.created, hasLength(1));
    final draft = tasks.created.single;
    expect(draft.description, 'SVC-01\n\nBoiler service');
    expect(draft.clientId, 'client-1');
    expect(draft.projectId, 'project-1');
    expect(draft.rate, Decimal.parse('150'));
    final entry = draft.timeLog.single;
    expect(entry.start, DateTime(2026, 6, 14, 9));
    expect(entry.stop!.difference(entry.start!), const Duration(hours: 2));
    expect(entry.billable, isTrue);
  });

  testWidgets('a fractional cost round-trips into the task rate', (
    tester,
  ) async {
    // NOTE: this pins the seed→parse round trip, not the choice of seeder.
    // These fixtures run with no `Formatter`, so `Formatter.inputMoney` (which
    // rounds to a currency's precision, and is what this field used to use)
    // isn't reachable here — distinguishing the two needs a warmed formatter on
    // a 0-decimal currency, which is the `_seedCurrencies` + `buildFixture`
    // harness in `line_item_party_currency_test.dart`.
    await open(tester, item: line(cost: '150.75'));
    expect(find.text('150.75'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(tasks.created.single.rate, Decimal.parse('150.75'));
  });

  testWidgets('renders as a bottom sheet on a narrow viewport', (tester) async {
    await open(tester, item: line(), size: const Size(400, 800));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Create Task'), findsOneWidget);
  });

  testWidgets('an emptied duration reverts to the committed value on blur', (
    tester,
  ) async {
    await open(tester, item: line());
    await tester.enterText(_field('Duration'), '');
    // Blur it — the field must not keep showing something it won't save.
    await tester.tap(_field('Description'));
    await tester.pumpAndSettle();

    expect(find.text('2:00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final entry = tasks.created.single.timeLog.single;
    expect(entry.stop!.difference(entry.start!), const Duration(hours: 2));
  });

  testWidgets('an edited duration reaches the created task', (tester) async {
    await open(tester, item: line());
    await tester.enterText(_field('Duration'), '0:45');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final entry = tasks.created.single.timeLog.single;
    expect(entry.stop!.difference(entry.start!), const Duration(minutes: 45));
  });

  testWidgets('an empty day reads as available', (tester) async {
    await open(tester, item: line());
    expect(find.text('Available'), findsOneWidget);
  });

  testWidgets('a busy day lists its entries and flags the overlap', (
    tester,
  ) async {
    await open(
      tester,
      item: line(),
      existing: [
        // 09:00-11:00 collides with the seeded 09:00 + 2h block.
        _taskAt('Annual inspection', 9, 11),
        _taskAt('Site survey', 14, 16),
      ],
    );

    expect(find.text('Schedule · 2'), findsOneWidget);
    expect(find.textContaining('Annual inspection'), findsOneWidget);
    expect(find.textContaining('Site survey'), findsOneWidget);
    // Only the colliding entry is flagged.
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('changing the date preserves the duration', (tester) async {
    await open(tester, item: line());

    await tester.enterText(_field('Date'), '2026-06-20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final entry = tasks.created.single.timeLog.single;
    expect(entry.start, DateTime(2026, 6, 20, 9));
    expect(entry.stop!.difference(entry.start!), const Duration(hours: 2));
  });

  testWidgets('an untouched sheet saves the first status and no assignee', (
    tester,
  ) async {
    await open(tester, item: line());

    // Seeded from the stream, so it is on screen before Save.
    expect(find.text('Backlog'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final draft = tasks.created.single;
    // `statusId: ''` would put the task in NO kanban column until the create
    // round-trips — i.e. never, offline (invoiceninja/flutter#135's defect).
    expect(draft.statusId, 's1');
    expect(draft.assignedUserId, '');
  });

  testWidgets('an empty status list leaves the status unset', (tester) async {
    await open(tester, item: line(), statuses: const <TaskStatus>[]);

    // The field is the disabled placeholder, and it reads "Loading" rather
    // than "No records found": statuses arrive bundled on `/refresh`, so an
    // empty list is a loading state and neither picker passes `emptyHintKey`.
    // Without this the test's only teeth were that `statuses.first` did not
    // throw on an empty list — it passed with the whole seed deleted.
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('No records found'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tasks.created.single.statusId, '');
  });

  testWidgets('a picked assignee reaches the created task', (tester) async {
    await open(tester, item: line());

    await tester.tap(_field('Assigned User'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ada Lovelace').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tasks.created.single.assignedUserId, 'u1');
  });

  testWidgets('a picked status survives a later stream emission', (
    tester,
  ) async {
    await open(tester, item: line());

    await tester.tap(_field('Status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Progress').last);
    await tester.pumpAndSettle();

    // Blur first, or the display half of this is vacuous:
    // `SearchableDropdownField.didUpdateWidget` guards its resync on
    // `!_focusNode.hasFocus`, and `RawAutocomplete._select` does not unfocus —
    // so with the field still focused the text would read 'In Progress'
    // whatever the seed did.
    await tester.tap(_field('Description'));
    await tester.pumpAndSettle();

    // The seed must be a one-shot, or this next Drift emission silently
    // reverts the user to the first status.
    statusRepo.reemit();
    await tester.pumpAndSettle();
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Backlog'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tasks.created.single.statusId, 's2');
  });

  group('createTaskFromLineItemHandler', _handlerGateTests);

  testWidgets('a second Save tap while busy does not double-create', (
    tester,
  ) async {
    await open(tester, item: line());

    final save = find.widgetWithText(FilledButton, 'Save');
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(tasks.created, hasLength(1));
  });
}

/// `createTaskFromLineItemHandler` returns null when the affordance shouldn't
/// exist at all — that null is what hides the row menu item and the mobile
/// button, so each branch is load-bearing.
void _handlerGateTests() {
  Future<ValueChanged<LineItem>?> resolve(
    WidgetTester tester, {
    required FakeCompany company,
    String clientId = 'client-1',
  }) async {
    final fixture = await buildFixture(companies: [company]);
    addTearDown(fixture.dispose);
    ValueChanged<LineItem>? handler;
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) {
            handler = createTaskFromLineItemHandler(
              context,
              companyId: 'co1',
              clientId: clientId,
              projectId: '',
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    return handler;
  }

  const owner = FakeCompany(id: 'co1', name: 'Co');

  testWidgets('wired for an owner with the Tasks module on', (tester) async {
    expect(await resolve(tester, company: owner), isNotNull);
  });

  testWidgets('null when the document has no client yet', (tester) async {
    // A task scheduled from a quote is FOR that client; without one the action
    // would quietly mint an unattached task (and `client_id: ''` risks a 422).
    expect(await resolve(tester, company: owner, clientId: ''), isNull);
  });

  testWidgets('null when the Tasks module is off', (tester) async {
    expect(
      await resolve(
        tester,
        company: const FakeCompany(id: 'co1', name: 'Co', enabledModules: 0),
      ),
      isNull,
    );
  });

  testWidgets('null without the create_task permission', (tester) async {
    // `can()` short-circuits true for an admin/owner, so both must be off for
    // the token list to bite.
    expect(
      await resolve(
        tester,
        company: const FakeCompany(
          id: 'co1',
          name: 'Co',
          isOwner: false,
          isAdmin: false,
          permissions: 'edit_invoice',
        ),
      ),
      isNull,
    );
  });
}
