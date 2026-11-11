/// The Invoice Ninja server that served this web page, if one did
/// ([ServingServer], docs/web-deploy.md).
///
/// Conditional-import seam in the house style (default file = web, the
/// `dart.library.io` override = native — see CLAUDE.md § Web).
library;

export 'package:admin/app/serving_server_parse.dart' show ServingServer;
export 'package:admin/app/serving_server_web.dart'
    if (dart.library.io) 'package:admin/app/serving_server_io.dart';
