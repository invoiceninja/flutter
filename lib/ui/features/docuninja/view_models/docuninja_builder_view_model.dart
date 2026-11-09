import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/domain/docuninja/docuninja_embed.dart';

final _log = Logger('DocuNinjaBuilderViewModel');

/// Where the embedded builder stands.
enum DnBuilderPhase {
  /// The page is loading, or has not asked for its token yet.
  loading,

  /// The builder is up.
  ready,

  /// The page never answered (no embed mode on the server yet, or another
  /// protocol version), or failed to load: the screen offers the browser.
  unavailable,
}

/// The app's half of the embedded builder (docs/docuninja.md § The field
/// builder runs embedded where a web view can): answers the page's messages,
/// hands it the token, and tracks unsaved work. It never touches a web view
/// itself; the screen passes in what it needs, so this is testable without
/// one.
class DocuNinjaBuilderViewModel extends ChangeNotifier {
  DocuNinjaBuilderViewModel({
    required Future<void> Function(String script) runJavaScript,
    required Future<String?> Function() currentUrl,
    required String? Function() token,
    required VoidCallback onDocumentChanged,
    required VoidCallback onClose,
    required void Function(Uri uri) openExternal,
    required Future<void> Function(Uri uri) openInPlace,
    Duration readyTimeout = const Duration(seconds: 20),
    Duration slowTimeout = const Duration(seconds: 60),
  }) : _runJavaScript = runJavaScript,
       _currentUrl = currentUrl,
       _token = token,
       _onDocumentChanged = onDocumentChanged,
       _onClose = onClose,
       _openExternal = openExternal,
       _openInPlace = openInPlace,
       _readyTimeout = readyTimeout,
       _slowTimeout = slowTimeout;

  final Future<void> Function(String script) _runJavaScript;
  final Future<String?> Function() _currentUrl;
  final String? Function() _token;
  final VoidCallback _onDocumentChanged;
  final VoidCallback _onClose;
  final void Function(Uri uri) _openExternal;
  final Future<void> Function(Uri uri) _openInPlace;
  final Duration _readyTimeout;
  final Duration _slowTimeout;

  DnBuilderPhase _phase = DnBuilderPhase.loading;
  DnBuilderPhase get phase => _phase;

  String? _loadedDocumentId;

  /// The document (or template) the page last reported up (`loaded`). In a
  /// template's builder, React's Use Template moves the page on to the new
  /// document's builder, and this follows it.
  String? get loadedDocumentId => _loadedDocumentId;

  bool _dirty = false;

  /// Fields placed or changed since the last save (the page reports it).
  bool get isDirty => _dirty;

  Timer? _readyTimer;
  Timer? _slowTimer;
  bool _disposed = false;

  bool _slow = false;

  /// The page asked for its token but the builder has not come up after
  /// [_slowTimeout]: a document it cannot open (deleted, no access) never
  /// does, and its own message sits under the loading cover. The screen
  /// keeps waiting (a large upload's previews can take minutes) but offers
  /// the browser.
  bool get isSlow => _slow;

  /// A secret for this screen: the page echoes it on every message after
  /// `init`, so a message from any other frame on the page is ignored.
  final String _nonce = List.generate(
    32,
    (_) => Random.secure().nextInt(16).toRadixString(16),
  ).join();

  /// A main-frame page started since the last `ready`: only a real boot
  /// (a reload) clears the unsaved flag, not a `ready` some frame posts.
  bool _pageStarted = true;

  /// The web view started loading a page in its main frame.
  void pageStarted() => _pageStarted = true;

  /// Starts the wait for the page: one that never asks for its token within
  /// [_readyTimeout] is not an embed (the server has no embed mode, or the
  /// load failed), and the builder opens in the browser. Once it has asked,
  /// it is an embed however long the builder then takes (previews of a big
  /// upload can take minutes).
  void start() {
    _readyTimer?.cancel();
    _readyTimer = Timer(_readyTimeout, () {
      if (_phase == DnBuilderPhase.loading) _set(DnBuilderPhase.unavailable);
    });
  }

  /// The page failed to load.
  void loadFailed() => _set(DnBuilderPhase.unavailable);

  /// Discards unsaved work: the user chose to leave without saving.
  void discard() {
    _dirty = false;
    _notify();
  }

