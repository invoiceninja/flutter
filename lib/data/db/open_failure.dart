import 'dart:async';

// The library is tagged @experimental for its wire protocol only; drift's own
// docs call its public API — DriftRemoteException included — stable.
// ignore: experimental_member_use
import 'package:drift/remote.dart' show DriftRemoteException;
import 'package:sqlite3/common.dart' show SqliteException;

import 'package:admin/data/db/db_open_exception.dart';

// SQLite primary result codes (https://sqlite.org/rescode.html).
const _sqliteBusy = 5;
const _sqliteLocked = 6;
const _sqliteReadOnly = 8;
const _sqliteIoErr = 10;
const _sqliteCorrupt = 11;
const _sqliteFull = 13;
const _sqliteCantOpen = 14;
const _sqliteNotADb = 26;

/// `SqliteException.toString()` starts with `SqliteException(<extended code>)`.
/// A remote error that crossed a web worker (or a serializing isolate channel)
/// arrives as that string, so the code has to be read back out of it — and so
/// does one inside a wrapper that only carries it as text
/// (`CouldNotRollBackException`).
final _sqliteCodeInText = RegExp(r'SqliteException\((\d+)\)');

/// Classify an error thrown while opening, probing or migrating the database.
///
/// Unwraps drift's [DriftRemoteException] (errors from the background isolate
/// on native and from the web worker arrive wrapped) and reads the SQLite
/// result code from either a live [SqliteException] or its serialized text
/// — every code in that text, when it carries several.
DbOpenFailureKind classifyDbOpenFailure(Object error) {
  var e = error;
  // Nested wrappers are possible (an isolate relaying a worker's error);
  // bounded so a pathological self-reference can't spin.
  for (var i = 0; i < 4 && e is DriftRemoteException; i++) {
    e = e.remoteCause;
  }
  if (e is DatabaseMigrationException) {
    // Judged by what failed the step: a full disk or a lock mid-upgrade is
    // the same failure it is anywhere else, and a fresh store fixes neither.
    final cause = classifyDbOpenFailure(e.cause);
    return cause == DbOpenFailureKind.transient ||
            cause == DbOpenFailureKind.storageFull
        ? cause
        : DbOpenFailureKind.migrationFailed;
  }
  if (e is TimeoutException) return DbOpenFailureKind.transient;
  if (e is DatabaseInUseException) return DbOpenFailureKind.inUse;

  final kind = switch (e) {
    SqliteException(:final resultCode) => _kindOfCode(resultCode),
    _ => _kindFromText(e.toString()),
  };
  if (kind != null) return kind;

  // Browser storage errors carry no SQLite code at all.
  final text = e.toString();
  if (text.contains('QuotaExceededError')) return DbOpenFailureKind.storageFull;
  // A failed upgrade that crossed the web worker as text. A code the switch
  // above knows has already decided, as the cause does natively; anything
  // else failed the step itself.
  if (text.contains('DatabaseMigrationException(')) {
    return DbOpenFailureKind.migrationFailed;
  }
  return DbOpenFailureKind.unknown;
}

/// What a SQLite result [code] — primary or extended — says about the store,
/// or null when it says nothing (a plain SQL error, say).
DbOpenFailureKind? _kindOfCode(int code) => switch (code & 0xFF) {
  _sqliteBusy ||
  _sqliteLocked ||
  _sqliteReadOnly ||
  _sqliteIoErr ||
  _sqliteCantOpen => DbOpenFailureKind.transient,
  _sqliteFull => DbOpenFailureKind.storageFull,
  _sqliteCorrupt || _sqliteNotADb => DbOpenFailureKind.corrupt,
  _ => null,
};

/// What the serialized `SqliteException(<extended>)`s in [text] say, or null
/// when none of them says anything.
///
/// drift's `CouldNotRollBackException` leads with its failed ROLLBACK — after
/// a full disk or an I/O error SQLite has already rolled back, so that is "no
/// transaction is active" — and names the error that failed the transaction
/// after it. So a later code may make the verdict one that leaves the store
/// alone (full disk first, then transient), but never a reset: corruption
/// counts only from the first code, as it always did. Destroying the store is
/// the one outcome that can't be taken back.
DbOpenFailureKind? _kindFromText(String text) {
  final kinds = [
    for (final match in _sqliteCodeInText.allMatches(text))
      switch (int.tryParse(match.group(1)!)) {
        final int code => _kindOfCode(code),
        null => null,
      },
  ];
  if (kinds.contains(DbOpenFailureKind.storageFull)) {
    return DbOpenFailureKind.storageFull;
  }
  if (kinds.contains(DbOpenFailureKind.transient)) {
    return DbOpenFailureKind.transient;
  }
  final first = kinds.isEmpty ? null : kinds.first;
  return first == DbOpenFailureKind.corrupt ? first : null;
}
