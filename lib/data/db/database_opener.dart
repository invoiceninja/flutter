/// Platform seam for opening (and, on recovery, destroying) the Drift store.
///
/// Two implementations sit behind this conditional export:
///
/// - **Native** (`database_opener_io.dart`): an encrypted SQLCipher file
///   under the app-support directory, keyed from the OS keychain via
///   `flutter_secure_storage`. Recovery renames the file to
///   `<name>.broken.<ts>` and prunes old snapshots.
/// - **Web** (`database_opener_web.dart`): an unencrypted IndexedDB / OPFS
///   store via drift WASM — no SQLCipher, no `PRAGMA key`. The browser
///   origin sandbox is the trust boundary (see CLAUDE.md § Web). Recovery
///   deletes the IndexedDB/OPFS database.
///
/// Both expose the identical surface consumed by `openAppDatabase()`:
/// `openDatabaseExecutor()` and `destroyDatabaseStore()`. `pruneBrokenDbFiles`
/// is native-only and absent from the web stub.
///
/// The default target is the web stub; `dart.library.io` (true on the Dart
/// VM / Flutter native, false on web) swaps in the native implementation.
library;

export 'package:admin/data/db/database_opener_web.dart'
    if (dart.library.io) 'package:admin/data/db/database_opener_io.dart';
