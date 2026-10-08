// A minimal Chrome DevTools Protocol client for the web benchmark: launches
// the installed Chrome on a throwaway profile and drives one page over a
// `dart:io` WebSocket. No chromedriver, no package — see `main.dart`.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const kDefaultChromeBinary =
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

class CdpException implements Exception {
  CdpException(this.message);
  final String message;
  @override
  String toString() => 'CdpException: $message';
}

class CdpEvent {
  CdpEvent(this.method, this.params, this.sessionId);
  final String method;
  final Map<String, dynamic> params;
  final String? sessionId;
}

/// One Chrome process on its own profile directory, with a single attached
/// page. Every cold-start sample gets a new one, so no cache, storage or
/// compiled-code cache carries over between samples.
class Chrome {
  Chrome._(this._process, this._profile, this._socket) {
    _socket.listen(
      _onMessage,
      onDone: () => _failPending('Chrome closed the DevTools socket'),
      onError: (Object e) => _failPending('DevTools socket error: $e'),
    );
  }

  final Process _process;
  final Directory _profile;
  final WebSocket _socket;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _events = StreamController<CdpEvent>.broadcast();
  int _nextId = 1;
  late String _session;
  bool _closed = false;

  /// Main-frame navigations seen since the last [resetNavigationCount].
  int mainFrameNavigations = 0;

  Stream<CdpEvent> get events => _events.stream;

  static Future<Chrome> launch({
    required String binary,
    required bool headless,
    required int width,
    required int height,
    required double deviceScaleFactor,
    required String initScript,
  }) async {
    final profile = await Directory.systemTemp.createTemp('in-web-bench-');
    final args = <String>[
      '--user-data-dir=${profile.path}',
      '--remote-debugging-port=0',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-extensions',
      '--disable-component-extensions-with-background-pages',
      '--disable-component-update',
      '--disable-background-networking',
      '--disable-sync',
      '--disable-default-apps',
      '--password-store=basic',
      '--use-mock-keychain',
      // A measured page must keep drawing whether or not its window is in
      // front — and must never be resurrected from the back/forward cache,
      // where a frozen copy would still hold the app's database open.
      '--disable-backgrounding-occluded-windows',
      '--disable-renderer-backgrounding',
      '--disable-background-timer-throttling',
      '--disable-features=BackForwardCache,Translate,MediaRouter,'
          'OptimizationHints,CalculateNativeWinOcclusion',
      // The harness serves everything the app needs from 127.0.0.1, so any
      // other host is unreachable by construction: no third-party fetch can
      // add network noise to a sample.
      '--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1',
      '--window-size=$width,$height',
      if (headless) '--headless=new',
      'about:blank',
    ];
    final process = await Process.start(binary, args);
    // Chrome is chatty on stderr; drain both so the pipes never fill.
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());

