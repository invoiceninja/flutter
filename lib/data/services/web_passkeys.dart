/// The browser's WebAuthn API (`navigator.credentials`) for passkeys on web.
///
/// Conditional-import seam in the house style (default file = web, the
/// `dart.library.io` override = native — see CLAUDE.md § Web). Native
/// platforms never reach it: they use `NativePasskeys`, behind
/// `PasskeyAuthenticator`.
library;

export 'package:admin/data/services/web_passkeys_web.dart'
    if (dart.library.io) 'package:admin/data/services/web_passkeys_io.dart';
