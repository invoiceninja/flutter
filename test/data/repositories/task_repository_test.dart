import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/services/tasks_api.dart';

/// Task-specific repository behavior the base contract doesn't probe:
/// the kanban invoiced-exclusion (B6) and the bulk `startTimer` op (B7).
void main() {
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  Task task({
    String statusId = 's1',
    String invoiceId = '',
    String projectId = '',
    List<String> tagIds = const <String>[],
    List<TimeEntry> timeLog = const <TimeEntry>[],
  }) => Task(
    id: '',
    number: '',
    description: '',
    rate: Decimal.zero,
    invoiceId: invoiceId,
    clientId: '',
    projectId: projectId,
    tagIds: tagIds,
    statusId: statusId,
    statusOrder: 0,
    assignedUserId: '',
    timeLog: timeLog,
    customValue1: '',
    customValue2: '',
    customValue3: '',
    customValue4: '',
    updatedAt: epoch,
    createdAt: epoch,
    archivedAt: null,
    isDeleted: false,
  );

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  TaskRepository makeRepo() => TaskRepository(db: db, api: _FakeTasksApi());

  test(
    'watchAllByStatus excludes invoiced tasks from the kanban (B6)',
    () async {
      final repo = makeRepo();
      await repo.create(
        companyId: 'co',
        draft: task(statusId: 's1'),
      );
      await repo.create(
        companyId: 'co',
        draft: task(statusId: 's1', invoiceId: 'inv_1'),
      );

      final byStatus = await repo.watchAllByStatus(companyId: 'co').first;
      expect(byStatus['s1'], hasLength(1));
      expect(byStatus['s1']!.single.isInvoiced, isFalse);
    },
  );

  test('startTimer appends a running entry (B7 bulk start)', () async {
    final repo = makeRepo();
    final created = await repo.create(companyId: 'co', draft: task());
    final id = created.entity.id;

    await repo.startTimer(companyId: 'co', taskId: id);

    final after = await repo.watchByRealId(companyId: 'co', id: id).first;
    expect(after, isNotNull);
    expect(after!.timeLog, hasLength(1));
    expect(after.isRunning, isTrue);
  });

  test(
    'startTimer carries description but NOT billable from the last entry',
    () async {
      final repo = makeRepo();
      final created = await repo.create(
        companyId: 'co',
        draft: task(
          timeLog: [
            // Real (non-zero) timestamps: unix second 0 is the "no time"
            // sentinel and would round-trip to a null start and be dropped.
            // Last entry is NON-billable to prove billable is not inherited.
            TimeEntry(
              start: DateTime.utc(2026, 1, 1, 9),
              stop: DateTime.utc(2026, 1, 1, 10),
              description: 'Design work',
              billable: false,
            ),
          ],
        ),
      );
      final id = created.entity.id;

      await repo.startTimer(companyId: 'co', taskId: id);

      final after = await repo.watchByRealId(companyId: 'co', id: id).first;
      expect(after!.timeLog, hasLength(2));
      final running = after.timeLog.last;
      expect(running.isRunning, isTrue);
      expect(running.description, 'Design work', reason: 'description carries');
      expect(running.billable, isTrue, reason: 'a new timer starts billable');
    },
  );

  test('watchRunningCount + stopAllRunning cover concurrent timers', () async {
    final repo = makeRepo();
    final a = await repo.create(companyId: 'co', draft: task());
    final b = await repo.create(companyId: 'co', draft: task());
    await repo.startTimer(companyId: 'co', taskId: a.entity.id);
    await repo.startTimer(companyId: 'co', taskId: b.entity.id);

    expect(await repo.watchRunningCount(companyId: 'co').first, 2);

    await repo.stopAllRunning(companyId: 'co');
    expect(await repo.watchRunningCount(companyId: 'co').first, 0);
  });

  test('startTimer is a no-op on a soft-deleted task', () async {
    final repo = makeRepo();
    final created = await repo.create(
      companyId: 'co',
      draft: task(
        timeLog: [
          TimeEntry(
            start: DateTime.utc(2026, 1, 1, 9),
            stop: DateTime.utc(2026, 1, 1, 10),
          ),
        ],
      ),
    );
    final id = created.entity.id;
    // Soft-delete through the real flow: `markDeletedDirty` flips the
    // is_deleted column, and `_fromRow` overlays it so the domain isDeleted
    // (which startTimer guards on) reflects it immediately.
    await repo.delete(companyId: 'co', id: id);

    await repo.startTimer(companyId: 'co', taskId: id);

    // The guard blocked appending a running entry: still the single stopped
    // one, and not running. (`watchByRealId` maps through `_fromRow` and does
    // not filter deleted rows, so it still surfaces the soft-deleted task.)
    final after = await repo.watchByRealId(companyId: 'co', id: id).first;
    expect(after, isNotNull);
    expect(after!.isRunning, isFalse);
    expect(after.timeLog, hasLength(1));
  });

  group('watchPage extraFilters mirrors (H1)', () {
    test('task_status narrows locally and hides invoiced rows', () async {
      final repo = makeRepo();
      await repo.create(
        companyId: 'co',
        draft: task(statusId: 's1'),
      );
      await repo.create(
        companyId: 'co',
        draft: task(statusId: 's2'),
      );
      // Matches the status but is invoiced — the server pairs task_status
      // with whereNull(invoice_id), so the local mirror must exclude it.
      await repo.create(
        companyId: 'co',
        draft: task(statusId: 's1', invoiceId: 'inv_1'),
      );

      final rows = await repo
          .watchPage(
            companyId: 'co',
            extraFilters: const {
              'task_status': {'s1'},
            },
          )
          .first;
      expect(rows, hasLength(1));
      expect(rows.single.statusId, 's1');
      expect(rows.single.isInvoiced, isFalse);
    });

    test('project_tasks narrows locally', () async {
      final repo = makeRepo();
      await repo.create(
        companyId: 'co',
        draft: task(projectId: 'p1'),
      );
      await repo.create(
        companyId: 'co',
        draft: task(projectId: 'p2'),
      );

      final rows = await repo
          .watchPage(
            companyId: 'co',
            extraFilters: const {
              'project_tasks': {'p1'},
            },
          )
          .first;
      expect(rows, hasLength(1));
      expect(rows.single.projectId, 'p1');
    });

    test('save/create stamp the denormalized tag_names sort key from the '
        'local tag cache (offline rows are dirty — the server echo cannot '
        'refresh it, so sort-by-tags would go stale)', () async {
      final repo = makeRepo();
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 't1',
              companyId: 'co',
              entityType: const Value('task'),
              name: const Value('Design'),
              updatedAt: 0,
              payload: '{}',
            ),
          );

      final created = await repo.create(
        companyId: 'co',
        draft: task(tagIds: const ['t1']),
      );
      var row = await db.taskDao.getByIds(
        companyId: 'co',
        ids: [created.entity.id],
      );
      expect(row.single.tagNames, 'design');

      await repo.save(
        companyId: 'co',
        task: created.entity.copyWith(tagIds: const []),
      );
      row = await db.taskDao.getByIds(
        companyId: 'co',
        ids: [created.entity.id],
      );
      expect(row.single.tagNames, '', reason: 'tag removal clears the key');
    });

    test('tag_ids narrows post-decode with OR membership', () async {
      final repo = makeRepo();
      await repo.create(
        companyId: 'co',
        draft: task(tagIds: const ['t1', 't2']),
      );
      await repo.create(
        companyId: 'co',
        draft: task(tagIds: const ['t3']),
      );
      await repo.create(companyId: 'co', draft: task());

      final rows = await repo
          .watchPage(
            companyId: 'co',
            extraFilters: const {
              'tag_ids': {'t1', 't3'},
            },
          )
          .first;
      // OR semantics: any selected tag matches (server whereIn parity).
      expect(rows, hasLength(2));
      expect(rows.every((t) => t.tagIds.isNotEmpty), isTrue);
    });
  });

  test('startTimer is a no-op on an invoiced task', () async {
    final repo = makeRepo();
    final created = await repo.create(
      companyId: 'co',
      draft: task(invoiceId: 'inv_1'),
    );

    await repo.startTimer(companyId: 'co', taskId: created.entity.id);

    final after = await repo
        .watchByRealId(companyId: 'co', id: created.entity.id)
        .first;
    expect(after!.isRunning, isFalse);
    expect(after.timeLog, isEmpty);
  });
}

/// The repo paths under test never hit the network, so a throwing stub is
/// sufficient (mirrors `_FakeProductsApi`).
class _FakeTasksApi implements TasksApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
