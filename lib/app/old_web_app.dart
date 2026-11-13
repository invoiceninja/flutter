/// Whether admin-portal's web app signed someone in on this origin, for the
/// one-time "new web app" card on a self-hosted login screen
/// (docs/web-deploy.md § Going live).
///
/// Conditional-import seam in the house style (default file = web, the
/// `dart.library.io` override = native — see CLAUDE.md § Web).
library;

export 'package:admin/app/old_web_app_web.dart'
    if (dart.library.io) 'package:admin/app/old_web_app_io.dart';
