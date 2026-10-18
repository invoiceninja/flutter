@TestOn('vm')
library;

import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/ensure_loaded_outcome.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/services/company_switched_exception.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/reports/local_report_source.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/task_items_source.dart';
import 'package:admin/ui/features/tasks/view_models/task_weekly_view_model.dart';

/// Fixtures use the LOCAL `DateTime(...)` constructor, far from midnight: the
/// local day then equals the constructed one in every timezone, so this file
/// reads the same on a UTC+2 laptop and on CI in UTC (CLAUDE.md § Strict
/// rules). Check with `TZ=UTC flutter test` before pushing.

final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Sunday 18 October 2026, midday.
final _now = DateTime(2026, 10, 18, 12);

Task _t(
  String id, {
  List<TimeEntry> log = const [],
  String clientId = '',
  String projectId = '',
  String invoiceId = '',
  String statusId = 's1',
  String assignedUserId = '',
  List<String> tagIds = const [],
  bool isDeleted = false,
  Date? dueDate,
}) => Task(
  id: id,
  number: id,
  description: 'Task $id',
  rate: Decimal.zero,
  invoiceId: invoiceId,
  clientId: clientId,
  projectId: projectId,
  statusId: statusId,
  statusOrder: 0,
  assignedUserId: assignedUserId,
  timeLog: log,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: _epoch,
  createdAt: _epoch,
  archivedAt: null,
  isDeleted: isDeleted,
  tagIds: tagIds,
  dueDate: dueDate,
);

TimeEntry _e(
  DateTime start,
  DateTime? stop, {
  String description = '',
  bool billable = true,
}) => TimeEntry(
  start: start,
  stop: stop,
  description: description,
  billable: billable,
);

/// An hour's entry at 09:00 on [day].
TimeEntry _hour(Date day, {String description = ''}) => _e(
  DateTime(day.year, day.month, day.day, 9),
  DateTime(day.year, day.month, day.day, 10),
  description: description,
);

/// "Last 7 days" as of [_now].
ReportQuery _lastWeek({
  String status = '',
  Set<String> clientIds = const {},
  Set<String> projectIds = const {},
  Set<String> tagIds = const {},
  bool includeDeleted = false,
}) => ReportQuery(
  companyId: 'co',
  now: _now,
  label: (key) => key,
  start: Date(2026, 10, 12),
  end: Date(2026, 10, 18),
  status: status,
  clientIds: clientIds,
  projectIds: projectIds,
  tagIds: tagIds,
  includeDeleted: includeDeleted,
);

int _column(ReportPreview p, String id) =>
    p.columns.indexWhere((c) => c.identifier == id);

List<String> _notes(ReportPreview p) => [
  for (final row in p.rows)
    (row.cells[_column(p, 'task.item_notes')] as ReportStringCell).value ?? '',
];

int _seconds(ReportPreview p) => p.rows.fold(
  0,
  (sum, row) =>
      sum +
      ((row.cells[_column(p, 'task.duration')] as ReportDurationCell).seconds ??
          0),
);

