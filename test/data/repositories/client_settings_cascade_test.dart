import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/group_setting_api_model.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/client_settings_cascade.dart';
import 'package:admin/data/repositories/group_setting_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/group_settings_api.dart';

/// The client→group→company currency cascade the server applies in
/// `Client::getSetting()`. The app used to stop after the client's own
/// override, so a client inheriting from a group billed in the COMPANY
/// currency — wrong symbol, separators and precision vs the PDF.
void main() {
  late AppDatabase db;
  late ClientRepository clients;
  late GroupSettingRepository groups;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clients = ClientRepository(db: db, api: _FakeClientsApi());
    groups = GroupSettingRepository(db: db, api: _FakeGroupSettingsApi());
  });
  tearDown(() async => db.close());

  Future<void> seedGroup({required String id, String? currencyId}) =>
      groups.applyBundle(
        companyId: 'co',
        bundle: [
          GroupSettingApi(
            id: id,
            name: 'Group $id',
            settings: currencyId == null
                ? const {}
                : {'currency_id': currencyId},
          ),
        ],
      );

  Future<void> seedClient({
    required String id,
    String? currencyId,
    String groupId = '',
  }) => clients.applyCreateResponse(
    companyId: 'co',
    tempId: id,
    serverResponse: ClientApi(
      id: id,
      name: 'Acme',
      groupSettingsId: groupId,
      settings: currencyId == null ? null : {'currency_id': currencyId},
    ),
  );

  /// Bounded drain of pending microtasks/events — `pumpEventQueue()` does not
  /// return here (a live Drift watch keeps the queue non-empty), and an
  /// unbounded wait just trips the 30 s test timeout.
  Future<void> settle() async {
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<String> resolve(String clientId) => watchEffectiveClientCurrency(
    clients: clients,
    groups: groups,
    companyId: 'co',
    clientId: clientId,
  ).first;

  test('the client own override wins over its group', () async {
    await seedGroup(id: 'g1', currencyId: '3');
    await seedClient(id: 'c1', currencyId: '1', groupId: 'g1');
    expect(await resolve('c1'), '1');
  });

  test('falls through to the GROUP when the client has no override', () async {
    await seedGroup(id: 'g1', currencyId: '3');
    await seedClient(id: 'c1', groupId: 'g1');
    expect(
      await resolve('c1'),
      '3',
      reason:
          'server Client::getSetting() checks group_settings before company',
    );
  });

  test('empty (→ company default) when neither tier sets one', () async {
    await seedGroup(id: 'g1');
    await seedClient(id: 'c1', groupId: 'g1');
    expect(await resolve('c1'), '');
  });

  test('empty when the client has no group at all', () async {
    await seedClient(id: 'c1');
    expect(await resolve('c1'), '');
  });

  test(
    'keeps reacting after the first resolution — a later change to the '
    'client re-emits (asyncExpand would have paused the client stream)',
    () async {
      await seedGroup(id: 'g1', currencyId: '3');
      await seedClient(id: 'c1', groupId: 'g1');

      final seen = <String>[];
      final sub = watchEffectiveClientCurrency(
        clients: clients,
        groups: groups,
        companyId: 'co',
        clientId: 'c1',
      ).listen(seen.add);
      await settle();
      expect(seen, ['3'], reason: 'resolves through the group first');

      // The client now sets its OWN currency — must win over the group.
      await seedClient(id: 'c1', currencyId: '1', groupId: 'g1');
      await settle();
      expect(seen, ['3', '1']);

      // Back to inheriting — resolves through the group again.
      await seedClient(id: 'c1', groupId: 'g1');
      await settle();
      expect(seen.last, '3', reason: 're-resolves through the group');

      // Editing the GROUP itself does not push: the group map is cached for
      // the life of the subscription (a live second watch would mean two Drift
      // streams per list row). Such a screen re-resolves on remount. This pins
      // that documented trade-off.
      await seedGroup(id: 'g1', currencyId: '5');
      await seedClient(id: 'c1', groupId: 'g1');
      await settle();
      expect(
        seen.last,
        '3',
        reason: 'group edits are picked up on the next subscribe, not live',
      );

      // Don't await: cancelling a generator suspended inside `await for` over a
      // never-completing Drift watch doesn't settle in the test harness.
      unawaited(sub.cancel());
    },
  );

  test('empty for a missing client id', () async {
    expect(await resolve(''), '');
    expect(await resolve('nope'), '');
  });
}

/// Never hit: every fixture seeds Drift directly.
class _FakeClientsApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeGroupSettingsApi implements GroupSettingsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
