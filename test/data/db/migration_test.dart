import 'dart:convert';
import 'dart:io';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, Variable;
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../generated/schema.dart';
import '../../generated/schema_v1.dart' as v1;
import '../../generated/schema_v8.dart' as v8;
import '../../generated/schema_v11.dart' as v11;
import '../../generated/schema_v13.dart' as v13;
import '../../generated/schema_v14.dart' as v14;
import '../../generated/schema_v15.dart' as v15;

/// Drift schema guard tests — the CI enforcement behind the post-beta
/// forward-migration policy (see `docs/migrations.md`).
///
/// The app is shipped: installed databases hold real user data and unsynced
/// outbox edits, and the `isSchemaIntact()` backstop in `AppDatabase` WIPES any
/// local DB whose columns don't match the code. So every schema change must
/// ship a real forward migration (bump `schemaVersion`, add an `onUpgrade`
/// step, re-dump + re-generate, extend the matrix below) — never a re-squash.
///
/// These tests make the wrong path fail the build:
///   * `createAll()` must match the latest dumped schema (un-dumped change → red);
///   * `schemaVersion` must equal the count of committed `drift_schema_v*.json`
///     files (bump-without-dump / dump-without-bump → red);
///   * shipped dump files are frozen by checksum (editing v1 — a re-squash — red);
///   * every prior version must migrate cleanly up to the current one (matrix).
void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  // SHA-256 of every SHIPPED schema dump, keyed by version. A shipped baseline
  // is FROZEN: never edit its `drift_schemas/drift_schema_vN.json`. To land a
  // schema change, add the *next* version (bump `schemaVersion`, dump vN+1,
  // write its `onUpgrade` step) and append its hash here — don't overwrite an
  // existing entry. Overwriting v1 (a re-squash) wipes every installed user's
  // local DB via the reset backstop. See `docs/migrations.md`.
  const frozenSchemaHashes = <int, String>{
    1: '036c0de0fcd92c943e915800a61d5e20da8f8a345ad318e0ad43fc6624705004',
    2: 'd5da8c93f363e8c7ab95bf6be124b387832bb84f0a24a576fd84edf522028b06',
    3: 'b320f8d71dffdd0e7a8f6fd069f8a7207c2beb8d7207907007811f71f2303bf2',
    4: '54be9c4ef437fcd6e5a7d8927eca8737f1f582b26b225211a5274d563e3c7eef',
    5: '5ec0013e47f74da5e433b736a3bdc3c040eb09219358d3c08ab693d387870f91',
    6: 'c54173a0059bf0eb1f550c09081e7c59f50673588b7bda1d969b79425401ce90',
    7: '13773cfe170d086a17c91ce69d08c5914f065a8773202859009d0ccad74dc196',
    8: 'c1269adc91f8f62e33e1fe3fdf02c24509a69e96aa50613438d71e4319c3f7c8',
    9: 'ad33ee319136e8eca6f5cf450f4d9031c304a02e711a75565c5221deac952d83',
    10: '603ef90e495e502e8526107a50d57baf58286e2e05b1ff9e026bb05b2b3cdf4f',
    11: '40ff0b42ef0fdd14988a566af67df71c5e14d0b109184e3c1227489fb82ea573',
    12: '6d0bcacd8770299886fc9ce93390b0ad9998c699a8d965ba1c65c935a041afc8',
    // Byte-identical to v12: v13 adds only `createListSortIndexes`, which
    // drift does not model, so the dump cannot see it — the index tests
    // below are what pin it.
    13: '6d0bcacd8770299886fc9ce93390b0ad9998c699a8d965ba1c65c935a041afc8',
    14: 'a97b89f9b596bee6c58211ad778d68913e8fb933579484795fd61c653242821d',
    15: 'a9e25a73d3eeb9b00cc83e412a95a8d20f1069609eccfbdd2e25ea2015e63269',
    16: '9db7061812c29fe2531ca892746b82dd7f1171e87704c1cab2c08fd94054b66d',
  };

  // The live schema version the Dart code declares. (Building one throwaway DB
  // is the cheapest way to read it without exposing it as a static.)
  final schemaVersion = AppDatabase(NativeDatabase.memory()).schemaVersion;

  group('schema dump consistency', () {
    test('createAll() matches the generated current schema dump', () async {
      // A fresh in-memory database runs `onCreate` → `createAll()` from the
      // live Dart table definitions; `migrateAndValidate` compares that against
      // the dumped schema for `schemaVersion`. Fails if a table/column changed
      // without re-running `drift_dev schema dump` + `schema generate`.
      // (Indexes aren't compared by the verifier, so the imperative perf/filter
      // indexes in `onCreate` don't trip it — they're covered by the dedicated
      // index test below.)
      final db = AppDatabase(NativeDatabase.memory());
      await verifier.migrateAndValidate(db, db.schemaVersion);
      await db.close();
    });
  });

  group('forward-migration policy guard', () {
    test('schemaVersion equals the count of committed schema dumps', () {
      // One `drift_schema_vN.json` per version, contiguous from 1. Catches a
      // version bump with no new dump (and a stray/missing dump): on the next
      // schema change BOTH must move together.
      final dumps = Directory('drift_schemas')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => RegExp(r'^drift_schema_v\d+\.json$').hasMatch(n))
          .toList();
      expect(
        dumps.length,
        schemaVersion,
        reason:
            'Expected $schemaVersion dumped schema(s) '
            '(drift_schema_v1..$schemaVersion.json) to match '
            'schemaVersion=$schemaVersion, found ${dumps.length}: $dumps. '
            'A schema change must bump schemaVersion AND add a new dump — see '
            'docs/migrations.md.',
      );
      for (var v = 1; v <= schemaVersion; v++) {
        expect(
          File('drift_schemas/drift_schema_v$v.json').existsSync(),
          isTrue,
          reason: 'Missing drift_schemas/drift_schema_v$v.json',
        );
      }
    });

    test('shipped schema dumps are frozen (checksums unchanged)', () {
      // A shipped dump is an immutable record of what real users' DBs look like
      // at that version. Editing one means a re-squash — which the reset
      // backstop turns into silent data loss. If this fails you almost
      // certainly meant to add a NEW version, not edit an existing one.
      for (var v = 1; v <= schemaVersion; v++) {
        final expected = frozenSchemaHashes[v];
        expect(
          expected,
          isNotNull,
          reason:
              'No frozen checksum recorded for schema v$v. Append its sha256 to '
              'frozenSchemaHashes once v$v is shipped (docs/migrations.md).',
        );
        // Normalize CRLF → LF so a Windows (autocrlf) checkout can't false-fail:
        // the schema content is frozen, not the line endings. The pinned hashes
        // are computed over LF-normalized bytes.
        final normalized = File(
          'drift_schemas/drift_schema_v$v.json',
        ).readAsStringSync().replaceAll('\r\n', '\n');
        final actual = sha256.convert(utf8.encode(normalized)).toString();
        expect(
          actual,
          expected,
          reason:
              'drift_schemas/drift_schema_v$v.json changed. A shipped schema '
              'dump is FROZEN — do not edit it. To change the schema, add '
              'v${schemaVersion + 1} (bump schemaVersion, dump it, write its '
              'onUpgrade step) instead. See docs/migrations.md.',
        );
      }
    });

    test(
      'every prior schema version migrates cleanly up to the current one',
      () async {
        // Upgrade matrix. Dormant while only v1 exists (the loop is empty); once
        // v2+ lands it drives each historical version through AppDatabase's real
        // `onUpgrade` and validates the result against the current schema — so a
        // missing or incorrect migration step fails here. To verify migrated data
        // (not just shape), seed rows via `verifier.schemaAt(from)` first.
        for (var from = 1; from < schemaVersion; from++) {
          final connection = await verifier.startAt(from);
          final db = AppDatabase(connection);
          await verifier.migrateAndValidate(db, schemaVersion);
          await db.close();
        }
      },
    );

    test('device preferences seeded at v8 survive the upgrade', () async {
      // Shape is what `migrateAndValidate` proves; this proves the *values*
      // survive. Through v11 every device preference was a `nav_state` column,
      // and v12 moved them into `device_prefs` rows — so a migration that lost
      // them on either leg would pass every other test in this file and
      // surface only as "the app forgot my settings" after an update.
      // `schemaAt` (not `startAt`) so the seeding database and the migrating
      // one get separate connections over the same store — `newConnection()`
      // wraps it with `closeUnderlyingOnClose: false`, so closing the v8 handle
      // leaves the data in place.
      final schema = await verifier.schemaAt(8);
      final old = v8.DatabaseAtV8(schema.newConnection());
      // Raw SQL rather than a generated companion: this is deliberately the
      // shape a v8 install has on disk, not one re-derived from today's tables.
      await old.customStatement(
        'INSERT INTO nav_state (id, current_route, status_tabs, '
        "sidebar_collapsed, updated_at) VALUES (0, '/tasks?view=kanban', 0, 1, "
        '1234)',
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      // `schemaVersion`, never a literal: `migrateAndValidate` opens the real
      // AppDatabase, which migrates to its OWN version — pinning a number here
      // would fail with a schema diff the day someone lands the next one,
      // inside a test about a migration they never touched.
      await verifier.migrateAndValidate(db, schemaVersion);
      final row = await db.navStateDao.current();
      expect(row?.currentRoute, '/tasks?view=kanban');
      final prefs = DevicePrefsStore(db);
      await prefs.load();
      expect(prefs.read(DevicePrefKeys.statusTabs), isFalse);
      expect(prefs.read(DevicePrefKeys.sidebarCollapsed), isTrue);
      // The v9 column had no backfill: an upgraded install is on the list
      // until the user picks a view, exactly like a fresh one.
      expect(prefs.read(DevicePrefKeys.tasksView), isNull);
      // The v10 column's `ADD COLUMN ... DEFAULT 0` backfilled an upgraded
      // install to off — the same state a fresh one gets, so the feature never
      // switches itself on under an existing user (invoiceninja/flutter#150).
      expect(prefs.read(DevicePrefKeys.hideUnverifiedUsers), isFalse);
      // The v11 column had no backfill either: absent is "automatic" (on for a
      // phone, off elsewhere), so an upgraded install resolves exactly as a
      // fresh one on the same device (invoiceninja/flutter#161).
      expect(prefs.read(DevicePrefKeys.hideEmptyPanels), isNull);
      await db.close();
    });

    test('v12 carries every nav_state preference column into device_prefs, '
        'decodable by its key', () async {
      final schema = await verifier.schemaAt(11);
      final old = v11.DatabaseAtV11(schema.newConnection());
      // Every column away from its default, in the storage class SQLite gave
      // it — BOOLEAN as INTEGER, `text_scale` as REAL — so the TEXT
      // conversion on the way into `device_prefs` is what is under test.
      await old.customStatement(
        'INSERT INTO nav_state (id, current_route, locale, theme_mode, '
        'light_variant, dark_variant, custom_theme_json, text_scale, '
        'filters_json, keyboard_shortcuts_json, sidebar_badge_modes_json, '
        'confirm_actions, status_tabs, contacts_sync_json, '
        'phone_actions_json, sidebar_menu_json, tasks_view, '
        'hide_unverified_users, hide_empty_panels, recent_entities_json, '
        'sidebar_collapsed, updated_at) VALUES (0, '
        "'/clients', 'de', 'dark', 'paper', 'midnight', '{\"l\":{}}', 1.2, "
        "'{\"client\":{}}', '{\"save\":null}', '{\"invoice\":\"overdue\"}', "
        "0, 0, '{\"enabled\":true}', '{\"tapToCall\":false}', "
        "'{\"layout\":\"grid\"}', 'kanban', 1, 0, '[]', 1, 1234)",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, schemaVersion);
      final prefs = DevicePrefsStore(db);
      await prefs.load();
      expect(prefs.read(DevicePrefKeys.locale), 'de');
      expect(prefs.read(DevicePrefKeys.themeMode), 'dark');
      expect(prefs.read(DevicePrefKeys.lightVariant), 'paper');
      expect(prefs.read(DevicePrefKeys.darkVariant), 'midnight');
      expect(prefs.read(DevicePrefKeys.customTheme), '{"l":{}}');
      expect(prefs.read(DevicePrefKeys.textScale), 1.2);
      expect(prefs.read(DevicePrefKeys.keyboardShortcuts), '{"save":null}');
      expect(
        prefs.read(DevicePrefKeys.sidebarBadgeModes),
        '{"invoice":"overdue"}',
      );
      expect(prefs.read(DevicePrefKeys.confirmActions), isFalse);
      expect(prefs.read(DevicePrefKeys.statusTabs), isFalse);
      expect(prefs.read(DevicePrefKeys.contactsSync), '{"enabled":true}');
      expect(prefs.read(DevicePrefKeys.phoneActions), '{"tapToCall":false}');
      expect(prefs.read(DevicePrefKeys.sidebarMenu), '{"layout":"grid"}');
      expect(prefs.read(DevicePrefKeys.tasksView), 'kanban');
      expect(prefs.read(DevicePrefKeys.hideUnverifiedUsers), isTrue);
      expect(prefs.read(DevicePrefKeys.hideEmptyPanels), isFalse);
      expect(prefs.read(DevicePrefKeys.sidebarCollapsed), isTrue);
      // Keys added after v12 have no `nav_state` column to carry from — they
      // start unset, which is what their defaults are for.
      const addedAfterV12 = {
        'default_items_tab',
        'list_density',
        'hours_format',
        'hide_peppol_status',
        'trusted_certificates_json',
        'sign_out_notice_json',
        'mobile_app_promo_json',
        'whats_new_json',
        'spell_check',
      };
      for (final key in DevicePrefKeys.all) {
        if (addedAfterV12.contains(key.name)) {
          expect(prefs.read(key), isNull, reason: key.name);
          continue;
        }
        expect(
          prefs.read(key),
          isNotNull,
          reason:
              '${key.name} was not carried — a key added to the list '
              'without a legacy column needs no carry, but then this seed '
              'must stop expecting it',
        );
      }
      // What stays in `nav_state` stays.
      final row = await db.navStateDao.current();
      expect(row?.currentRoute, '/clients');
      expect(row?.filtersJson, '{"client":{}}');
      await db.close();
    });

    test('re-running the v12 step never overwrites a preference changed or '
        'reset since', () async {
      // The upgrade re-runs whenever `user_version` did not land: the app
      // killed between the step's commit and drift's version write, or a build
      // rolled back past v12 and then upgraded again. By then the user may
      // have changed a preference, or reset one (its row removed) — and the
      // stale `nav_state` column must not come back over either.
      final schema = await verifier.schemaAt(11);
      final old = v11.DatabaseAtV11(schema.newConnection());
      await old.customStatement(
        'INSERT INTO nav_state (id, theme_mode, tasks_view, updated_at) '
        "VALUES (0, 'dark', 'kanban', 1)",
      );
      await old.close();

      var db = AppDatabase(schema.newConnection());
      await db.customSelect('SELECT 1').getSingle();
      final prefs = DevicePrefsStore(db);
      await prefs.load();
      await prefs.write(DevicePrefKeys.themeMode, 'light');
      await prefs.write(DevicePrefKeys.tasksView, null);
      await db.customStatement('PRAGMA user_version = 11');
      await db.close();

      db = AppDatabase(schema.newConnection());
      await db.customSelect('SELECT 1').getSingle();
      final again = DevicePrefsStore(db);
      await again.load();
      expect(again.read(DevicePrefKeys.themeMode), 'light');
      expect(again.read(DevicePrefKeys.tasksView), isNull);
      expect(await isSchemaIntact(db), isTrue);
      await db.close();
    });

    test('an upgrade interrupted after its first steps re-runs cleanly, '
        'keeping the outbox', () async {
      // drift runs `onUpgrade` outside any transaction and bumps
      // `user_version` only after it returns, so an app killed mid-upgrade
      // left the early columns added under the OLD version. The next launch
      // re-ran `ADD COLUMN` into "duplicate column name", and the opener
      // answered that by wiping the database — outbox included.
      final schema = await verifier.schemaAt(1);
      final old = v1.DatabaseAtV1(schema.newConnection());
      // The v2 and v3 steps landed; the kill came before the version bump.
      // Exactly the DDL drift's `addColumn` emits (`TEXT NULL`), so the result
      // is byte-for-byte the state a real interrupted upgrade leaves.
      await old.customStatement(
        'ALTER TABLE "nav_state" ADD COLUMN "keyboard_shortcuts_json" '
        'TEXT NULL',
      );
      await old.customStatement(
        'ALTER TABLE "nav_state" ADD COLUMN "sidebar_badge_modes_json" '
        'TEXT NULL',
      );
      // A queued offline edit — the thing a wipe would have destroyed.
      await old.customStatement(
        'INSERT INTO outbox (company_id, entity_type, entity_id, '
        'mutation_kind, payload, idempotency_key, next_attempt_at, '
        "created_at) VALUES ('co', 'client', 'tmp_1', 'create', '{}', "
        "'k1', 0, 0)",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, schemaVersion);
      final queued = await db.outboxDao.nextReady(companyId: 'co', now: 1);
      expect(queued.single.idempotencyKey, 'k1');
      await db.close();
    });

    test('an installed v12 database gains the list sort indexes', () async {
      final connection = await verifier.startAt(12);
      final db = AppDatabase(connection);
      await verifier.migrateAndValidate(db, schemaVersion);
      for (final t in kNumberSortedTables) {
        final rows = await db.customSelect('PRAGMA index_list($t)').get();
        expect(
          rows.map((r) => r.data['name']),
          contains('idx_${t}_company_number'),
          reason:
              'the upgrade must reach installed databases, not only '
              'fresh ones',
        );
      }
      await db.close();
    });

    test('v13 → v14 adds document_records beside the untouched documents '
        'scaffold, keeping the outbox', () async {
      final schema = await verifier.schemaAt(13);
      final old = v13.DatabaseAtV13(schema.newConnection());
      await old.customStatement(
        'INSERT INTO outbox (company_id, entity_type, entity_id, '
        'mutation_kind, payload, idempotency_key, next_attempt_at, '
        "created_at) VALUES ('co', 'invoice', 'i1', 'update', '{}', "
        "'k13', 0, 0)",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, schemaVersion);
      final tables =
          (await db
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'table'",
                  )
                  .get())
              .map((r) => r.data['name'] as String)
              .toSet();
      expect(tables, containsAll(['document_records', 'documents']));
      final queued = await db.outboxDao.nextReady(companyId: 'co', now: 1);
      expect(queued.single.idempotencyKey, 'k13');
      // The list's own indexes come from the generic pass, which only an
      // upgrade re-runs on an installed database.
      final indexes =
          (await db.customSelect('PRAGMA index_list(document_records)').get())
              .map((r) => r.data['name']);
      expect(indexes, contains('idx_document_records_company_updated'));
      await db.close();
    });

    test('v14 → v15 adds device_contact_links.raw_contact_id as null, keeping '
        'the links already written', () async {
      final schema = await verifier.schemaAt(14);
      final old = v14.DatabaseAtV14(schema.newConnection());
      await old.customStatement(
        'INSERT INTO device_contact_links (company_id, source_id, '
        "device_contact_id, hash, updated_at) VALUES ('co', 'c1', '42', "
        "'h', 0)",
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, schemaVersion);
      final link = (await db.deviceContactLinkDao.byCompany('co'))['c1']!;
      expect(link.deviceContactId, '42');
      // Null is "not checked yet" — the reconcile settles it on its first
      // update or delete of the row (`ownsDeviceContact`).
      expect(link.rawContactId, isNull);
      await db.close();
    });

    test('v15 → v16 adds contact_search as null, and a client found by a '
        'contact before and after the fill', () async {
      final schema = await verifier.schemaAt(15);
      final old = v15.DatabaseAtV15(schema.newConnection());
      final payload = jsonEncode({
        'contacts': [
          {'first_name': 'Jürgen', 'last_name': 'Öz', 'email': 'j@x.de'},
        ],
      });
      await old.customStatement(
        'INSERT INTO clients (id, company_id, updated_at, payload, name, '
        "number, email, display_name, balance) VALUES ('c1', 'co', 1, ?, "
        "'Acme', '', '', 'Acme', '0')",
        [payload],
      );
      await old.close();

      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, schemaVersion);
      // A direct read: the fill notifies no watcher, by design.
      Future<String?> contactSearch() async =>
          (await db
                      .customSelect(
                        "SELECT contact_search AS v FROM clients WHERE id = 'c1'",
                      )
                      .getSingle())
                  .data['v']
              as String?;
      Future<List<String>> found(String search) async => [
        for (final r
            in await db.clientDao
                .watchPage(
                  companyId: 'co',
                  offset: 0,
                  limit: 50,
                  search: search,
                )
                .first)
          r.id,
      ];
      expect(await contactSearch(), isNull);
      // Read through the payload until the fill reaches the row.
      expect(await found('jurgen'), ['c1']);

      expect(await db.clientDao.fillContactSearch(companyId: 'co'), 1);
      expect(await contactSearch(), 'jurgen\noz\nj@x.de');
      expect(await found('jurgen'), ['c1']);
      expect(await db.clientDao.fillContactSearch(companyId: 'co'), 0);
      await db.close();
    });

    test('a pre-squash v1 database missing a table still migrates', () async {
      // `user_version = 1` is not one schema. v1 was re-squashed repeatedly
      // while the app was pre-beta, so tables joined the baseline with no
      // version bump: `tags` landed in `8c4d8b7e` (2026-06-11) with
      // `schemaVersion` still 1. Every database written before that reports v1
      // and has no `tags` table, which the dumped v1 above cannot represent —
      // so the matrix test passes while the real upgrade throws.
      //
      // It shipped: the 2026-09-22 web demo failed `onUpgrade` on
      // `CREATE INDEX … ON tags` with `no such table: main.tags`, and
      // `openAppDatabase`'s catch wiped the whole database — pending offline
      // edits included — for every returning visitor.
      final schema = await verifier.schemaAt(1);
      final old = v1.DatabaseAtV1(schema.newConnection());
      await old.customStatement('DROP TABLE tags');
      final before = await old
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'tags'",
          )
          .get();
      expect(before, isEmpty, reason: 'the pre-squash state must have no tags');
      await old.close();

      // The real `AppDatabase`, so this exercises the shipped `onUpgrade`.
      final db = AppDatabase(schema.newConnection());
      await db.customSelect('SELECT 1').getSingleOrNull();
      final after = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name = 'tags'",
          )
          .get();
      expect(
        after,
        hasLength(1),
        reason: 'the upgrade must create the table it is about to index',
      );
      // The backstop that decides whether the user's data gets wiped.
      expect(await isSchemaIntact(db), isTrue);
      await db.close();
    });
  });

  group('fresh-install schema canaries', () {
    test(
      'a fresh database passes the isSchemaIntact runtime backstop',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        expect(await isSchemaIntact(db), isTrue);
        await db.close();
      },
    );

    test(
      'a fresh database has the late-added single-row + entity columns',
      () async {
        // Belt-and-suspenders column canaries, independent of the schema dump:
        // these were folded in from their historical migration steps and are
        // easy to drop by accident when editing table definitions.
        final db = AppDatabase(NativeDatabase.memory());
        await db.customSelect('SELECT 1').getSingle();

        Future<Set<String>> columnsOf(String table) async {
          final rows = await db.customSelect('PRAGMA table_info($table)').get();
          return rows.map((r) => r.data['name'] as String).toSet();
        }

        expect(
          await columnsOf('nav_state'),
          containsAll(<String>{
            'custom_theme_json',
            'recent_entities_json',
            'text_scale',
            'contacts_sync_json',
            'status_tabs',
            'hide_unverified_users',
            'hide_empty_panels',
            'sidebar_menu_json',
          }),
        );
        // The v5 address-book link index — a whole table rather than a column,
        // so `createAll()` dropping it would otherwise only surface as a
        // confusing "no such table" at contacts-sync time.
        expect(
          await columnsOf('device_contact_links'),
          containsAll(<String>{
            'company_id',
            'source_id',
            'device_contact_id',
            'hash',
          }),
        );
        expect(await columnsOf('saved_views'), contains('icon'));
        expect(await columnsOf('companies'), contains('first_day_of_week'));
        expect(
          await columnsOf('companies'),
          contains('use_comma_as_decimal_place'),
        );
        // Top-level Client Portal registration toggle (the server gates
        // registration on this column, not the deprecated settings copy).
        expect(await columnsOf('companies'), contains('client_can_register'));
        await db.close();
      },
    );

    test('a fresh database has the company-scoped perf + client-filter indexes '
        'and the list query uses one (no full table scan)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1').getSingle();

      Future<Set<String>> indexesOn(String table) async {
        final rows = await db.customSelect('PRAGMA index_list($table)').get();
        return rows.map((r) => r.data['name'] as String).toSet();
      }

      // Representative high-volume entity tables across the mixin set
      // (createPerformanceIndexes auto-discovers any company_id table).
      for (final t in [
        'clients',
        'invoices',
        'payments',
        'bank_transactions',
      ]) {
        final idx = await indexesOn(t);
        expect(
          idx,
          containsAll(<String>{
            'idx_${t}_company_updated',
            'idx_${t}_company_deleted',
          }),
          reason: '$t is missing its company-scoped performance indexes',
        );
      }

      // The targeted Client filter indexes (createClientFilterIndexes).
      expect(
        await indexesOn('clients'),
        containsAll(<String>{
          'idx_clients_company_country',
          'idx_clients_company_group',
        }),
      );

      // Prove the index is actually chosen for the canonical list query rather
      // than scanning the table.
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN SELECT * FROM clients '
            "WHERE company_id = 'co' ORDER BY updated_at DESC LIMIT 50",
          )
          .get();
      final detail = plan.map((r) => r.data['detail'] as String).join(' | ');
      expect(
        detail,
        contains('USING INDEX'),
        reason: 'list query should use an index, got: $detail',
      );
      expect(
        detail,
        isNot(contains('SCAN clients')),
        reason: 'list query must not full-scan clients, got: $detail',
      );
      await db.close();
    });

    test('each billing list opens on its sort index, not a sort of every '
        'row', () async {
      // The DAOs' real page-1 statements, recorded as drift sends them — the
      // index only helps while its expression matches theirs exactly.
      final recorder = _SelectRecorder();
      final db = AppDatabase(NativeDatabase.memory().interceptWith(recorder));
      await db.customSelect('SELECT 1').getSingle();

      final reads = <String, Future<Object?> Function()>{
        'invoices': () => db.invoiceDao
            .watchPage(companyId: 'co', offset: 0, limit: 50)
            .first,
        'quotes': () =>
            db.quoteDao.watchPage(companyId: 'co', offset: 0, limit: 50).first,
        'credits': () =>
            db.creditDao.watchPage(companyId: 'co', offset: 0, limit: 50).first,
        'purchase_orders': () => db.purchaseOrderDao
            .watchPage(companyId: 'co', offset: 0, limit: 50)
            .first,
        'recurring_invoices': () => db.recurringInvoiceDao
            .watchPage(companyId: 'co', offset: 0, limit: 50)
            .first,
      };
      expect(reads.keys, unorderedEquals(kNumberSortedTables));

      for (final MapEntry(key: table, value: read) in reads.entries) {
        recorder.selects.clear();
        await read();
        final (sql, args) = recorder.selects.firstWhere(
          (s) => s.$1.contains('FROM "$table"'),
        );
        // Qualified or not, depending on whether the DAO joins.
        expect(sql, matches(RegExp('LOWER\\(("$table"\\.)?"number"\\)')));
        final plan = await db
            .customSelect(
              'EXPLAIN QUERY PLAN $sql',
              variables: [for (final a in args) Variable(a)],
            )
            .get();
        final detail = plan.map((r) => r.data['detail'] as String).join(' | ');
        expect(
          detail,
          contains('idx_${table}_company_number'),
          reason: '$table page 1 should walk its sort index, got: $detail',
        );
        expect(
          detail,
          isNot(contains('USE TEMP B-TREE FOR ORDER BY')),
          reason:
              '$table page 1 must not sort every row (a temp B-tree for the '
              'LAST TERM — the id tie-break — is fine), got: $detail',
        );
      }
      await db.close();
    });
  });
}

/// Every SELECT the database runs, with its arguments.
class _SelectRecorder extends QueryInterceptor {
  final List<(String, List<Object?>)> selects = [];

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects.add((statement, args));
    return executor.runSelect(statement, args);
  }
}
