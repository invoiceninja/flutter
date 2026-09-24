/// The app's default HTTP client — a conditional-import seam in the house
/// style (default file = web, the `dart.library.io` override = native; see
/// CLAUDE.md § Web).
library;

export 'package:admin/data/services/http_client_factory_web.dart'
    if (dart.library.io) 'package:admin/data/services/http_client_factory_io.dart';
