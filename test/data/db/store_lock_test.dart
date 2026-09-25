@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/database_opener_io.dart'
    show
        destroyDatabaseStoreAt,
        listRetainedStoresIn,
        openDatabaseExecutorAt,
        pruneBrokenDbFiles,
        quarantineDatabaseFile;
import 'package:admin/data/db/db_open_exception.dart';
import 'package:admin/data/db/store_lock.dart';

/// Two copies of the app on one store both drained its outbox — every change
/// sent twice — and the second copy's boot screen offered a Reset that moved
/// the store out from under the first, which kept writing to it. A second
/// copy is now refused before it reads the key.

const _key = '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';

/// Another copy of the app: `_store_lock_holder.dart` in its own process.
class _OtherCopy {
  _OtherCopy._(this._process)
    : _lines = StreamIterator(
        _process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      ) {
    unawaited(_process.stderr.drain<void>());
  }

  final Process _process;
  final StreamIterator<String> _lines;

  /// Starts one, or returns null when this machine has no `dart` executable
  /// to start it with. [posingAs] is the process id it writes as the holder.
  static Future<_OtherCopy?> start(
    String mode,
    Directory dir, {
    int? posingAs,
  }) async {
    final script = p.join(
      Directory.current.path,
      'test',
      'data',
      'db',
      '_store_lock_holder.dart',
    );
    for (final dart in _dartBinaries()) {
      try {
        return _OtherCopy._(
          await Process.start(dart, [
            script,
            mode,
            p.join(dir.path, kStoreLockFileName),
            if (posingAs != null) '$posingAs',
          ]),
        );
      } on ProcessException {
        continue;
      }
    }
    return null;
  }

  /// The Dart VM binary itself, never the SDK's `dart` wrapper and never
  /// through a shell. On Windows the wrapper is `dart.bat`, which needs a
  /// shell and starts `dart.exe` as a child — killing the shell left that
  /// child holding the lock.
  static Iterable<String> _dartBinaries() sync* {
    final exe = Platform.isWindows ? 'dart.exe' : 'dart';
    // `flutter test` runs under `<flutter>/bin/cache/artifacts/engine/…`.
    var dir = File(Platform.resolvedExecutable).parent;
    while (dir.parent.path != dir.path) {
      if (p.basename(dir.path) == 'cache' &&
          p.basename(dir.parent.path) == 'bin') {
        yield p.join(dir.path, 'dart-sdk', 'bin', exe);
        break;
      }
      dir = dir.parent;
    }
    final root = Platform.environment['FLUTTER_ROOT'];
    if (root != null) {
      yield p.join(root, 'bin', 'cache', 'dart-sdk', 'bin', exe);
    }
    if (!Platform.isWindows) yield 'dart';
  }

  /// `held` or `refused`: what it made of the lock.
  Future<String> verdict() async =>
      await _lines.moveNext().timeout(const Duration(seconds: 60))
      ? _lines.current
      : 'exited without a verdict';

  Future<void> kill() async {
    _process.kill(ProcessSignal.sigkill);
    await _process.exitCode;
  }
}

