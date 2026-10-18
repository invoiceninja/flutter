import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/id_remap_dao.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/reports/local_report_source.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/notes_html.dart';

final _log = Logger('TaskItemsReportSource');

/// The Task Items report: one row per **time entry**, each kept or dropped by
/// its own day.
///
/// The server cannot answer this. Its task report filters whole tasks by the
/// day of their first entry (`calculated_start_date`), so a task worked on
/// all month is missing from "last week" though half its time is there, and
/// one that matches brings every entry it has. So the report is built here:
/// the tasks with activity in the range are fetched into the device's store
/// (`GET /tasks?activity_dates=`, the task calendar's fetch), and each of
/// their entries is tested on its own.
///
/// The rules are the weekly timesheet's (`TaskWeeklyViewModel.secondsFor`),
/// so the two agree about the same week: an entry belongs wholly to the
/// local day it **started** on ([timeEntryLocalDate]), a running timer counts
/// up to now, and a block booked ahead ([isTimeEntryBooking]) is not time
/// worked.
class TaskItemsReportSource implements LocalReportSource {
  TaskItemsReportSource({
    required this.fetchPage,
    required this.readTasks,
    required this.readNames,
    required this.supportsActivityDates,
    this.hydrateNames,
  });

  /// Wires the source to the app's repositories.
  factory TaskItemsReportSource.from({
    required TaskRepository tasks,
    required ClientRepository clients,
    required ProjectRepository projects,
    required UserRepository users,
    required TaskStatusRepository taskStatuses,
    required IdRemapDao idRemap,
    required bool Function() supportsActivityDates,
  }) => TaskItemsReportSource(
    fetchPage: (companyId, page, states, filters) => tasks.ensurePageLoaded(
      companyId: companyId,
      page: page,
      states: states,
      extraFilters: filters,
      // A narrowed sweep of its own: the shared task cursor is neither read
      // nor advanced (CLAUDE.md § Sync) — except on "All time" with deleted
      // tasks included, whose first page is the unfiltered list and moves
      // the cursor as a sync would. Harmless: the pages it skips past are
      // the ones this sweep is fetching.
      ignoreCursor: true,
      excludeDeletedClients: false,
    ),
    readTasks: (companyId, states) =>
        tasks.watchAllActive(companyId: companyId, states: states).first,
    readNames: (companyId, rows) => _readNames(
      companyId,
      rows,
      clients: clients,
      projects: projects,
      users: users,
      taskStatuses: taskStatuses,
      idRemap: idRemap,
    ),
    supportsActivityDates: supportsActivityDates,
    hydrateNames: (companyId, clientIds, projectIds) async {
      // One request per record (the list routes take no id filter), a few at
      // a time. `ensureLoaded`, not a refetch: it skips what is held, joins a
      // fetch already under way, never throws, and remembers a record the
      // server says is gone or not this user's — so a name that cannot be
      // had is not asked for again on every run.
      for (final chunk in _chunks(clientIds, 10)) {
        await Future.wait([
          for (final id in chunk)
            clients.ensureLoaded(companyId: companyId, id: id),
        ]);
      }
      for (final chunk in _chunks(projectIds, 10)) {
        await Future.wait([
          for (final id in chunk)
            projects.ensureLoaded(companyId: companyId, id: id),
        ]);
      }
    },
  );

  /// One page of tasks from the server into the device's store; true while
  /// there are more.
  final Future<bool> Function(
    String companyId,
    int page,
    Set<EntityState> states,
    Map<String, Set<String>> filters,
  )
  fetchPage;

  /// The tasks the device holds in [states].
  final Future<List<Task>> Function(String companyId, Set<EntityState> states)
  readTasks;

  /// The names the tasks' ids resolve to.
  final Future<TaskItemNames> Function(String companyId, List<Task> tasks)
  readNames;

  /// Fetch the clients and projects whose names the rows need and the device
  /// does not hold — sign-in fetches one page of each, so on a company of
  /// more than fifty most of them would read `—`. Null fetches nothing.
  final Future<void> Function(
    String companyId,
    Set<String> clientIds,
    Set<String> projectIds,
  )?
  hydrateNames;

  /// Whether the server takes `activity_dates` (5.13.43 —
  /// `ServerFeatures.taskActivityDates`). Read at each refresh: the version
  /// is unknown until the first response.
  final bool Function() supportsActivityDates;

