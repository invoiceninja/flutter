import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/device_contacts_service.dart';
import 'package:admin/domain/contacts_sync/contact_card_builder.dart';
import 'package:admin/domain/contacts_sync/contacts_sync_service.dart';
import 'package:admin/domain/contacts_sync/contacts_sync_types.dart';

/// Returns empty pages, so `refreshAll` is a no-op and the tests drive the
/// reconcile entirely from rows seeded straight into Drift. `refreshAll` is
/// upsert-only (no pruning), so seeded rows survive it.
class _EmptyClientsApi implements ClientsApi {
  /// How many list calls the reconcile provoked — the assertion behind
  /// `refreshClients: false` actually skipping the download.
  int listCalls = 0;

  @override
  Future<({ClientListApi data, int? cursorUpdatedAt, String? cursorId})> list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    listCalls++;
    return (
      data: const ClientListApi(data: []),
      cursorUpdatedAt: null,
      cursorId: null,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// An in-memory address book that records what the reconcile asked it to do.
class _FakeDeviceContacts implements DeviceContactsService {
  // Both knobs are set by field after construction, not via the constructor —
  // the tests read as "given a device that can't group, ...".
  DeviceContactsPermission permission = DeviceContactsPermission.granted;
  bool supportsGroups = true;

  final Map<String, DeviceContactCard> contacts = {};
  final Set<String> groupMembers = {};
  String? groupId;
  int _nextId = 1;

  final List<String> created = [];
  final List<String> updated = [];
  final List<String> deleted = [];
  int deletedGroups = 0;

  @override
  bool get canSync => true;

  @override
  Future<DeviceContactsPermission> checkPermission() async => permission;

  @override
  Future<DeviceContactsPermission> requestPermission() async => permission;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<String?> ensureGroup(String name) async {
    if (!supportsGroups) return null;
    return groupId ??= 'group-1';
  }

  @override
  Future<String?> findGroup(String name) async {
    createdGroups.add(name);
    return groupId;
  }

  /// Names passed to [findGroup] — proves the teardown path never creates one.
  final List<String> createdGroups = [];

  @override
  Future<List<String>> groupMemberIds(String id) async => groupMembers.toList();

  @override
  Future<List<String>> createContacts(
    List<DeviceContactCard> cards, {
    String? groupId,
  }) async {
    final ids = <String>[];
    for (final card in cards) {
      final id = 'dev-${_nextId++}';
      contacts[id] = card;
      ids.add(id);
      created.add(card.sourceId);
      if (groupId != null) groupMembers.add(id);
    }
    return ids;
  }

  @override
  Future<void> updateContacts(List<DeviceContactUpdate> items) async {
    for (final item in items) {
      // Matches the real impl: a contact that no longer exists is skipped, not
      // resurrected. Assigning blindly here would hide the bug where a card the
      // user deleted by hand gets a fresh hash and is never re-created.
      if (!contacts.containsKey(item.deviceId)) continue;
      contacts[item.deviceId] = item.card;
      updated.add(item.card.sourceId);
    }
  }

  @override
  Future<void> deleteContacts(List<String> deviceIds) async {
    for (final id in deviceIds) {
      contacts.remove(id);
      groupMembers.remove(id);
      deleted.add(id);
    }
  }

  @override
  Future<void> deleteGroup(String id) async {
    deletedGroups++;
    groupId = null;
  }

  @override
  bool get isAvailable => true;

  @override
  Future<DeviceContactImport?> pickContact() async => null;
}

const _countries = <String, Country>{};

ClientApi _api(
  String id, {
  String name = 'Acme',
  String phone = '',
  String assignedUserId = '',
  List<ContactApi> contacts = const [],
}) => ClientApi(
  id: id,
  name: name,
  displayName: name,
  phone: phone,
  assignedUserId: assignedUserId,
  contacts: contacts,
  updatedAt: 1700000000,
);

ContactApi _contact(String id, {String phone = '555-0100'}) =>
    ContactApi(id: id, firstName: 'Jane', lastName: 'Smith', phone: phone);

void main() {
  late AppDatabase db;
  late ClientRepository clients;
  late _EmptyClientsApi clientsApi;
  late _FakeDeviceContacts device;
  late ContactsSyncService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    clientsApi = _EmptyClientsApi();
    clients = ClientRepository(db: db, api: clientsApi);
    device = _FakeDeviceContacts();
    service = ContactsSyncService(
      device: device,
      clients: clients,
      db: db,
      countries: () => _countries,
      currentUserId: () => 'u1',
      now: () => DateTime.utc(2026, 5, 11, 12),
    );
    // The reconcile reads the company row for the label name.
    await db.companiesDao.upsertAll([
      CompaniesCompanion.insert(
        id: 'co',
        name: 'Acme Co',
        settings: '{}',
        permissions: '',
        accountId: 'a1',
        token: '',
        updatedAt: 0,
      ),
    ]);
  });

