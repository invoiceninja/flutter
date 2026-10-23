import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as raw;

import 'package:admin/data/db/database_opener_io.dart';
import 'package:admin/data/db/store_lock.dart';

/// A store written by an OLDER sqlite3 / SQLite3MultipleCiphers build still
/// opens with the production pragmas.
///
/// The fixture was written by `sqlite3` 3.3.2 (SQLite3MultipleCiphers 2.3.4)
/// before the bump to 3.7.1 (2.6.1), whose 2.6.0 changed "handling of legacy
/// cipher modes" — and the app runs `cipher = 'sqlcipher'`, `legacy = 4`. A
/// cipher change that cannot read an existing store does not fail loudly: the
/// opener quarantines the file as corrupt and the user's unsynced edits go
/// with it. Never regenerate the fixture on a bump — that would test the new
/// build against itself. Regenerate only on purpose, on the OLD lockfile:
///
///     IN_REGENERATE_DB_FIXTURE=1 flutter test test/data/db/encrypted_fixture_compat_test.dart
const _fixturePath = 'test/fixtures/db/sqlcipher4_legacy_raw_key.db';

/// Test-only key, in the raw 64-hex form `_getOrCreateDbKey` mints.
const _key = '0f1e2d3c4b5a69788796a5b4c3d2e1f00112233445566778899aabbccddeeff0';

const _rows = 200;

String _label(int i) => 'row $i · Ünïcødé ✓ ${'x' * 64}';

/// Run first on the OLD build only (see the library comment).
void _writeFixture() {
  final file = File(_fixturePath);
  if (file.existsSync()) file.deleteSync();
  file.parent.createSync(recursive: true);
  final db = raw.sqlite3.open(file.path)
    ..execute("PRAGMA cipher = 'sqlcipher'")
    ..execute('PRAGMA legacy = 4')
    ..execute("PRAGMA key = \"x'$_key'\"")
    ..execute('CREATE TABLE probe (id INTEGER PRIMARY KEY, label TEXT)');
  final insert = db.prepare('INSERT INTO probe (id, label) VALUES (?, ?)');
  for (var i = 0; i < _rows; i++) {
    insert.execute([i, _label(i)]);
  }
  insert.close();
  // Matches `_Probe.schemaVersion`, so drift opens it without a migration.
  db
    ..execute('PRAGMA user_version = 1')
    ..close();
}

class _Probe extends GeneratedDatabase {
  _Probe(super.executor);

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => 1;
}

void main() {
  if (Platform.environment['IN_REGENERATE_DB_FIXTURE'] == '1') {
    test('regenerate the fixture', _writeFixture);
    return;
  }

  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('db_fixture_');
    file = File(p.join(dir.path, 'invoiceninja.sqlite'));
    // A copy: opening may write, and the fixture must stay byte-identical.
    File(_fixturePath).copySync(file.path);
  });
  tearDown(() async {
    await releaseStoreLockForTesting(dir);
    await dir.delete(recursive: true);
  });

  test('the fixture is encrypted — not a plain SQLite file', () {
    final header = File(_fixturePath).readAsBytesSync().sublist(0, 15);
    expect(String.fromCharCodes(header), isNot('SQLite format 3'));
  });

  test(
    'the production opener reads a store an older cipher build wrote',
    () async {
      final db = _Probe(
        await openDatabaseExecutorAt(
          file,
          fetchKey: () async => (key: _key, minted: false),
        ),
      );
      addTearDown(db.close);

      final rows = await db
          .customSelect('SELECT id, label FROM probe ORDER BY id')
          .get();
      expect(rows, hasLength(_rows));
      for (final row in rows) {
        final id = row.read<int>('id');
        expect(row.read<String>('label'), _label(id));
      }
      final check = await db.customSelect('PRAGMA integrity_check').getSingle();
      expect(check.data.values.single, 'ok');
    },
  );

  test('the wrong key cannot read it', () async {
    final db = _Probe(
      await openDatabaseExecutorAt(
        file,
        fetchKey: () async => (key: 'f' * 64, minted: false),
      ),
    );
    addTearDown(db.close);
    await expectLater(
      db.customSelect('SELECT count(*) FROM probe').get(),
      throwsA(anything),
    );
  });
}
