/// Picks the production [TokenStorage] for the current platform.
///
/// - Native (`token_storage_io_factory.dart`): [SecureTokenStorage] over
///   `flutter_secure_storage` (iOS/macOS Keychain, Android AES-GCM).
/// - Web (`token_storage_web_factory.dart`): `LocalStorageTokenStorage`
///   over `window.localStorage`. The browser origin sandbox is the trust
///   boundary; there is no Keychain equivalent and the chosen approach is
///   plain localStorage (see CLAUDE.md § Web).
///
/// Tests inject `InMemoryTokenStorage` directly and never hit this factory.
/// Default target is the web factory; `dart.library.io` swaps in native.
library;

export 'package:admin/data/services/token_storage_web_factory.dart'
    if (dart.library.io) 'package:admin/data/services/token_storage_io_factory.dart';
