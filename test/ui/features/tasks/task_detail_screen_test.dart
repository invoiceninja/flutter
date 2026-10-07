// The task record screen, assembled — the record layout end to end against a
// real `Services` graph and a real local database, with the network played by
// a `MockClient`. The harness is `test/_support/record_screen_harness.dart`.

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
import 'package:admin/data/models/api/task_status_api_model.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/tasks/views/task_detail_screen.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_description_card.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_header.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_standing.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_time_log.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

// Durations, not dates: every figure below is a sum of `stop - start`, so no
// clock or timezone can move it. All well in the past, so none is a booking.
const _t0 = 1700000000;

String _log(List<List<Object>> entries) => jsonEncode(entries);

/// Two entries: two hours, then an hour and a half. No rate of its own.
final _worked = _log([
  [_t0, _t0 + 7200, 'Wireframes', true],
  [_t0 + 10000, _t0 + 10000 + 5400, '', true],
]);

TaskApi _task({
  String id = 't1',
  String description = 'Design homepage',
  String? timeLog,
  String invoiceId = '',
  bool isDeleted = false,
  int archivedAt = 0,
}) => TaskApi(
  id: id,
  number: '0101',
  description: description,
  clientId: 'c1',
  projectId: 'p1',
  statusId: 'st2',
  invoiceId: invoiceId,
  timeLog: timeLog ?? _worked,
  isDeleted: isDeleted,
  archivedAt: archivedAt,
  updatedAt: 1710000000,
  createdAt: 1700000000,
);

Future<void> _seed(Services services, TaskApi task) async {
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
  // The task has no rate of its own; this is the one it inherits.
  await services.projects.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: const ProjectApi(
      id: 'p1',
      name: 'Website Redesign',
      clientId: 'c1',
      taskRate: '100',
      updatedAt: 1710000000,
      createdAt: 1700000000,
    ),
  );
  await services.taskStatuses.applyBundle(
    companyId: 'co1',
    bundle: const [
      TaskStatusApi(id: 'st1', name: 'Backlog', statusOrder: 1),
      TaskStatusApi(id: 'st2', name: 'In progress', statusOrder: 2),
    ],
  );
  await services.tasks.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: task,
  );
}

/// What the app asked the server about tasks.
class _Server {
  /// The record `GET /tasks/{id}` returns — null leaves it unanswered.
  Map<String, dynamic>? record;

  /// Every task request that names a record or a scope. (Not the fixture's
  /// own sidebar prefetch, which asks for the bare first page of every entity
  /// on start and is not this screen's doing.)
  final List<Uri> requests = [];

  Iterable<Uri> get recordAsks =>
      requests.where((u) => u.path.startsWith('/api/v1/tasks/'));

  http.Client get client => MockClient((request) async {
    final url = request.url;
    if (request.method == 'GET' && url.path.startsWith('/api/v1/tasks/')) {
      requests.add(url);
      final record = this.record;
      if (record != null) return jsonOk({'data': record});
    } else if (request.method == 'GET' &&
        url.path == '/api/v1/tasks' &&
        url.queryParameters.keys.any(
          (k) => k.contains('project') || k.contains('client_id'),
        )) {
      requests.add(url);
    }
    throw http.ClientException('offline (test fixture)');
  });
}

