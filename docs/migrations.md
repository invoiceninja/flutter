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
3. **Add an `onUpgrade` step** inside the existing `transaction(() async { … })` block in
   `app_database.dart`, and **make it idempotent**: add a column with
   `_addColumnIfMissing(m, table, table.column)` — never a bare `m.addColumn` — and a table
   with `m.createTable` (drift emits `IF NOT EXISTS`). Each step transforms the previous
   version's shape into the next. Leave `onCreate` as the fresh-install path. See
   § Every upgrade step is idempotent and transactional.
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
or unreadable store by quarantining it and starting fresh; the cache refills from the server
(`wasReset: true`, which the user is told about once — § What the user is told about a
reset — and which does not route to `/login`).
That is a recovery net for corruption, **not** a way to "migrate" — natively it carries the
durable and anchor tables across only when the old store can still be read, and on web it
carries nothing, unsynced outbox edits included. Never lean on it to absorb a schema change;
always ship the `onUpgrade`. Which failures may reach it at all: § A failed open destroys
the store only when a fresh store fixes it. What it keeps: § A reset carries the user's own
tables across.

## A device preference is not a schema change

Through v11 every device preference was a `nav_state` column, and all ten
schema bumps after release existed only to add one — each an `onUpgrade` run on
every installed database. Since v12 a preference is a `DevicePrefKeys` entry
(one `device_prefs` row) and needs no bump at all; `nav_state`'s column list is
frozen (`test/lint/nav_state_columns_frozen_test.dart`). How to add one, and how
v12 carried the old columns across exactly once — including after a repair and a
salvage — is in `docs/device-preferences.md`.

## Every upgrade step is idempotent and transactional

drift calls `onUpgrade` outside any transaction (from `beforeOpen`, drift 2.33
`db_base.dart:131`), writes the new `user_version` only after it returns, and latches a
migration error so every later query on that connection rethrows it (`engines.dart:505`).
The steps used to be bare `m.addColumn` calls, so an upgrade interrupted halfway (the app
killed, the tab closed) committed its first `ALTER TABLE`s under the old version number. The
next launch re-ran them into `duplicate column name`, and the opener's catch-all answered
that by wiping the database — pending outbox edits included.

Two things close it, and both are needed:

- **One `transaction()` around the whole body** (drift's own `alterTable` opens one during
  migrations; its docs wrap `runMigrationSteps` the same way), so a failing step rolls back
  its siblings instead of leaving a half-applied version.
- **Every step safe to run twice** — `_addColumnIfMissing` checks `PRAGMA table_info` first.
  The transaction commits *before* drift's separate `user_version` write, so a kill between
  the two re-runs the entire upgrade on the next launch.

Any exception out of the body is rethrown as `DatabaseMigrationException(from, to, cause)`
(`db_open_exception.dart`), so the opener can tell a failed upgrade from an unrelated error
that merely surfaced during the open. Pinned by `test/data/db/migration_test.dart` › "an
upgrade interrupted after its first steps re-runs cleanly, keeping the outbox": a v1 store
with the v2/v3 columns already added under `user_version = 1` (with the exact `TEXT NULL`
DDL drift emits) plus a queued outbox row.

## A failed open destroys the store only when a fresh store fixes it

The store is the only home of unsynced work (outbox, `id_remap`, dirty and `tmp_` rows), so
`openAppDatabase` classifies a failure — `classifyDbOpenFailure`,
`lib/data/db/open_failure.dart` — before choosing what to do:

