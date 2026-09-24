import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:admin/data/db/db_open_exception.dart';
import 'package:admin/data/db/salvage.dart';
import 'package:admin/data/services/token_storage.dart' show kSecureStorage;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

final _log = Logger('AppDatabase');

/// Where the SQLCipher key lives in the OS keychain. v1 — bump on format
/// changes (e.g. moving from raw-bytes to a passphrase-derived key).
const _kDbEncryptionKeyName = 'invoiceninja.db.key.v1';

const _kDbFileName = 'invoiceninja.sqlite';

Future<File> _dbFile() async {
  final dir = await getApplicationSupportDirectory();
  return File(p.join(dir.path, _kDbFileName));
}

/// Fetch the per-install database encryption key, generating one on first
/// launch. The key is 256 random bits, hex-encoded, stored in the platform
/// keychain via [FlutterSecureStorage] (same trust boundary as auth tokens).
///
/// Returned as a hex string suitable for the raw-bytes form of `PRAGMA key`
/// — `"x'<hex>'"` — so SQLCipher uses it directly without PBKDF2 derivation.
/// `minted` is true when no usable key was stored and this call made one.
Future<({String key, bool minted})> _getOrCreateDbKey() async {
  // kSecureStorage pins iOS/macOS Keychain accessibility to
  // first_unlock_this_device — see token_storage.dart for the rationale.
  // Both call sites (auth tokens, this DB key) MUST use the same instance
  // so they land in the same keychain compartment.
  const secure = kSecureStorage;
  final String? existing;
  try {
    existing = await secure.read(key: _kDbEncryptionKeyName);
  } on PlatformException catch (e, st) {
    // The OS secret store is unreachable (e.g. a Linux snap whose
    // `password-manager-service` plug isn't connected → libsecret/keyring
    // locked). We can't derive the DB key. Surface a distinct, actionable
    // failure instead of letting the raw exception propagate into the
    // open orchestrator's reset path, which would destroy the DB file and
    // re-throw here every launch (the Linux crash-loop). A genuine
    // first-launch returns null here (not a throw), so key generation below
    // still runs normally.
    throw KeyringUnavailableException(e.message ?? e.code, st);
  }
  if (existing != null && existing.length == 64) {
    return (key: existing, minted: false);
  }
  final rng = Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  try {
    await secure.write(key: _kDbEncryptionKeyName, value: hex);
  } on PlatformException catch (e, st) {
    // errSecDuplicateItem (-25299) on macOS: an orphan item exists under
    // the same account name but our read() couldn't see its value. Common
    // after dev-build code-signing churn (the previous build wrote the
    // key under a different signing identity / accessibility flag than the
    // one we read with). We can't recover the existing key — delete the
    // orphan and retry. The SQLite file encrypted with the old key becomes
    // unreadable; the reset quarantines it, and salvage keeps it as
    // `.unrecovered.<ts>` ([readQuarantinedStore]) before starting fresh.
    // Better a fresh DB than a blank window.
    if (e.code == '-25299' ||
        (e.message?.contains('already exists in the keychain') ?? false)) {
      await secure.delete(key: _kDbEncryptionKeyName);
      await secure.write(key: _kDbEncryptionKeyName, value: hex);
    } else {
      // Any other write failure means the secret store is unwritable (Linux
      // keyring locked, etc.) — same actionable path as a failed read, not a
      // raw rethrow into the DB-reset loop.
      throw KeyringUnavailableException(e.message ?? e.code, st);
    }
  }
  return (key: hex, minted: true);
}

/// Set when a key had to be minted while a store already existed: the
/// keychain item that encrypted that store is gone, so it can never be
/// decrypted again and its salvage is reported as [DatabaseKeyLostException]
/// rather than as damage.
bool _keyLost = false;

