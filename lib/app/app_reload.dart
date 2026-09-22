/// Reload the running app, where the platform has such a concept.
///
/// Conditional-import seam in the house style (default file = web, the
/// `dart.library.io` override = native — see CLAUDE.md § Web). Only web can
/// genuinely re-run the app in place; on native the caller tells the user to
/// relaunch instead.
library;

export 'package:admin/app/app_reload_web.dart'
    if (dart.library.io) 'package:admin/app/app_reload_io.dart';
