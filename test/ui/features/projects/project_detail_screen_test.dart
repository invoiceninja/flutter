// The project record screen, assembled — the record layout end to end against
// a real `Services` graph and a real local database, with the network played
// by a `MockClient`. The harness is `test/_support/record_screen_harness.dart`.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/projects/views/project_detail_screen.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_header.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_standing.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_progress_card.dart';
import 'package:admin/ui/features/projects/widgets/project_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

ProjectApi _project({
  String id = 'p1',
  bool isDeleted = false,
  int archivedAt = 0,
  String clientId = 'c1',
  double currentHours = 0,
}) => ProjectApi(
  currentHours: currentHours,
  id: id,
  name: 'Website Redesign',
  number: '0007',
  clientId: clientId,
  taskRate: '100',
  budgetedHours: 10,
  // Far enough ahead that no clock can bring it round.
  dueDate: '2999-01-01',
  privateNotes: 'Weekly demos on Fridays.',
  isDeleted: isDeleted,
  archivedAt: archivedAt,
  updatedAt: 1710000000,
  createdAt: 1700000000,
);

// Durations, not dates: every figure below is a sum of `stop - start`, so no
// clock or timezone can move it. All well in the past, so none is a booking.
const _t0 = 1700000000;

String _log(List<List<Object>> entries) => jsonEncode(entries);

/// Two hours worked, at the project's rate.
TaskApi _taskA({String projectId = 'p1'}) => TaskApi(
  id: 't1',
  number: '0101',
  description: 'Design homepage',
  projectId: projectId,
  clientId: 'c1',
  timeLog: _log([
    [_t0, _t0 + 7200, '', true],
  ]),
  createdAt: _t0,
  updatedAt: _t0 + 7200,
);

/// An hour and a half, at a rate of its own.
TaskApi _taskB() => TaskApi(
  id: 't2',
  number: '0102',
  description: 'Build components',
  projectId: 'p1',
  clientId: 'c1',
  rate: '200',
  timeLog: _log([
    [_t0 + 10000, _t0 + 10000 + 5400, '', true],
  ]),
  createdAt: _t0 + 10000,
  updatedAt: _t0 + 20000,
);

Future<void> _seed(
  Services services,
  ProjectApi project, {
  List<TaskApi> tasks = const [],
}) async {
  await services.clients.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const ClientApi(
      id: 'c1',
      name: 'Acme Corporation',
      displayName: 'Acme Corporation',
      updatedAt: 1710000000,
      createdAt: 1700000000,
    ),
  );
  await services.projects.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: project,
  );
  for (final t in tasks) {
    await services.tasks.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: t,
    );
  }
}

/// What the app asked the server, and what the server says back.
class _Server {
  /// `meta.pagination.total` by list path, for a `per_page=1` count request.
  Map<String, int> totals = const {};

  /// Rows returned for a project-scoped task list.
  List<Map<String, dynamic>> tasks = const [];

  /// When set, a project-scoped task list is not answered until it completes
  /// — so a test can look at the screen while the rows are still on the wire.
  Completer<void>? gate;

  /// Counts, and task lists scoped to a project — what this screen asks.
  final List<Uri> requests = [];

  Iterable<Uri> get counts =>
      requests.where((u) => u.queryParameters['per_page'] == '1');

  Iterable<Uri> get taskLists => requests.where(
    (u) => u.path == '/api/v1/tasks' && u.queryParameters['per_page'] != '1',
  );

  http.Client get client => MockClient((request) async {
    final url = request.url;
    final query = url.queryParameters;
    if (request.method == 'GET' && query['per_page'] == '1') {
      final total = totals[url.path];
      if (total != null) {
        requests.add(url);
        return countOf(total);
      }
    } else if (request.method == 'GET' &&
        url.path == '/api/v1/tasks' &&
        // Only a list scoped to a project: the fixture's own sidebar prefetch
        // asks for the first page of every entity on start, and that is not
        // this screen's doing.
        query.containsKey('project_tasks')) {
      requests.add(url);
      await gate?.future;
      return jsonOk({'data': tasks});
    }
    throw http.ClientException('offline (test fixture)');
  });
}

