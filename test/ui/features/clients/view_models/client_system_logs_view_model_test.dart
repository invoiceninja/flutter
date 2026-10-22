import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/system_log_api_model.dart';
import 'package:admin/data/repositories/system_log_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/system_logs_api.dart';
import 'package:admin/ui/features/clients/view_models/client_system_logs_view_model.dart';

class _FakeApi implements SystemLogsApi {
  _FakeApi(this._scripted);

  final List<Object> _scripted;
  int calls = 0;
  String? lastClientId;

  @override
  Future<SystemLogListApi> fetchPage({
    int perPage = 200,
    String sort = 'created_at|DESC',
    String? clientId,
    int? typeId,
  }) async {
    calls++;
    lastClientId = clientId;
    if (_scripted.isEmpty) throw StateError('no scripted response');
    final next = _scripted.removeAt(0);
    if (next is SystemLogListApi) return next;
    throw next;
  }
}

SystemLogApi _row(String id, {int createdAt = 1778830000}) => SystemLogApi(
  id: id,
  companyId: 'c1',
  userId: 'u1',
  clientId: 'cli_1',
  eventId: 30,
  categoryId: 2,
  typeId: 303,
  log: '"hello"',
  createdAt: createdAt,
  updatedAt: createdAt,
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  ClientSystemLogsViewModel vmWith(
    List<Object> scripted, {
    String client = 'cli_1',
  }) {
    final repo = SystemLogRepository(db: db, api: _FakeApi(scripted));
    return ClientSystemLogsViewModel(repo: repo, clientId: client);
  }

  test('ensureLoaded fetches this client\'s logs', () async {
    final api = _FakeApi([
      SystemLogListApi(
        data: [_row('a', createdAt: 2000), _row('b', createdAt: 1000)],
      ),
    ]);
    final repo = SystemLogRepository(db: db, api: api);
    final vm = ClientSystemLogsViewModel(repo: repo, clientId: 'cli_1');

    await vm.ensureLoaded();

    expect(vm.result, SystemLogRefreshResult.ok);
    expect(vm.logs.map((l) => l.id).toList(), ['a', 'b']);
    expect(vm.isLoading, isFalse);
    expect(api.lastClientId, 'cli_1');
  });

  test('forbidden surfaces forbidden result + empty logs', () async {
    final vm = vmWith([const ServerException(403, 'no')]);
    await vm.ensureLoaded();
    expect(vm.result, SystemLogRefreshResult.forbidden);
    expect(vm.logs, isEmpty);
  });

  test('network error surfaces networkError', () async {
    final vm = vmWith([const NetworkException('offline')]);
    await vm.ensureLoaded();
    expect(vm.result, SystemLogRefreshResult.networkError);
    expect(vm.logs, isEmpty);
  });

  test('ensureLoaded is idempotent', () async {
    final api = _FakeApi([
      SystemLogListApi(data: [_row('a')]),
    ]);
    final repo = SystemLogRepository(db: db, api: api);
    final vm = ClientSystemLogsViewModel(repo: repo, clientId: 'cli_1');

    await vm.ensureLoaded();
    await vm.ensureLoaded();

    expect(api.calls, 1);
  });
}
