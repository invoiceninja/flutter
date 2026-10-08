// The benchmark's one HTTP origin: the build under test as static files, and
// a record/replay stand-in for the Invoice Ninja API on the same origin.
//
// The app is built with IN_DEMO_API_URL pointing here, so every API call it
// makes lands on [BenchServer._api]. In record mode a request with no fixture
// is forwarded to the real demo server once and stored; in replay mode a
// request with no fixture is a hard miss the sample is thrown out for. A
// measured run therefore never waits on the network, and the demo server's
// 0.3–1.4 s per call never reaches a number.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const kUpstream = 'https://demo.invoiceninja.com';

/// Headers that make a page cross-origin isolated — the pair Flutter's own
/// tooling sends (`kCrossOriginIsolationHeaders`), and what lets skwasm
/// rasterise on a worker thread.
const kIsolationHeaders = {
  'Cross-Origin-Opener-Policy': 'same-origin',
  'Cross-Origin-Embedder-Policy': 'credentialless',
};

/// POSTs the app makes that only read. Anything else non-GET is refused in
/// record mode, so a benchmark can never write to the shared demo account
/// (the build also sets IN_DEMO_MODE=true; this is the second lock).
const _readOnlyPosts = [
  '/api/v1/refresh',
  '/api/v1/charts/',
  '/api/v1/activities/entity',
  '/api/v1/live_preview',
];

class AccessEntry {
  AccessEntry(this.path, this.status, this.bytes, {required this.api});
  final String path;
  final int status;

  /// Bytes on the wire for the body (gzip where the browser accepted it).
  final int bytes;
  final bool api;

  List<Object> toJson() => [path, status, bytes];
}

class _Asset {
  _Asset(this.bytes, this.gzipped, this.etag, this.mime);
  final Uint8List bytes;
  final Uint8List? gzipped;
  final String etag;
  final String mime;
}

class _Fixture {
  _Fixture(this.status, this.headers, this.file);
  final int status;
  final Map<String, String> headers;
  final String file;
  Uint8List? body;

  Map<String, Object> toJson() => {
    'status': status,
    'headers': headers,
    'file': file,
  };
}

class BenchServer {
  BenchServer._(this._http, this._fixtureDir, {required this.record});

  final HttpServer _http;
  final Directory _fixtureDir;

  /// Forward a request with no fixture upstream and store the answer.
  final bool record;

  final _fixtures = <String, _Fixture>{};
  final _assets = <String, _Asset>{};
  final _upstream = HttpClient()..userAgent = 'invoiceninja-web-bench';

  Directory? _root;
  bool _isolated = false;
  bool _forceSingleThread = false;

  final List<AccessEntry> _log = [];
  int inflightApi = 0;
  int lastApiEndMicros = 0;
  int replayMisses = 0;
  int writeGuardHits = 0;
  int upstreamCalls = 0;
  final List<String> missedKeys = [];

  int get port => _http.port;
  int get fixtureCount => _fixtures.length;

  static Future<BenchServer> start({
    required int port,
    required Directory fixtureDir,
    required bool record,
  }) async {
    fixtureDir.createSync(recursive: true);
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    final server = BenchServer._(http, fixtureDir, record: record);
    server._loadIndex();
    http.listen(server._handle);
    return server;
  }

  /// Points the origin at one build and one header policy. Every file is read
  /// and compressed up front, so the first sample does not pay for it.
  Future<void> serve(
    Directory root, {
    required bool isolated,
    required bool forceSingleThread,
  }) async {
    _root = root;
    _isolated = isolated;
    _forceSingleThread = forceSingleThread;
    await for (final entity in root.list(recursive: true)) {
      if (entity is File) await _asset(entity);
    }
  }

  List<AccessEntry> takeLog() {
    final copy = List<AccessEntry>.of(_log);
    _log.clear();
    return copy;
  }

  void resetCounters() {
    replayMisses = 0;
    writeGuardHits = 0;
    upstreamCalls = 0;
    missedKeys.clear();
    _log.clear();
  }

  Future<void> close() async {
    _upstream.close(force: true);
    await _http.close(force: true);
  }

  // -------------------------------------------------------------------------
  // Fixtures
  // -------------------------------------------------------------------------

  File get _indexFile => File('${_fixtureDir.path}/index.json');
  File get _stampFile => File('${_fixtureDir.path}/recorded.json');

  void _loadIndex() {
    if (!_indexFile.existsSync()) return;
    final index =
        jsonDecode(_indexFile.readAsStringSync()) as Map<String, dynamic>;
    for (final MapEntry(:key, :value) in index.entries) {
      final map = value as Map<String, dynamic>;
      _fixtures[key] = _Fixture(
        map['status'] as int,
        (map['headers'] as Map<String, dynamic>).cast<String, String>(),
        map['file'] as String,
      );
    }
  }

