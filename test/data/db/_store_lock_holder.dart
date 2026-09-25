import 'dart:io';

/// A second process for `store_lock_test.dart` — not a test itself. It locks
/// the file the way `holdStoreLock` does, so to the test it is another copy of
/// the app.
///
/// `hold <lock file> [pid]`: take the lock, write the process id — its own,
/// or [pid] to pose as another — print `held` (or `refused`), and keep it
/// until stdin closes or the process is killed. `probe <lock file>`: print
/// `held` or `refused` and exit, which lets the lock go.
///
/// Plain `dart:io` and no package imports, so it runs under the `dart`
/// executable with no package resolution. The locked byte is
/// `kStoreLockedByte`.
Future<void> main(List<String> args) async {
  const lockedByte = 1 << 20;
  final mode = args[0];
  final handle = await File(args[1]).open(mode: FileMode.append);
  try {
    await handle.lock(FileLock.exclusive, lockedByte, lockedByte + 1);
    if (mode == 'hold') {
      await handle.truncate(0);
      await handle.setPosition(0);
      await handle.writeString(args.length > 2 ? args[2] : '$pid');
      await handle.flush();
    }
    stdout.writeln('held');
  } on FileSystemException {
    stdout.writeln('refused');
  }
  if (mode == 'hold') await stdin.drain<void>();
  exit(0);
}
