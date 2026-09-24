import 'package:http/http.dart' as http;

/// Web half of the [http_client_factory] seam: the browser owns connection
/// management, so the stock (`fetch`-based) client is used as is.
http.Client createDefaultHttpClient() => http.Client();