/// Native executor: a background-isolate SQLCipher connection over the
/// app-support file. Behavior is byte-identical to the pre-web-seam
/// implementation — this code was moved here verbatim.
Future<QueryExecutor> openDatabaseExecutor() async {
  final file = await _dbFile();
  final hadStore = await file.exists();
  final (:key, :minted) = await _getOrCreateDbKey();
  if (minted && hadStore) {
    _keyLost = true;
    _log.severe(
      'No database key in the keychain, but a store exists at ${file.path}: '
      'it was encrypted with a key that is gone and will be quarantined',
    );
  }
  return NativeDatabase.createInBackground(
    file,
    // SQLite3MultipleCiphers (bundled via `hooks: user_defines: sqlite3:
    // source: sqlite3mc` in pubspec.yaml) reads existing SQLCipher 4
    // databases when these three pragmas run before any other query.
    // Raw-bytes form via `x'…'` skips PBKDF2 (we already generate 256
    // random bits).
    setup: (database) {
      database.execute("PRAGMA cipher = 'sqlcipher'");
      database.execute('PRAGMA legacy = 4');
      database.execute("PRAGMA key = \"x'$key'\"");
    },
  );
}

/// SQLite's companion files. This app runs in the default rollback-journal
/// mode (no `journal_mode` pragma is set), so `-journal` is the one that
/// matters; `-wal` / `-shm` are handled too in case that ever changes.
const _kSidecarSuffixes = ['-journal', '-wal', '-shm'];

/// Native recovery: rename the corrupt file to `<name>.broken.<ts>` (so
/// support can inspect it) and prune old snapshots. The next
/// [openDatabaseExecutor] opens a fresh file at the same path.
///
/// Sidecars move with it, first, keeping SQLite's `<db>-journal` pairing on
/// the snapshot. Renaming only the main file used to leave a hot journal
/// under the live name — and SQLite rolls a hot journal back into whatever
/// file is next opened under that name, i.e. the fresh store, writing the
/// old database's pages into it.
///
/// Returns whether the next open is guaranteed clean — always `true` here,
/// because a failed rename *throws* (a Windows sharing violation, say) rather
/// than returning. The bool exists for the web half, where the browser can
/// refuse a delete without any error the caller would otherwise see; the
/// shared signature lets `openAppDatabase()` stop inferring success.
Future<bool> destroyDatabaseStore() async {
  await quarantineDatabaseFile(await _dbFile());
  return true;
}

/// Names the one snapshot whose durable tables have not been carried into the
/// live store yet. A file rather than process state, so the salvage survives
/// the process: the app killed between the quarantine and the import, or the
/// boot screen's Reset followed by a relaunch. Only ever the snapshot the
/// latest quarantine made — an older one was imported by the reset that made
/// it, and reading it again would resurrect outbox rows delivered since.
const _kSalvageMarkerName = '$_kDbFileName.salvage';

/// Move [file] and its sidecars aside as one `.broken.<ts>` snapshot, mark it
/// for salvage, then prune old snapshots — the body of
/// [destroyDatabaseStore], taking the file directly so tests can drive it
/// without `path_provider`. Returns the snapshot's path, or null when there
/// was no store to move.
Future<String?> quarantineDatabaseFile(File file) async {
  final dir = file.parent;
  final snapshot = p.join(
    dir.path,
    '$_kDbFileName.broken.${DateTime.now().millisecondsSinceEpoch}',
  );
  final moved = await file.exists();
  // Marked before the move: a crash in between leaves a marker naming a
  // snapshot that never appeared, which the reader drops — the other order
  // could leave a moved store nobody salvages.
  if (moved) {
    await File(
      p.join(dir.path, _kSalvageMarkerName),
    ).writeAsString(p.basename(snapshot), flush: true);
  }
  for (final suffix in _kSidecarSuffixes) {
    final sidecar = File('${file.path}$suffix');
    if (await sidecar.exists()) await sidecar.rename('$snapshot$suffix');
  }
  if (moved) await file.rename(snapshot);
  // Keep at most the two most-recent `.broken.*` snapshots so a device that
  // hits repeated corruption doesn't accumulate encrypted PII forever. Two
  // is enough for support to compare "this failure" against "the previous
  // one"; older snapshots are unrecoverable anyway.
  await pruneBrokenDbFiles(dir);
  return moved ? snapshot : null;
}

/// `invoiceninja.sqlite.broken.<ts>`, optionally with the sidecar suffix it
/// was renamed alongside ([destroyDatabaseStore]).
final _brokenSnapshotName = RegExp(
  '^${RegExp.escape(_kDbFileName)}\\.broken\\.(\\d+)(?:-journal|-wal|-shm)?\$',
);

