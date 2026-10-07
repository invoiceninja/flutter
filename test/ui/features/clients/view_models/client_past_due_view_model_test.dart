import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/ui/features/clients/view_models/client_past_due_view_model.dart';

/// When the past-due view model asks the server, and when it does not.
///
/// A real database, so real time — but every *positive* expectation polls for
/// its condition ([until]) rather than sleeping a fixed while and hoping. The
/// only fixed waits are in front of "nothing was asked", which cannot be
/// polled for and can only ever pass early, never fail late.
class _Api implements InvoicesApi {
  List<InvoiceApi> rows = const [];
  bool fail = false;
  int calls = 0;

  /// When set, each request waits here before answering.
  Completer<void>? gate;

  @override
  Future<({InvoiceListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    calls++;
    final answer = rows;
    await gate?.future;
    if (fail) throw const NetworkException('offline');
    return (
      data: InvoiceListApi(data: answer),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected API call: ${invocation.memberName}');
}

Client _client(String balance, {String id = 'c1', int updatedAt = 1}) =>
    Client.fromApi(
      ClientApi(id: id, name: 'Acme', balance: balance, updatedAt: updatedAt),
    );

InvoiceApi _inv(String id, String balance, String due) => InvoiceApi(
  id: id,
  clientId: 'c1',
  statusId: '2',
  amount: balance,
  balance: balance,
  dueDate: due,
  updatedAt: 1700000000,
);

const _today = Date(2026, 6, 15);

/// Long enough for a debounced fetch that *was* going to happen to have gone.
const _quiet = Duration(milliseconds: 120);

Future<void> until(bool Function() done, String what) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting for $what');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late AppDatabase db;
  late _Api api;
  late ClientPastDueViewModel vm;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    // Open it now, so the first query's migrations are not part of any wait.
    await db.customSelect('SELECT 1').get();
    api = _Api();
    vm = ClientPastDueViewModel(
      invoices: InvoiceRepository(
        db: db,
        api: api,
        settings: SettingsRepository(db: db),
      ),
      companyId: 'co',
      clientId: 'c1',
      debounce: const Duration(milliseconds: 5),
    );
  });
  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  Future<void> known(Client client) =>
      until(() => vm.valueFor(client, today: _today) != null, 'a figure');

  test('a client that owes nothing is never asked about', () async {
    vm.kick(_client('0'), enabled: true);
    await Future<void>.delayed(_quiet);
    expect(api.calls, 0);
    expect(vm.valueFor(_client('0'), today: _today), isNull);
  });

  test('nor one with the invoices module off, nor an unsynced one', () async {
    vm.kick(_client('100'), enabled: false);
    vm.kick(_client('100', id: 'tmp_1'), enabled: true);
    await Future<void>.delayed(_quiet);
    expect(api.calls, 0);
  });

  test('kicked every build, it asks once per state of the record', () async {
    api.rows = [_inv('a', '100', '2026-06-01')];
    final client = _client('100');
    for (var i = 0; i < 5; i++) {
      vm.kick(client, enabled: true);
    }
    await known(client);
    expect(api.calls, 1);
    expect(vm.valueFor(client, today: _today)!.count, 1);

    vm.kick(client, enabled: true);
    await Future<void>.delayed(_quiet);
    expect(api.calls, 1);
  });

  test('a balance that moved is asked about again, and nothing is claimed '
      'in between', () async {
    api.rows = [_inv('a', '100', '2026-06-01')];
    vm.kick(_client('100'), enabled: true);
    await known(_client('100'));

    // The record re-check brought a new balance: a second invoice exists that
    // this device has not seen yet.
    final moved = _client('250', updatedAt: 2);
    api.rows = [_inv('a', '100', '2026-06-01'), _inv('b', '150', '2026-07-01')];
    vm.kick(moved, enabled: true);
    expect(vm.valueFor(moved, today: _today), isNull);
    await known(moved);
    expect(api.calls, 2);
    final after = vm.valueFor(moved, today: _today)!;
    expect(after.count, 1);
    expect('${after.amount}', '100');
  });

