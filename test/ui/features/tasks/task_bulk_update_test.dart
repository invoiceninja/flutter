import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/tasks_api.dart';
import 'package:admin/ui/features/bulk_update/bulk_update_dialog.dart';
import 'package:admin/ui/features/tasks/view_models/task_list_view_model.dart';

class _UnusedTasksApi implements TasksApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  // The ids are taken before the dialog opens; a row can leave the loaded
  // window while it is up. It is read back from Drift and written — not
  // skipped and still counted as updated.
  test('a selected row no longer loaded is read back, not dropped', () async {
    final repo = TaskRepository(db: db, api: _UnusedTasksApi());
    await repo.bulkUpdate(
      companyId: 'co',
      task: Task.fromApi(const TaskApi(id: 't1', clientId: 'c0')),
      column: 'status_id',
      newValue: 's1',
    );
    await db.outboxDao.deletePendingForCompany('co');

    final vm = TaskListViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
    );
    addTearDown(vm.dispose);
    expect(vm.items, isEmpty, reason: 'nothing loaded into the list');

    final result = await vm.applyBulkAction(
      vm.bulkActionById('bulk_update')!,
      ids: {'t1'},
      arg: const BulkUpdate(column: 'status_id', newValue: 's9'),
    );

    expect(result.ok, 1);
    final rows = await db.outboxDao.pendingRowsForCompany('co');
    expect(
      [for (final r in rows) jsonDecode(r.payload)],
      [
        {'id': 't1', 'column': 'status_id', 'new_value': 's9'},
      ],
    );
  });
}
