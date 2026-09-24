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
/// arrives as that string, so the code has to be read back out of it.
final _sqliteCodeInText = RegExp(r'SqliteException\((\d+)\)');

/// Classify an error thrown while opening, probing or migrating the database.
///
/// Unwraps drift's [DriftRemoteException] (errors from the background isolate
/// on native and from the web worker arrive wrapped) and reads the SQLite
/// result code from either a live [SqliteException] or its serialized text.
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

  final code = switch (e) {
    SqliteException(:final resultCode) => resultCode,
    _ => _codeFromText(e.toString()),
  };
  switch (code) {
    case _sqliteBusy ||
        _sqliteLocked ||
        _sqliteReadOnly ||
        _sqliteIoErr ||
        _sqliteCantOpen:
      return DbOpenFailureKind.transient;
    case _sqliteFull:
      return DbOpenFailureKind.storageFull;
    case _sqliteCorrupt || _sqliteNotADb:
      return DbOpenFailureKind.corrupt;
  }

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

/// Primary result code from a serialized `SqliteException(<extended>)`, or
/// null when [text] carries none.
int? _codeFromText(String text) {
  final match = _sqliteCodeInText.firstMatch(text);
  if (match == null) return null;
  final extended = int.tryParse(match.group(1)!);
  return extended == null ? null : extended & 0xFF;
}
