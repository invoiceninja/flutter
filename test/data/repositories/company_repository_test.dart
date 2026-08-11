import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_registration_field_api_model.dart';
import 'package:admin/data/models/api/company_api_model.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/services/companies_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';

class _FakeCompaniesApi implements CompaniesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _StubCompaniesApi implements CompaniesApi {
  _StubCompaniesApi(this.response);
  final CompanyItemApi response;

  @override
  Future<CompanyItemApi> get(String id) async => response;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  CompanyRepository makeRepo() => CompanyRepository(
    db: db,
    api: _FakeCompaniesApi(),
    uuid: const Uuid(),
    now: () => DateTime.utc(2026, 5, 11, 12),
  );

  Future<void> seedCompany(
    String id, {
    String name = 'Acme',
    Map<String, dynamic> settings = const {'name': 'Acme'},
    Map<String, String> customFields = const {},
    String? logoUrl,
    List<Map<String, dynamic>>? documents,
  }) async {
    await db.companiesDao.upsertAll([
      CompaniesCompanion.insert(
        id: id,
        name: name,
        displayName: Value(name),
        settings: jsonEncode(settings),
        customFields: Value(jsonEncode(customFields)),
        logoUrl: Value(logoUrl),
        documents: Value(documents == null ? null : jsonEncode(documents)),
        permissions: '',
        accountId: 'acct',
        token: 'tok',
        updatedAt: 1700000000,
      ),
    ]);
  }

