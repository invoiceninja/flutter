import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/task_api_model.dart';
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

    /// The quiet half of the `tmp_` tag bug: a tag whose inline create drained
    /// while the task form was open has had its tmp row deleted, so the draft's
    /// id names nothing. `resolveTagNames` did `byId[id] ?? ''` and
    /// `joinTagNames` drops empties, so the row's `tag_names` sort key silently
    /// lost that tag — and the stored payload kept a token only the sync drain
    /// could rescue.
    test('create canonicalizes a tmp tag id whose create already round-tripped '
        '(tag_names and the stored ids both follow the remap)', () async {
      final repo = makeRepo();
      // The post-drain state: real tag row present, tmp row gone, alias written.
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'real9',
              companyId: 'co',
              entityType: const Value('task'),
              name: const Value('Design'),
              updatedAt: 0,
              payload: '{}',
            ),
          );
      await db.idRemapDao.remember(
        entityType: 'tag',
        tempId: 'tmp_1f3c',
        realId: 'real9',
        now: 0,
      );

      final created = await repo.create(
        companyId: 'co',
        draft: task(tagIds: const ['tmp_1f3c']),
      );

      final row = await db.taskDao.getByIds(
        companyId: 'co',
        ids: [created.entity.id],
      );
      expect(row.single.tagNames, 'design', reason: 'sort key keeps the tag');
      expect(
        created.entity.tagIds,
        ['real9'],
        reason: 'the stored id follows the remap, not just the sort key',
      );
    });

    test(
      'canonicalizing collapses a draft holding both the tmp and real id',
      () async {
        // Reachable on rows saved before this shipped: the picker filtered its
        // pool by raw id, so after the swap it re-offered the just-created tag
        // under its real id and appended a second entry for the same tag.
        final repo = makeRepo();
        await db.idRemapDao.remember(
          entityType: 'tag',
          tempId: 'tmp_1f3c',
          realId: 'real9',
          now: 0,
        );

        final created = await repo.create(
          companyId: 'co',
          draft: task(tagIds: const ['tmp_1f3c', 'real9']),
        );

        expect(created.entity.tagIds, ['real9']);
      },
    );

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

  // TaskRepository isn't registered on the shared contract (see
  // `_base_entity_repository_contract.dart`), so the timestamp-survival check
  // every other entity gets from there lives here instead.
  test('a locally-edited task keeps its server timestamps and creator', () async {
    final repo = makeRepo();
    const seconds = 1700000000;
    final seeded = Task.fromApi(
      const TaskApi(
        id: 't_1',
        userId: 'u_9',
        updatedAt: seconds,
        createdAt: seconds,
      ),
    );
    await repo.save(companyId: 'co', task: seeded);

    // `toApiJson` (rightly) omits `created_at` / `updated_at`, and the same map
    // is written into the Drift `payload` column — so a `_fromRow` that decodes
    // the payload without overlaying the columns reports epoch 0, which the
    // list paints as 1 Jan 1970. `user_id` has no column at all, which is why
    // `Task.toApiJson` emits it.
    final after = await repo.watchByRealId(companyId: 'co', id: 't_1').first;
    expect(after, isNotNull);
    expect(after!.updatedAt.millisecondsSinceEpoch ~/ 1000, seconds);
    expect(after.createdAt.millisecondsSinceEpoch ~/ 1000, seconds);
    expect(after.userId, 'u_9', reason: 'the created-by column needs this');
  });
}

/// The repo paths under test never hit the network, so a throwing stub is
/// sufficient (mirrors `_FakeProductsApi`).
class _FakeTasksApi implements TasksApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