/// The task screen over a task seeded into the local database.
void _screenTest(
  String description,
  TaskApi task,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  bool online = false,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
  Size size = const Size(480, 2000),
}) => recordScreenTest(
  description,
  seed: (services) => _seed(services, task),
  screen: () => TaskDetailScreen(id: task.id),
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
    find.descendant(of: find.byType(TaskDetailHeader), matching: finder);

/// The quick-action tile labelled [label].
Finder _tile(String label) => find.descendant(
  of: find.byType(EntityQuickActions<TaskAction>),
  matching: find.text(label),
);

Future<Task> _stored(WidgetTester tester, RecordScreen screen) async {
  final task = await tester.runAsync(
    () => screen.services.tasks.watch(companyId: 'co1', id: 't1').first,
  );
  return task!;
}

void main() {
  _screenTest(
    'an active task: identity, actions, standing, profile, tabs',
    _task(),
    (tester, screen) async {
      expect(_inHeader(find.text('Design homepage')), findsOneWidget);
      // What it is attached to, under the name: the client and the project,
      // each a link to its own screen (an owner may view both), then the
      // number.
      await screen.untilFound(
        _inHeader(find.widgetWithText(LinkText, 'Acme Corporation')),
        'the client link',
      );
      await screen.untilFound(
        _inHeader(find.widgetWithText(LinkText, 'Website Redesign')),
        'the project link',
      );
      expect(_inHeader(find.text('#0101')), findsOneWidget);
      // In reading order: the client, then the project (the line wraps
      // between segments in a narrow pane).
      final client = tester.getTopLeft(
        _inHeader(find.text('Acme Corporation')),
      );
      final project = tester.getTopLeft(
        _inHeader(find.text('Website Redesign')),
      );
      expect(
        client.dy < project.dy ||
            (client.dy == project.dy && client.dx < project.dx),
        isTrue,
      );

      // Tiles: the timer first — Resume, because there is worked time to
      // resume — then the ways to bill it.
      expect(_tile('Resume'), findsOneWidget);
      expect(_tile('Start'), findsNothing);
      expect(_tile('Invoice'), findsOneWidget);
      expect(_tile('Clone'), findsOneWidget);
      expect(
        tester.getTopLeft(_tile('Resume')).dx,
        lessThan(tester.getTopLeft(_tile('Invoice')).dx),
      );

      // Standing: 2:00 + 1:30 worked, at the PROJECT's rate — the task has
      // none of its own, and its own is what the old strip multiplied.
      expect(find.text('3:30:00'), findsOneWidget);
      await screen.untilFound(find.text(r'$350.00'), 'the amount');
      expect(find.text(r'$100.00'), findsOneWidget);
      await screen.untilFound(find.text('In progress'), 'the status');

      // The profile is simply there — nothing to open.
      expect(find.text('Details'), findsOneWidget);
      // A description the header shows whole is not printed a second time.
      expect(find.byType(TaskDetailDescriptionCard), findsNothing);

      // Comments and Activity still lead the strip, then the task's own
      // content: its time log, counted from the record itself.
      final comments = tester.getTopLeft(find.text('Comments')).dx;
      final activity = tester.getTopLeft(find.text('Activity')).dx;
      final timeLog = tester.getTopLeft(find.text('Time Log')).dx;
      expect(comments, lessThan(activity));
      expect(activity, lessThan(timeLog));
      expect(_badge('Time Log', '2'), findsOneWidget);
      expect(find.text('Overview'), findsNothing);

      // And it is the tab the screen lands on.
      expect(find.byType(TaskDetailTimeLog), findsOneWidget);
      expect(find.text('Wireframes'), findsOneWidget);
      expect(find.text('2:00:00'), findsOneWidget);
      expect(find.text('1:30:00'), findsOneWidget);
    },
  );

  _screenTest(
    'a deleted task is read-only, and says so once',
    _task(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
      // Nothing that writes to the record is offered — the timer least of all.
      expect(find.byType(InkWell).evaluate().isNotEmpty, isTrue);
      expect(_tile('Resume'), findsNothing);
      expect(_tile('Clone'), findsNothing);
      // What it holds stays readable.
      expect(find.text('3:30:00'), findsOneWidget);
      expect(find.text('Wireframes'), findsOneWidget);
    },
  );

  _screenTest(
    'an archived task says so and keeps its actions',
    _task(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only: the server still accepts edits to it.
      expect(_tile('Resume'), findsOneWidget);
    },
  );

  _screenTest(
    'a user who may only view gets the banner without Restore, no create or '
    'billing tiles, and names that are not links',
    _task(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      expect(_tile('Invoice'), findsNothing);
      expect(_tile('Clone'), findsNothing);
      await screen.untilFound(
        _inHeader(find.text('Acme Corporation')),
        'the client name',
      );
      // Named, but not a way into screens this user cannot open.
      expect(_inHeader(find.byType(LinkText)), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      permissions: 'view_task',
    ),
  );

  final unsynced = _Server();
  _screenTest(
    'an unsynced task gets the sync banner — no tiles, and nothing is asked '
    'of a server that has never seen it',
    _task(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(find.byType(EntityQuickActions<TaskAction>), findsOneWidget);
      expect(_tile('Resume'), findsNothing);
      expect(_tile('Clone'), findsNothing);
      await screen.quiet();
      expect(unsynced.requests, isEmpty, reason: '${unsynced.requests}');
    },
    server: unsynced,
    online: true,
  );

  _screenTest(
    'an invoiced task offers no timer, and leads to its invoice',
    _task(invoiceId: 'inv1'),
    (tester, screen) async {
      // Server-immutable: there is nothing to start, resume or bill again.
      expect(_tile('Resume'), findsNothing);
      expect(_tile('Start'), findsNothing);
      expect(_tile('Invoice'), findsNothing);
      // Said in the standing card, and the Details card has the way there.
      expect(
        find.descendant(
          of: find.byType(TaskDetailStanding),
          matching: find.text('Invoiced'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('Details'),
            matching: find.byType(DashboardCardShell),
          ),
          matching: find.text('Invoice'),
        ),
        findsOneWidget,
      );
    },
  );

  group('the timer tile', () {
    _screenTest(
      'starts the timer, turns into Stop, and stops it',
      // Nothing logged: the tile is Start, not Resume.
      _task(timeLog: '[]'),
      (tester, screen) async {
        expect(_tile('Start'), findsOneWidget);
        expect(find.text('0:00:00'), findsOneWidget);
        // Nothing to bill yet, so the billing tiles yield their slots.
        expect(_tile('Invoice'), findsNothing);

        await tester.tap(_tile('Start'));
        await screen.untilFound(_tile('Stop'), 'the running state');
        expect(_tile('Start'), findsNothing);
        var stored = await _stored(tester, screen);
        expect(stored.isRunning, isTrue);
        expect(stored.timeLog, hasLength(1));
        // The log is the tab's own count, straight off the record.
        expect(_badge('Time Log', '1'), findsOneWidget);

        await tester.tap(_tile('Stop'));
        await screen.until(() => _tile('Stop').evaluate().isEmpty, 'the stop');
        // Let the write and what it queued finish before the fixture closes
        // the database under them: a save still mid-transaction when the
        // test ends is a `close()` that never returns.
        await screen.quiet();
        stored = await _stored(tester, screen);
        expect(stored.isRunning, isFalse);
        expect(stored.timeLog, hasLength(1));
      },
    );

    _screenTest(
      'takes one tap at a time — a second tap while the first is in flight '
      'does not start a second entry',
      _task(timeLog: '[]'),
      (tester, screen) async {
        final start = _tile('Start');
        await tester.tap(start);
        // Before the write has landed: the tile is still there, and inert.
        await tester.tap(start, warnIfMissed: false);
        await screen.untilFound(_tile('Stop'), 'the running state');
        await screen.quiet();
        final stored = await _stored(tester, screen);
        expect(stored.timeLog, hasLength(1));
        expect(stored.isRunning, isTrue);
      },
    );
  });

  _screenTest(
    'a description the header cuts off is printed in full below',
    _task(
      description:
          'Rework the checkout flow so the address step validates postcodes '
          'for every country we ship to, and the payment form keeps what was '
          'typed when a card is declined.',
    ),
    (tester, screen) async {
      expect(find.byType(TaskDetailDescriptionCard), findsOneWidget);
      expect(find.text('Description'), findsOneWidget);
    },
  );

  group('refresh', () {
    final server = _Server()
      ..record = {
        'id': 't1',
        'number': '0101',
        'description': 'Design homepage',
        'client_id': 'c1',
        'project_id': 'p1',
        'status_id': 'st2',
        'time_log': _worked,
        'updated_at': 1710009999,
        'created_at': 1700000000,
      };
    _screenTest(
      'R re-fetches this task and nothing wider — with nothing clicked first',
      _task(),
      (tester, screen) async {
        // The quiet re-check on open asks once.
        await screen.until(() => server.recordAsks.isNotEmpty, 'the re-check');
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

        // The record, by id — and no list of anything.
        final after = server.requests.skip(before).toList();
        expect(after, isNotEmpty);
        for (final u in after) {
          expect(u.path, '/api/v1/tasks/t1', reason: '$u');
        }
      },
      server: server,
      online: true,
    );
  });

  _screenTest(
    'wide: the standing card ends level with the tiles, and Details takes '
    'the row',
    _task(),
    (tester, screen) async {
      await screen.untilFound(find.text('Details'), 'the profile');
      expect(tester.takeException(), isNull);
      final standing = tester.getRect(find.byType(TaskDetailStanding));
      final tile = tester.getRect(
        find.ancestor(of: _tile('Resume'), matching: find.byType(InkWell)),
      );
      expect(standing.bottom, moreOrLessEquals(tile.bottom, epsilon: 0.5));
      expect(standing.left, greaterThan(tile.right), reason: 'beside it');

      final details = tester.getRect(
        find.ancestor(
          of: find.text('Details'),
          matching: find.byType(DashboardCardShell),
        ),
      );
      // Edge to edge with the band above it — not held to the header's
      // column with a blank under the standing card.
      expect(details.left, moreOrLessEquals(tile.left, epsilon: 0.5));
      expect(details.right, moreOrLessEquals(standing.right, epsilon: 0.5));
    },
    size: const Size(1400, 2000),
  );
}