  void _saveIndex() {
    _indexFile.writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert({
        for (final MapEntry(:key, :value) in _fixtures.entries)
          key: value.toJson(),
      }),
    );
    if (!_stampFile.existsSync()) {
      _stampFile.writeAsStringSync(jsonEncode({'day': localDay()}));
    }
  }

  /// The local calendar day the fixtures were recorded on, or null if none
  /// were. The dashboard's "previous period" request body is derived from
  /// today's date, so a recording is only replayable on the day it was made.
  String? get recordedDay {
    if (!_stampFile.existsSync()) return null;
    return (jsonDecode(_stampFile.readAsStringSync())
            as Map<String, dynamic>)['day']
        as String?;
  }

  /// The recorded body for the first fixture whose key satisfies [test].
  Uint8List? fixtureBody(bool Function(String key) test) {
    for (final MapEntry(:key, :value) in _fixtures.entries) {
      if (test(key)) return _body(value);
    }
    return null;
  }

  Uint8List _body(_Fixture fixture) => fixture.body ??= File(
    '${_fixtureDir.path}/${fixture.file}',
  ).readAsBytesSync();

  /// Method + path + sorted query + a hash of the body. The one request whose
  /// query depends on the wall clock — the delta `/refresh`, keyed on the last
  /// sync time — has that parameter dropped.
  static String replayKey(String method, Uri uri, List<int> body) {
    final query = uri.queryParametersAll;
    final delta =
        uri.path == '/api/v1/refresh' &&
        (query['current_company']?.contains('true') ?? false);
    final pairs = <String>[
      for (final name in query.keys.toList()..sort())
        if (!(delta && name == 'updated_at'))
          for (final value in query[name]!) '$name=$value',
    ];
    final hash = body.isEmpty ? '' : ' #${_fnv1a(body)}';
    return '$method ${uri.path}?${pairs.join('&')}$hash';
  }

  static String _fnv1a(List<int> bytes) {
    var hash = 0xcbf29ce484222325;
    for (final byte in bytes) {
      hash ^= byte;
      hash *= 0x100000001b3;
    }
    return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }

  // -------------------------------------------------------------------------
  // Requests
  // -------------------------------------------------------------------------

  Future<void> _handle(HttpRequest request) async {
    try {
      final path = request.uri.path;
      if (path.startsWith('/api/')) {
        await _api(request);
      } else if (path == '/__bench/refresh.json') {
        await _snapshot(request);
      } else {
        await _static(request);
      }
    } on Object catch (error, stack) {
      stderr.writeln('bench server: ${request.uri} failed: $error\n$stack');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } on Object {
        // The socket is already gone.
      }
    }
  }

  void _commonHeaders(HttpResponse response) {
    if (_isolated) kIsolationHeaders.forEach(response.headers.set);
  }

  Future<void> _api(HttpRequest request) async {
    inflightApi++;
    final response = request.response;
    _commonHeaders(response);
    try {
      final builder = await request.fold(
        BytesBuilder(copy: false),
        (b, chunk) => b..add(chunk),
      );
      final body = builder.takeBytes();
      final key = replayKey(request.method, request.uri, body);
      var fixture = _fixtures[key];
      if (fixture == null) {
        if (!record) {
          replayMisses++;
          missedKeys.add(key);
          await _json(response, 599, '{"message":"bench: no fixture"}');
          _log.add(AccessEntry(request.uri.toString(), 599, 0, api: true));
          return;
        }
        final path = request.uri.path;
        final readOnly =
            request.method == 'GET' ||
            (request.method == 'POST' && _readOnlyPosts.any(path.startsWith));
        if (!readOnly) {
          writeGuardHits++;
          await _json(response, 403, '{"message":"bench: write refused"}');
          return;
        }
        fixture = await _fetch(request, body, key);
      }
      final bytes = _body(fixture);
      response.statusCode = fixture.status;
      fixture.headers.forEach(response.headers.set);
      response.headers.contentLength = bytes.length;
      response.add(bytes);
      await response.close();
      _log.add(
        AccessEntry(
          request.uri.toString(),
          fixture.status,
          bytes.length,
          api: true,
        ),
      );
    } finally {
      inflightApi--;
      lastApiEndMicros = DateTime.now().microsecondsSinceEpoch;
    }
  }

  Future<void> _json(HttpResponse response, int status, String body) async {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(body);
    await response.close();
  }

  Future<_Fixture> _fetch(
    HttpRequest request,
    List<int> body,
    String key,
  ) async {
    upstreamCalls++;
    final target = Uri.parse(kUpstream).replace(
      path: request.uri.path,
      query: request.uri.hasQuery ? request.uri.query : null,
    );
    final outbound = await _upstream.openUrl(request.method, target);
    request.headers.forEach((name, values) {
      final forward =
          name.startsWith('x-') || name == 'content-type' || name == 'accept';
      if (forward) outbound.headers.set(name, values);
    });
    if (body.isNotEmpty) {
      outbound.headers.contentLength = body.length;
      outbound.add(body);
    }
    final inbound = await outbound.close();
    final builder = await inbound.fold(
      BytesBuilder(copy: false),
      (b, chunk) => b..add(chunk),
    );
    final bytes = builder.takeBytes();
    final headers = <String, String>{};
    inbound.headers.forEach((name, values) {
      if (name == 'content-type' || name.startsWith('x-')) {
        headers[name] = values.join(', ');
      }
    });
    final file = '${(_fixtures.length + 1).toString().padLeft(4, '0')}.body';
    File('${_fixtureDir.path}/$file').writeAsBytesSync(bytes);
    final fixture = _Fixture(inbound.statusCode, headers, file)..body = bytes;
    _fixtures[key] = fixture;
    _saveIndex();
    return fixture;
  }

  /// The recorded cold-boot snapshot, for the JSON micro-benchmarks.
  Future<void> _snapshot(HttpRequest request) async {
    final response = request.response;
    _commonHeaders(response);
    final bytes = fixtureBody(
      (key) =>
          key.startsWith('POST /api/v1/refresh?') &&
          key.contains('first_load=true') &&
          !key.contains('current_company'),
    );
    if (bytes == null) {
      await _json(response, 404, '{"message":"bench: no snapshot recorded"}');
      return;
    }
    response.headers.contentType = ContentType.json;
    response.headers.contentLength = bytes.length;
    response.add(bytes);
    await response.close();
  }

  static const _mime = {
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript; charset=utf-8',
    'mjs': 'text/javascript; charset=utf-8',
    'json': 'application/json',
    'wasm': 'application/wasm',
    'css': 'text/css; charset=utf-8',
    'png': 'image/png',
    'ico': 'image/x-icon',
    'svg': 'image/svg+xml',
    'ttf': 'font/ttf',
    'otf': 'font/otf',
    'woff2': 'font/woff2',
  };

  /// Types a static host compresses. Already-compressed formats are left
  /// alone, as they would be in production.
  static const _compressible = {
    'html',
    'js',
    'mjs',
    'json',
    'wasm',
    'css',
    'svg',
    'ttf',
    'otf',
    'symbols',
    'bin',
  };

  Future<_Asset> _asset(File file) async {
    final cached = _assets[file.path];
    if (cached != null) return cached;
    final bytes = await file.readAsBytes();
    final name = file.uri.pathSegments.last;
    final extension = name.contains('.') ? name.split('.').last : '';
    final stat = file.statSync();
    final asset = _Asset(
      bytes,
      _compressible.contains(extension)
          ? Uint8List.fromList(GZipCodec(level: 6).encode(bytes))
          : null,
      '"${stat.size}-${stat.modified.millisecondsSinceEpoch}"',
      _mime[extension] ?? 'application/octet-stream',
    );
    return _assets[file.path] = asset;
  }

  Future<void> _static(HttpRequest request) async {
    final response = request.response;
    _commonHeaders(response);
    final root = _root;
    if (root == null) {
      response.statusCode = HttpStatus.serviceUnavailable;
      await response.close();
      return;
    }
    var relative = Uri.decodeComponent(request.uri.path);
    if (relative.endsWith('/')) relative = '${relative}index.html';
    final file = File('${root.path}$relative');
    final inside = file.absolute.path.startsWith(root.absolute.path);
    if (relative.contains('..') || !inside || !file.existsSync()) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      _log.add(AccessEntry(relative, 404, 0, api: false));
      return;
    }
    final asset = await _asset(file);
    // What GitHub Pages sends for the live demo: ten minutes, then revalidate.
    response.headers
      ..set(HttpHeaders.cacheControlHeader, 'max-age=600')
      ..set(HttpHeaders.etagHeader, asset.etag)
      ..set(HttpHeaders.contentTypeHeader, asset.mime);
    if (request.headers.value(HttpHeaders.ifNoneMatchHeader) == asset.etag) {
      response.statusCode = HttpStatus.notModified;
      await response.close();
      _log.add(AccessEntry(relative, 304, 0, api: false));
      return;
    }
    var bytes = asset.bytes;
    var gzipped = asset.gzipped;
    if (_forceSingleThread && relative == '/flutter_bootstrap.js') {
      // The loader's own switch for single-threaded skwasm, so an isolated
      // page can be measured with and without the raster worker.
      const call = '_flutter.loader.load({';
      final source = utf8.decode(bytes);
      if (!source.contains(call)) {
        throw StateError('flutter_bootstrap.js has no `$call` to patch');
      }
      bytes = Uint8List.fromList(
        utf8.encode(
          source.replaceFirst(
            call,
            '$call config: {forceSingleThreadedSkwasm: true},',
          ),
        ),
      );
      gzipped = null;
    }
    final accepts =
        request.headers.value(HttpHeaders.acceptEncodingHeader) ?? '';
    if (gzipped != null && accepts.contains('gzip')) {
      response.headers.set(HttpHeaders.contentEncodingHeader, 'gzip');
      bytes = gzipped;
    }
    response.headers.contentLength = bytes.length;
    response.add(bytes);
    await response.close();
    _log.add(AccessEntry(relative, 200, bytes.length, api: false));
  }
}

String localDay() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}-${two(now.month)}-${two(now.day)}';
}
