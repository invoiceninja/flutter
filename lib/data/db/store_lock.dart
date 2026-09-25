import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'package:admin/data/db/db_open_exception.dart';

final _log = Logger('StoreLock');

/// The file whose lock says a process has the local store open. It sits beside
/// the store but outside every name the opener works with: SQLite's own
/// `<db>-journal` sidecars and the `invoiceninja.sqlite.*` snapshots that
/// pruning deletes.
const kStoreLockFileName = 'invoiceninja.instance.lock';

/// The one byte of [kStoreLockFileName] that is locked — past the process id
/// the holder writes at the start. Windows locks are mandatory, so a lock on
/// the whole file would leave that id unreadable to the process it refuses.
const kStoreLockedByte = 1 << 20;

/// The lock this process holds, one per store directory, for the life of the
/// process: never closed and never reopened. POSIX drops every lock a process
/// holds on a file the moment ANY descriptor for that file is closed, and an
/// unreachable [RandomAccessFile] is closed when it is collected. So the
/// handle stays here, reachable, and a second call reuses it.
final _held = <String, RandomAccessFile>{};

/// Serialises [holdStoreLock]. Two calls racing past [_held] would both open
/// the file, and closing the loser's handle would release the winner's lock.
Future<void> _queue = Future<void>.value();

/// Take the lock that keeps a second copy of the app away from the store in
/// [dir], or throw [DatabaseInUseException] when another process holds it.
///
/// Only a positive "held by another process" refuses
/// ([storeLockHeldElsewhere]). Any other failure — a file system with no lock
/// support, say — logs and opens without the lock, exactly as before it
/// existed: an unlockable disk is not a reason to lock the user out.
///
/// Native only. [os] overrides `Platform.operatingSystem` for tests.
Future<void> holdStoreLock(Directory dir, {String? os}) {
  final attempt = _queue.then(
    (_) => _hold(dir, os ?? Platform.operatingSystem),
  );
  _queue = attempt.then<void>((_) {}, onError: (Object _) {});
  return attempt;
}

Future<void> _hold(Directory dir, String os) async {
  final path = p.join(dir.path, kStoreLockFileName);
  if (_held.containsKey(path)) return;
  final RandomAccessFile handle;
  try {
    // Append: a lock for writing needs a descriptor open for writing, and
    // `write` would truncate.
    handle = await File(path).open(mode: FileMode.append);
  } on FileSystemException catch (e) {
    _log.warning('Could not open $path; opening the store without its lock', e);
    return;
  }
  try {
    await handle.lock(
      FileLock.exclusive,
      kStoreLockedByte,
      kStoreLockedByte + 1,
    );
  } on FileSystemException catch (e) {
    // Closing is safe here, POSIX semantics included: this process holds no
    // lock on the file, or [_held] would have returned above.
    try {
      await handle.close();
    } catch (_) {}
    if (!storeLockHeldElsewhere(e.osError?.errorCode, os: os)) {
      _log.warning(
        'Could not lock $path; opening the store without its lock',
        e,
      );
      return;
    }
    // Held by this very process: a hot restart reruns `main` while the
    // previous isolate's handle is still open. POSIX lets a process take its
    // own lock again, so only Windows, whose locks belong to the handle, gets
    // here — and only there is it asked. On POSIX a refusal is always another
    // process, even one whose id matches the file's (a stale id, or a copy
    // in another pid namespace, as two sandboxed instances can be).
    if (os == 'windows' && await _holderPid(path) == pid) return;
    throw const DatabaseInUseException();
  }
  // Which process holds it, for the check above. The lock is what counts:
  // an id that can't be written costs only that check. Append mode opens at
  // the end of the file and `truncate` leaves the position there, so an id
  // written without the seek landed after a run of zero bytes and never
  // parsed.
  try {
    await handle.truncate(0);
    await handle.setPosition(0);
    await handle.writeString('$pid');
    await handle.flush();
  } on FileSystemException catch (e) {
    _log.warning('Could not record this process in $path', e);
  }
  _held[path] = handle;
}

Future<int?> _holderPid(String path) async {
  try {
    return int.tryParse((await File(path).readAsString()).trim());
  } on FileSystemException {
    return null;
  }
}

/// Whether [code], the OS error a non-blocking lock failed with on [os], means
/// another process holds the lock. `fcntl(F_SETLK)` reports that as EAGAIN or
/// EACCES, and EAGAIN is 11 on Linux (Android too) and 35 on Darwin, where 11
/// is EDEADLK. `LockFileEx` reports ERROR_LOCK_VIOLATION.
bool storeLockHeldElsewhere(int? code, {required String os}) => switch (os) {
  'windows' => code == 33,
  'macos' || 'ios' => code == 35 || code == 13,
  _ => code == 11 || code == 13,
};

/// Release the lock [holdStoreLock] took on [dir] — tests only. The app never
/// releases it: the process ending does.
Future<void> releaseStoreLockForTesting(Directory dir) async {
  final handle = _held.remove(p.join(dir.path, kStoreLockFileName));
  await handle?.close();
}