/// Delete `invoiceninja.sqlite.broken.<ts>` snapshots in [dir], keeping the
/// [keep] most-recent ones (by filename timestamp suffix, falling back to
/// modification time). A snapshot's sidecars (`…broken.<ts>-journal` etc.)
/// share its timestamp and are kept or deleted with it. Errors are logged but
/// swallowed — sweep failure must never block startup.
///
/// Exposed for tests (re-exported via `app_database.dart`); production calls
/// it from [destroyDatabaseStore] whenever a new broken snapshot is created.
Future<void> pruneBrokenDbFiles(Directory dir, {int keep = 2}) async {
  try {
    if (!await dir.exists()) return;
    final snapshots = <int, List<File>>{};
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith('$_kDbFileName.broken.')) continue;
      // Defensive fallback to mtime — we always write a numeric ts.
      final ts =
          int.tryParse(_brokenSnapshotName.firstMatch(name)?.group(1) ?? '') ??
          entity.statSync().modified.millisecondsSinceEpoch;
      (snapshots[ts] ??= []).add(entity);
    }
    if (snapshots.length <= keep) return;
    final newestFirst = snapshots.keys.toList()..sort((a, b) => b - a);
    for (final ts in newestFirst.skip(keep)) {
      for (final stale in snapshots[ts]!) {
        try {
          await stale.delete();
        } catch (e) {
          _log.warning('Failed to delete stale broken DB ${stale.path}: $e');
        }
      }
    }
  } catch (e, st) {
    _log.warning('pruneBrokenDbFiles failed', e, st);
  }
}

/// Read the durable and anchor tables ([kSalvagedTables]) out of the store
/// the latest reset quarantined, so `openAppDatabase` can carry them into the
/// live one. Null when nothing is awaiting salvage.
///
/// Raw `package:sqlite3`, not drift: opening it through `AppDatabase` would
/// run the very migrations that may have broken it. The same three cipher
/// pragmas as [openDatabaseExecutor] run first. An unreadable store — damaged
/// past reading, or encrypted with a key this install no longer has (a device
/// restored from a backup does not bring `first_unlock_this_device` keychain
/// items with it) — is renamed `.unrecovered.<ts>`, so snapshot pruning never
/// deletes it.
Future<QuarantinedStore?> readQuarantinedStore() async => readPendingSalvage(
  (await _dbFile()).parent,
  key: () async => (await _getOrCreateDbKey()).key,
  keyLost: _keyLost,
);

/// [readQuarantinedStore] with its inputs explicit — exposed for tests. [key]
/// returns null for an unencrypted store.
Future<QuarantinedStore?> readPendingSalvage(
  Directory dir, {
  required Future<String?> Function() key,
  bool keyLost = false,
}) async {
  final marker = File(p.join(dir.path, _kSalvageMarkerName));
  if (!await marker.exists()) return null;
  final name = (await marker.readAsString()).trim();
  // Taken before the import, never after it: a crash between the import's
  // commit and the marker's removal would import these rows again on the
  // next launch, resurrecting outbox rows delivered in between. Losing the
  // import instead still leaves the snapshot on disk.
  await marker.delete();
  if (name.isEmpty) return null;
  final snapshot = File(p.join(dir.path, name));
  if (!await snapshot.exists()) return null;
  final String? secret;
  try {
    secret = await key();
  } catch (e) {
    return QuarantinedStore(
      source: await retainQuarantinedStore(snapshot.path),
      error: e,
    );
  }
  final store = readQuarantinedStoreFrom(snapshot, key: secret);
  if (store.readable) return store;
  return QuarantinedStore(
    source: await retainQuarantinedStore(snapshot.path),
    error: keyLost ? const DatabaseKeyLostException() : store.error,
  );
}