void main() {
  late Directory dir;
  late File store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('store_lock_');
    store = File(p.join(dir.path, 'invoiceninja.sqlite'));
  });
  tearDown(() async {
    await releaseStoreLockForTesting(dir);
    await dir.delete(recursive: true);
  });

  group('storeLockHeldElsewhere', () {
    test('reads the answer each OS gives for a lock another process holds', () {
      // fcntl(F_SETLK) says EAGAIN or EACCES, and EAGAIN is 11 on Linux and
      // 35 on Darwin — where 11 is EDEADLK, and the other way round.
      for (final os in ['linux', 'android']) {
        expect(storeLockHeldElsewhere(11, os: os), isTrue, reason: os);
        expect(storeLockHeldElsewhere(13, os: os), isTrue, reason: os);
        expect(storeLockHeldElsewhere(35, os: os), isFalse, reason: os);
      }
      for (final os in ['macos', 'ios']) {
        expect(storeLockHeldElsewhere(35, os: os), isTrue, reason: os);
        expect(storeLockHeldElsewhere(13, os: os), isTrue, reason: os);
        expect(storeLockHeldElsewhere(11, os: os), isFalse, reason: os);
      }
      // LockFileEx says ERROR_LOCK_VIOLATION. A sharing violation is not a
      // lock at all.
      expect(storeLockHeldElsewhere(33, os: 'windows'), isTrue);
      expect(storeLockHeldElsewhere(32, os: 'windows'), isFalse);
      expect(storeLockHeldElsewhere(11, os: 'windows'), isFalse);
    });

    test('an error without a code never locks the user out', () {
      for (final os in ['linux', 'macos', 'ios', 'android', 'windows']) {
        expect(storeLockHeldElsewhere(null, os: os), isFalse, reason: os);
      }
    });
  });

  test('a store directory that cannot be locked opens as it did before the '
      'lock existed', () async {
    // A directory where the lock file goes: opening it fails, and that is not
    // another copy of the app.
    Directory(p.join(dir.path, kStoreLockFileName)).createSync();
    await holdStoreLock(dir);

    final db = AppDatabase(
      await openDatabaseExecutorAt(
        store,
        fetchKey: () async => (key: _key, minted: true),
      ),
    );
    await db.customSelect('SELECT 1').get();
    await db.close();
  });

  test('the holder\'s id starts the file, even over one an earlier launch '
      'left — a refused copy reads it from there', () async {
    File(p.join(dir.path, kStoreLockFileName)).writeAsStringSync('4242424');
    await holdStoreLock(dir);
    expect(
      File(p.join(dir.path, kStoreLockFileName)).readAsStringSync(),
      '$pid',
    );
  });

  group('with another process', () {
    final copies = <_OtherCopy>[];
    tearDown(() async {
      for (final copy in copies) {
        await copy.kill();
      }
      copies.clear();
    });

    Future<_OtherCopy?> startOther(String mode, {int? posingAs}) async {
      final copy = await _OtherCopy.start(mode, dir, posingAs: posingAs);
      if (copy == null) {
        markTestSkipped('no `dart` executable to start a second process');
        return null;
      }
      copies.add(copy);
      return copy;
    }

    test('a second copy is refused before it reads the key, and its Reset '
        'moves nothing', () async {
      final first = await startOther('hold');
      if (first == null) return;
      expect(await first.verdict(), 'held');
      store.writeAsStringSync('the first copy\'s data');

      var keyReads = 0;
      await expectLater(
        openDatabaseExecutorAt(
          store,
          fetchKey: () async {
            keyReads++;
            return (key: _key, minted: true);
          },
        ),
        throwsA(isA<DatabaseInUseException>()),
      );
      // An empty read mints a key, and writes it over the one the first
      // copy's store is encrypted with.
      expect(keyReads, 0);

      await expectLater(
        destroyDatabaseStoreAt(store),
        throwsA(isA<DatabaseInUseException>()),
      );
      expect(store.readAsStringSync(), 'the first copy\'s data');
      expect(
        {for (final entry in dir.listSync()) p.basename(entry.path)},
        {'invoiceninja.sqlite', kStoreLockFileName},
        reason: 'no snapshot, no salvage marker',
      );
    });

    test('the open reports it as in use, and leaves the store alone', () async {
      final first = await startOther('hold');
      if (first == null) return;
      expect(await first.verdict(), 'held');

      var destroyed = 0;
      await expectLater(
        openAppDatabase(
          openExecutor: () => openDatabaseExecutorAt(
            store,
            fetchKey: () async => (key: _key, minted: true),
          ),
          destroyStore: () async {
            destroyed++;
            return destroyDatabaseStoreAt(store);
          },
          transientRetries: 0,
        ),
        throwsA(
          isA<DatabaseUnavailableException>().having(
            (e) => e.kind,
            'kind',
            DbOpenFailureKind.inUse,
          ),
        ),
      );
      expect(destroyed, 0);
    });

    test('the lock goes with the process that held it', () async {
      final first = await startOther('hold');
      if (first == null) return;
      expect(await first.verdict(), 'held');
      await expectLater(
        holdStoreLock(dir),
        throwsA(isA<DatabaseInUseException>()),
      );

      await first.kill();
      // Windows releases a dead process's locks a moment later.
      for (var attempt = 0; ; attempt++) {
        try {
          await holdStoreLock(dir);
          break;
        } on DatabaseInUseException {
          if (attempt == 20) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      expect(await (await startOther('probe'))!.verdict(), 'refused');
    });

    test(
      'taken once per process: callers asking together leave it held — '
      'on POSIX, closing any second handle on the file would release it',
      () async {
        await Future.wait([holdStoreLock(dir), holdStoreLock(dir)]);
        await holdStoreLock(dir);
        final probe = await startOther('probe');
        if (probe == null) return;
        expect(await probe.verdict(), 'refused');
      },
    );

    test('a lock held under this process\'s own id is not another copy — '
        'on Windows a hot restart finds its previous isolate\'s lock, which '
        'is still open', () async {
      // A second process posing as this one: the refusal a Windows hot
      // restart meets, where the lock belongs to the old isolate's handle.
      final earlier = await startOther('hold', posingAs: pid);
      if (earlier == null) return;
      expect(await earlier.verdict(), 'held');
      await holdStoreLock(dir);
    });

    test('nothing that tidies the store directory touches the lock', () async {
      await holdStoreLock(dir);
      store.writeAsStringSync('store');
      await quarantineDatabaseFile(store);
      await pruneBrokenDbFiles(dir, keep: 0);
      expect(File(p.join(dir.path, kStoreLockFileName)).existsSync(), isTrue);
      expect([
        for (final copy in await listRetainedStoresIn(dir))
          p.basename(copy.path),
      ], isNot(contains(kStoreLockFileName)));

      final probe = await startOther('probe');
      if (probe == null) return;
      expect(await probe.verdict(), 'refused');
    });
  });
}