  group('updateCompany', () {
    test(
      'writes the new settings JSON and enqueues an update outbox row',
      () async {
        const companyId = 'co';
        await seedCompany(companyId);
        final repo = makeRepo();

        final current = await repo.get(companyId);
        expect(current, isNotNull);
        final draft = current!.copyWith(
          settings: current.settings.copyWith(
            name: 'Acme Renamed',
            idNumber: 'REG-9',
          ),
        );

        await repo.updateCompany(draft: draft);

        final row = await db.companiesDao.byId(companyId);
        expect(row, isNotNull);
        final decoded = jsonDecode(row!.settings) as Map<String, dynamic>;
        expect(decoded['name'], 'Acme Renamed');
        expect(decoded['id_number'], 'REG-9');

        final pending = await db.outboxDao.nextReady(
          companyId: companyId,
          now: 1 << 60,
        );
        expect(pending, hasLength(1));
        expect(pending.single.mutationKind, MutationKind.update.wireName);
        expect(pending.single.entityType, 'company');
        expect(pending.single.entityId, companyId);
        expect(pending.single.idempotencyKey, isNotEmpty);
      },
    );

    test(
      'fires onSettingsWritten with the company id after the write commits',
      () async {
        // Wired in services.dart to Services.invalidateFormatter — without
        // this callback, a Date Format / currency change stays invisible
        // until logout/restart because the per-company Formatter is memoized.
        const companyId = 'co';
        await seedCompany(companyId);
        final invalidated = <String>[];
        final repo = CompanyRepository(
          db: db,
          api: _FakeCompaniesApi(),
          uuid: const Uuid(),
          now: () => DateTime.utc(2026, 5, 11, 12),
          onSettingsWritten: invalidated.add,
        );

        final current = await repo.get(companyId);
        final draft = current!.copyWith(
          settings: current.settings.copyWith(name: 'Acme Renamed'),
        );
        await repo.updateCompany(draft: draft);

        expect(invalidated, [companyId]);
      },
    );

    test('drops the masked SMTP credentials from the outbox payload but keeps '
        'them in the local row', () async {
      // The server masks stored credentials as `********` on every read, and
      // the login/refresh envelope seeds that mask into the local row — so an
      // unrelated settings save would otherwise echo the mask back. The server
      // discards it (`UpdateCompanyRequest::prepareForValidation` unsets
      // anything under two chars once `*` is stripped), but we shouldn't be
      // relying on that, and must never write the literal mask as a password.
      const companyId = 'co';
      await seedCompany(companyId);
      final repo = makeRepo();

      final current = await repo.get(companyId);
      final draft = current!.copyWith(
        smtpHost: 'smtp.example.com',
        smtpUsername: '********',
        smtpPassword: '********',
      );
      await repo.updateCompany(draft: draft);

      final pending = await db.outboxDao.nextReady(
        companyId: companyId,
        now: 1 << 60,
      );
      final payload =
          jsonDecode(pending.single.payload) as Map<String, dynamic>;
      expect(payload['smtp_host'], 'smtp.example.com');
      expect(payload.containsKey('smtp_username'), isFalse);
      expect(payload.containsKey('smtp_password'), isFalse);

      // The local row still mirrors what the server holds, so the fields keep
      // rendering as masked rather than looking unset.
      final row = await db.companiesDao.byId(companyId);
      expect(row!.smtpUsername, '********');
      expect(row.smtpPassword, '********');
    });

    test('sends the SMTP credentials the user actually typed', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final repo = makeRepo();

      final current = await repo.get(companyId);
      final draft = current!.copyWith(
        smtpUsername: 'postmaster@example.com',
        smtpPassword: 'hunter2',
      );
      await repo.updateCompany(draft: draft);

      final pending = await db.outboxDao.nextReady(
        companyId: companyId,
        now: 1 << 60,
      );
      final payload =
          jsonDecode(pending.single.payload) as Map<String, dynamic>;
      expect(payload['smtp_username'], 'postmaster@example.com');
      expect(payload['smtp_password'], 'hunter2');
    });

    test('preserves unknown settings keys across the round-trip', () async {
      // An "unknown" field is one the typed `CompanySettingsApi` doesn't
      // model. The original implementation silently dropped these on every
      // save, corrupting fields like `mailgun_secret` server-side.
      const companyId = 'co';
      await seedCompany(
        companyId,
        settings: const {
          'name': 'Acme',
          // Real fields we don't currently model:
          'mailgun_secret': 'super-secret',
          'a_brand_new_field_we_dont_model': 42,
        },
      );
      final repo = makeRepo();

      final current = await repo.get(companyId);
      final draft = current!.copyWith(
        settings: current.settings.copyWith(name: 'Acme Renamed'),
      );
      await repo.updateCompany(draft: draft);

      // Drift row keeps the unknown keys.
      final row = await db.companiesDao.byId(companyId);
      final stored = jsonDecode(row!.settings) as Map<String, dynamic>;
      expect(stored['name'], 'Acme Renamed');
      expect(stored['mailgun_secret'], 'super-secret');
      expect(stored['a_brand_new_field_we_dont_model'], 42);

      // Outbox payload (what gets PUT'd to the server) also keeps them.
      final pending = await db.outboxDao.nextReady(
        companyId: companyId,
        now: 1 << 60,
      );
      final payload =
          jsonDecode(pending.single.payload) as Map<String, dynamic>;
      final settings = payload['settings'] as Map<String, dynamic>;
      expect(settings['name'], 'Acme Renamed');
      expect(settings['mailgun_secret'], 'super-secret');
      expect(settings['a_brand_new_field_we_dont_model'], 42);
    });

    test('persists portal fields and clientRegistrationFields edits', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final repo = makeRepo();

      final current = await repo.get(companyId);
      final draft = current!.copyWith(
        subdomain: 'acme',
        portalDomain: 'https://billing.acme.test',
        portalMode: 'subdomain',
        clientCanRegister: true,
        companyKey: 'CK1',
        clientRegistrationFields: [
          const ClientRegistrationFieldApi(
            key: 'email',
            required: true,
            visible: true,
          ),
          const ClientRegistrationFieldApi(
            key: 'phone',
            required: false,
            visible: true,
          ),
        ],
      );
      await repo.updateCompany(draft: draft);

      final row = await db.companiesDao.byId(companyId);
      expect(row!.subdomain, 'acme');
      expect(row.portalDomain, 'https://billing.acme.test');
      expect(row.portalMode, 'subdomain');
      expect(row.clientCanRegister, true);
      expect(row.companyKey, 'CK1');
      final decoded = jsonDecode(row.clientRegistrationFields) as List;
      expect(decoded, hasLength(2));
      expect(decoded.first, {
        'key': 'email',
        'required': true,
        'visible': true,
      });

      final reloaded = await repo.get(companyId);
      expect(reloaded!.subdomain, 'acme');
      expect(reloaded.clientCanRegister, true);
      // Top-level field must be in the PUT body, not the settings blob —
      // the server gates registration on `company.client_can_register`.
      expect(reloaded.toApiJson()['client_can_register'], true);
      expect(reloaded.clientRegistrationFields, hasLength(2));
      expect(reloaded.clientRegistrationFields.first.key, 'email');
      expect(reloaded.clientRegistrationFields.first.required, true);
    });