  @override
  Future<ReportPreview> fromDevice(ReportQuery query) async {
    final tasks = await readTasks(query.companyId, _states(query));
    final names = await readNames(query.companyId, tasks);
    return buildTaskItemsPreview(tasks: tasks, query: query, names: names);
  }

  @override
  Future<ReportPreview> refresh(
    ReportQuery query, {
    bool Function()? isCancelled,
  }) async {
    final states = _states(query);
    final filters = taskItemsFetchFilters(
      query,
      activityDates: supportsActivityDates(),
    );
    try {
      for (var page = 1; ; page++) {
        // Before the page, not after: a cancelled run must not spend a
        // request it will throw away.
        if (isCancelled?.call() ?? false) {
          throw const ReportError(kind: ReportErrorKind.cancelled);
        }
        if (page > kTaskItemsMaxPages) {
          // A server that never says "no more" would loop for ever; one that
          // stops answering part-way would be an under-count. Either is an
          // error, never a quiet partial report. No message: the banner
          // shows a message as written, and this one would be in English.
          _log.warning('Task Items gave up after $kTaskItemsMaxPages pages');
          throw const ReportError(kind: ReportErrorKind.unknown);
        }
        final more = await fetchPage(query.companyId, page, states, filters);
        if (!more) break;
      }
    } on ReportError {
      rethrow;
    } catch (e, st) {
      throw reportErrorFrom(e, st);
    }
    if (isCancelled?.call() ?? false) {
      throw const ReportError(kind: ReportErrorKind.cancelled);
    }
    final tasks = await readTasks(query.companyId, states);
    var names = await readNames(query.companyId, tasks);
    final hydrate = hydrateNames;
    if (hydrate != null) {
      final missing = _missingNames(tasks, query, names);
      if (missing.clients.isNotEmpty || missing.projects.isNotEmpty) {
        try {
          await hydrate(query.companyId, missing.clients, missing.projects);
        } catch (e, st) {
          // The rows stand without the names; each reads `—`.
          _log.warning('Could not fetch the names Task Items needs', e, st);
        }
        if (isCancelled?.call() ?? false) {
          throw const ReportError(kind: ReportErrorKind.cancelled);
        }
        names = await readNames(query.companyId, tasks);
      }
    }
    return buildTaskItemsPreview(tasks: tasks, query: query, names: names);
  }

  /// Whether the device holds a task, passing [query]'s filters, with time
  /// both inside its range and outside it — where the Tasks report, which
  /// lists a task by its first entry with all of its time, disagrees with
  /// this one. See `ReportsViewModel.tasksCrossRange`.
  Future<bool> crossesRange(ReportQuery query) async {
    if (query.isAllTime) return false;
    final tasks = await readTasks(query.companyId, _states(query));
    return taskTimeCrossesRange(tasks, query);
  }

  /// The lifecycle states the report reads: the server's task report keeps
  /// archived tasks (`withTrashed()`) and drops deleted ones unless asked.
  static Set<EntityState> _states(ReportQuery query) => {
    EntityState.active,
    EntityState.archived,
    if (query.includeDeleted) EntityState.deleted,
  };
}

/// At most this many clients, and as many projects, are fetched for their
/// names in one refresh — one request each.
const int kTaskItemsMaxNameFetches = 200;

/// The client and project ids the rows of [tasks] name and [names] cannot
/// resolve — real ids only: one created offline has nothing to fetch.
({Set<String> clients, Set<String> projects}) _missingNames(
  Iterable<Task> tasks,
  ReportQuery query,
  TaskItemNames names,
) {
  final clients = <String>{};
  final projects = <String>{};
  final status = _StatusFilter.parse(query.status);
  final filter = _IdFilter(query, names);
  for (final task in tasks) {
    if (!_matches(task, query, status, filter)) continue;
    if (!task.timeLog.any((e) => _counts(task, e, query))) continue;
    final client = names.idOf(task.clientId);
    if (client.isNotEmpty &&
        !client.startsWith('tmp_') &&
        !names.clients.containsKey(client)) {
      clients.add(client);
    }
    final project = names.idOf(task.projectId);
    if (project.isNotEmpty &&
        !project.startsWith('tmp_') &&
        !names.projects.containsKey(project)) {
      projects.add(project);
    }
  }
  return (
    clients: clients.take(kTaskItemsMaxNameFetches).toSet(),
    projects: projects.take(kTaskItemsMaxNameFetches).toSet(),
  );
}

