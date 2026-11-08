import 'dart:async';

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
    Duration readyTimeout = const Duration(seconds: 20),
  }) : _runJavaScript = runJavaScript,
       _currentUrl = currentUrl,
       _token = token,
       _onDocumentChanged = onDocumentChanged,
       _onClose = onClose,
       _openExternal = openExternal,
       _readyTimeout = readyTimeout;

  final Future<void> Function(String script) _runJavaScript;
  final Future<String?> Function() _currentUrl;
  final String? Function() _token;
  final VoidCallback _onDocumentChanged;
  final VoidCallback _onClose;
  final void Function(Uri uri) _openExternal;
  final Duration _readyTimeout;

  DnBuilderPhase _phase = DnBuilderPhase.loading;
  DnBuilderPhase get phase => _phase;

  bool _dirty = false;

  /// Fields placed or changed since the last save (the page reports it).
  bool get isDirty => _dirty;

  Timer? _readyTimer;
  bool _handedOver = false;
  bool _disposed = false;

  /// Starts the wait for the page: one that never asks for its token within
  /// [_readyTimeout] is not an embed, and the builder opens in the browser.
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

  /// One message from the page's `InvoiceNinjaApp` channel.
  Future<void> handle(String raw) async {
    final message = DnEmbedMessage.parse(raw);
    if (message == null) {
      _log.warning('DocuNinja builder: unreadable message');
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
        await _handOver();
      case 'loaded':
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
      case 'mapSignatoriesSent':
        _onDocumentChanged();
        _onClose();
      case 'openExternal':
        final uri = Uri.tryParse('${message.payload['url'] ?? ''}');
        if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
          _openExternal(uri);
        }
      case 'saveError' || 'sendError':
        // The page shows its own error; nothing for the app to do.
        break;
      default:
        _log.fine('DocuNinja builder: ignored ${message.type}');
    }
  }

  /// Hands the page its token, once, and only while the web view is on the
  /// web app's own origin: a message is no proof of where it came from.
  Future<void> _handOver() async {
    if (_handedOver) return;
    final url = Uri.tryParse(await _currentUrl() ?? '');
    final token = _token();
    if (url == null || !dnEmbedAllowed(url) || token == null || token.isEmpty) {
      _log.warning('DocuNinja builder: not handing over the token');
      _set(DnBuilderPhase.unavailable);
      return;
    }
    _handedOver = true;
    await _runJavaScript(dnEmbedInitScript(token));
  }

  void _set(DnBuilderPhase phase) {
    if (_phase == phase) return;
    _phase = phase;
    if (phase != DnBuilderPhase.loading) _readyTimer?.cancel();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _readyTimer?.cancel();
    super.dispose();
  }
}
