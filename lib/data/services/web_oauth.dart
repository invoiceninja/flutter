/// Google and Microsoft sign-in in the browser, through the providers' own
/// scripts the boot page loads (docs/web-deploy.md § Web sign-in).
///
/// Conditional-import seam in the house style (default file = web, the
/// `dart.library.io` override = native — see CLAUDE.md § Web). Native builds
/// sign in through `GoogleSignInClient` and have no Microsoft sign-in.
library;

export 'package:admin/data/services/web_oauth_types.dart';
export 'package:admin/data/services/web_oauth_web.dart'
    if (dart.library.io) 'package:admin/data/services/web_oauth_io.dart';
