/// Where a refused server certificate meets the app — a conditional-import
/// seam in the house style (default file = web, the `dart.library.io`
/// override = native; see CLAUDE.md § Web). On web the browser owns TLS, so
/// both halves of it are no-ops there.
library;

export 'package:admin/data/services/tls/certificate_trust_seam_web.dart'
    if (dart.library.io) 'package:admin/data/services/tls/certificate_trust_seam_io.dart';
