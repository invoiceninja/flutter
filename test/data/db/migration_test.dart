import 'dart:convert';
import 'dart:io';

import 'package:admin/data/db/app_database.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../generated/schema.dart';

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
  });
}