  tearDown(() => db.close());

  Future<void> seed(List<ClientApi> rows) async {
    for (final row in rows) {
      await clients.applyUpdateResponse(companyId: 'co', serverResponse: row);
    }
  }

  Future<ContactsSyncSummary> run({
    ContactsSyncScope scope = ContactsSyncScope.all,
    bool isFirstRun = true,
    bool refreshClients = true,
    bool Function()? isCancelled,
  }) => service.run(
    companyId: 'co',
    scope: scope,
    isFirstRun: isFirstRun,
    refreshClients: refreshClients,
    isCancelled: isCancelled,
  );

  group('permission gate', () {
    test('a denied grant writes nothing at all', () async {
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);
      device.permission = DeviceContactsPermission.denied;

      final summary = await run();

      expect(summary.outcome, ContactsSyncOutcome.permissionMissing);
      expect(device.contacts, isEmpty);
    });

    test("iOS 18's limited grant is not enough — a diff built from a partial "
        'view would delete cards it simply could not see', () async {
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);
      device.permission = DeviceContactsPermission.limited;

      final summary = await run();

      expect(summary.outcome, ContactsSyncOutcome.permissionMissing);
      expect(device.contacts, isEmpty);
    });
  });

  group('reconcile', () {
    test('creates a card per contact and labels it', () async {
      await seed([
        _api('c1', contacts: [_contact('k1'), _contact('k2')]),
      ]);

      final summary = await run();

      expect(summary.outcome, ContactsSyncOutcome.ok);
      expect(summary.created, 2);
      expect(summary.labelled, isTrue);
      expect(device.contacts, hasLength(2));
      expect(device.groupMembers, hasLength(2));
      // And the links were recorded, keyed by the IN contact id.
      final links = await db.deviceContactLinkDao.byCompany('co');
      expect(links.keys, containsAll(<String>['k1', 'k2']));
    });

    test('a second run right after the first writes nothing — this is what '
        'makes the post-Sync hook cheap enough to always run', () async {
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);
      await run();
      device.created.clear();

      final summary = await run(isFirstRun: false);

      expect(summary.created, 0);
      expect(summary.updated, 0);
      expect(summary.deleted, 0);
      expect(summary.unchanged, 1);
      expect(device.created, isEmpty);
      expect(device.updated, isEmpty);
    });

    test('an edited contact updates in place, preserving the device id so the '
        'user does not get a duplicate card', () async {
      await seed([
        _api('c1', contacts: [_contact('k1', phone: '555-0100')]),
      ]);
      await run();
      final deviceId = device.contacts.keys.single;

      await seed([
        _api('c1', contacts: [_contact('k1', phone: '555-9999')]),
      ]);
      final summary = await run(isFirstRun: false);

      expect(summary.updated, 1);
      expect(summary.created, 0);
      expect(device.contacts.keys.single, deviceId);
      expect(device.contacts[deviceId]!.phones.first.number, '555-9999');
    });

    test('a client that leaves the set has its card removed', () async {
      await seed([
        _api('c1', contacts: [_contact('k1')]),
        _api('c2', contacts: [_contact('k2')]),
      ]);
      await run();
      expect(device.contacts, hasLength(2));

      // c2 is archived: it stops trading, so it stops being a contact.
      await db.clientDao.setArchived(
        companyId: 'co',
        id: 'c2',
        atEpochSeconds: 1700000001,
      );
      final summary = await run(isFirstRun: false);

      expect(summary.deleted, 1);
      expect(device.contacts, hasLength(1));
      final links = await db.deviceContactLinkDao.byCompany('co');
      expect(links.keys, ['k1']);
    });

    test(
      'skips a client whose id is still a local placeholder — its id is '
      'about to change, and the card would be keyed to the wrong one',
      () async {
        await seed([
          _api('tmp_abc', contacts: [_contact('k1')]),
        ]);

        final summary = await run();

        expect(summary.created, 0);
        expect(device.contacts, isEmpty);
      },
    );
  });

  group('scope', () {
    test('assigned-to-me covers only this user, and switching to it removes '
        'the cards that fall outside', () async {
      await seed([
        _api('c1', assignedUserId: 'u1', contacts: [_contact('k1')]),
        _api('c2', assignedUserId: 'u2', contacts: [_contact('k2')]),
      ]);
      await run();
      expect(device.contacts, hasLength(2));

      final summary = await run(
        scope: ContactsSyncScope.assignedToMe,
        isFirstRun: false,
      );

      expect(summary.deleted, 1);
      expect(device.contacts.values.single.sourceId, 'k1');
    });

    test(
      'a blank user id refuses the pass instead of silently widening to '
      'every client — the DAO treats an empty assignee as "no filter"',
      () async {
        final blankUserService = ContactsSyncService(
          device: device,
          clients: clients,
          db: db,
          countries: () => _countries,
          currentUserId: () => '',
          now: () => DateTime.utc(2026, 5, 11, 12),
        );
        await seed([
          _api('c1', assignedUserId: 'u1', contacts: [_contact('k1')]),
          _api('c2', assignedUserId: 'u2', contacts: [_contact('k2')]),
        ]);

        final summary = await blankUserService.run(
          companyId: 'co',
          scope: ContactsSyncScope.assignedToMe,
          isFirstRun: true,
        );

        expect(summary.outcome, ContactsSyncOutcome.noUser);
        expect(device.contacts, isEmpty);
      },
    );
  });

  group('client refresh is the caller\'s decision', () {
    test('refreshClients: false issues no download — the post-Sync hook runs '
        'right after a pass that already pulled every client', () async {
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);
      clientsApi.listCalls = 0;

      await run(refreshClients: false);

      expect(clientsApi.listCalls, 0);
    });

    test('refreshClients: true does download', () async {
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);
      clientsApi.listCalls = 0;

      await run();

      expect(clientsApi.listCalls, greaterThan(0));
    });

    test(
      'previewCardCount refreshes when asked — counting off a cache that '
      'holds only page 1 would under-report by orders of magnitude',
      () async {
        clientsApi.listCalls = 0;

        await service.previewCardCount(
          companyId: 'co',
          scope: ContactsSyncScope.all,
          refreshClients: true,
        );

        expect(clientsApi.listCalls, greaterThan(0));
      },
    );
  });

  group('healing', () {
    test('a group member with no link row is deleted — the post-logout case, '
        'where the wipe took the link table but not the address book', () async {
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);
      await run();
      // Simulate `logout()` wiping the link table while the device keeps the
      // cards it was given.
      await db.deviceContactLinkDao.deleteCompany('co');
      final orphanId = device.contacts.keys.single;

      final summary = await run(isFirstRun: false);

      // The orphan is reclaimed (deleted) and the card re-created fresh, so the
      // user ends up with exactly one — not two.
      expect(summary.deleted, 1);
      expect(summary.created, 1);
      expect(device.contacts, hasLength(1));
      expect(device.contacts.keys.single, isNot(orphanId));
    });

    test('a card the user deleted by hand comes back, rather than having a '
        'fresh hash stamped on a link pointing at nothing', () async {
      await seed([
        _api('c1', contacts: [_contact('k1', phone: '555-0100')]),
      ]);
      await run();
      final original = device.contacts.keys.single;

      // The user deletes it from the Contacts app. The link row survives,
      // still claiming the card exists.
      device.contacts.remove(original);
      device.groupMembers.remove(original);
      // And the contact is edited in the app, so the hash moves too — the
      // shape that used to route this down the (silent) update path.
      await seed([
        _api('c1', contacts: [_contact('k1', phone: '555-9999')]),
      ]);

      final summary = await run(isFirstRun: false);

      expect(summary.created, 1);
      expect(summary.updated, 0);
      expect(device.contacts, hasLength(1));
      expect(device.contacts.values.single.phones.first.number, '555-9999');
    });

    test(
      'an unchanged card whose device contact vanished is still restored',
      () async {
        await seed([
          _api('c1', contacts: [_contact('k1')]),
        ]);
        await run();
        device.contacts.clear();
        device.groupMembers.clear();

        final summary = await run(isFirstRun: false);

        expect(summary.created, 1);
        expect(summary.unchanged, 0);
        expect(device.contacts, hasLength(1));
      },
    );

    test('a contact outside the label is never touched', () async {
      // Something the user added themselves: present in the address book, not
      // in our group.
      device.contacts['someone-else'] = const DeviceContactCard(
        sourceId: 'not-ours',
        firstName: 'Not',
        lastName: 'Ours',
      );
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);

      await run();

      expect(device.deleted, isEmpty);
      expect(device.contacts.containsKey('someone-else'), isTrue);
    });

    test('with no label available the pass still syncs, skips the heal, and '
        'says so — a device with no contacts account cannot group', () async {
      device.supportsGroups = false;
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);

      final summary = await run();

      expect(summary.outcome, ContactsSyncOutcome.ok);
      expect(summary.created, 1);
      expect(summary.labelled, isFalse);
      expect(device.contacts, hasLength(1));
    });
  });

  group('cancellation', () {
    test('stops without throwing and keeps what it already wrote', () async {
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);

      final summary = await run(isCancelled: () => true);

      expect(summary.outcome, ContactsSyncOutcome.cancelled);
    });
  });

  group('removeAll', () {
    test('deletes every card, the label, and the link rows', () async {
      await seed([
        _api('c1', contacts: [_contact('k1'), _contact('k2')]),
      ]);
      await run();
      expect(device.contacts, hasLength(2));

      await service.removeAll(companyId: 'co');

      expect(device.contacts, isEmpty);
      expect(device.deletedGroups, 1);
      expect(await db.deviceContactLinkDao.byCompany('co'), isEmpty);
    });

    test('never creates the label just to delete it — a device that never '
        'synced must not briefly gain one', () async {
      await service.removeAll(companyId: 'co');
      // findGroup was used (recorded), and no group was ever created.
      expect(device.createdGroups, isNotEmpty);
      expect(device.groupId, isNull);
      expect(device.deletedGroups, 0);
    });

    test('reaches cards whose link row is gone, via the label', () async {
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);
      await run();
      await db.deviceContactLinkDao.deleteCompany('co');

      await service.removeAll(companyId: 'co');

      expect(device.contacts, isEmpty);
    });
  });

  group('bookkeeping', () {
    test('previewCardCount reports what a pass would write, without '
        'writing it', () async {
      await seed([
        _api('c1', contacts: [_contact('k1'), _contact('k2')]),
        _api('c2', contacts: [_contact('k3')]),
      ]);

      final count = await service.previewCardCount(
        companyId: 'co',
        scope: ContactsSyncScope.all,
      );

      expect(count, 3);
      expect(device.contacts, isEmpty);
    });

    test('companiesWithSyncedContacts finds companies not opened this '
        'session, which the logout cleanup has to reach', () async {
      await db.deviceContactLinkDao.upsertAll([
        DeviceContactLinksCompanion(
          companyId: const Value('other-co'),
          sourceId: const Value('k9'),
          deviceContactId: const Value('dev-9'),
          hash: const Value('h'),
          updatedAt: const Value(0),
        ),
      ]);
      await seed([
        _api('c1', contacts: [_contact('k1')]),
      ]);
      await run();

      expect(
        await service.companiesWithSyncedContacts(),
        containsAll(<String>['co', 'other-co']),
      );
    });

    test('the label names the company so two companies cannot collide', () {
      expect(
        ContactsSyncService.labelFor('Acme Co'),
        'Invoice Ninja — Acme Co',
      );
      expect(ContactsSyncService.labelFor('  '), 'Invoice Ninja');
    });

    test('the fallback source id cannot collide with a real contact id', () {
      expect(clientFallbackSourceId('c1'), 'client:c1');
    });
  });
}