Iterable<List<String>> _chunks(Set<String> ids, int size) sync* {
  final list = ids.toList(growable: false);
  for (var i = 0; i < list.length; i += size) {
    yield list.sublist(i, i + size > list.length ? list.length : i + size);
  }
}

/// Whether [entry] of [task] is a row of [query]: it has a start, it is not
/// a booking, and its day is in the range.
bool _counts(Task task, TimeEntry entry, ReportQuery query) {
  if (entry.start == null) return false;
  if (isTimeEntryBooking(entry, now: query.now, dueDate: task.dueDate)) {
    return false;
  }
  final start = query.start;
  final end = query.end;
  if (start == null || end == null) return true;
  final day = timeEntryLocalDate(entry)!;
  return day.compareTo(start) >= 0 && day.compareTo(end) <= 0;
}

/// Pages a refresh may take before it gives up — `refreshAll`'s ceiling.
const int kTaskItemsMaxPages = 1000;

/// The list filters a refresh sends: the tasks with any activity in the
/// range, widened two days each way.
///
/// The server's test is loose on purpose (`TaskFilters::activity_dates`):
/// the task's first entry is on or before the range's last day, and it was
/// last touched — or is running — on or after the first. It compares a
/// company-timezone date with a UTC one, and this report buckets on the
/// device's own day, so two days of slack keep a task near midnight from
/// falling off either end; the entries themselves are tested exactly.
///
/// A server without `activity_dates` (before 5.13.43) gets every task whose
/// first entry is on or before the end — a superset, so nothing is lost, only
/// fetched. "All time" asks for every task either way.
Map<String, Set<String>> taskItemsFetchFilters(
  ReportQuery query, {
  required bool activityDates,
}) {
  final start = query.start;
  final end = query.end;
  if (start == null || end == null) return const {};
  final to = end.addDays(2).toIso();
  if (activityDates) {
    return {
      'activity_dates': {'${start.addDays(-2).toIso()},$to'},
    };
  }
  return {
    // One element: the values of a filter are joined with commas, so a
    // second element would corrupt this into a four-part value.
    'date_range': {'calculated_start_date,1970-01-01,$to'},
  };
}

/// The report's columns: the order is the default one, phone first — the
/// day and the time, then what was done and for whom. Ids reuse the server
/// task report's names, so the conventions keyed on them (a date column, a
/// duration) hold here too.
const List<String> kTaskItemsColumnIds = [
  'task.start_date',
  'task.duration',
  'task.description',
  'client.name',
  'task.project_id',
  'task.item_notes',
  'task.assigned_user_id',
  'task.start_time',
  'task.end_time',
  'task.billable',
  'task.user_id',
  'task.number',
  'task.status_id',
  'task.is_invoiced',
];

/// Each column's header (a localization key) and type.
const Map<String, (String, ReportColumnType)> _kColumns = {
  'task.start_date': ('date', ReportColumnType.date),
  'task.duration': ('duration', ReportColumnType.duration),
  // A task's description is its name.
  'task.description': ('task', ReportColumnType.string),
  'client.name': ('client', ReportColumnType.string),
  'task.project_id': ('project', ReportColumnType.string),
  // What the time entry editor calls an entry's own text.
  'task.item_notes': ('description', ReportColumnType.string),
  // Who did the work, as every task view filters it.
  'task.assigned_user_id': ('assigned_user', ReportColumnType.string),
  'task.start_time': ('start_time', ReportColumnType.dateTime),
  'task.end_time': ('end_time', ReportColumnType.dateTime),
  'task.billable': ('billable', ReportColumnType.boolean),
  'task.user_id': ('created_by_user', ReportColumnType.string),
  'task.number': ('number', ReportColumnType.string),
  'task.status_id': ('status', ReportColumnType.string),
  'task.is_invoiced': ('invoiced', ReportColumnType.boolean),
};

/// The names a task's ids resolve to. A `tmp_` id (a record created offline)
/// is first mapped to the real one it became, where it has synced.
class TaskItemNames {
  const TaskItemNames({
    this.clients = const {},
    this.projects = const {},
    this.users = const {},
    this.statuses = const {},
    this.remap = const {},
  });

  final Map<String, String> clients;
  final Map<String, String> projects;
  final Map<String, String> users;
  final Map<String, String> statuses;

  /// `tmp_` id → the real id it became.
  final Map<String, String> remap;

  String idOf(String id) => remap[id] ?? id;
}