  /// The nonce, for tests.
  @visibleForTesting
  String get nonce => _nonce;

  /// One message from the page's `InvoiceNinjaApp` channel.
  Future<void> handle(String raw) async {
    if (_disposed) return;
    final message = DnEmbedMessage.parse(raw);
    if (message == null) {
      _log.warning('DocuNinja builder: unreadable message');
      return;
    }
    // Before the page has its nonce it may only say `ready`; after, every
    // message must carry it back.
    if (message.type != 'ready' && message.nonce != _nonce) {
      _log.warning('DocuNinja builder: message without the page nonce');
      return;
    }
    // A `ready` carries no nonce, so any frame on the page can post one:
    // only a page that really started may turn the screen off with it.
    if (message.type == 'ready' &&
        message.version != kDnEmbedProtocolVersion &&
        !_pageStarted) {
      _log.warning('DocuNinja builder: ignored a ready from another frame');
      return;
    }
    if (message.version != kDnEmbedProtocolVersion) {
      _log.warning(
        'DocuNinja builder: protocol ${message.version}, '
        'expected $kDnEmbedProtocolVersion',
      );
      _set(DnBuilderPhase.unavailable);
      return;
    }
    switch (message.type) {
      case 'ready':
        // A new boot (a reload, or the first): nothing on it is unsaved.
        if (_pageStarted && _dirty) {
          _dirty = false;
          _notify();
        }
        _pageStarted = false;
        await _handOver();
        if (_phase == DnBuilderPhase.loading) {
          _readyTimer?.cancel();
          _slowTimer ??= Timer(_slowTimeout, () {
            if (_phase != DnBuilderPhase.loading) return;
            _slow = true;
            _notify();
          });
        }
      case 'loaded':
        final id = message.payload['documentId'];
        if (id is String && id.isNotEmpty) _loadedDocumentId = id;
        _readyTimer?.cancel();
        _set(DnBuilderPhase.ready);
      case 'dirty':
        _dirty = message.payload['dirty'] == true;
        _notify();
      case 'saved':
        _dirty = false;
        _notify();
        _onDocumentChanged();
      case 'sent' || 'documentUpdated':
        _onDocumentChanged();
      case 'mapSignatoriesSent' || 'signed':
        // A send from the builder, or the user's signature on React's sign
        // page: the document changed, and this page is done (nothing left
        // unsaved to ask about).
        _dirty = false;
        _onDocumentChanged();
        _onClose();
      case 'error':
        // The page could not sign in (a 401 it would otherwise reload on
        // forever; a 429 shows its own toast and stays): the browser is the
        // way on.
        _set(DnBuilderPhase.unavailable);
      case 'openExternal':
        final uri = Uri.tryParse('${message.payload['url'] ?? ''}');
        if (uri == null) return;
        if (dnEmbedAllowed(uri)) {
          // The web app's own page (React's Sign): here, signed in.
          await _openInPlace(uri);
        } else if (uri.scheme == 'https' || uri.scheme == 'http') {
          _openExternal(uri);
        }
      case 'saveError' || 'sendError':
        // The page shows its own error; nothing for the app to do.
        break;
      default:
        _log.fine('DocuNinja builder: ignored ${message.type}');
    }
  }

  /// Hands the page its token, on every `ready` (React reloads itself, on a
  /// 401 or after an update, and each boot waits for it), and only while the
  /// web view is on the web app's own origin: a message is no proof of where
  /// it came from.
  Future<void> _handOver() async {
    final url = Uri.tryParse(await _currentUrl() ?? '');
    final token = _token();
    if (url == null || !dnEmbedAllowed(url) || token == null || token.isEmpty) {
      _log.warning('DocuNinja builder: not handing over the token');
      _set(DnBuilderPhase.unavailable);
      return;
    }
    try {
      await _runJavaScript(dnEmbedInitScript(token, _nonce));
    } on Object catch (e) {
      // The web view went away (the screen closed) meanwhile.
      _log.fine('DocuNinja builder: handover failed: $e');
    }
  }

  void _set(DnBuilderPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    if (phase != DnBuilderPhase.loading) {
      _readyTimer?.cancel();
      _slowTimer?.cancel();
      _slow = false;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _readyTimer?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }
}
