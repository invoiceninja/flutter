/// Emit a diagnostic line on a channel the current platform actually shows.
///
/// Conditional-import seam in the house style (default file = web, the
/// `dart.library.io` override = native — see CLAUDE.md § Web).
///
/// This exists because `print` / `debugPrint` produce **no console output** in a
/// `dart2wasm` release build (measured against the demo: a page-side
/// `console.log` tee captured the JS chatter and not one Dart line), and
/// `dart:developer`'s `log` is a no-op on every web target. Web is also the one
/// platform with no diagnostics log, so without this seam a fatal boot error has
/// nowhere at all to surface — which is exactly how a wedged web boot showed up
/// as nothing but a spinner.
library;

export 'package:admin/app/boot_log_web.dart'
    if (dart.library.io) 'package:admin/app/boot_log_io.dart';
