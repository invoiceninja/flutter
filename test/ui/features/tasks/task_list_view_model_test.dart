import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/task_api_model.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/tasks_api.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/ui/features/tasks/view_models/task_list_view_model.dart';

/// The Upcoming tab tops the local cache up itself (invoiceninja/flutter#149).
///
/// Its predicate reads the payload, so the tab has no server mapping and the
/// auto-chain would otherwise page the whole task list hunting for future
/// blocks — the #119 shape. The first cut of this hydration gated on the
/// `extraFilters` handed to `fetchPage`, which `_serverExtraFilters()` strips
/// `badge_mode` from by design, so it **never ran** and nothing noticed. This
/// is the mirror of `client_list_view_model_test.dart`'s hydration group, which
/// is what would have caught it.
void main() {
  late AppDatabase db;
  late _FakeTasksApi api;
  late TaskRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _FakeTasksApi();
    repo = TaskRepository(db: db, api: api);
  });
  tearDown(() => db.close());

  TaskListViewModel vmFor() => TaskListViewModel(
    repo: repo,
    navStateDao: db.navStateDao,
    userSettings: UserSettingsRepository(db: db),
    companyId: 'co',
    searchDebounce: const Duration(milliseconds: 1),
    persistDebounce: const Duration(milliseconds: 1),
  );

  Future<void> settle() async {
    for (var i = 0; i < 6; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Calls carrying the dated top-up filter, as opposed to the ordinary list
  /// page every load makes.
  Iterable<Map<String, String>> hydrationCalls() =>
      api.calls.where((c) => c.containsKey('date_range'));

  test('no tab, no hydration', () async {
    final vm = vmFor();
    await settle();
    expect(hydrationCalls(), isEmpty);
    expect(api.calls, isNotEmpty, reason: 'the ordinary page still loads');
    vm.dispose();
  });

  test('selecting Upcoming pulls the dated slice', () async {
    final vm = vmFor();
    await settle();

    await vm.setBadgeMode(kBadgeModeUpcoming);
    await settle();

    expect(hydrationCalls(), isNotEmpty);
    final filter = hydrationCalls().first['date_range']!;
    expect(
      filter.startsWith('calculated_start_date,'),
      isTrue,
      reason: 'the server filter the Tasks calendar already proves',
    );
    expect(
      filter.split(',').length,
      3,
      reason:
          'ensurePageLoadedTemplate joins a filter\'s values with a comma, so a '
          'second element would corrupt this 3-part value into a 4-part one',
    );
    vm.dispose();
  });

  test('it is latched — selecting the tab twice fetches once', () async {
    final vm = vmFor();
    await settle();
    await vm.setBadgeMode(kBadgeModeUpcoming);
    await settle();
    final first = hydrationCalls().length;

    await vm.setBadgeMode(null);
    await settle();
    await vm.setBadgeMode(kBadgeModeUpcoming);
    await settle();

    expect(hydrationCalls(), hasLength(first));
    vm.dispose();
  });

  test('pull-to-refresh re-arms it', () async {
    // `repo.refreshAll` sweeps by the delta cursor, which is `updated_at`
    // ordered — a job booked on another device for next month is not in that
    // window, so the latch would block the one fetch that finds it.
    final vm = vmFor();
    await settle();
    await vm.setBadgeMode(kBadgeModeUpcoming);
    await settle();
    final before = hydrationCalls().length;

    await vm.refreshAll();
    await settle();

    expect(hydrationCalls().length, greaterThan(before));
    vm.dispose();
  });

  test('a failure is silent and re-armable — the list still loads', () async {
    final vm = vmFor();
    await settle();
    api.failNext = true;

    await vm.setBadgeMode(kBadgeModeUpcoming);
    await settle();

    expect(
      vm.initialError,
      isNull,
      reason:
          'a best-effort top-up must not '
          'break the list the user actually asked for',
    );
    vm.dispose();
  });
}

class _FakeTasksApi implements TasksApi {
  final List<Map<String, String>> calls = [];
  bool failNext = false;

  @override
  Future<({TaskListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls.add(Map<String, String>.from(filters));
    if (failNext) {
      failNext = false;
      throw Exception('boom');
    }
    return (
      data: const TaskListApi(data: <TaskApi>[]),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
