# Drift schema migrations

**The app is shipped (beta).** Installed databases hold real user data and unsynced outbox
edits, so every schema change now ships a real **forward migration**. The pre-launch
"squash to a single v1" workflow is retired — it survives only as a historical appendix
below. Skipping a migration is **silent data loss**: the `isSchemaIntact()` backstop in
`lib/data/db/app_database.dart` wipes (and re-syncs from the server) any local DB whose
columns don't match the code, taking unsynced offline edits with it.

The schema lives in the Dart table classes under `lib/data/db/`; `AppDatabase`
(`lib/data/db/app_database.dart`) owns `schemaVersion` and the `MigrationStrategy`.

## Changing the schema (the workflow)

1. **Edit the table(s)** under `lib/data/db/` (add a column, a table, etc.).
2. **Bump the version** — `int get schemaVersion => N;` in `app_database.dart`.
3. **Add an `onUpgrade` step** to the `MigrationStrategy`. Use drift's `stepByStep` (or a
   manual `onUpgrade` body with `m.addColumn` / `m.createTable`); each step transforms the
   previous version's shape into the next. Leave `onCreate` as the fresh-install path.
4. **Re-create new indexes inside `onUpgrade` too.** The performance and Client-filter
   indexes are created in `onCreate` via `createPerformanceIndexes(this)` /
   `createClientFilterIndexes(this)`, which **existing users never re-run**. Both use
   `CREATE INDEX IF NOT EXISTS` (idempotent), so call them again at the end of the relevant
   upgrade step so a new index reaches already-installed databases.
5. **Regenerate codegen:**
   ```sh
   dart run build_runner build --delete-conflicting-outputs
   ```
6. **Dump the new schema** (run *after* `schemaVersion` is `N`):
   ```sh
   dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/   # -> drift_schema_vN.json
   ```
7. **Generate the test helpers:**
   ```sh
   dart run drift_dev schema generate drift_schemas/ test/generated/
   ```
8. **Extend the matrix** in `test/data/db/migration_test.dart`:
   - append the new dump's sha256 to the `frozenSchemaHashes` map (this freezes vN — get it
     with `shasum -a 256 drift_schemas/drift_schema_vN.json`);
   - the upgrade-matrix test then drives every prior version through `onUpgrade` up to N;
   - to verify migrated *data* (not just shape), seed rows via `verifier.schemaAt(from)`
     before migrating (see drift's migration-testing docs).
9. **Verify:**
   ```sh
   flutter test test/data/db/migration_test.dart
   flutter analyze
   ```

## What CI enforces

`test/data/db/migration_test.dart` is the guard. After a schema change the **only** green
path is bump + `onUpgrade` + new dump + matrix entry:

- **Dump consistency** — `createAll()` must match the latest `drift_schema_vN.json`. Change
  a Dart table without re-dumping → red.
- **Version/dump coherence** — `schemaVersion` must equal the count of committed
  `drift_schema_v*.json` files (contiguous from 1). Bump without dumping, or vice-versa → red.
- **Frozen shipped dumps** — each shipped dump's sha256 is pinned in `frozenSchemaHashes`.
  Editing `drift_schema_v1.json` (i.e. re-squashing) → red. Landing v2 means *adding*
  `2: '<hash>'`, never editing v1.
- **Upgrade matrix** — every prior version must migrate cleanly up to the current schema; a
  missing or wrong `onUpgrade` step → red. (Dormant while only v1 exists.)

## `user_version = 1` is not one schema

The dumped `drift_schemas/drift_schema_v1.json` is the baseline as it stood at
the *end* of the pre-launch squashes, and real databases on disk predate it.
v1 was re-squashed repeatedly while the app was pre-beta, so tables joined the
baseline with no version bump — `tags` arrived in `8c4d8b7e` (2026-06-11) while
`schemaVersion` was still 1. A database written by any build before that
reports `user_version = 1` and has no `tags` table.

The matrix test cannot see this. It starts every run from the *dumped* v1, which
does have `tags`, so it stays green while the real upgrade throws.

It shipped. The 2026-09-22 web demo replaced a build from 2026-06-08, and every
returning visitor's `onUpgrade` died on

```
SqliteException(1): no such table: main.tags
  Causing statement: CREATE INDEX IF NOT EXISTS idx_tags_company_updated ON tags (company_id, updated_at)
```

because the `onUpgrade` steps only add `nav_state` columns and then run the
index pass over tables they assume already exist. `openAppDatabase`'s catch then
did what it is designed to do — destroyed the store and reopened it fresh —
so the failure presented as *every returning user silently losing their local
database, pending offline edits included*, and on web as a boot that never
painted at all.

**So `onUpgrade` creates any declared table the database is missing before the
index pass**, diffing `allTables` against `sqlite_master`. Two consequences
worth keeping:

- It is deliberately a diff, not `createAll()` — only genuinely absent tables
  are touched, and it does not depend on whether drift's generated DDL carries
  `IF NOT EXISTS`.
- A table that exists but is missing a *column* is a different failure, and
  `isSchemaIntact()` still resets for it. That is correct: a column add is what
  the versioned `onUpgrade` steps are for, and a database that skipped one
  cannot be repaired by guessing.

`test/data/db/migration_test.dart` pins it — the test drops `tags` from a v1
schema before migrating, and fails with the exact error above if the backstop
is removed. **Add a case there for any other table suspected of post-dating a
squash**; the matrix test will not cover it.

## The reset backstop is a last resort, not a migration path

`openAppDatabase()` + `isSchemaIntact()` (`app_database.dart`) self-heal a genuinely corrupt
or unreadable store by destroying it and re-syncing from the server (`wasReset: true` →
`/login`). That is a recovery net for corruption, **not** a way to "migrate" — it discards
the local DB, including any unsynced outbox edits. Never lean on it to absorb a schema
change; always ship the `onUpgrade`.

## Appendix — historical: the pre-launch squash (do NOT run)

Before launch, with no installed databases to upgrade, the accumulated migration history was
collapsed to a single `schemaVersion = 1` with an `onCreate`-only strategy — one schema
built straight from the current Dart tables. **This throws away every upgrade path and is
unsafe now that real users exist. Do not run it.** It's recorded here only to explain how v1
became the baseline.

<details>
<summary>The retired squash procedure</summary>

1. Make the schema `onCreate`-only (`schemaVersion => 1`; `createAll()` +
   `createPerformanceIndexes(this)` + `createClientFilterIndexes(this)`; delete the
   `onUpgrade` callback and any `lib/data/db/migrations.dart`).
2. `dart run build_runner build --delete-conflicting-outputs`
3. Reset the baseline:
   ```sh
   rm drift_schemas/*.json
   rm test/generated/schema_v*.dart test/generated/schema.dart
   dart run drift_dev schema dump lib/data/db/app_database.dart drift_schemas/
   dart run drift_dev schema generate drift_schemas/ test/generated/
   ```
4. Keep only fresh-install checks in `migration_test.dart` (no historical `schema_vN`
   imports while there is a single version).

</details>
