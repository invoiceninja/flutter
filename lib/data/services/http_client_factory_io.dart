import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Native half of the [http_client_factory] seam.
///
/// Two timeouts the stock `http.Client()` leaves at the OS / `dart:io`
/// defaults, both about telling "never sent" from "maybe sent" (see
/// `RequestNotSentException`):
///   * `connectionTimeout` 15 s — an unreachable host fails fast, and fails
///     while the request is still provably unsent (the connection is opened
///     before the body is read), instead of after the OS's much longer
///     connect timeout;
///   * `idleTimeout` 4 s — below the 5 s keep-alive common on Apache, so the
///     client never writes a request onto a socket the server has just
///     closed. That race fails AFTER the body is read, which is
///     indistinguishable from a lost response and would otherwise make a
///     perfectly ordinary retry look like it might have landed.
http.Client createDefaultHttpClient() => IOClient(
  HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 4),
);