    test('persists custom_fields edits', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final repo = makeRepo();

      final current = await repo.get(companyId);
      final draft = current!.copyWith(
        customFields: const {'company1': 'Department|single_line_text'},
      );
      await repo.updateCompany(draft: draft);

      final row = await db.companiesDao.byId(companyId);
      final decoded = jsonDecode(row!.customFields) as Map<String, dynamic>;
      expect(decoded['company1'], 'Department|single_line_text');

      // Round-trip through the repo's `_fromRow` — should see the same map.
      final reloaded = await repo.get(companyId);
      expect(reloaded!.customFields, {
        'company1': 'Department|single_line_text',
      });
    });

    test(
      'persists enable_applying_payments + convert_payment_currency edits '
      'and surfaces them through _fromRow + the outbox payload — Online '
      'Payments "Payment Settings" toggles. Regression: with no column the '
      'toggle reverted after restart even though the PUT carried it',
      () async {
        const companyId = 'co';
        await seedCompany(companyId);
        final repo = makeRepo();

        final current = await repo.get(companyId);
        final draft = current!.copyWith(
          enableApplyingPayments: true,
          convertPaymentCurrency: true,
        );
        await repo.updateCompany(draft: draft);

        // Written to the dedicated columns (survives restart)…
        final row = await db.companiesDao.byId(companyId);
        expect(row!.enableApplyingPayments, true);
        expect(row.convertPaymentCurrency, true);
        // …surfaced on the domain model the toggle binds to…
        final reloaded = await repo.get(companyId);
        expect(reloaded!.enableApplyingPayments, true);
        expect(reloaded.convertPaymentCurrency, true);
        // …and present in the outbox payload PUT to the server.
        final pending = await db.outboxDao.nextReady(
          companyId: companyId,
          now: 1 << 60,
        );
        final payload =
            jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['enable_applying_payments'], true);
        expect(payload['convert_payment_currency'], true);
      },
    );
  });

  group('applyUpdateResponse', () {
    test('overwrites settings + custom_fields with the server body', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final repo = makeRepo();

      final response = CompanyApi(
        id: companyId,
        name: 'Acme',
        settings: const {'name': 'Acme Inc', 'country_id': '276'},
        customFields: const {'company1': 'Department|single_line_text'},
        updatedAt: 1900000000,
      );

      await repo.applyUpdateResponse(
        companyId: companyId,
        serverResponse: response,
      );

      final row = await db.companiesDao.byId(companyId);
      final decodedSettings = jsonDecode(row!.settings) as Map<String, dynamic>;
      expect(decodedSettings['name'], 'Acme Inc');
      expect(decodedSettings['country_id'], '276');
      final decodedCustom =
          jsonDecode(row.customFields) as Map<String, dynamic>;
      expect(decodedCustom['company1'], 'Department|single_line_text');
      expect(row.updatedAt, 1900000000);
    });

    test('persists first_month_of_year and surfaces it through _fromRow — '
        'regression: this top-level company field was dropped (no column), '
        'leaving the Localization dropdown blank', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final repo = makeRepo();

      await repo.applyUpdateResponse(
        companyId: companyId,
        serverResponse: CompanyApi(
          id: companyId,
          name: 'Acme',
          // Top-level on the company object (not inside `settings`), exactly
          // as the live API returns it. '1' == January.
          firstMonthOfYear: '1',
        ),
      );

      // Written to the dedicated column…
      final row = await db.companiesDao.byId(companyId);
      expect(row!.firstMonthOfYear, '1');
      // …and surfaced on the domain model the Localization screen binds to.
      final company = await repo.get(companyId);
      expect(company!.firstMonthOfYear, '1');
    });

    test('persists use_comma_as_decimal_place + first_day_of_week and surfaces '
        'them through _fromRow — top-level company fields the money formatter '
        'and week-start logic read off the company row, never `settings`. '
        'Regression: decimal_comma was misfiled under settings and silently '
        'never took effect', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final repo = makeRepo();

      await repo.applyUpdateResponse(
        companyId: companyId,
        serverResponse: CompanyApi(
          id: companyId,
          name: 'Acme',
          // Both top-level on the company object (not inside `settings`),
          // exactly as the live API returns them. '1' == Monday.
          useCommaAsDecimalPlace: true,
          firstDayOfWeek: '1',
        ),
      );

      // Written to the dedicated columns…
      final row = await db.companiesDao.byId(companyId);
      expect(row!.useCommaAsDecimalPlace, true);
      expect(row.firstDayOfWeek, '1');
      // …and surfaced on the domain model.
      final company = await repo.get(companyId);
      expect(company!.useCommaAsDecimalPlace, true);
      expect(company.firstDayOfWeek, '1');
    });

    test('persists enable_applying_payments + convert_payment_currency and '
        'surfaces them through _fromRow — the Online Payments "Payment '
        'Settings" toggles live top-level on the company (not in `settings`). '
        'Regression: both had no column, so they reset to false on every '
        'login/refresh after the user enabled them', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final repo = makeRepo();

      await repo.applyUpdateResponse(
        companyId: companyId,
        serverResponse: CompanyApi(
          id: companyId,
          name: 'Acme',
          // Both top-level on the company object (not inside `settings`),
          // exactly as the live API returns them.
          enableApplyingPayments: true,
          convertPaymentCurrency: true,
        ),
      );

      // Written to the dedicated columns…
      final row = await db.companiesDao.byId(companyId);
      expect(row!.enableApplyingPayments, true);
      expect(row.convertPaymentCurrency, true);
      // …and surfaced on the domain model the Online Payments screen binds to.
      final company = await repo.get(companyId);
      expect(company!.enableApplyingPayments, true);
      expect(company.convertPaymentCurrency, true);
    });

    test('persists client_can_register and surfaces it through _fromRow — the '
        'Client Portal registration toggle is a top-level company column (the '
        'server gates registration on it; the `settings` copy is deprecated). '
        'Regression: with no column it reset on every login/refresh', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final repo = makeRepo();

      await repo.applyUpdateResponse(
        companyId: companyId,
        serverResponse: CompanyApi(
          id: companyId,
          name: 'Acme',
          // Top-level on the company object, not inside `settings`.
          clientCanRegister: true,
        ),
      );

      final row = await db.companiesDao.byId(companyId);
      expect(row!.clientCanRegister, true);
      final company = await repo.get(companyId);
      expect(company!.clientCanRegister, true);
    });

    test('refreshes the logo_url column from settings.company_logo', () async {
      // Regression: the dedicated logo_url column must follow the applied
      // settings. `_onCompaniesChanged` / `restore` prefer the column, so a
      // stale value left the company-picker avatar on the old logo after an
      // upload (Invoice Ninja returns a new logo URL per upload).
      const companyId = 'co';
      await seedCompany(
        companyId,
        settings: const {
          'name': 'Acme',
          'company_logo': 'https://old.example/old.png',
        },
        logoUrl: 'https://old.example/old.png',
      );
      final repo = makeRepo();

      await repo.applyUpdateResponse(
        companyId: companyId,
        serverResponse: CompanyApi(
          id: companyId,
          name: 'Acme',
          settings: const {
            'name': 'Acme',
            'company_logo': 'https://new.example/new.png',
          },
          updatedAt: 1900000000,
        ),
      );

      final row = await db.companiesDao.byId(companyId);
      expect(row!.logoUrl, 'https://new.example/new.png');
    });
  });

  group('refresh', () {
    test('upserts the GET /companies/{id} response into Drift', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final response = CompanyItemApi(
        data: CompanyApi(
          id: companyId,
          name: 'Acme',
          settings: const {'name': 'Acme Inc', 'country_id': '276'},
          customFields: const {'company1': 'Department|single_line_text'},
          sizeId: '4',
          industryId: '11',
          legalEntityId: 0,
          updatedAt: 1900000000,
        ),
      );
      final repo = CompanyRepository(
        db: db,
        api: _StubCompaniesApi(response),
        uuid: const Uuid(),
        now: () => DateTime.utc(2026, 5, 11, 12),
      );

      await repo.refresh(companyId);

      final row = await db.companiesDao.byId(companyId);
      final settings = jsonDecode(row!.settings) as Map<String, dynamic>;
      expect(settings['name'], 'Acme Inc');
      expect(settings['country_id'], '276');
      final custom = jsonDecode(row.customFields) as Map<String, dynamic>;
      expect(custom['company1'], 'Department|single_line_text');
      expect(row.sizeId, '4');
      expect(row.industryId, '11');
    });

    test('a successful refresh releases the Account-Management control gate '
        '(canonicalFetched) for that company (Finding 40)', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final response = CompanyItemApi(
        data: CompanyApi(id: companyId, name: 'Acme', updatedAt: 1900000000),
      );
      final repo = CompanyRepository(
        db: db,
        api: _StubCompaniesApi(response),
        uuid: const Uuid(),
      );

      expect(repo.isCanonicalFetched(companyId), isFalse);
      var notified = false;
      repo.canonicalFetched.addListener(() => notified = true);

      await repo.refresh(companyId);

      expect(repo.isCanonicalFetched(companyId), isTrue);
      expect(notified, isTrue, reason: 'gating widgets rebuild on the change');
    });

    test(
      'swallows errors so the page can still render the cached row',
      () async {
        const companyId = 'co';
        await seedCompany(companyId);
        final repo = CompanyRepository(
          db: db,
          api: _FakeCompaniesApi(), // throws on every call
          uuid: const Uuid(),
        );

        await repo.refresh(companyId); // must not throw
        expect(
          repo.isCanonicalFetched(companyId),
          isFalse,
          reason:
              'a failed/offline fetch must NOT release the control gate — '
              'saving would clobber server-only fields with cached defaults',
        );
      },
    );

    test('no-op for empty companyId', () async {
      final repo = CompanyRepository(
        db: db,
        api: _FakeCompaniesApi(), // would throw if called
        uuid: const Uuid(),
      );

      await repo.refresh(''); // must not invoke the api
    });
  });

  group('_fromRow hardening', () {
    test(
      'parses loose-type numeric/bool fields via the lenient parser',
      () async {
        // Regression for the form-rendering-blank bug: the live server sends
        // `reset_counter_frequency_id` as a String, which used to crash the
        // strict parser and trigger the empty-typed fallback. The lenient
        // parser coerces it; the form sees real values.
        const companyId = 'co';
        await seedCompany(
          companyId,
          settings: const {
            'name': 'Acme',
            'reset_counter_frequency_id': '1',
            'tax_rate1': '19.5',
            'military_time': 1,
          },
        );
        final repo = makeRepo();

        final company = await repo.get(companyId);
        expect(company, isNotNull);
        expect(company!.settings.name, 'Acme');
        expect(company.settings.resetCounterFrequencyId, 1);
        expect(company.settings.taxRate1, 19.5);
        expect(company.settings.militaryTime, true);
      },
    );

    test('survives a TypeError in CompanySettingsApi.fromJson', () async {
      // Invoice Ninja occasionally returns legacy booleans as `0`/`1` ints.
      // The generated `fromJson` uses bare `as bool?` casts, which throw.
      // The repo must catch that so the UI doesn't get stuck on a spinner —
      // `rawSettings` is preserved so the eventual PUT round-trip is intact.
      const companyId = 'co';
      await seedCompany(
        companyId,
        settings: const {
          'name': 'Acme',
          'enable_reminder1': 0, // <-- the trap
          'a_brand_new_field_we_dont_model': 'untouched',
        },
      );
      final repo = makeRepo();

      final company = await repo.get(companyId);
      expect(company, isNotNull);
      // Typed view falls back to empty; raw map keeps every original key
      // so the merge in `updateCompany` can round-trip them.
      expect(company!.rawSettings['name'], 'Acme');
      expect(company.rawSettings['enable_reminder1'], 0);
      expect(
        company.rawSettings['a_brand_new_field_we_dont_model'],
        'untouched',
      );
    });
  });

  group('uploadLogo', () {
    test('enqueues an outbox row carrying the local file path', () async {
      const companyId = 'co';
      await seedCompany(companyId);
      final repo = makeRepo();

      await repo.uploadLogo(
        companyId: companyId,
        source: fileUploadSource('/tmp/logo.png'),
      );

      final pending = await db.outboxDao.nextReady(
        companyId: companyId,
        now: 1 << 60,
      );
      expect(pending, hasLength(1));
      final payload =
          jsonDecode(pending.single.payload) as Map<String, dynamic>;
      expect(payload['_action'], 'upload_logo');
      expect(payload['local_path'], '/tmp/logo.png');
    });
  });

  group('documents', () {
    test(
      'deleteDocument enqueues a password-required documentDelete row',
      () async {
        const companyId = 'co';
        await seedCompany(companyId);
        final repo = makeRepo();

        await repo.deleteDocument(companyId: companyId, documentId: 'doc-7');

        final pending = await db.outboxDao.nextReady(
          companyId: companyId,
          now: 1 << 60,
        );
        expect(pending, hasLength(1));
        expect(
          pending.single.mutationKind,
          MutationKind.documentDelete.wireName,
        );
        expect(pending.single.entityId, companyId);
        // Server gates DELETE /documents/{id} on X-API-PASSWORD-BASE64; the
        // row must carry the flag so the sync engine fires ConfirmPasswordSheet.
        expect(pending.single.requiresPassword, true);
        final payload =
            jsonDecode(pending.single.payload) as Map<String, dynamic>;
        expect(payload['document_id'], 'doc-7');
      },
    );

    test(
      'removeDocumentLocally drops the matching doc from the column',
      () async {
        const companyId = 'co';
        await seedCompany(
          companyId,
          documents: const [
            {'id': 'doc-1', 'name': 'a.pdf'},
            {'id': 'doc-2', 'name': 'b.pdf'},
          ],
        );
        final repo = makeRepo();

        await repo.removeDocumentLocally(
          companyId: companyId,
          documentId: 'doc-1',
        );

        final reloaded = await repo.get(companyId);
        expect(reloaded!.documents.map((d) => d.id), ['doc-2']);
      },
    );

    test('removeDocumentLocally is a no-op when the id is absent', () async {
      const companyId = 'co';
      await seedCompany(
        companyId,
        documents: const [
          {'id': 'doc-1', 'name': 'a.pdf'},
        ],
      );
      final repo = makeRepo();

      await repo.removeDocumentLocally(
        companyId: companyId,
        documentId: 'missing',
      );

      final reloaded = await repo.get(companyId);
      expect(reloaded!.documents.map((d) => d.id), ['doc-1']);
    });
  });
}
