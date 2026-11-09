import 'dart:async';
import 'dart:convert';
import 'dart:io' show TlsException;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/http_client_factory.dart';
import 'package:admin/data/services/upload_source.dart';

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

  /// Changes whenever the session resets (company switch, sign-out): a
  /// request that started under one epoch is never retried under another.
  int get epoch;
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

/// One file of a multipart upload: [source] sent as [field], under
/// [filename] when given (React sends a password-protected PDF as
/// `name.pdf|password`).
typedef DnUploadPart = ({String field, UploadSource source, String? filename});

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

  /// A `multipart/form-data` POST: [fields] plus [files] (a new document's
  /// upload). The body is rebuilt for the retry after a 401, since a
  /// multipart stream can be sent only once.
  Future<Object?> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    required List<DnUploadPart> files,
  }) async => _decode(
    await _sendWith((token) async {
      final request = http.MultipartRequest('POST', _uri(path, null))
        ..followRedirects = false
        ..headers.addAll(_headers(token, json: false))
        ..fields.addAll(fields);
      for (final f in files) {
        final part = await f.source.toMultipartFile(f.field);
        request.files.add(
          f.filename == null
              ? part
              : http.MultipartFile(
                  f.field,
                  part.finalize(),
                  part.length,
                  filename: f.filename,
                  contentType: part.contentType,
                ),
        );
      }
      return request;
    }, timeout: _uploadTimeout),
  );

  /// POST for a file response (the signed PDF, the audit log).
  Future<DnFileBytes> postForFile(String path, {Object? body}) async {
    // A signed PDF can be large: the upload's allowance, not a JSON call's.
    final response = await _send(
      'POST',
      path,
      body: body ?? const {},
      timeout: _uploadTimeout,
    );
    return (
      bytes: response.bodyBytes,
      filename: _filenameFrom(response.headers['content-disposition']),
    );
  }

  /// An upload can take far longer than a JSON call.
  static const _uploadTimeout = Duration(minutes: 5);

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    Duration? timeout,
  }) => _sendWith((token) async {
    final request = http.Request(method, _uri(path, query))
      ..followRedirects = false
      ..headers.addAll(_headers(token, json: body != null));
    if (body != null) request.body = jsonEncode(body);
    return request;
  }, timeout: timeout);

  Map<String, String> _headers(String token, {required bool json}) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
    'X-Requested-With': 'XMLHttpRequest',
    if (json) 'Content-Type': 'application/json',
  };

  /// Sends the request [build] makes for a token, re-running the handshake
  /// once on a 401 and building the request again for the retry.
  Future<http.Response> _sendWith(
    Future<http.BaseRequest> Function(String token) build, {
    Duration? timeout,
  }) async {
    // No token yet (a screen opened before the handshake answered, or after
    // a company switch): run the handshake before the first attempt.
    final token = _tokens.token ?? await _tokens.refreshToken();
    // The company this request is for: its retry must not go out with the
    // next company's token (a create would land in the wrong company).
    final epoch = _tokens.epoch;
    var response = await _attempt(build, token, timeout ?? _timeout);
    if (response.statusCode == 401 && _tokens.epoch == epoch) {
      final fresh = await _tokens.refreshToken();
      if (fresh != null && _tokens.epoch == epoch) {
        response = await _attempt(build, fresh, timeout ?? _timeout);
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw _error(response);
  }

  Future<http.Response> _attempt(
    Future<http.BaseRequest> Function(String token) build,
    String? token,
    Duration timeout,
  ) async {
    if (token == null || token.isEmpty) {
      throw const DocuNinjaException(401, 'No DocuNinja token');
    }
    final request = await build(token);
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      // A read that timed out never changed anything: offline. A write may
      // still land (the timeout does not stop it), so it is an error, not
      // "offline" — the screen re-reads instead of inviting a second send.
      if (request.method == 'GET') {
        throw const NetworkException('DocuNinja request timed out');
      }
      throw const DocuNinjaException(408, 'DocuNinja request timed out');
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } on TlsException catch (e) {
      // A captive portal or a broken connection's TLS: not a client
      // exception under `IOClient`, and offline all the same.
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
      final encoded = star.group(1)!.trim().replaceAll('"', '');
      // A malformed escape (`50%.pdf`) must not fail a download that has
      // already arrived: fall back to the plain name, or none.
      try {
        return Uri.decodeComponent(encoded);
      } on ArgumentError {
        // Fall through.
      }
    }
    final plain = RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(disposition);
    return plain?.group(1)?.trim();
  }
}