| Kind | Examples | Result |
|---|---|---|
| `corrupt` | SQLITE_CORRUPT (11), SQLITE_NOTADB (26 — also a wrong key) | reset |
| `migrationFailed` | `DatabaseMigrationException` out of `onUpgrade` (the in-upgrade repair below also failed), unless its `cause` is transient or storageFull — then it is that kind | reset |
| schema drift | the open succeeds but the schema check is false | `repairSchema`; reset only on drift it refuses (`SchemaUnrepairableException`) |
| `transient` | BUSY / LOCKED / READONLY / IOERR / CANTOPEN, `TimeoutException` | store untouched |
| `inUse` | `DatabaseInUseException` — another copy of the app holds the store (§ A second copy of the app never opens the store) | store untouched, and the boot screen offers no Reset |
| `storageFull` | SQLITE_FULL, `QuotaExceededError` | store untouched |
| `unknown` | anything else | store untouched |

"Store untouched" means native retries once after 2 s, then `DatabaseUnavailableException`
reaches `main`, which renders the boot screen with advice for that kind. It used to reset on
*every* exception. On web the open is bounded at 5 s (`database_opener_web.dart`) and times
out whenever another tab — or one that just closed — holds the store's lock, so merely
having the app open twice abandoned the store, and the next load swept it.

- **Errors arrive wrapped.** From the native background isolate a failure is a
  `DriftRemoteException` around the `SqliteException`; from the web worker it is that
  exception's *text* (drift's `protocol.dart` sends `error.toString()`). The classifier
  unwraps the first and parses `SqliteException(<code>)` out of the second;
  `test/data/db/open_failure_test.dart` pins the unwrap against a real background isolate.
  A failed upgrade crosses the worker as text too, so text naming
  `DatabaseMigrationException(` with no code in it is `migrationFailed` — it used to be
  `unknown`, whose advice ("close your other tab") the boot screen then gave on every reload.
- **A failed upgrade is judged by what failed it.** `DatabaseMigrationException.cause` is
  classified first: SQLITE_FULL or a lock mid-upgrade is `storageFull` / `transient`, store
  untouched, exactly as it would be anywhere else in the open. Filing every migration
  failure under `migrationFailed` reset the store over a full disk.
- **A failed rollback is judged by every code it carries.** After SQLITE_FULL or IOERR,
  SQLite has already rolled the transaction back, so drift's own `ROLLBACK` fails ("no
  transaction is active") and it throws `CouldNotRollBackException` (drift 2.33,
  `rollbackAfterException`). Its text *leads* with that SQLITE_ERROR and names the real
  failure after it, so reading the first code only made a full disk mid-upgrade
  `migrationFailed` — a reset. The classifier reads every `SqliteException(<code>)` in the
  text: any code saying storage full, then any saying transient, wins. A later code never
  makes a reset, though — corruption counts only from the first code, as it always did, so
  no text resets a store the old reading kept. It deliberately does not unwrap to `cause`:
  the rollback's own error can be the only sign of a failing disk (a step that threw a Dart
  error, then a `ROLLBACK` that hit an I/O error), and drift's text carries both.
- **An error during the schema check or the repair is not drift.** The open loop uses a
  check that throws (`_schemaIntact`) and catches only `SchemaUnrepairableException` around
  `repairSchema`, so a BUSY or IOERR there reaches the classifier. `isSchemaIntact` — which
  answers false for any error — stays for its other two callers, and used to be the open
  loop's too: a lock while the opener checked the schema reset the store.
- **No in-process retry on web.** A timed-out `WasmDatabase.open` can still complete later
  and hold the lock in the same page, so a second open would queue behind our own abandoned
  attempt. The boot screen's Try again (a page reload) is the clean retry.
- **A native reset moves the sidecars too.** `quarantineDatabaseFile`
  (`database_opener_io.dart`) renames `-journal` / `-wal` / `-shm` with the main file,
  keeping SQLite's `<db>-journal` pairing on the `.broken.<ts>` snapshot. Renaming only the
  main file left a hot journal under the live name, and SQLite rolls a hot journal into
  whatever file is next opened under that name — the fresh store. `pruneBrokenDbFiles` keeps
  or deletes a snapshot and its sidecars together.

"Reset" means quarantine, not delete — § A reset carries the user's own tables across. The
boot screen's copy says what that keeps on each platform instead of promising that
everything is re-downloaded.

