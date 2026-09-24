import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:admin/data/db/db_open_exception.dart';
import 'package:admin/data/services/token_storage.dart' show kSecureStorage;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
Future<String> _getOrCreateDbKey() async {
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
  if (existing != null && existing.length == 64) return existing;
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
    // unreadable, but `destroyDatabaseStore` handles that by renaming it to
    // `.broken.<ts>` and starting fresh. Better a fresh DB than a blank
    // window.
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
  return hex;
}

/// Native executor: a background-isolate SQLCipher connection over the
/// app-support file. Behavior is byte-identical to the pre-web-seam
/// implementation — this code was moved here verbatim.
Future<QueryExecutor> openDatabaseExecutor() async {
  final file = await _dbFile();
  final key = await _getOrCreateDbKey();
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

/// Move [file] and its sidecars aside as one `.broken.<ts>` snapshot, then
/// prune old snapshots — the body of [destroyDatabaseStore], taking the file
/// directly so tests can drive it without `path_provider`.
Future<void> quarantineDatabaseFile(File file) async {
  final dir = file.parent;
  final snapshot = p.join(
    dir.path,
    '$_kDbFileName.broken.${DateTime.now().millisecondsSinceEpoch}',
  );
  for (final suffix in _kSidecarSuffixes) {
    final sidecar = File('${file.path}$suffix');
    if (await sidecar.exists()) await sidecar.rename('$snapshot$suffix');
  }
  if (await file.exists()) await file.rename(snapshot);
  // Keep at most the two most-recent `.broken.*` snapshots so a device that
  // hits repeated corruption doesn't accumulate encrypted PII forever. Two
  // is enough for support to compare "this failure" against "the previous
  // one"; older snapshots are unrecoverable anyway.
  await pruneBrokenDbFiles(dir);
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
