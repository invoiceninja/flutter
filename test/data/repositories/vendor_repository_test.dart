import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/vendors_api.dart';

import '_base_entity_repository_contract.dart';

/// Covers the universal `BaseEntityRepository` contract via the shared
/// harness and the entity-specific behaviour the contract doesn't probe
/// (contact mapping, tmp_-id stripping in `VendorContact.toApiJson`).
class _VendorFixture
    extends EntityRepositoryContractFixture<Vendor, VendorApi> {
  @override
  String get entityType => 'vendor';

  @override
  VendorRepository buildRepo(AppDatabase db) =>
      VendorRepository(db: db, api: _FakeVendorsApi());

  @override
  VendorApi buildApiModel({
    required String id,
    String? displayValue,
    int updatedAt = 1700000000,
  }) => VendorApi(id: id, name: displayValue ?? id, updatedAt: updatedAt);

  @override
  Vendor fromApi(VendorApi api) => Vendor.fromApi(api);

  @override
  Vendor editCopy(Vendor item, {required String displayValue}) =>
      item.copyWith(name: displayValue);

  @override
  String idOf(Vendor item) => item.id;

  @override
  bool isDirtyOf(Vendor item) => item.isDirty;

  @override
  DateTime Function(Vendor item)? get updatedAtOf =>
      (item) => item.updatedAt;

  @override
  Future<SaveResult<Vendor>> create(
    BaseEntityRepository<Vendor, VendorApi> repo, {
    required String companyId,
    required Vendor draft,
  }) => (repo as VendorRepository).create(companyId: companyId, draft: draft);

  @override
  Future<SaveResult<Vendor>> save(
    BaseEntityRepository<Vendor, VendorApi> repo, {
    required String companyId,
    required Vendor entity,
  }) => (repo as VendorRepository).save(companyId: companyId, vendor: entity);

  @override
  Future<void> delete(
    BaseEntityRepository<Vendor, VendorApi> repo, {
    required String companyId,
    required String id,
  }) => (repo as VendorRepository).delete(companyId: companyId, id: id);
}