Future<TaskItemNames> _readNames(
  String companyId,
  List<Task> tasks, {
  required ClientRepository clients,
  required ProjectRepository projects,
  required UserRepository users,
  required TaskStatusRepository taskStatuses,
  required IdRemapDao idRemap,
}) async {
  final clientIds = {
    for (final t in tasks)
      if (t.clientId.isNotEmpty) t.clientId,
  };
  final projectIds = {
    for (final t in tasks)
      if (t.projectId.isNotEmpty) t.projectId,
  };
  final remap = await idRemap.resolveAllAnyType({...clientIds, ...projectIds});
  String real(String id) => remap[id] ?? id;
  final clientRows = await clients.getByIds(
    companyId: companyId,
    ids: clientIds.map(real),
  );
  final projectRows = await projects.getByIds(
    companyId: companyId,
    ids: projectIds.map(real),
  );
  final userRows = await users.watchAllForPicker(companyId: companyId).first;
  final statusRows = await taskStatuses
      .watchAllIncludingArchived(companyId: companyId)
      .first;
  return TaskItemNames(
    clients: {for (final c in clientRows) c.id: c.displayName},
    projects: {for (final p in projectRows) p.id: p.name},
    users: {for (final u in userRows) u.id: u.displayName},
    statuses: {for (final s in statusRows) s.id: s.name},
    remap: remap,
  );
}

/// Whether one of [tasks] that passes [query]'s filters has worked time both
/// inside [query]'s range and outside it, by the same rules as the rows.
bool taskTimeCrossesRange(Iterable<Task> tasks, ReportQuery query) {
  final start = query.start;
  final end = query.end;
  if (start == null || end == null) return false;
  final status = _StatusFilter.parse(query.status);
  final filter = _IdFilter(query, const TaskItemNames());
  for (final task in tasks) {
    if (!_matches(task, query, status, filter)) continue;
    var inside = false;
    var outside = false;
    for (final entry in task.timeLog) {
      if (entry.start == null) continue;
      if (isTimeEntryBooking(entry, now: query.now, dueDate: task.dueDate)) {
        continue;
      }
      if (_counts(task, entry, query)) {
        inside = true;
      } else {
        outside = true;
      }
      if (inside && outside) return true;
    }
  }
  return false;
}

/// The report's rows from [tasks] — every time entry of every task that
/// passes [query]'s filters, whose day falls in its range, oldest first.
ReportPreview buildTaskItemsPreview({
  required Iterable<Task> tasks,
  required ReportQuery query,
  TaskItemNames names = const TaskItemNames(),
}) {
  final columns = [
    for (final id in kTaskItemsColumnIds)
      ReportColumn(
        identifier: id,
        displayLabel: query.label(_kColumns[id]!.$1),
        type: _kColumns[id]!.$2,
        timeOnly: id == 'task.start_time' || id == 'task.end_time',
      ),
  ];
  final statusFilter = _StatusFilter.parse(query.status);
  final filter = _IdFilter(query, names);
  final entries = <(Task, TimeEntry, DateTime)>[];
  for (final task in tasks) {
    if (!_matches(task, query, statusFilter, filter)) continue;
    for (final entry in task.timeLog) {
      if (!_counts(task, entry, query)) continue;
      entries.add((task, entry, entry.start!));
    }
  }
  entries.sort((a, b) {
    final byStart = a.$3.compareTo(b.$3);
    return byStart != 0 ? byStart : a.$1.id.compareTo(b.$1.id);
  });
  // A task's description is on every one of its entries: flattened once.
  final flat = <String, String>{};
  return ReportPreview(
    columns: columns,
    rows: [
      for (final (task, entry, began) in entries)
        _row(task, entry, began, query, names, flat),
    ],
  );
}