void main() {
  group('buildTaskItemsPreview', () {
    test('the beta case: a month-long task shows only last week\'s time', () {
      // Worked on all month. The server's Tasks report drops this task from
      // "last 7 days" — its first entry is in September — and a task it
      // does keep brings every entry it has.
      final task = _t(
        'long',
        log: [
          _hour(Date(2026, 9, 28), description: 'kick-off'),
          _hour(Date(2026, 10, 5), description: 'first draft'),
          _hour(Date(2026, 10, 13), description: 'review'),
          _hour(Date(2026, 10, 16), description: 'final'),
        ],
      );
      final p = buildTaskItemsPreview(tasks: [task], query: _lastWeek());
      expect(_notes(p), ['review', 'final']);
      expect(_seconds(p), 2 * 3600);
      // Each row is the task's, and opens it.
      expect(p.rows.map((r) => r.recordId), ['long', 'long']);
      expect(p.rows.map((r) => r.recordWire), ['task', 'task']);
    });

    test('both ends of the range are kept', () {
      final p = buildTaskItemsPreview(
        tasks: [
          _t(
            'a',
            log: [
              _hour(Date(2026, 10, 11), description: 'before'),
              _hour(Date(2026, 10, 12), description: 'first day'),
              _hour(Date(2026, 10, 18), description: 'last day'),
            ],
          ),
        ],
        query: _lastWeek(),
      );
      expect(_notes(p), ['first day', 'last day']);
    });

    test('an entry belongs wholly to the day it started on', () {
      // 22:00 on the 11th to 02:00 on the 12th: the 11th's, so out.
      final p = buildTaskItemsPreview(
        tasks: [
          _t(
            'a',
            log: [_e(DateTime(2026, 10, 11, 22), DateTime(2026, 10, 12, 2))],
          ),
        ],
        query: _lastWeek(),
      );
      expect(p.rows, isEmpty);
    });

    test('a running timer counts up to now, and its end says so', () {
      final p = buildTaskItemsPreview(
        tasks: [
          _t('a', log: [_e(DateTime(2026, 10, 18, 9), null)]),
        ],
        query: _lastWeek(),
      );
      expect(_seconds(p), 3 * 3600);
      final end = p.rows.single.cells[_column(p, 'task.end_time')];
      expect((end as ReportDateTimeCell).value, isNull);
      expect(end.displayValue, 'running');
    });

    test('a block booked ahead is not time worked', () {
      // As the weekly timesheet: a future block is a booking.
      final p = buildTaskItemsPreview(
        tasks: [
          _t(
            'a',
            log: [_e(DateTime(2026, 10, 18, 15), DateTime(2026, 10, 18, 16))],
          ),
        ],
        query: _lastWeek(),
      );
      expect(p.rows, isEmpty);
    });

    test('rows are oldest first, across tasks', () {
      final p = buildTaskItemsPreview(
        tasks: [
          _t('b', log: [_hour(Date(2026, 10, 15), description: 'third')]),
          _t(
            'a',
            log: [
              _hour(Date(2026, 10, 14), description: 'second'),
              _hour(Date(2026, 10, 13), description: 'first'),
            ],
          ),
        ],
        query: _lastWeek(),
      );
      expect(_notes(p), ['first', 'second', 'third']);
    });

    test('All time keeps every entry', () {
      final p = buildTaskItemsPreview(
        tasks: [
          _t('a', log: [_hour(Date(2020, 1, 6)), _hour(Date(2026, 10, 13))]),
        ],
        query: ReportQuery(companyId: 'co', now: _now, label: (k) => k),
      );
      expect(p.rows, hasLength(2));
    });

    test('the filters are the task report\'s, applied per task', () {
      final day = Date(2026, 10, 13);
      final tasks = [
        _t('billed', log: [_hour(day)], invoiceId: 'inv', clientId: 'c1'),
        _t(
          'open',
          log: [_hour(day)],
          clientId: 'c2',
          projectId: 'p1',
          tagIds: const ['tag1'],
          statusId: 's2',
        ),
        _t('gone', log: [_hour(day)], isDeleted: true),
      ];
      List<String?> ids(ReportQuery q) => [
        for (final r in buildTaskItemsPreview(tasks: tasks, query: q).rows)
          r.recordId,
      ];
      expect(ids(_lastWeek()), ['billed', 'open']);
      expect(ids(_lastWeek(includeDeleted: true)), hasLength(3));
      expect(ids(_lastWeek(status: 'invoiced')), ['billed']);
      expect(ids(_lastWeek(status: 'uninvoiced')), ['open']);
      expect(ids(_lastWeek(status: 's2')), ['open']);
      expect(ids(_lastWeek(clientIds: {'c1'})), ['billed']);
      expect(ids(_lastWeek(projectIds: {'p1'})), ['open']);
      expect(ids(_lastWeek(tagIds: {'tag1'})), ['open']);
    });

    test('ids read as names, and an unknown one as a dash — never an id', () {
      final day = Date(2026, 10, 13);
      final p = buildTaskItemsPreview(
        tasks: [
          _t(
            'a',
            log: [_hour(day)],
            clientId: 'tmp_client',
            projectId: 'missing',
            assignedUserId: 'u1',
          ),
        ],
        query: _lastWeek(),
        names: const TaskItemNames(
          clients: {'real_client': 'Acme'},
          users: {'u1': 'Ann Lee'},
          remap: {'tmp_client': 'real_client'},
        ),
      );
      String text(String id) =>
          (p.rows.single.cells[_column(p, id)] as ReportStringCell).value!;
      expect(text('client.name'), 'Acme');
      expect(text('task.project_id'), '—');
      expect(text('task.assigned_user_id'), 'Ann Lee');
      // The synced client is a link; its old offline id is not.
      expect(
        p.rows.single.cells[_column(p, 'client.name')].entityId,
        'real_client',
      );
    });

    test('a task not yet on the server is not a link', () {
      final p = buildTaskItemsPreview(
        tasks: [
          _t('tmp_abc', log: [_hour(Date(2026, 10, 13))]),
        ],
        query: _lastWeek(),
      );
      expect(p.rows.single.recordId, isNull);
    });

    test('text is flattened, as the server\'s string cells are', () {
      final task = _t(
        'a',
        log: [
          _e(
            DateTime(2026, 10, 13, 9),
            DateTime(2026, 10, 13, 10),
            description: 'Called <b>Ann</b>\nabout the draft',
          ),
        ],
      );
      final p = buildTaskItemsPreview(tasks: [task], query: _lastWeek());
      expect(_notes(p), ['Called Ann about the draft']);
    });

    test('a client filter matches across an offline client\'s sync', () {
      // The filter names the real id; the task still holds the offline one.
      final p = buildTaskItemsPreview(
        tasks: [
          _t('a', log: [_hour(Date(2026, 10, 13))], clientId: 'tmp_c'),
        ],
        query: _lastWeek(clientIds: {'c1'}),
        names: const TaskItemNames(remap: {'tmp_c': 'c1'}),
      );
      expect(p.rows, hasLength(1));
    });

    test('every column has a header and a type of its own', () {
      final p = buildTaskItemsPreview(
        tasks: const [],
        query: ReportQuery(
          companyId: 'co',
          now: _now,
          label: (key) => '[$key]',
        ),
      );
      expect(p.columns.map((c) => c.identifier), kTaskItemsColumnIds);
      ReportColumnType type(String id) =>
          p.columns.singleWhere((c) => c.identifier == id).type;
      expect(type('task.start_date'), ReportColumnType.date);
      expect(type('task.duration'), ReportColumnType.duration);
      expect(type('task.start_time'), ReportColumnType.dateTime);
      expect(type('task.billable'), ReportColumnType.boolean);
      expect(type('client.name'), ReportColumnType.string);
      expect(p.columns.where((c) => c.timeOnly).map((c) => c.identifier), [
        'task.start_time',
        'task.end_time',
      ]);
      expect(p.columns.first.displayLabel, '[date]');
    });
  });

  group('taskTimeCrossesRange', () {
    test('a task with time both in the range and out of it crosses', () {
      expect(
        taskTimeCrossesRange([
          _t('a', log: [_hour(Date(2026, 10, 1)), _hour(Date(2026, 10, 13))]),
        ], _lastWeek()),
        isTrue,
      );
    });

    test('one wholly inside or wholly outside does not', () {
      expect(
        taskTimeCrossesRange([
          _t('in', log: [_hour(Date(2026, 10, 13))]),
          _t('out', log: [_hour(Date(2026, 10, 1))]),
        ], _lastWeek()),
        isFalse,
      );
    });
  });

  group('taskItemsFetchFilters', () {
    test('asks for the tasks active in the range, two days either side', () {
      expect(taskItemsFetchFilters(_lastWeek(), activityDates: true), {
        'activity_dates': {'2026-10-10,2026-10-20'},
      });
    });

    test('an older server gets every task begun by the end', () {
      expect(taskItemsFetchFilters(_lastWeek(), activityDates: false), {
        'date_range': {'calculated_start_date,1970-01-01,2026-10-20'},
      });
    });

    test('All time asks for every task', () {
      expect(
        taskItemsFetchFilters(
          ReportQuery(companyId: 'co', now: _now, label: (k) => k),
          activityDates: true,
        ),
        isEmpty,
      );
    });
  });

  group('TaskItemsReportSource.refresh', () {
    TaskItemsReportSource source({
      required List<int> pages,
      required List<Map<String, Set<String>>> filters,
      required List<Set<EntityState>> states,
      int pagesBeforeEnd = 2,
      Object? failure,
      bool activityDates = true,
    }) => TaskItemsReportSource(
      fetchPage: (companyId, page, s, f) async {
        pages.add(page);
        filters.add(f);
        states.add(s);
        if (failure != null) throw failure;
        return page < pagesBeforeEnd;
      },
      readTasks: (companyId, s) async => [
        _t('a', log: [_hour(Date(2026, 10, 13))]),
      ],
      readNames: (companyId, tasks) async => const TaskItemNames(),
      supportsActivityDates: () => activityDates,
    );

    test(
      'pages until the server says no more, then reads the device',
      () async {
        final pages = <int>[];
        final filters = <Map<String, Set<String>>>[];
        final states = <Set<EntityState>>[];
        final p = await source(
          pages: pages,
          filters: filters,
          states: states,
          pagesBeforeEnd: 3,
        ).refresh(_lastWeek());
        expect(pages, [1, 2, 3]);
        expect(filters.first, {
          'activity_dates': {'2026-10-10,2026-10-20'},
        });
        // Archived tasks count, as on the server; deleted ones only on ask.
        expect(states.first, {EntityState.active, EntityState.archived});
        expect(p.rows, hasLength(1));
      },
    );

    test('a cancelled refresh spends no request', () async {
      final pages = <int>[];
      await expectLater(
        source(
          pages: pages,
          filters: [],
          states: [],
        ).refresh(_lastWeek(), isCancelled: () => true),
        throwsA(
          isA<ReportError>().having(
            (e) => e.kind,
            'kind',
            ReportErrorKind.cancelled,
          ),
        ),
      );
      expect(pages, isEmpty);
    });

    test('a company switched mid-fetch is a cancel, not a failure', () async {
      await expectLater(
        source(
          pages: [],
          filters: [],
          states: [],
          failure: const CompanySwitchedException(
            expected: 'co',
            active: 'other',
            entityType: 'task',
          ),
        ).refresh(_lastWeek()),
        throwsA(
          isA<ReportError>().having(
            (e) => e.kind,
            'kind',
            ReportErrorKind.cancelled,
          ),
        ),
      );
    });

    test(
      'a server that never stops is an error, not a quiet partial',
      () async {
        final pages = <int>[];
        await expectLater(
          source(
            pages: pages,
            filters: [],
            states: [],
            pagesBeforeEnd: 1 << 30,
          ).refresh(_lastWeek()),
          throwsA(isA<ReportError>()),
        );
        expect(pages.length, kTaskItemsMaxPages);
      },
    );
  });

  group('names the device lacks', () {
    test('a refresh fetches the clients its rows name, once, and then names '
        'them', () async {
      var fetched = <String>{};
      final source = TaskItemsReportSource(
        fetchPage: (companyId, page, states, filters) async => false,
        readTasks: (companyId, states) async => [
          _t('a', log: [_hour(Date(2026, 10, 13))], clientId: 'c9'),
          // Outside the range: its client is not this report's business.
          _t('b', log: [_hour(Date(2026, 9, 1))], clientId: 'c8'),
        ],
        readNames: (companyId, tasks) async => TaskItemNames(
          clients: fetched.contains('c9') ? const {'c9': 'Acme'} : const {},
        ),
        supportsActivityDates: () => true,
        hydrateNames: (companyId, clients, projects) async {
          expect(clients, {'c9'});
          fetched = {...clients};
        },
      );
      final p = await source.refresh(_lastWeek());
      final cell =
          p.rows.single.cells[_column(p, 'client.name')] as ReportStringCell;
      expect(cell.value, 'Acme');
    });

    test('names that cannot be fetched leave the rows standing', () async {
      final source = TaskItemsReportSource(
        fetchPage: (companyId, page, states, filters) async => false,
        readTasks: (companyId, states) async => [
          _t('a', log: [_hour(Date(2026, 10, 13))], clientId: 'c9'),
        ],
        readNames: (companyId, tasks) async => const TaskItemNames(),
        supportsActivityDates: () => true,
        hydrateNames: (companyId, clients, projects) async =>
            throw Exception('offline'),
      );
      final p = await source.refresh(_lastWeek());
      final cell =
          p.rows.single.cells[_column(p, 'client.name')] as ReportStringCell;
      expect(cell.value, '—');
    });

    test('reading from the device alone fetches nothing', () async {
      var asked = false;
      final source = TaskItemsReportSource(
        fetchPage: (companyId, page, states, filters) async => false,
        readTasks: (companyId, states) async => [
          _t('a', log: [_hour(Date(2026, 10, 13))], clientId: 'c9'),
        ],
        readNames: (companyId, tasks) async => const TaskItemNames(),
        supportsActivityDates: () => true,
        hydrateNames: (companyId, clients, projects) async => asked = true,
      );
      await source.fromDevice(_lastWeek());
      expect(asked, isFalse);
    });
  });

  group('TaskItemsReportSource.from', () {
    test(
      'sweeps narrowed, keeps deleted clients, and resolves offline ids',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.idRemapDao.remember(
          entityType: 'client',
          tempId: 'tmp_c',
          realId: 'c1',
          now: 0,
        );
        final tasks = _Tasks([
          _t('a', log: [_hour(Date(2026, 10, 13))], clientId: 'tmp_c'),
        ]);
        final clients = _Clients();
        final source = TaskItemsReportSource.from(
          tasks: tasks,
          clients: clients,
          projects: _Projects(),
          users: _Users(),
          taskStatuses: _Statuses(),
          idRemap: db.idRemapDao,
          supportsActivityDates: () => true,
        );
        await source.refresh(_lastWeek(includeDeleted: true));

        final page = tasks.pages.single;
        expect(page.namedArguments[#ignoreCursor], isTrue);
        expect(page.namedArguments[#excludeDeletedClients], isFalse);
        expect(page.namedArguments[#states], {
          EntityState.active,
          EntityState.archived,
          EntityState.deleted,
        });
        expect(page.namedArguments[#extraFilters], {
          'activity_dates': {'2026-10-10,2026-10-20'},
        });
        expect(tasks.readStates, {
          EntityState.active,
          EntityState.archived,
          EntityState.deleted,
        });
        // The offline id is looked up — and fetched — as the real one.
        expect(clients.lookedUp.first, ['c1']);
        expect(clients.refetched, [
          ['c1'],
        ]);
      },
    );
  });

  group('parity with the weekly timesheet', () {
    // The report and the timesheet must agree about the same week — the
    // reader checks one against the other. Asserted against the function the
    // timesheet actually calls.
    test('a timesheet week totals the same in both', () async {
      final tasks = [
        _t(
          'a',
          log: [
            _e(DateTime(2026, 10, 12, 9), DateTime(2026, 10, 12, 11, 30)),
            _e(DateTime(2026, 10, 14, 13), DateTime(2026, 10, 14, 14)),
            // Booked for later today: in neither.
            _e(DateTime(2026, 10, 18, 15), DateTime(2026, 10, 18, 16)),
          ],
        ),
        _t(
          'b',
          log: [
            _e(DateTime(2026, 10, 9, 16), DateTime(2026, 10, 9, 17)),
            _e(DateTime(2026, 10, 16, 16), DateTime(2026, 10, 16, 17)),
          ],
        ),
        _t('c', log: [_e(DateTime(2026, 10, 18, 9), null)]), // running
      ];
      final ctrl = StreamController<List<Task>>();
      final vm = TaskWeeklyViewModel(
        repo: _FakeRepo(ctrl),
        companyId: 'co',
        firstDayOfWeek: 1,
        focus: Date(2026, 10, 14),
        now: () => _now,
      );
      ctrl.add(tasks);
      await Future<void>.delayed(Duration.zero);

      final weekly = [
        for (final day in vm.weekDays)
          for (final t in tasks) vm.secondsFor(t.id, day),
      ].fold<int>(0, (a, b) => a + b);
      final report = buildTaskItemsPreview(
        tasks: tasks,
        query: ReportQuery(
          companyId: 'co',
          now: _now,
          label: (k) => k,
          start: vm.weekDays.first,
          end: vm.weekDays.last,
        ),
      );
      // 2.5 h + 1 h of a, 1 h of b, 3 h of c's running timer.
      expect(weekly, 27000);
      expect(_seconds(report), weekly);

      vm.dispose();
      await ctrl.close();
    });
  });
}

class _FakeRepo implements TaskRepository {
  _FakeRepo(this.controller);
  final StreamController<List<Task>> controller;

  @override
  Stream<List<Task>> watchAllActive({
    required String companyId,
    states = const {},
  }) => controller.stream;

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Tasks implements TaskRepository {
  _Tasks(this.held);
  final List<Task> held;
  final List<Invocation> pages = [];
  Set<EntityState>? readStates;

  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #ensurePageLoaded) {
      pages.add(i);
      return Future<bool>.value(false);
    }
    if (i.memberName == #watchAllActive) {
      readStates = i.namedArguments[#states] as Set<EntityState>?;
      return Stream<List<Task>>.value(held);
    }
    return super.noSuchMethod(i);
  }
}

class _Clients implements ClientRepository {
  final List<List<String>> lookedUp = [];
  final List<List<String>> refetched = [];

  @override
  dynamic noSuchMethod(Invocation i) {
    final ids = i.namedArguments[#ids] as Iterable<String>?;
    if (i.memberName == #getByIds) {
      lookedUp.add([...?ids]);
      return Future.value(const <Never>[]);
    }
    if (i.memberName == #ensureLoaded) {
      refetched.add([i.namedArguments[#id] as String]);
      return Future.value(EnsureLoadedOutcome.fetched);
    }
    return super.noSuchMethod(i);
  }
}

class _Projects implements ProjectRepository {
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #getByIds) return Future.value(const <Never>[]);
    if (i.memberName == #ensureLoaded) {
      return Future.value(EnsureLoadedOutcome.fetched);
    }
    return super.noSuchMethod(i);
  }
}

class _Users implements UserRepository {
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #watchAllForPicker) {
      return Stream.value(const <Never>[]);
    }
    return super.noSuchMethod(i);
  }
}

class _Statuses implements TaskStatusRepository {
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #watchAllIncludingArchived) {
      return Stream.value(const <Never>[]);
    }
    return super.noSuchMethod(i);
  }
}