/// The project screen over a project seeded into the local database.
void _screenTest(
  String description,
  ProjectApi project,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  List<TaskApi> tasks = const [],
  _Server? server,
  bool online = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
  Size size = const Size(480, 2000),
}) => recordScreenTest(
  description,
  seed: (services) => _seed(services, project, tasks: tasks),
  screen: () => ProjectDetailScreen(id: project.id),
  ready: () => find.byType(StandingCard),
  body: body,
  httpClient: server?.client,
  online: online,
  company: company,
  size: size,
);

/// The count badge drawn inside the tab labelled [label].
Finder _badge(String label, String count) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
  matching: find.text(count),
);

Finder _inHeader(Finder finder) =>
    find.descendant(of: find.byType(ProjectDetailHeader), matching: finder);

void main() {
  _screenTest(
    'an active project: identity, actions, standing, profile, tabs',
    _project(),
    tasks: [_taskA(), _taskB()],
    (tester, screen) async {
      expect(find.text('Website Redesign'), findsWidgets);
      // What it is attached to, under the name: the client, as a link to the
      // client (an owner may view clients), and the number.
      await screen.untilFound(
        _inHeader(find.text('Acme Corporation')),
        'the client name',
      );
      expect(
        _inHeader(find.widgetWithText(LinkText, 'Acme Corporation')),
        findsOneWidget,
      );
      expect(_inHeader(find.text('#0007')), findsOneWidget);

      // Tiles: the same actions the menu has, most-used first. Invoice is
      // there because there is work to bill.
      expect(find.byType(EntityQuickActions<ProjectAction>), findsOneWidget);
      expect(find.text('+ Task'), findsOneWidget);
      expect(find.text('Invoice'), findsOneWidget);
      expect(find.text('+ Expense'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('+ Task')).dx,
        lessThan(tester.getTopLeft(find.text('Invoice')).dx),
      );

      // Standing: 2 h + 1.5 h logged; 2 h at the project's 100 and 1.5 h at
      // that task's own 200 not yet invoiced.
      await screen.untilFound(find.text('3.5 h'), 'the logged figure');
      await screen.untilFound(find.text(r'$500.00'), 'the uninvoiced figure');
      expect(find.text('35% of budget'), findsOneWidget);
      expect(find.byType(ProjectBudgetBar), findsOneWidget);
      // The budget itself is a secondary figure.
      expect(find.text('10 h'), findsOneWidget);

      // The profile is simply there — nothing to open.
      expect(find.text('Due Date'), findsOneWidget);
      expect(find.text('Task Rate'), findsOneWidget);
      expect(find.text('Weekly demos on Fridays.'), findsOneWidget);

      // Comments and Activity still lead the strip, then the project's own
      // lists.
      final comments = tester.getTopLeft(find.text('Comments')).dx;
      final activity = tester.getTopLeft(find.text('Activity')).dx;
      final tasks = tester.getTopLeft(find.text('Tasks')).dx;
      expect(comments, lessThan(activity));
      expect(activity, lessThan(tasks));

      // Rapid entry heads the Tasks tab, which is where the screen lands.
      expect(find.byKey(const Key('project_quick_add_task')), findsOneWidget);
    },
  );

  _screenTest(
    'a project with nothing to bill has no Invoice tile, and says zero',
    _project(),
    (tester, screen) async {
      expect(find.text('+ Task'), findsOneWidget);
      // Not worth a slot: there is nothing to put on an invoice.
      expect(find.text('Invoice'), findsNothing);
      expect(find.text('Add To Invoice'), findsNothing);
      // On this card a zero is the answer, not a dash.
      expect(find.text('0 h'), findsOneWidget);
      await screen.untilFound(find.text(r'$0.00'), 'the uninvoiced figure');
    },
  );

  _screenTest(
    'a deleted project is read-only, and says so once',
    _project(isDeleted: true),
    tasks: [_taskA()],
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
      // Nothing that writes to the record is offered.
      expect(find.text('+ Task'), findsNothing);
      expect(find.byKey(const Key('project_quick_add_task')), findsNothing);
      expect(find.widgetWithText(FilledButton, 'New'), findsNothing);
    },
  );

  _screenTest(
    'an archived project says so and keeps its actions',
    _project(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only: the server still accepts edits and new
      // records for it.
      expect(find.text('+ Task'), findsOneWidget);
      // But rapid entry is for a project being worked on.
      expect(find.byKey(const Key('project_quick_add_task')), findsNothing);
    },
  );

  _screenTest(
    'a user who may only view gets the banner without Restore, no create '
    'tiles, and a client that is not a link',
    _project(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      expect(find.text('+ Task'), findsNothing);
      expect(find.text('Clone'), findsNothing);
      await screen.untilFound(
        _inHeader(find.text('Acme Corporation')),
        'the client name',
      );
      // Named, but not a way into a screen this user cannot open.
      expect(_inHeader(find.byType(LinkText)), findsNothing);

      // This user may not view tasks, so nothing is added up from them: the
      // hours are the server's own running total, and there is no money
      // figure to derive.
      expect(find.text('LOGGED'), findsOneWidget);
      expect(find.text('UNINVOICED'), findsNothing);
      expect(find.text('BUDGETED'), findsOneWidget);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_project',
    ),
  );

  final unsynced = _Server()..totals = const {'/api/v1/tasks': 12};
  _screenTest(
    'an unsynced project gets the sync banner — no tiles, and nothing is '
    'asked of a server that has never seen it',
    _project(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(find.text('+ Task'), findsNothing);
      expect(find.byKey(const Key('project_quick_add_task')), findsNothing);
      await screen.quiet();
      expect(unsynced.requests, isEmpty, reason: '${unsynced.requests}');
    },
    server: unsynced,
    online: true,
  );

  group('counts on the related tabs', () {
    final counted = _Server()
      ..totals = const {
        '/api/v1/tasks': 12,
        '/api/v1/invoices': 3,
        '/api/v1/expenses': 0,
        // The server would answer — with every quote the company has.
        '/api/v1/quotes': 99,
      };
    _screenTest(
      'each counted tab says how many records it holds, asked with the '
      'filter that tab\'s own list sends',
      _project(),
      (tester, screen) async {
        await screen.untilFound(_badge('Tasks', '12'), 'the badges');
        await screen.untilFound(_badge('Invoices', '3'), 'the invoices badge');
        // A real zero is worth saying: it is a tab not worth opening.
        await screen.untilFound(_badge('Expenses', '0'), 'the expenses badge');

        // The server names a project differently on every list.
        final byPath = {
          for (final u in counted.counts) u.path: u.queryParameters,
        };
        expect(byPath['/api/v1/tasks']?['project_tasks'], 'p1');
        expect(byPath['/api/v1/invoices']?['project_id'], 'p1');
        expect(byPath['/api/v1/expenses']?['project_ids'], 'p1');
        for (final q in byPath.values) {
          expect(q['status'], 'active');
          // What each of those lists sends when it is not scoped to a client
          // (`excludeDeletedClients` in its repository). Counted without it,
          // the badge includes the rows of an archived client that the tab
          // will never fetch — and the Tasks count is what the figures above
          // are checked against.
          expect(q['without_deleted_clients'], 'true');
        }

        // Quotes cannot be scoped to a project on the server, so they are
        // never counted: the number would be the whole company's.
        await screen.quiet();
        expect(byPath.containsKey('/api/v1/quotes'), isFalse);
        expect(_badge('Quotes', '99'), findsNothing);
      },
      server: counted,
      online: true,
    );

    final short = _Server()
      ..totals = const {'/api/v1/tasks': 2}
      ..tasks = [_taskA().toJson(), _taskB().toJson()]
      ..gate = Completer<void>();
    _screenTest(
      'the totals are added up only from every task: while the device holds '
      'fewer than the server counted, the card says what the server totalled '
      'and prints no money',
      _project(currentHours: 4),
      // One of the project's two tasks is here — as after opening a project
      // whose list has only ever been scrolled part of the way.
      tasks: [_taskA()],
      (tester, screen) async {
        await screen.untilFound(_badge('Tasks', '2'), 'the count');
        // Not "2 h" and "$200.00" — a sum of the one task held — but the
        // server's own running total, and no amount at all.
        await screen.untilFound(find.text('4 h'), 'the server\'s total');
        expect(find.text('2 h'), findsNothing);
        expect(find.text(r'$200.00'), findsNothing);
        // The card keeps the shape it is about to have — the figure is there,
        // blank — rather than opening on the reduced card a user without
        // `view_task` gets and snapping to this one when the rows land.
        expect(find.text('UNINVOICED'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(ProjectDetailStanding),
            matching: find.textContaining(r'$'),
          ),
          findsNothing,
        );
        final loggedAt = tester.getTopLeft(find.text('LOGGED'));
        final uninvoicedAt = tester.getTopLeft(find.text('UNINVOICED'));

        // The rest arrive — asked for by project, never as a sweep.
        short.gate!.complete();
        await screen.untilFound(find.text('3.5 h'), 'the logged figure');
        await screen.untilFound(find.text(r'$500.00'), 'the uninvoiced one');
        // …and nothing moved to make room for them.
        expect(tester.getTopLeft(find.text('LOGGED')), loggedAt);
        expect(tester.getTopLeft(find.text('UNINVOICED')), uninvoicedAt);
        for (final u in short.taskLists) {
          expect(u.queryParameters['project_tasks'], 'p1', reason: '$u');
        }
      },
      server: short,
      online: true,
    );

    final offline = _Server()..totals = const {'/api/v1/tasks': 12};
    _screenTest('offline, the tabs carry no counts at all', _project(), (
      tester,
      screen,
    ) async {
      await screen.quiet();
      expect(_badge('Tasks', '12'), findsNothing);
      expect(offline.counts, isEmpty);
    }, server: offline);
  });

  group('refresh', () {
    final server = _Server()
      ..tasks = [
        {
          'id': 't1',
          'number': '0101',
          'description': 'Design homepage',
          'project_id': 'p1',
          'client_id': 'c1',
          'time_log': '[]',
          'updated_at': 1700000000,
        },
      ];
    _screenTest(
      'R reloads this project\'s list — one page, still scoped — with '
      'nothing clicked first',
      _project(),
      (tester, screen) async {
        await screen.until(() => server.taskLists.isNotEmpty, 'the list');
        await screen.quiet();
        final before = server.requests.length;

        // Straight from arrival: no click into the body to give the key
        // somewhere to land.
        expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
        await screen.until(
          () => server.requests.length > before,
          'the refresh',
        );
        await screen.quiet();

        // Every task request the refresh made named the project. The list's
        // own `refresh` is a sweep of the whole entity — every page, no
        // project — and that is what a record refresh must never call.
        final after = server.requests.skip(before).toList();
        final lists = after.where(
          (u) =>
              u.path == '/api/v1/tasks' && u.queryParameters['per_page'] != '1',
        );
        expect(lists, isNotEmpty);
        for (final u in lists) {
          expect(u.queryParameters['project_tasks'], 'p1', reason: '$u');
          expect(u.queryParameters['page'], '1', reason: '$u');
        }
      },
      server: server,
    );
  });

  group('wide', () {
    _screenTest(
      'the band and the profile row each end on one line',
      _project(),
      tasks: [_taskA(), _taskB()],
      (tester, screen) async {
        await screen.untilFound(find.byType(ProjectProgressCard), 'the chart');
        expect(tester.takeException(), isNull);

        // The band: the standing card ends level with the last tile.
        final standing = tester.getRect(find.byType(ProjectDetailStanding));
        final tile = tester.getRect(
          find.ancestor(
            of: find.text('+ Task'),
            matching: find.byType(InkWell),
          ),
        );
        expect(standing.bottom, moreOrLessEquals(tile.bottom, epsilon: 0.5));
        expect(standing.left, greaterThan(tile.right), reason: 'beside it');

        // The profile row: Details and the chart, side by side, same foot.
        final details = tester.getRect(
          find.ancestor(
            of: find.text('Details'),
            matching: find.byType(DashboardCardShell),
          ),
        );
        final chart = tester.getRect(find.byType(ProjectProgressCard));
        expect(chart.left, greaterThan(details.right));
        expect(chart.top, moreOrLessEquals(details.top, epsilon: 0.5));
        expect(chart.bottom, moreOrLessEquals(details.bottom, epsilon: 0.5));
        // Equal cards.
        expect(chart.width, moreOrLessEquals(details.width, epsilon: 0.5));
      },
      size: const Size(1400, 2000),
    );

    _screenTest(
      'with nothing logged there is no chart, and Details takes the row',
      _project(),
      (tester, screen) async {
        await screen.untilFound(find.text('Details'), 'the profile');
        expect(find.byType(ProjectProgressCard), findsNothing);
        final details = tester.getRect(
          find.ancestor(
            of: find.text('Details'),
            matching: find.byType(DashboardCardShell),
          ),
        );
        final standing = tester.getRect(find.byType(ProjectDetailStanding));
        final tile = tester.getRect(
          find.ancestor(
            of: find.text('+ Task'),
            matching: find.byType(InkWell),
          ),
        );
        // Edge to edge with the band above it, its rows in two columns —
        // not held to the header's column with a blank under the standing
        // card.
        expect(details.left, moreOrLessEquals(tile.left, epsilon: 0.5));
        expect(details.right, moreOrLessEquals(standing.right, epsilon: 0.5));
        // Two columns: some later row starts level with the first one, to
        // its right.
        final first = tester.getTopLeft(find.text('Due Date'));
        expect(
          ['Task Rate', 'Date Created', 'Updated']
              .map((label) => tester.getTopLeft(find.text(label)))
              .where((at) => at.dy == first.dy && at.dx > first.dx),
          hasLength(1),
        );
      },
      size: const Size(1400, 2000),
    );
  });

  _screenTest(
    'on a pane the chart is not drawn — the budget bar is the chart',
    _project(),
    tasks: [_taskA(), _taskB()],
    (tester, screen) async {
      await screen.untilFound(find.text('3.5 h'), 'the logged figure');
      expect(find.byType(ProjectBudgetBar), findsOneWidget);
      expect(find.byType(ProjectProgressCard), findsNothing);
    },
  );

  _screenTest(
    'a task typed into the quick-add field lands in the list under it',
    _project(),
    (tester, screen) async {
      final field = find.byKey(const Key('project_quick_add_task'));
      await tester.tap(field);
      await tester.enterText(field, 'Write the brief');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      // The field empties once the create has gone through; only then is the
      // text on screen the new row and not what was typed.
      await screen.until(
        () => tester.widget<TextField>(field).controller!.text.isEmpty,
        'the create',
      );
      await screen.untilFound(find.text('Write the brief'), 'the new task');
      final created = await tester.runAsync(
        () => screen.services.tasks
            .watchForProject(companyId: 'co1', projectId: 'p1')
            .first,
      );
      expect(created!.single.description, 'Write the brief');
      // The project's rate and client came with it.
      expect(created.single.clientId, 'c1');
    },
  );
}