## A second copy of the app never opens the store

Two processes on one store both drained its outbox, so every change went out twice. A second
copy whose open hit a lock also showed the boot screen's Reset. That Reset moved the store out
from under the first copy, and POSIX renames an open file without complaint. The first copy
kept writing into the snapshot, and the next open salvaged it half-written.

Three ways to get a second copy:
- Linux: the GTK runner is `G_APPLICATION_NON_UNIQUE`. Calendar OAuth needs that; see
  `calendar_connection_view_model.dart`.
- macOS: `open -n`.
- Windows: two launches racing the runner's `FindWindow` check.

`holdStoreLock` (`lib/data/db/store_lock.dart`) is the first thing `openDatabaseExecutorAt`
does and the first thing `destroyDatabaseStoreAt` does.

- **A lock file, not the store.** The lock sits on `invoiceninja.instance.lock` beside the
  store, not on the store itself: SQLite locks the store's own byte ranges, and Windows locks
  are mandatory. The name is also outside `invoiceninja.sqlite*`, which snapshot pruning
  deletes.
- **Before the key is read.** A second copy that read the keychain and got nothing back
  would mint a key and write it over the one that encrypts the first copy's store.
- **Held for the life of the process: never closed, never reopened.** POSIX drops every lock
  a process holds on a file the moment *any* descriptor for that file is closed, and an
  unreachable `RandomAccessFile` is closed when it is collected. So:
  - the handle lives in a top-level map, and a second call reuses it;
  - the calls are serialised, so two can't race past the map;
  - the process ending releases the lock, so a crash can't leave it stuck.
- **Only a positive "held by another process" refuses** (`storeLockHeldElsewhere`):
  - `fcntl(F_SETLK)` fails with EAGAIN or EACCES: 11 or 13 on Linux and Android, 35 or 13 on
    Darwin;
  - `LockFileEx` fails with ERROR_LOCK_VIOLATION (33) on Windows.

  Any other failure, such as a file system without lock support, logs a warning and opens
  without the lock, exactly as before. A disk that can't be locked is no reason to lock the
  user out.
- **A refusal is `DatabaseInUseException`, which maps to `DbOpenFailureKind.inUse`.** That is
  not a reset kind, so the open retries once after 2 s. The retry covers Windows, which
  releases a dead process's locks a moment late. After that, the boot screen says the app is
  open in another window and offers no Reset.
- **One byte past the holder's process id.** The holder writes its `pid` at the start of the
  file and locks byte `kStoreLockedByte`. It seeks back to the start after truncating:
  append mode opens at the end of the file, and truncating leaves the position there. The
  first cut wrote the id after a run of zero bytes, so it never parsed once an earlier launch
  had left a file. A refused open reads that id, and when it is its own
  id it carries on. That is a hot restart on Windows: `main` runs again while the previous
  isolate's handle is still open, and Windows locks belong to the handle. Windows locks are
  mandatory, so a whole-file lock would leave the id unreadable. On POSIX a process can always
  take its own lock again. Either way, collecting the old handle later can drop the lock, so
  after a hot restart the check may be off until the next cold start. That only happens in
  debug builds.
- **Web is untouched.** It has no `dart:io`. The browser's own lock on the store is what makes
  a second tab's open time out (§ A failed open destroys the store only when a fresh store
  fixes it).

`test/data/db/store_lock_test.dart` pins it. Its second copy is a real process:
`_store_lock_holder.dart` under the Dart VM binary itself, never the SDK's `dart` wrapper and
never through a shell. On Windows the wrapper is `dart.bat`, whose `dart.exe` child outlived
a kill and kept holding the lock. The tests skip where no process can be started. They check that the second copy is refused before the key is read, that its Reset
moves nothing, that the lock dies with its holder, and that it survives repeated calls in one
process. CI runs them on Linux; run them on macOS and Windows by hand when this changes.

## Drift is repaired in place, and only the cache may be dropped