/// [readQuarantinedStore]'s read of one file with an explicit [key] (null
/// for an unencrypted store) — exposed for tests.
QuarantinedStore readQuarantinedStoreFrom(File snapshot, {String? key}) {
  final raw.Database db;
  try {
    db = raw.sqlite3.open(snapshot.path);
  } catch (e) {
    return QuarantinedStore(source: snapshot.path, error: e);
  }
  try {
    if (key != null) {
      db.execute("PRAGMA cipher = 'sqlcipher'");
      db.execute('PRAGMA legacy = 4');
      db.execute("PRAGMA key = \"x'$key'\"");
    }
    // The key is only checked on the first read; fail here, not per table.
    final present = {
      for (final row in db.select(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      ))
        row['name'] as String,
    };
    final tables = <String, List<Map<String, Object?>>>{};
    for (final name in kSalvagedTables) {
      // A table the store predates (`device_prefs` in one older than v12)
      // has nothing to carry — not a failure worth a warning.
      if (!present.contains(name)) continue;
      try {
        final result = db.select('SELECT * FROM "$name"');
        tables[name] = [
          for (final row in result)
            {for (final column in result.columnNames) column: row[column]},
        ];
      } catch (e) {
        // One unreadable table must not cost the others.
        _log.warning('Salvage could not read $name from ${snapshot.path}: $e');
      }
    }
    return QuarantinedStore(source: snapshot.path, tables: tables);
  } catch (e) {
    return QuarantinedStore(source: snapshot.path, error: e);
  } finally {
    db.close();
  }
}

/// `invoiceninja.sqlite.broken.<ts>` / `.unrecovered.<ts>` — a kept copy's
/// main file, never one of its sidecars and never the live store.
final _retainedStoreName = RegExp(
  '^${RegExp.escape(_kDbFileName)}\\.(broken|unrecovered)\\.(\\d+)\$',
);

/// The old copies of the database this device still holds, newest first:
/// the `.broken` snapshots a reset kept and every `.unrecovered` one. Nothing
/// else ever deletes an `.unrecovered` copy, so Device Settings → Data lists
/// them for the user to delete.
Future<List<RetainedStore>> listRetainedStores() async =>
    listRetainedStoresIn((await _dbFile()).parent);

/// [listRetainedStores] with its directory explicit — exposed for tests.
Future<List<RetainedStore>> listRetainedStoresIn(Directory dir) async {
  if (!await dir.exists()) return const [];
  final copies = <RetainedStore>[];
  await for (final entity in dir.list()) {
    if (entity is! File) continue;
    final match = _retainedStoreName.firstMatch(p.basename(entity.path));
    if (match == null) continue;
    var bytes = await entity.length();
    for (final suffix in _kSidecarSuffixes) {
      final sidecar = File('${entity.path}$suffix');
      if (await sidecar.exists()) bytes += await sidecar.length();
    }
    copies.add(
      RetainedStore(
        path: entity.path,
        keptAt: DateTime.fromMillisecondsSinceEpoch(int.parse(match.group(2)!)),
        bytes: bytes,
        unrecovered: match.group(1) == 'unrecovered',
      ),
    );
  }
  return copies..sort((a, b) => b.keptAt.compareTo(a.keptAt));
}

/// Delete one copy [listRetainedStores] returned, with its sidecars. Refuses
/// any other file — the live store above all.
Future<void> deleteRetainedStore(String path) async {
  if (_retainedStoreName.firstMatch(p.basename(path)) == null) {
    throw ArgumentError.value(path, 'path', 'not a kept copy of the database');
  }
  for (final suffix in ['', ..._kSidecarSuffixes]) {
    final file = File('$path$suffix');
    if (await file.exists()) await file.delete();
  }
}

/// Rename a quarantined snapshot (and its sidecars) to `.unrecovered.<ts>`,
/// out of reach of [pruneBrokenDbFiles]. Returns the new path — or the old
/// one if the rename failed.
Future<String> retainQuarantinedStore(String source) async {
  final target = source.replaceFirst('.broken.', '.unrecovered.');
  if (target == source) return source;
  try {
    for (final suffix in _kSidecarSuffixes) {
      final sidecar = File('$source$suffix');
      if (await sidecar.exists()) await sidecar.rename('$target$suffix');
    }
    await File(source).rename(target);
    return target;
  } catch (e, st) {
    _log.warning('Could not retain the quarantined store $source', e, st);
    return source;
  }
}
