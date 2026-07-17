import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/task_status_api_model.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/data/services/task_statuses_api.dart';
import 'package:admin/ui/features/tasks/task_filter_keys.dart';

/// `StatusFilterKey.displayValueFor` must resolve a task-status id to its
/// name so the filter chip reads "Status: Backlog" instead of the raw hashid
/// (the reported bug). Names come from the same `watchAll` stream that backs
/// the suggestion dropdown, with a graceful fallback to the id until the
/// stream has emitted.
class _NoopApi implements TaskStatusesApi {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call: ${invocation.memberName}');
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<TaskStatusRepository> seeded() async {
    final repo = TaskStatusRepository(db: db, api: _NoopApi());
    await repo.applyBundle(
      companyId: 'co',
      bundle: [
        TaskStatusApi(id: 's1', name: 'Backlog', statusOrder: 1, updatedAt: 1),
        TaskStatusApi(id: 's2', name: 'Ready', statusOrder: 2, updatedAt: 2),
      ],
    );
    return repo;
  }

  // Give the names-cache subscription a few turns to drain its first event.
  Future<void> pump() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('id and serverKey are stable wire contracts', () async {
    final key = StatusFilterKey(statuses: await seeded(), companyId: 'co');
    expect(key.id, 'status');
    expect(key.serverKey, 'task_status');
    key.dispose();
  });

  test('displayValueFor resolves a status id to its name', () async {
    final key = StatusFilterKey(statuses: await seeded(), companyId: 'co');
    await pump();
    expect(key.displayValueFor('s1'), 'Backlog');
    expect(key.displayValueFor('s2'), 'Ready');
    key.dispose();
  });

  test(
    'displayValueFor falls back to the raw id for an unknown status',
    () async {
      final key = StatusFilterKey(statuses: await seeded(), companyId: 'co');
      await pump();
      expect(key.displayValueFor('not-a-status'), 'not-a-status');
      key.dispose();
    },
  );
}