    final portFile = File('${profile.path}/DevToolsActivePort');
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    while (!portFile.existsSync() || portFile.lengthSync() == 0) {
      if (DateTime.now().isAfter(deadline)) {
        process.kill(ProcessSignal.sigkill);
        throw CdpException('Chrome did not open a DevTools port in 30 s');
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final lines = portFile.readAsLinesSync();
    final socket = await WebSocket.connect(
      'ws://127.0.0.1:${lines[0]}${lines[1]}',
    );
    final chrome = Chrome._(process, profile, socket);
    await chrome._attach(
      width: width,
      height: height,
      deviceScaleFactor: deviceScaleFactor,
      initScript: initScript,
    );
    return chrome;
  }

  Future<void> _attach({
    required int width,
    required int height,
    required double deviceScaleFactor,
    required String initScript,
  }) async {
    final targets = await browser('Target.getTargets');
    final page = (targets['targetInfos'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((t) => t['type'] == 'page');
    final attached = await browser('Target.attachToTarget', {
      'targetId': page['targetId'],
      'flatten': true,
    });
    _session = attached['sessionId'] as String;
    await send('Page.enable');
    await send('Emulation.setDeviceMetricsOverride', {
      'width': width,
      'height': height,
      'deviceScaleFactor': deviceScaleFactor,
      'mobile': false,
    });
    // Pinned: a real focus change makes the app fire a time-keyed refresh.
    await send('Emulation.setFocusEmulationEnabled', {'enabled': true});
    await send('Page.addScriptToEvaluateOnNewDocument', {'source': initScript});
  }

  void _onMessage(dynamic raw) {
    final message = jsonDecode(raw as String) as Map<String, dynamic>;
    final id = message['id'];
    if (id is int) {
      final completer = _pending.remove(id);
      if (completer == null) return;
      final error = message['error'];
      if (error != null) {
        completer.completeError(CdpException(jsonEncode(error)));
      } else {
        completer.complete(
          (message['result'] as Map<String, dynamic>?) ?? const {},
        );
      }
      return;
    }
    final method = message['method'] as String?;
    if (method == null) return;
    final params = (message['params'] as Map<String, dynamic>?) ?? const {};
    if (method == 'Page.frameNavigated') {
      final frame = params['frame'] as Map<String, dynamic>;
      if (frame['parentId'] == null) mainFrameNavigations++;
    }
    _events.add(CdpEvent(method, params, message['sessionId'] as String?));
  }

  void _failPending(String why) {
    for (final completer in _pending.values) {
      completer.completeError(CdpException(why));
    }
    _pending.clear();
  }

  Future<Map<String, dynamic>> _call(
    String method,
    Map<String, dynamic>? params,
    String? session,
  ) {
    if (_closed) throw CdpException('$method after close');
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _socket.add(
      jsonEncode({
        'id': id,
        'method': method,
        'params': ?params,
        'sessionId': ?session,
      }),
    );
    return completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () {
        _pending.remove(id);
        throw CdpException('$method timed out');
      },
    );
  }

  /// A browser-level command (targets, system info).
  Future<Map<String, dynamic>> browser(
    String method, [
    Map<String, dynamic>? params,
  ]) => _call(method, params, null);

  /// A command on the attached page.
  Future<Map<String, dynamic>> send(
    String method, [
    Map<String, dynamic>? params,
  ]) => _call(method, params, _session);

  /// Evaluates [expression] in the page and returns its JSON-able value.
  Future<Object?> eval(String expression, {bool awaitPromise = false}) async {
    final response = await send('Runtime.evaluate', {
      'expression': expression,
      'returnByValue': true,
      'awaitPromise': awaitPromise,
    });
    final details = response['exceptionDetails'];
    if (details != null) {
      final text = (details as Map<String, dynamic>)['exception'] is Map
          ? ((details['exception'] as Map)['description'] ?? details['text'])
          : details['text'];
      throw CdpException('eval failed: $text\n  in: $expression');
    }
    return (response['result'] as Map<String, dynamic>)['value'];
  }

  /// [eval] for an expression that returns a JSON string.
  Future<Map<String, dynamic>> evalJson(
    String expression, {
    bool awaitPromise = false,
  }) async {
    final value = await eval(expression, awaitPromise: awaitPromise);
    return jsonDecode(value! as String) as Map<String, dynamic>;
  }

  Future<void> navigate(String url) async {
    final response = await send('Page.navigate', {'url': url});
    final error = response['errorText'];
    if (error != null) throw CdpException('navigate($url): $error');
  }

  void resetNavigationCount() => mainFrameNavigations = 0;

  /// The app's own shared and service workers still alive in this browser.
  /// A warm reload waits for zero: a worker left over from the previous page
  /// still holds the app's database, and opening over it is what the app
  /// reports as "open in another tab". Filtered to [origin] because Chrome's
  /// built-in extensions run a service worker of their own for ~25 s.
  Future<int> backgroundWorkers(String origin) async {
    final targets = await browser('Target.getTargets');
    return (targets['targetInfos'] as List)
        .cast<Map<String, dynamic>>()
        .where(
          (t) =>
              (t['type'] == 'shared_worker' || t['type'] == 'service_worker') &&
              (t['url'] as String).startsWith(origin),
        )
        .length;
  }

  Future<void> wheel(double x, double y, double deltaY) => send(
    'Input.dispatchMouseEvent',
    {'type': 'mouseWheel', 'x': x, 'y': y, 'deltaX': 0, 'deltaY': deltaY},
  );

  Future<void> mouseMove(double x, double y) =>
      send('Input.dispatchMouseEvent', {'type': 'mouseMoved', 'x': x, 'y': y});

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await _socket.close().timeout(const Duration(seconds: 2));
    } on Object {
      // Closing a dead socket is fine.
    }
    _process.kill(ProcessSignal.sigterm);
    try {
      await _process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _process.kill(ProcessSignal.sigkill);
      await _process.exitCode;
    }
    await _events.close();
    // Chrome's helpers can still be flushing the profile for a moment.
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        if (_profile.existsSync()) _profile.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
  }
}
