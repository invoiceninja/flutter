import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/http_client_factory.dart';

final _log = Logger('DocuNinjaClient');

/// DocuNinja's REST host. `docuninja.co` serves the marketing site; the API
/// is `api.docuninja.co` (probed live; docs/docuninja.md). Overridable for a
/// staging service with `--dart-define=IN_DOCUNINJA_API_URL=…`.
const String kDocuNinjaApiUrl = String.fromEnvironment(
  'IN_DOCUNINJA_API_URL',
  defaultValue: 'https://api.docuninja.co',
);

/// Where [DocuNinjaClient] gets its bearer token, and a fresh one after a 401.
abstract interface class DocuNinjaTokenSource {
  /// The active company's DocuNinja token, or null when there is none.
  String? get token;

  /// Re-runs the login handshake and returns the new token, or null.
  Future<String?> refreshToken();
}

/// A DocuNinja request the service refused. [statusCode] is the HTTP status;
/// [message] is the service's own text, for the log, never shown raw (toast
/// strings go through `tr()`, CLAUDE.md § Strict rules).
class DocuNinjaException implements Exception {
  const DocuNinjaException(
    this.statusCode,
    this.message, {
    this.fieldErrors = const {},
  });

  final int statusCode;
  final String message;
  final Map<String, List<String>> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'DocuNinjaException($statusCode, $message)';
}

/// A file the service sent back (`/download`, `/audit_log`).
typedef DnFileBytes = ({Uint8List bytes, String? filename});

/// The app's only way to talk to DocuNinja. Its own `http.Client`, never
/// `ApiClient`: that client's 401 handling ends the Invoice Ninja session,
/// and a DocuNinja 401 says nothing about it. A 401 here re-runs the login
/// handshake once and retries; a second one is surfaced as a
/// [DocuNinjaException] the screens answer with "Reconnect"
/// (docs/docuninja.md).
class DocuNinjaClient {
  DocuNinjaClient({
    required DocuNinjaTokenSource tokens,
    http.Client? httpClient,
    String baseUrl = kDocuNinjaApiUrl,
    Duration timeout = const Duration(seconds: 60),
  }) : _tokens = tokens,
       _http = httpClient ?? createDefaultHttpClient(),
       _base = Uri.parse(baseUrl),
       _timeout = timeout;

  final DocuNinjaTokenSource _tokens;
  final http.Client _http;
  final Uri _base;
  final Duration _timeout;

  Uri _uri(String path, Map<String, String>? query) {
    final uri = _base.resolve(path);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Future<Object?> getJson(String path, {Map<String, String>? query}) async =>
      _decode(await _send('GET', path, query: query));

  Future<Object?> postJson(String path, {Object? body}) async =>
      _decode(await _send('POST', path, body: body ?? const {}));

  Future<Object?> putJson(String path, {Object? body}) async =>
      _decode(await _send('PUT', path, body: body ?? const {}));

  Future<Object?> deleteJson(String path, {Object? body}) async =>
      _decode(await _send('DELETE', path, body: body));

  /// POST for a file response (the signed PDF, the audit log).
  Future<DnFileBytes> postForFile(String path, {Object? body}) async {
    final response = await _send('POST', path, body: body ?? const {});
    return (
      bytes: response.bodyBytes,
      filename: _filenameFrom(response.headers['content-disposition']),
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    // No token yet (a screen opened before the handshake answered, or after
    // a company switch): run the handshake before the first attempt.
    final token = _tokens.token ?? await _tokens.refreshToken();
    var response = await _attempt(method, path, query, body, token);
    if (response.statusCode == 401) {
      final fresh = await _tokens.refreshToken();
      if (fresh != null) {
        response = await _attempt(method, path, query, body, fresh);
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw _error(response);
  }

  Future<http.Response> _attempt(
    String method,
    String path,
    Map<String, String>? query,
    Object? body,
    String? token,
  ) async {
    if (token == null || token.isEmpty) {
      throw const DocuNinjaException(401, 'No DocuNinja token');
    }
    final request = http.Request(method, _uri(path, query))
      ..followRedirects = false
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Requested-With': 'XMLHttpRequest',
        if (body != null) 'Content-Type': 'application/json',
      });
    if (body != null) request.body = jsonEncode(body);
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      return await http.Response.fromStream(streamed).timeout(_timeout);
    } on TimeoutException {
      throw const NetworkException('DocuNinja request timed out');
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    }
  }

  DocuNinjaException _error(http.Response response) {
    var message = response.reasonPhrase ?? 'HTTP ${response.statusCode}';
    final fieldErrors = <String, List<String>>{};
    try {
      final json = jsonDecode(response.body);
      if (json is Map) {
        if (json['message'] != null) message = json['message'].toString();
        final errors = json['errors'];
        if (errors is Map) {
          for (final e in errors.entries) {
            final v = e.value;
            fieldErrors['${e.key}'] = v is List
                ? [for (final x in v) '$x']
                : ['$v'];
          }
        }
      }
    } on FormatException {
      /* not JSON */
    }
    _log.warning(
      'DocuNinja ${response.request?.method} '
      '${response.request?.url.path} -> ${response.statusCode}: $message',
    );
    return DocuNinjaException(
      response.statusCode,
      message,
      fieldErrors: fieldErrors,
    );
  }

  static Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  static String? _filenameFrom(String? disposition) {
    if (disposition == null) return null;
    final star = RegExp(
      r"filename\*=(?:UTF-8'')?([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition);
    if (star != null) {
      return Uri.decodeComponent(star.group(1)!.trim().replaceAll('"', ''));
    }
    final plain = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition);
    return plain?.group(1)?.trim();
  }
}
