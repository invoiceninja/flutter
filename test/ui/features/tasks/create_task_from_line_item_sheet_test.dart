import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart'
    show emptyTask;
import 'package:admin/ui/features/tasks/widgets/create_task_from_line_item_sheet.dart';

import '../../../_localization_helper.dart';
import '../shell/_shell_test_helpers.dart';

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

class _FakeCompany implements CompanyRepository {
  @override
  Stream<Company?> watchCompany(String companyId) =>
      Stream<Company?>.value(null);

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.tasks);

  @override
  final TaskRepository tasks;

  @override
  final CompanyRepository company = _FakeCompany();

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

void main() {
  late _FakeTasks tasks;

  Future<void> open(
    WidgetTester tester, {
    required LineItem item,
    List<Task> existing = const <Task>[],
    Size size = const Size(900, 900),
  }) async {
    tasks = _FakeTasks(existing);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      // Provider above MaterialApp, as `main.dart` has it — `showDialog` pushes
      // onto the root navigator, whose overlay sits above `home:`.
      Provider<Services>.value(
        value: _FakeServices(tasks),
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
    // Duration is field 3: description, date, time, duration, rate.
    await tester.enterText(find.byType(TextField).at(3), '');
    // Blur it — the field must not keep showing something it won't save.
    await tester.tap(find.byType(TextField).at(0));
    await tester.pumpAndSettle();

    expect(find.text('2:00'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final entry = tasks.created.single.timeLog.single;
    expect(entry.stop!.difference(entry.start!), const Duration(hours: 2));
  });

  testWidgets('an edited duration reaches the created task', (tester) async {
    await open(tester, item: line());
    await tester.enterText(find.byType(TextField).at(3), '0:45');
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

    await tester.enterText(find.byType(TextField).at(1), '2026-06-20');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final entry = tasks.created.single.timeLog.single;
    expect(entry.start, DateTime(2026, 6, 20, 9));
    expect(entry.stop!.difference(entry.start!), const Duration(hours: 2));
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