ReportRow _row(
  Task task,
  TimeEntry entry,
  DateTime began,
  ReportQuery query,
  TaskItemNames names,
  Map<String, String> flattened,
) {
  final day = timeEntryLocalDate(entry)!;
  final seconds = entry.durationUpTo(query.now).inSeconds;
  final stop = entry.stop;
  final clientId = names.idOf(task.clientId);
  final projectId = names.idOf(task.projectId);
  ReportStringCell text(String value, {String? wire, String? id}) =>
      ReportStringCell(
        value: value,
        displayValue: value,
        entityWire: wire,
        // A record that has not reached the server is not a place to go.
        entityId: id == null || id.isEmpty || id.startsWith('tmp_') ? null : id,
      );
  // The two notes-shaped fields are flattened here, as the server's string
  // cells are when they are read in: the table, the search, the sort, a
  // group key and the chart all read this one string.
  String flat(String notes) => flattened.putIfAbsent(
    notes,
    () => plainTextFromHtml(notes, singleLine: true),
  );

  String name(Map<String, String> map, String id) =>
      id.isEmpty ? '' : (map[id] ?? '—');
  final cells = <String, ReportCell>{
    'task.start_date': ReportDateCell(value: day, displayValue: day.toIso()),
    'task.duration': ReportDurationCell(
      seconds: seconds,
      displayValue: hoursMinutesText(seconds),
    ),
    'task.description': text(flat(task.description)),
    'client.name': text(
      name(names.clients, clientId),
      wire: 'client',
      id: clientId,
    ),
    'task.project_id': text(
      name(names.projects, projectId),
      wire: 'project',
      id: projectId,
    ),
    'task.item_notes': text(flat(entry.description)),
    'task.assigned_user_id': text(name(names.users, task.assignedUserId)),
    // UTC, as the formatter expects a timestamp; it shows local time.
    'task.start_time': ReportDateTimeCell(
      value: began.toUtc(),
      displayValue: _clock(began),
    ),
    'task.end_time': stop == null
        ? ReportDateTimeCell(displayValue: query.label('running'))
        : ReportDateTimeCell(value: stop.toUtc(), displayValue: _clock(stop)),
    'task.billable': ReportBoolCell(
      value: entry.billable,
      displayValue: query.label(entry.billable ? 'yes' : 'no'),
    ),
    'task.user_id': text(name(names.users, task.userId)),
    'task.number': text(task.number),
    'task.status_id': text(name(names.statuses, task.statusId)),
    'task.is_invoiced': ReportBoolCell(
      value: task.invoiceId.isNotEmpty,
      displayValue: query.label(task.invoiceId.isNotEmpty ? 'yes' : 'no'),
    ),
  };
  return ReportRow(
    cells: [for (final id in kTaskItemsColumnIds) cells[id]!],
    recordWire: task.id.startsWith('tmp_') ? null : 'task',
    recordId: task.id.startsWith('tmp_') ? null : task.id,
  );
}

/// `09:30` in local time — what the row search matches a time against.
String _clock(DateTime t) {
  final local = t.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}

bool _matches(
  Task task,
  ReportQuery query,
  _StatusFilter status,
  _IdFilter ids,
) {
  if (task.isDeleted && !query.includeDeleted) return false;
  if (!ids.client(task.clientId) || !ids.project(task.projectId)) {
    return false;
  }
  if (query.tagIds.isNotEmpty && !task.tagIds.any(query.tagIds.contains)) {
    return false;
  }
  return status.matches(task);
}

/// The client and project filters, compared on real ids: a record created
/// offline is named by its `tmp_` id on one side until it syncs, and by its
/// real one on the other after.
class _IdFilter {
  _IdFilter(ReportQuery query, this.names)
    : clients = {for (final id in query.clientIds) names.idOf(id)},
      projects = {for (final id in query.projectIds) names.idOf(id)};

  final TaskItemNames names;
  final Set<String> clients;
  final Set<String> projects;

  bool client(String id) => clients.isEmpty || clients.contains(names.idOf(id));
  bool project(String id) =>
      projects.isEmpty || projects.contains(names.idOf(id));
}

/// The Status filter as `TaskExport::addTaskStatusFilter` reads it: each
/// condition named must hold — `invoiced`, `uninvoiced`, a set of status ids.
class _StatusFilter {
  const _StatusFilter({
    this.invoiced = false,
    this.uninvoiced = false,
    this.statusIds = const {},
  });

  factory _StatusFilter.parse(String raw) {
    final parts = {
      for (final p in raw.split(','))
        if (p.trim().isNotEmpty) p.trim(),
    };
    if (parts.isEmpty || parts.contains('all')) return const _StatusFilter();
    return _StatusFilter(
      invoiced: parts.contains('invoiced'),
      uninvoiced: parts.contains('uninvoiced'),
      statusIds: parts.difference({'invoiced', 'uninvoiced'}),
    );
  }

  final bool invoiced;
  final bool uninvoiced;
  final Set<String> statusIds;

  bool matches(Task task) {
    if (invoiced && task.invoiceId.isEmpty) return false;
    if (uninvoiced && task.invoiceId.isNotEmpty) return false;
    if (statusIds.isNotEmpty && !statusIds.contains(task.statusId)) {
      return false;
    }
    return true;
  }
}