`repairSchema` (`lib/data/db/schema_repair.dart`) brings a database to the declared shape
without a reset: a missing table is created; missing columns are added in place when each is
nullable or has a SQL default (rows kept); a table missing a column that can't be added
(NOT NULL, no default) is dropped and recreated — **only** if it is a cache table.
`lib/data/db/table_retention.dart` classifies every table: *durable* (the outbox, `id_remap`,
saved views, `nav_state`, `device_prefs`, `drafts` — data that exists nowhere else), *anchor* (`accounts`,
`companies`, `users` — `restore()` signs the user out without them) and *cache* (everything
the server can send again). A durable or anchor table in that state throws
`SchemaUnrepairableException` and the opener falls back to the reset. Any change to a cache
table resets `sync_state_rows`, `companies.last_sync_at` and `dashboard_cache`, so rows kept
through an added column (holding its default, not the server's value) download again.

It runs in two places: when an open succeeds but `isSchemaIntact()` fails, and inside
`onUpgrade` when the versioned steps throw — they roll back, and the repair then reaches the
declared shape directly (with a forced cursor reset, so the cache re-downloads anything a
skipped step would have transformed). Every step so far only adds columns and tables, so the
shape is all an upgrade has to produce. **A future step that transforms durable data cannot
lean on this** — the repair restores shape, not data; such a step must be written so it can
be re-run, and tested failing. One transaction, so a refusal changes nothing.
`test/data/db/schema_repair_test.dart` pins it, including a v10 store whose upgrade fails and
is repaired instead of reset; a new table without a classification fails that file.

## A reset carries the user's own tables across

A reset moves the store aside (`.broken.<ts>` natively) and the next open imports its
*durable* and *anchor* tables — `kSalvagedTables`, `lib/data/db/salvage.dart` — into the
fresh one: the outbox with its ids and idempotency keys, `id_remap`, saved views, device
preferences, and the rows `restore()` resumes the session from. Only the cache is lost, and
it downloads again. It used to delete the store outright, taking the only copy of every
change that had not reached the server.

- **Read raw, never through `AppDatabase`.** `readQuarantinedStoreFrom`
  (`database_opener_io.dart`) opens the snapshot with `package:sqlite3` and the same cipher
  pragmas as the live open; going through drift would run the very migrations that may have
  broken it. One unreadable table does not cost the others — but it is listed in
  `QuarantinedStore.unreadableTables`, and `importSalvaged` reports it as left behind. It
  used to be skipped silently, so an unreadable outbox imported as an empty one: "rebuilt",
  and the snapshot still holding the work stayed prunable.
- **Read with the key the open used — never a second keychain read.**
  `readQuarantinedStoreIn` takes the key `openDatabaseExecutorAt` fetched (`_liveStore`), and
  so does the reset's own reopen of the store: the key is kept per store path for the life of
  the process.
  It used to fetch again through `_getOrCreateDbKey`. If that read came back empty, it
  *minted* a key and wrote it over the one the live store had just been opened with, so the
  snapshot read as unrecoverable and the live store as corrupt on the next launch. A salvage
  that can't get a key keeps the snapshot as `.unrecovered.<ts>`. By then the marker is gone,
  so the salvage is never retried into a store that has moved on.
- **Only the first snapshot since the last open, and only once.** `quarantineDatabaseFile`
  writes `invoiceninja.sqlite.salvage`, naming its snapshot, *before* it moves the store (a
  crash in between leaves a marker for a snapshot that never appeared, which is dropped).
  A marker naming a snapshot that still exists is left alone: every successful open consumes
  the marker, so the store being moved now never finished an open — the reset's fresh store
  that failed too, or the one the boot screen's Reset clears. Re-marking it orphaned the
  snapshot that held the outbox, and the next launch reported a clean rebuild. That later
  store is kept as `.unrecovered.<ts>` rather than trusted to be empty, and
  `pruneBrokenDbFiles` never deletes the marked snapshot.
  `readPendingSalvage` deletes the marker *before* importing. An older snapshot was imported
  by the reset that made it, and its outbox rows may have been delivered since — importing it
  again would resurrect them and send them twice. Deleting after the commit risks exactly
  that on a crash in between; deleting first risks only losing the import, with the snapshot
  still on disk.
- **A full disk or a lock puts the salvage off; it does not lose it.** The import is one
  transaction, so SQLITE_FULL or a busy/I-O error mid-import leaves nothing behind — but the
  marker was already gone, and the snapshot went to `.unrecovered.<ts>`. Freeing space and
  relaunching never retried it, and Device Settings → Data can only delete a kept copy. Now
  `_salvageInto` asks `salvageRetries` (`salvage.dart`: `storageFull` or `transient` per
  `classifyDbOpenFailure`); for those, `requeueSalvage` writes the marker again, with an
  attempt count on its second line, and the open fails with `DatabaseUnavailableException` —
  the boot screen's "Try again" and Reset, as for any failure that leaves the store alone.
  The same applies to a snapshot whose *read* failed that way (`readPendingSalvage` leaves it
  `.broken` for the caller). Two things make this safe:
  - **It re-marks only after a rollback,** so the marker-first rule above still holds.
  - **The app never starts on the fresh store while a salvage is pending.** Started, it
    would queue new changes under outbox ids 1…n, which the snapshot's rows also hold: a
    later import would refuse them (`OR IGNORE`) or drain them after the newer ones.
  After `kMaxSalvageAttempts` (3) the snapshot is kept and reported as before, so an error
  that never clears cannot keep the app from starting. Any other import error (an
  unbindable value, a constraint) is not put off. Pinned by `salvage_test.dart` § a full disk
  mid-import (a real SQLITE_FULL from an in-memory store capped by `max_page_count`).
- **A file, not process state.** Every successful open looks for the marker (`finish` in
  `openAppDatabase`), not only a reset in the same process: the launch that quarantined may
  have died before importing, and the boot screen's Reset — a bare `destroyDatabaseStore` —
  is imported on relaunch.
- **Forgiving on shape, strict on count.** `importSalvaged` copies only the columns both
  schemas have, skips a table whose rows lack a column the current schema requires, and
  inserts `OR IGNORE`. A table comes across short when it was unreadable, when it was
  skipped, or when any of its rows was not inserted. Such a table is listed in
  `LocalDataSalvaged.incompleteTables`, and the snapshot is then kept as `.unrecovered.<ts>`.
  `companies.last_sync_at` is reset, because the cache it described is gone.
  - **Rows are counted as they go in.** The import inserts one row at a time and adds up what
    SQLite reports as changed; an ignored row changes nothing. It used to compare a
    `COUNT(*)` afterwards. A row dropped on an id the fresh store already held then went
    unnoticed whenever the table ended up as full as the snapshot.
- **Unreadable is kept, never pruned.** A store damaged past reading, or one whose key is
  gone, is renamed `.unrecovered.<ts>`, out of `pruneBrokenDbFiles`' reach. A lost key is
  told apart: `_getOrCreateDbKey` minting a key while a store already exists means the item
  that encrypted it is gone (a device restored from a backup does not bring
  `first_unlock_this_device` keychain items), reported as `DatabaseKeyLostException`.
- **The outcome is `OpenedDatabase.recovery`** — sealed `LocalDataRecovery`:
  `LocalDataSalvaged` or `LocalDataUnrecoverable`. `main` logs it at WARNING, so it lands in
  the diagnostics log, and the user is told once — § What the user is told about a reset.

Pinned by `test/data/db/salvage_test.dart`, including a round trip through an encrypted
file — `flutter test` builds sqlite3mc, so the wrong-key case genuinely fails to read.

**Web has no reader yet.** `readQuarantinedStore` returns null there, so a web reset still
loses the durable tables. Closing it means reading the abandoned store's bytes
(`IndexedDbFileSystem` / OPFS) into an in-memory wasm sqlite before it is deleted.

## What the user is told about a reset

A reset's outcome used to reach only the diagnostics log: a user whose unsynced changes could
not be recovered was never told, and one whose changes all came across watched their lists
empty and refill with no explanation. `LocalDataRecoveryNotice`
(`lib/ui/features/boot/local_data_recovery_notice.dart`), mounted in `MaterialApp.router`'s
builder beside `CallLogPrompter`, now says it once, after the first frame:

- **Everything carried across** (`LocalDataSalvaged` with no `incompleteTables`) is a toast
  that counts the unsynced changes kept: nothing was lost, so nothing blocks the user.
- **Something left behind** (`incompleteTables`), **nothing readable**
  (`LocalDataUnrecoverable`), and **a reset with nothing carried** (`wasReset` with no
  recovery — web, which has no reader yet) are dialogs, because the user may have lost work a
  toast could scroll past. The two native ones point at Settings → Device Settings → Data.
- It needs a context **inside** the router's `Navigator` (its own sits above it), which exists
  only after the first frame, so it waits up to ten frames for one — `localDataNoticeFor`
  holds the mapping, pinned by `test/ui/features/boot/local_data_recovery_notice_test.dart`.
- **Never over the lock screen, and never about wiped data.** While the lock is up, or while no
  one is signed in, the notice only listens (`LocalDataNoticeHold`). When both clear, it shows
  after the next frame; by then the router has swapped `/lock` or `/login` out. A dialog
  pushed onto `/lock` used to go with that page when unlocking replaced it, so the user was
  never told, and a toast expired behind the unlock prompt.
  - Held through a sign-out, it is told after the next sign-in.
  - A wipe of the data before then drops the toast unseen
    (`LocalDataNoticeSlot.forgetKeptChanges`, through `AuthRepository.onBeforeDataWipe`).
    That covers a sign-out, or a sign-in whose different identity wipes the store. The toast
    counts changes as kept, which the wipe made untrue.
  - A dialog stays after a wipe: the work it says was lost stays lost, and the copy it
    points to is kept.
  - Released on the lock alone, the lock screen's Sign out let the toast show on `/login`,
    saying changes were kept that the sign-out had just wiped.
- **Once per launch, not once per widget.** `LocalDataNoticeSlot` is take-once, and it lives in
  `_InvoiceNinjaAppState`, so a remounted notice finds it already taken. The guard used to
  live in the notice's own State, and a remount replaced that State.

**The copies a reset keeps leave the device only through the user.** Device Settings → Data
lists every kept copy — the recent `.broken.<ts>` snapshots and every `.unrecovered.<ts>` one —
with its age, its size and a Delete that always asks (`LocalDataCopies`,
`lib/ui/features/settings/widgets/local_data_copies.dart`, over `listRetainedStores` /
`deleteRetainedStore` in `database_opener_io.dart`; web keeps no copies). Nothing else ever
deletes an `.unrecovered` copy, so without this one repair failure after another would pile up
encrypted databases for good. `deleteRetainedStore` refuses any file that isn't a kept copy —
the live store above all. There is no export and no restore: a copy is encrypted with this
device's key, so it means nothing anywhere else, and re-importing it would fail exactly as the
import that kept it did.

The boot screen that renders when the store can't be opened at all is
`LocalDataUnavailableApp` (`lib/ui/features/boot/local_data_unavailable_app.dart`): plain
English, because it paints before `Services` and localization exist, with per-kind and
per-platform copy, and injectable seams so both platforms are widget-tested
(`local_data_unavailable_app_test.dart`). It scrolls, and its buttons wrap rather than
overflow — a landscape phone, or a large text size, is smaller than the screen assumed. On a
desktop it offers Quit. The app draws its own window buttons on Windows and Linux, and this
screen isn't the app, so without Quit the "already open in another window" screen had no way
out at all.

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
