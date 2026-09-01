import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:decimal/decimal.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/tasks/widgets/task_list_tile.dart';
import 'package:admin/ui/features/tasks/widgets/task_status_pill.dart';

import '../../../_localization_helper.dart';

/// Resolves status watches from an in-memory map so the StreamBuilder settles
/// synchronously — no Drift stream, no `pumpAndSettle` timeout.
class _FakeTaskStatusRepo implements TaskStatusRepository {
  _FakeTaskStatusRepo(this.byId);
  final Map<String, TaskStatus> byId;
  @override
  Stream<TaskStatus?> watch({required String companyId, required String id}) =>
      Stream<TaskStatus?>.value(byId[id]);
  // Cold peek cache: keeps these tests on the async watch path,
  // exactly as before `BaseEntityRepository.peek` existed.
  @override
  TaskStatus? peek({required String companyId, required String id}) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueListenable<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  _FakeServices({required this.auth, required this.taskStatuses});
  @override
  final AuthRepository auth;
  @override
  final TaskStatusRepository taskStatuses;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

TaskStatus _status({
  required String id,
  required String name,
  required String color,
}) => TaskStatus(
  id: id,
  name: name,
  color: color,
  statusOrder: 1,
  updatedAt: _epoch,
  createdAt: _epoch,
  archivedAt: null,
  isDeleted: false,
);

Task _task({required String statusId}) => Task(
  id: 't1',
  number: '1',
  description: 'Task',
  rate: Decimal.zero,
  invoiceId: '',
  clientId: '',
  projectId: '',
  statusId: statusId,
  statusOrder: 0,
  assignedUserId: '',
  timeLog: [
    TimeEntry(
      start: DateTime.utc(2026, 1, 1, 9),
      stop: DateTime.utc(2026, 1, 1, 10),
    ),
  ],
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
  /// The four statuses the server creates for a new company: named in the
  /// company's locale, and colorless (`#fff`, the MySQL column default).
  final statuses = <String, TaskStatus>{
    's_backlog': _status(id: 's_backlog', name: 'Backlog', color: '#fff'),
    's_ready': _status(id: 's_ready', name: 'Ready to do', color: '#fff'),
    's_progress': _status(id: 's_progress', name: 'In progress', color: '#fff'),
    's_done': _status(id: 's_done', name: 'Done', color: '#fff'),
    's_custom': _status(id: 's_custom', name: 'Blocked', color: '#EF4444'),
    's_uncolored': _status(id: 's_uncolored', name: 'Blocked', color: ''),
  };

  Future<void> pump(WidgetTester tester, Widget child) async {
    final session = ValueNotifier<AuthSession?>(
      const AuthSession(
        baseUrl: '',
        isHosted: false,
        accountId: '',
        companies: [],
        currentCompanyId: 'co',
      ),
    );
    addTearDown(session.dispose);
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(
          auth: _FakeAuth(session),
          taskStatuses: _FakeTaskStatusRepo(statuses),
        ),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  Future<StatusPill> pumpPill(WidgetTester tester, String statusId) async {
    await pump(tester, Center(child: TaskStatusPill(statusId: statusId)));
    return tester.widget<StatusPill>(find.byType(StatusPill));
  }

  const tokens = InTheme.light;

  testWidgets('the colorless built-ins each get their own color', (
    tester,
  ) async {
    // invoiceninja/flutter#33 — before this, all four fell back to `ink3`
    // because `#fff` never parsed, so the list read as one grey block.
    final backlog = await pumpPill(tester, 's_backlog');
    expect(backlog.fgColor, tokens.draft);
    expect(backlog.bgColor, tokens.draftSoft);

    final ready = await pumpPill(tester, 's_ready');
    expect(ready.fgColor, tokens.partial);
    expect(ready.bgColor, tokens.partialSoft);

    final progress = await pumpPill(tester, 's_progress');
    expect(progress.fgColor, tokens.sent);
    expect(progress.bgColor, tokens.sentSoft);

    final done = await pumpPill(tester, 's_done');
    expect(done.fgColor, tokens.paid);
    expect(done.bgColor, tokens.paidSoft);

    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('a user-picked color still wins', (tester) async {
    final pill = await pumpPill(tester, 's_custom');
    expect(pill.fgColor, const Color(0xFFEF4444));
    // Null bg → StatusPill derives the 15 % tint, as it always has.
    expect(pill.bgColor, isNull);
  });

  testWidgets('an unrecognized colorless status keeps the neutral', (
    tester,
  ) async {
    final pill = await pumpPill(tester, 's_uncolored');
    expect(pill.fgColor, tokens.ink3);
    expect(pill.bgColor, isNull);
  });

  testWidgets('an unknown status id falls back to the neutral', (tester) async {
    final pill = await pumpPill(tester, 'nope');
    expect(pill.fgColor, tokens.ink3);
    expect(pill.label, 'nope');
  });

  // The narrow layout has no column strip, so the status rides on the
  // secondary line — without it the phone list is the one surface where a
  // task's status is invisible.
  group('narrow task row', () {
    Future<void> pumpTile(
      WidgetTester tester, {
      required String statusId,
      double width = 360,
    }) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(
        tester,
        TaskListTile(
          task: _task(statusId: statusId),
          companyId: 'co',
          columns: const [],
          wide: false,
          onTap: () {},
        ),
      );
    }

    testWidgets('shows the status pill at phone width', (tester) async {
      await pumpTile(tester, statusId: 's_progress');
      expect(find.byType(TaskStatusPill), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long status name ellipsizes instead of overflowing', (
      tester,
    ) async {
      // The pill labels itself with the raw id when the status is unknown, so
      // a long id stands in for a long user-defined status name.
      await pumpTile(
        tester,
        statusId: 'Waiting on the client to approve the revised estimate',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders no pill when the task has no status', (tester) async {
      await pumpTile(tester, statusId: '');
      expect(find.byType(TaskStatusPill), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
