import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:admin/data/db/db_open_exception.dart';
import 'package:admin/data/db/open_failure.dart';

/// An error that only knows its serialized form — what a `SqliteException`
/// becomes after crossing drift's web-worker channel (`protocol.dart` sends
/// `error.toString()`).
class _Serialized implements Exception {
  _Serialized(this.text);
  final String text;
  @override
  String toString() => text;
}

SqliteException _sqlite(int code) =>
    SqliteException(extendedResultCode: code, message: 'test');

void main() {
  group('classifyDbOpenFailure', () {
    // The whole point of the classifier: only a failure a fresh store fixes
    // may destroy the store, because the store holds the user's unsynced work.
    test('a lock, busy handle or I/O error is transient — never a reset', () {
      for (final code in [5, 6, 8, 10, 14]) {
        final kind = classifyDbOpenFailure(_sqlite(code));
        expect(kind, DbOpenFailureKind.transient, reason: 'code $code');
        expect(kind.resetRecovers, isFalse, reason: 'code $code');
      }
    });

    test('extended result codes resolve to their primary code', () {
      // SQLITE_IOERR_READ = 266, SQLITE_BUSY_SNAPSHOT = 517.
      expect(classifyDbOpenFailure(_sqlite(266)), DbOpenFailureKind.transient);
      expect(classifyDbOpenFailure(_sqlite(517)), DbOpenFailureKind.transient);
    });

    test('the web open timing out behind a lock is transient', () {
      // `database_opener_web.dart` bounds `WasmDatabase.open` at 5 s; the
      // usual cause is the app open in another tab. This used to reset.
      expect(
        classifyDbOpenFailure(TimeoutException('open')),
        DbOpenFailureKind.transient,
      );
    });

    test('a full disk or quota is storageFull, not a reset', () {
      expect(classifyDbOpenFailure(_sqlite(13)), DbOpenFailureKind.storageFull);
      expect(
        classifyDbOpenFailure(_Serialized('QuotaExceededError: no space')),
        DbOpenFailureKind.storageFull,
      );
      expect(DbOpenFailureKind.storageFull.resetRecovers, isFalse);
    });

    test('another copy of the app holding the store is in use — never a '
        'reset, which would move the store out from under that copy', () {
      final kind = classifyDbOpenFailure(const DatabaseInUseException());
      expect(kind, DbOpenFailureKind.inUse);
      expect(kind.resetRecovers, isFalse);
    });

    test('corrupt / not-a-database resets', () {
      for (final code in [11, 26]) {
        final kind = classifyDbOpenFailure(_sqlite(code));
        expect(kind, DbOpenFailureKind.corrupt, reason: 'code $code');
        expect(kind.resetRecovers, isTrue);
      }
    });

    test('a failed onUpgrade step resets', () {
      final kind = classifyDbOpenFailure(
        DatabaseMigrationException(from: 3, to: 11, cause: _sqlite(1)),
      );
      expect(kind, DbOpenFailureKind.migrationFailed);
      expect(kind.resetRecovers, isTrue);
    });

    test('a failed onUpgrade step is judged by what failed it', () {
      // Filing every migration failure under `migrationFailed` reset the
      // store over a full disk or a lock mid-upgrade — the failures a fresh
      // store does not fix. Only a step that genuinely cannot apply resets.
      DbOpenFailureKind of(Object cause) => classifyDbOpenFailure(
        DatabaseMigrationException(from: 11, to: 12, cause: cause),
      );
      expect(of(_sqlite(13)), DbOpenFailureKind.storageFull);
      expect(of(_sqlite(5)), DbOpenFailureKind.transient);
      expect(of(_sqlite(266)), DbOpenFailureKind.transient);
      expect(of(TimeoutException('upgrade')), DbOpenFailureKind.transient);
      expect(of(_sqlite(1)), DbOpenFailureKind.migrationFailed);
      expect(of(StateError('step')), DbOpenFailureKind.migrationFailed);
    });

    test('a failed onUpgrade step that crossed the web worker as text', () {
      // From the worker the error is its `toString()`. A SQLite code in it
      // decides, as it does natively; without one it is still a failed
      // upgrade — not `unknown`, whose advice is "close your other tab", on
      // every reload.
      DbOpenFailureKind of(Object cause) => classifyDbOpenFailure(
        _Serialized(
          DatabaseMigrationException(from: 11, to: 12, cause: cause).toString(),
        ),
      );
      expect(of(StateError('step')), DbOpenFailureKind.migrationFailed);
      expect(of(_sqlite(1)), DbOpenFailureKind.migrationFailed);
      expect(of(_sqlite(13)), DbOpenFailureKind.storageFull);
      expect(of(_sqlite(5)), DbOpenFailureKind.transient);
    });

    test('a step that failed on a full disk is not filed under the failed '
        'rollback after it', () {
      // On a full disk or an I/O error SQLite rolls the transaction back
      // itself, so drift's own ROLLBACK then fails ("no transaction is
      // active") and it throws CouldNotRollBackException — whose text leads
      // with that rollback error. Read first-code-only, a full disk mid-upgrade
      // was a failed upgrade, and the store was reset.
      Object failedRollback(Object cause, Object rollback) =>
          CouldNotRollBackException(cause, StackTrace.empty, rollback);
      DbOpenFailureKind of(Object cause) => classifyDbOpenFailure(
        DatabaseMigrationException(from: 11, to: 12, cause: cause),
      );

      expect(
        of(failedRollback(_sqlite(13), _sqlite(1))),
        DbOpenFailureKind.storageFull,
      );
      expect(
        of(failedRollback(_sqlite(266), _sqlite(1))),
        DbOpenFailureKind.transient,
      );
      expect(
        classifyDbOpenFailure(
          _Serialized(
            DatabaseMigrationException(
              from: 11,
              to: 12,
              cause: failedRollback(_sqlite(13), _sqlite(1)),
            ).toString(),
          ),
        ),
        DbOpenFailureKind.storageFull,
        reason: 'the same failure, crossed the web worker as text',
      );
      expect(
        classifyDbOpenFailure(failedRollback(_sqlite(10), _sqlite(1))),
        DbOpenFailureKind.transient,
        reason: 'outside an upgrade too',
      );
      expect(
        of(failedRollback(StateError('step'), _sqlite(10))),
        DbOpenFailureKind.transient,
        reason: 'a rollback that hit an I/O error is the disk failing',
      );
      expect(
        of(failedRollback(StateError('step'), _sqlite(1))),
        DbOpenFailureKind.migrationFailed,
      );
      expect(
        classifyDbOpenFailure(failedRollback(_sqlite(11), _sqlite(1))),
        DbOpenFailureKind.unknown,
        reason: 'a later code never makes it a reset — only the first did',
      );
      expect(
        classifyDbOpenFailure(
          _Serialized(
            'SqliteException(1): x QuotaExceededError SqliteException(26): y',
          ),
        ),
        DbOpenFailureKind.storageFull,
        reason: 'as before: no code in it decided, so the quota does',
      );
    });

    test('reads the code back out of a serialized (web worker) error', () {
      expect(
        classifyDbOpenFailure(
          _Serialized(
            'SqliteException(26): while executing, file is not a database',
          ),
        ),
        DbOpenFailureKind.corrupt,
      );
      expect(
        classifyDbOpenFailure(
          _Serialized('SqliteException(5): database is locked'),
        ),
        DbOpenFailureKind.transient,
      );
    });

    test('anything unrecognised is unknown, which never resets', () {
      final kind = classifyDbOpenFailure(StateError('who knows'));
      expect(kind, DbOpenFailureKind.unknown);
      expect(kind.resetRecovers, isFalse);
      // A plain SQL error outside a migration is not evidence of corruption.
      expect(classifyDbOpenFailure(_sqlite(1)), DbOpenFailureKind.unknown);
    });

    test(
      'unwraps a real DriftRemoteException from a background isolate',
      () async {
        // Native opens through `NativeDatabase.createInBackground`, so a
        // failure reaches `openAppDatabase` wrapped in drift's remote
        // exception. A classifier that only matched `SqliteException` would
        // file a genuinely corrupt store under "unknown" and never recover it.
        final dir = Directory.systemTemp.createTempSync('open_failure_');
        addTearDown(() => dir.delete(recursive: true));
        final file = File(p.join(dir.path, 'garbage.sqlite'))
          ..writeAsStringSync(
            'this is not a database, just enough bytes '
                    'that SQLite reads a header and rejects it ' *
                20,
          );
        final db = _ProbeDb(NativeDatabase.createInBackground(file));
        Object? error;
        try {
          await db.customSelect('SELECT 1').get();
        } catch (e) {
          error = e;
        } finally {
          await db.close();
        }
        expect(error, isNotNull);
        expect(error, isNot(isA<SqliteException>()), reason: 'arrives wrapped');
        expect(classifyDbOpenFailure(error!), DbOpenFailureKind.corrupt);
      },
    );
  });
}

/// The smallest drift database that can run a raw query.
class _ProbeDb extends GeneratedDatabase {
  _ProbeDb(super.executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}
