import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web half of the [boot_log] seam: straight to the browser console, which is
/// the only channel that survives a `dart2wasm` release build.
void bootLog(String message) => web.console.log(message.toJS);