void main() {
  runEntityRepositoryContract(_VendorFixture());

  group('VendorRepository — entity-specific', () {
    test(
      'VendorApi → Vendor round-trip preserves nested contacts in order',
      () {
        const api = VendorApi(
          id: 'v_1',
          name: 'Acme Co',
          contacts: [
            VendorContactApi(
              id: 'vc_1',
              firstName: 'Alice',
              lastName: 'Anders',
              email: 'alice@acme.test',
            ),
            VendorContactApi(
              id: 'vc_2',
              firstName: 'Bob',
              lastName: 'Brown',
              email: 'bob@acme.test',
            ),
          ],
        );
        final domain = Vendor.fromApi(api);
        expect(domain.contacts, hasLength(2));
        expect(domain.contacts[0].id, 'vc_1');
        expect(domain.contacts[0].firstName, 'Alice');
        expect(domain.contacts[0].lastName, 'Anders');
        expect(domain.contacts[1].id, 'vc_2');
        expect(domain.contacts[1].firstName, 'Bob');
        expect(domain.contacts[1].lastName, 'Brown');
      },
    );

    test('vendor contact cc_only round-trips (defaults false)', () {
      final api = VendorApi.fromJson({
        'id': 'v_1',
        'name': 'Acme Co',
        'contacts': [
          {'id': 'vc_1', 'email': 'a@acme.test', 'cc_only': true},
          {'id': 'vc_2', 'email': 'b@acme.test'},
        ],
      });
      final domain = Vendor.fromApi(api);
      expect(domain.contacts[0].ccOnly, isTrue);
      expect(domain.contacts[1].ccOnly, isFalse, reason: 'defaults false');
      expect(domain.contacts[0].toApiJson()['cc_only'], isTrue);
      expect(domain.contacts[1].toApiJson()['cc_only'], isFalse);
    });

    test(
      'masked contact password is blanked on read and never re-sent — '
      'echoing `**********` would 422 against the backend password regex',
      () {
        final api = VendorApi.fromJson({
          'id': 'v_1',
          'name': 'Acme Co',
          'contacts': [
            {'id': 'vc_1', 'email': 'a@acme.test', 'password': kMaskedPassword},
            {'id': 'vc_2', 'email': 'b@acme.test', 'password': 'Real1Pass'},
          ],
        });
        final domain = Vendor.fromApi(api);
        // Masked sentinel → treated as "no password entered".
        expect(domain.contacts[0].password, isEmpty);
        expect(
          domain.contacts[0].toApiJson().containsKey('password'),
          isFalse,
          reason: 'the masked sentinel must never be written back',
        );
        // A genuine password the user typed still round-trips.
        expect(domain.contacts[1].password, 'Real1Pass');
        expect(domain.contacts[1].toApiJson()['password'], 'Real1Pass');
        // Defense-in-depth: even if the mask reaches toApiJson directly.
        expect(
          domain.contacts[1]
              .copyWith(password: kMaskedPassword)
              .toApiJson()
              .containsKey('password'),
          isFalse,
        );
      },
    );

    test(
      'server-minted portal placeholder email is blanked on read and carried '
      'back out untouched (invoiceninja/flutter#116)',
      () {
        const minted = 'dq9GHaI6Dncm0Zd@example.com';
        final api = VendorApi.fromJson({
          'id': 'v_1',
          'name': 'Acme Co',
          'contacts': [
            {'id': 'vc_1', 'first_name': 'Jimmy', 'email': minted},
            {'id': 'vc_2', 'first_name': 'Real', 'email': 'b@acme.test'},
          ],
        });
        final domain = Vendor.fromApi(api);

        expect(domain.contacts[0].email, isEmpty);
        expect(domain.contacts[0].portalPlaceholderEmail, minted);
        expect(
          domain.contacts[0].toApiJson()['email'],
          minted,
          reason: 'an unrelated save must not clear the server value',
        );

        expect(domain.contacts[1].email, 'b@acme.test');
        expect(domain.contacts[1].portalPlaceholderEmail, isEmpty);
        expect(
          domain.contacts[1].copyWith(email: '').toApiJson()['email'],
          isEmpty,
          reason: 'a user clearing a real address still transmits as empty',
        );
      },
    );

    test('a CLONED vendor contact drops the placeholder', () {
      // `VendorAction.clone` clears `id` and keeps everything else; the guard
      // in `toApiJson` is what stops the new contact inheriting the source
      // contact's minted portal-login address.
      const minted = 'dq9GHaI6Dncm0Zd@example.com';
      final domain = Vendor.fromApi(
        VendorApi.fromJson({
          'id': 'v_1',
          'name': 'Acme Co',
          'contacts': [
            {'id': 'vc_1', 'first_name': 'Jimmy', 'email': minted},
          ],
        }),
      );
      expect(domain.contacts[0].toApiJson()['email'], minted);
      expect(domain.contacts[0].copyWith(id: '').toApiJson()['email'], isEmpty);
    });

    test(
      'the vendor placeholder survives the local-save payload round-trip',
      () {
        // `_domainToCompanion` stores `toApiJson(preserveTempId: true)` in the
        // Drift payload and `_fromRow` re-reads the domain from it. Omitting
        // the key instead of re-emitting the raw value would round-trip the
        // carried address to '' on the first save.
        const minted = 'dq9GHaI6Dncm0Zd@example.com';
        var v = Vendor.fromApi(
          VendorApi.fromJson({
            'id': 'v_1',
            'name': 'Acme Co',
            'contacts': [
              {'id': 'vc_1', 'first_name': 'Jimmy', 'email': minted},
            ],
          }),
        );

        for (var save = 0; save < 2; save++) {
          final stored = jsonDecode(
            jsonEncode(v.toApiJson(preserveTempId: true)),
          );
          v = Vendor.fromApi(
            VendorApi.fromJson(stored as Map<String, dynamic>),
          );
          expect(v.contacts[0].email, isEmpty, reason: 'save ${save + 1}');
          expect(v.contacts[0].portalPlaceholderEmail, minted);
        }
        expect(v.contacts[0].toApiJson()['email'], minted);
      },
    );

    test(
      'vendor + contact extended fields round-trip through fromApi/toApiJson — '
      'including read-only last_login so the local Drift payload preserves it',
      () {
        final api = VendorApi.fromJson({
          'id': 'v_1',
          'name': 'Acme Co',
          'currency_id': '3',
          'language_id': '5',
          'classification': 'business',
          'is_tax_exempt': true,
          'routing_id': 'RT-9',
          'last_login': 1700000000,
          'contacts': [
            {
              'id': 'vc_1',
              'email': 'a@acme.test',
              'can_sign': true,
              'link': 'https://portal/x',
              'last_login': 1699999999,
            },
          ],
        });
        final v = Vendor.fromApi(api);
        expect(v.languageId, '5');
        expect(v.classification, 'business');
        expect(v.isTaxExempt, isTrue);
        expect(v.routingId, 'RT-9');
        expect(v.lastLogin, isNotNull);
        expect(v.contacts.single.canSign, isTrue);
        expect(v.contacts.single.link, 'https://portal/x');
        expect(v.contacts.single.lastLogin, isNotNull);

        final json = v.toApiJson();
        expect(json['language_id'], '5');
        expect(json['classification'], 'business');
        expect(json['is_tax_exempt'], true);
        expect(json['routing_id'], 'RT-9');
        expect(json['last_login'], 1700000000);
        final c = (json['contacts'] as List).single as Map;
        expect(c['can_sign'], true);
        expect(c['link'], 'https://portal/x');
      },
    );

    test(
      'VendorContact.toApiJson omits tmp_ ids by default but keeps them with '
      'preserveTempId — the create flow needs the server to allocate the id, '
      'local Drift persistence needs to keep watching the tmp row',
      () {
        final tmpContact = VendorContact(
          id: 'tmp_abc',
          firstName: 'New',
          lastName: 'Contact',
          email: 'new@acme.test',
          phone: '',
          password: '',
          sendEmail: true,
          isPrimary: false,
          customValue1: '',
          customValue2: '',
          customValue3: '',
          customValue4: '',
          updatedAt: epochSecondsToUtc(0),
          isDeleted: false,
        );

        final outbound = tmpContact.toApiJson();
        expect(
          outbound.containsKey('id'),
          isFalse,
          reason: 'tmp_ ids are stripped from the outbound payload',
        );

        final local = tmpContact.toApiJson(preserveTempId: true);
        expect(
          local['id'],
          'tmp_abc',
          reason: 'preserveTempId keeps the temp id for local Drift round-trip',
        );

        // And confirm real ids round-trip both ways.
        final saved = tmpContact.copyWith(id: 'vc_real');
        expect(saved.toApiJson()['id'], 'vc_real');
        expect(saved.toApiJson(preserveTempId: true)['id'], 'vc_real');
      },
    );
  });

  // Sanity-check that the in-memory DB harness still composes cleanly for
  // future tests added to this group.
  group('VendorRepository — DB smoke', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    test('repo can be constructed against an in-memory DB', () {
      final repo = VendorRepository(db: db, api: _FakeVendorsApi());
      expect(repo.entityTypeName, 'vendor');
    });

    test(
      'watchActiveNames falls back to the id when the display name is blank',
      () async {
        // `vendors.display_name` is empty for a vendor with no name of its own
        // — its seeded blank contact contributes nothing, and a contact whose
        // only email was a minted placeholder is scrubbed to '' too
        // (invoiceninja/flutter#116). The pickers order by this column and
        // render it verbatim, so an empty value is a blank, unselectable-
        // looking row sorted to the top.
        final repo = VendorRepository(db: db, api: _FakeVendorsApi());
        await repo.applyUpdateResponse(
          companyId: 'co',
          serverResponse: VendorApi.fromJson({
            'id': 'v_blank',
            'name': '',
            'updated_at': 1700000000,
            'contacts': [
              {'id': 'vc_1', 'email': 'dq9GHaI6Dncm0Zd@example.com'},
            ],
          }),
        );
        await repo.applyUpdateResponse(
          companyId: 'co',
          serverResponse: VendorApi.fromJson({
            'id': 'v_named',
            'name': 'Acme Co',
            'updated_at': 1700000000,
          }),
        );

        final rows = await repo.watchActiveNames(companyId: 'co').first;
        final byId = {for (final r in rows) r.id: r.name};
        expect(byId['v_blank'], 'v_blank', reason: 'never an empty label');
        expect(byId['v_named'], 'Acme Co');
      },
    );
  });

  // `ensureLoaded` is the lazy single-id hydrate that backs the
  // `*NameLabel` cache-miss path (a vendor referenced by an expense but
  // not on the prefetched first page). Verifies it network-fetches +
  // upserts once, short-circuits when cached, and skips/negative-caches
  // non-fetchable ids so it's safe to fire from every row/rebuild.
  group('VendorRepository — ensureLoaded (lazy hydrate)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    test('cache miss → fetches by id, upserts, watch resolves', () async {
      final api = _GetVendorsApi({
        'v1': VendorApi(id: 'v1', name: 'Acme', updatedAt: 1700000000),
      });
      final repo = VendorRepository(db: db, api: api);
      await repo.ensureLoaded(companyId: 'co', id: 'v1');
      final v = await repo.watch(companyId: 'co', id: 'v1').first;
      expect(v?.name, 'Acme');
      expect(api.getCalls, 1);
    });

    test('already cached → no second network fetch', () async {
      final api = _GetVendorsApi({
        'v1': VendorApi(id: 'v1', name: 'Acme', updatedAt: 1700000000),
      });
      final repo = VendorRepository(db: db, api: api);
      await repo.ensureLoaded(companyId: 'co', id: 'v1');
      await repo.ensureLoaded(companyId: 'co', id: 'v1');
      expect(api.getCalls, 1);
    });

    test('empty / tmp_ ids are no-ops (no network)', () async {
      final api = _GetVendorsApi(const {});
      final repo = VendorRepository(db: db, api: api);
      await repo.ensureLoaded(companyId: 'co', id: '');
      await repo.ensureLoaded(companyId: 'co', id: 'tmp_x');
      expect(api.getCalls, 0);
    });

    test('missing id is negative-cached — fetched at most once', () async {
      final api = _GetVendorsApi(const {});
      final repo = VendorRepository(db: db, api: api);
      await repo.ensureLoaded(companyId: 'co', id: 'gone');
      await repo.ensureLoaded(companyId: 'co', id: 'gone');
      expect(api.getCalls, 1);
    });

    test(
      'transient failure is NOT negative-cached — retried next call',
      () async {
        // A NetworkException (offline / 5xx / rate-limit) must leave the id
        // eligible so the label resolves once connectivity recovers, instead of
        // pinning the *NameLabel to a raw id for the whole session.
        final api = _FlakyVendorsApi(
          VendorApi(id: 'v1', name: 'Acme', updatedAt: 1700000000),
          failFirst: true,
        );
        final repo = VendorRepository(db: db, api: api);
        await repo.ensureLoaded(companyId: 'co', id: 'v1'); // transient throw
        expect(api.getCalls, 1);
        expect((await repo.watch(companyId: 'co', id: 'v1').first), isNull);
        await repo.ensureLoaded(companyId: 'co', id: 'v1'); // retried, succeeds
        expect(
          api.getCalls,
          2,
          reason: 'transient failure must not negative-cache',
        );
        expect(
          (await repo.watch(companyId: 'co', id: 'v1').first)?.name,
          'Acme',
        );
      },
    );
  });
}

/// Serves a single vendor but throws a *transient* `NetworkException` on the
/// first call, succeeding thereafter — exercises the retry-after-transient
/// path of `ensureLoadedTemplate`.
class _FlakyVendorsApi implements VendorsApi {
  _FlakyVendorsApi(this._vendor, {required this.failFirst});

  final VendorApi _vendor;
  final bool failFirst;
  int getCalls = 0;

  @override
  Future<VendorItemApi> get(String id) async {
    getCalls++;
    if (failFirst && getCalls == 1) {
      throw const NetworkException('connection failed');
    }
    return VendorItemApi(data: _vendor);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeVendorsApi implements VendorsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Fake that serves single-id GETs for the `ensureLoaded` tests and
/// counts calls so dedupe / negative-cache behaviour is observable.
class _GetVendorsApi implements VendorsApi {
  _GetVendorsApi(this._byId);

  final Map<String, VendorApi> _byId;
  int getCalls = 0;

  @override
  Future<VendorItemApi> get(String id) async {
    getCalls++;
    final v = _byId[id];
    if (v == null) throw const NotFoundException('404 — vendor not found');
    return VendorItemApi(data: v);
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