  test('the same balance on a newer record is asked about again', () async {
    // One invoice paid, another raised for the same amount: the balance did
    // not move, the invoices did. Keyed on the balance alone this was never
    // re-asked, and a stale local row still summed correctly.
    api.rows = [_inv('a', '100', '2026-06-01')];
    vm.kick(_client('100'), enabled: true);
    await until(() => api.calls == 1, 'the first ask');

    vm.kick(_client('100', updatedAt: 2), enabled: true);
    await until(() => api.calls == 2, 'the second ask');
  });

  test('an answer about the record as it was is not an answer about it '
      'as it is', () async {
    // The first request is still out when the record moves. Its answer says
    // "complete" — about a record that no longer exists in that form — and
    // the rows it brought sum to the balance, so taken at face value it would
    // put a figure on screen that nothing has checked.
    final slow = ClientPastDueViewModel(
      invoices: vm.invoices,
      companyId: 'co',
      clientId: 'c1',
      // Long, so the re-ask the move schedules cannot run inside this test:
      // every step below is awaited, none is raced.
      debounce: const Duration(minutes: 1),
    );
    addTearDown(slow.dispose);
    api.rows = [_inv('a', '100', '2026-06-01')];
    final gate = api.gate = Completer<void>();

    slow.kick(_client('100'), enabled: true);
    final firstAsk = slow.refresh();
    await until(() => api.calls == 1, 'the first ask');

    final moved = _client('100', updatedAt: 2);
    slow.kick(moved, enabled: true);
    gate.complete();
    await firstAsk;
    // Let the rows it brought reach the view model, so the only thing between
    // them and a figure is whether that answer was believed.
    await until(
      () => slow.hasArchivedPastDue(today: _today) == false && api.calls == 1,
      'the first answer',
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(slow.valueFor(moved, today: _today), isNull);

    api.gate = null;
    await slow.refresh();
    await until(
      () => slow.valueFor(moved, today: _today) != null,
      'a figure for the record as it is',
    );
  });

  test('a refresh asks again', () async {
    api.rows = [_inv('a', '100', '2026-06-01')];
    vm.kick(_client('100'), enabled: true);
    await known(_client('100'));
    await vm.refresh();
    expect(api.calls, 2);
  });

  test('a refresh before anything was ever asked stays quiet', () async {
    await vm.refresh();
    expect(api.calls, 0);
  });

  group('back online', () {
    test('an ask that got no answer is made again', () async {
      api.fail = true;
      final client = _client('100');
      vm.kick(client, enabled: true);
      await until(() => api.calls == 1, 'the failed ask');
      // Kicked again by every rebuild, and still not re-asked: the record has
      // not moved. This is the latch a reconnect has to clear.
      vm.kick(client, enabled: true);
      await Future<void>.delayed(_quiet);
      expect(api.calls, 1);

      api
        ..fail = false
        ..rows = [_inv('a', '100', '2026-06-01')];
      vm.retryIfUnanswered();
      await known(client);
      expect(api.calls, 2);
    });

    test('one that was answered is left alone', () async {
      api.rows = [_inv('a', '100', '2026-06-01')];
      vm.kick(_client('100'), enabled: true);
      await known(_client('100'));
      vm.retryIfUnanswered();
      await Future<void>.delayed(_quiet);
      expect(api.calls, 1);
    });
  });

  test('says when a counted invoice is archived', () async {
    api.rows = [
      InvoiceApi(
        id: 'a',
        clientId: 'c1',
        statusId: '2',
        amount: '100',
        balance: '100',
        dueDate: '2026-06-01',
        archivedAt: 1700000000,
        updatedAt: 1700000000,
      ),
    ];
    vm.kick(_client('100'), enabled: true);
    await known(_client('100'));
    expect(vm.valueFor(_client('100'), today: _today)!.count, 1);
    expect(vm.hasArchivedPastDue(today: _today), isTrue);
  });
}
