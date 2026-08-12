import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:logging/logging.dart';

import 'package:admin/data/services/templates_api.dart';

/// State of the template preview panel — drives the `PreviewIdle` /
/// `PreviewLoading` / `PreviewLoaded` / `PreviewError` switch in
/// `TemplatePreviewPanel`.
sealed class TemplatePreviewState {
  const TemplatePreviewState();
}

class TemplatePreviewIdle extends TemplatePreviewState {
  const TemplatePreviewIdle();
}

class TemplatePreviewLoading extends TemplatePreviewState {
  const TemplatePreviewLoading();
}

class TemplatePreviewLoaded extends TemplatePreviewState {
  const TemplatePreviewLoaded(this.preview);
  final TemplatePreview preview;
}

/// Categorized error so the preview panel can pattern-match on the kind
/// instead of substring-sniffing `e.toString()`.
enum TemplatePreviewErrorKind { network, timeout, server }

class TemplatePreviewError extends TemplatePreviewState {
  const TemplatePreviewError({required this.kind, required this.message});
  final TemplatePreviewErrorKind kind;
  final String message;
}

final _log = Logger('PreviewController');

/// Debounced fetcher for the live email-template preview. Exposed as a
/// `ValueListenable` so the panel can drive a single `ValueListenableBuilder`
/// without taking a Provider dependency on the parent VM.
///
/// Coalesces edits at ~400 ms; if a request comes in while another is in
/// flight the in-flight one is canceled via [_currentToken] (results from
/// stale requests are dropped). Each request is wrapped with a 15 s
/// timeout so a hung server doesn't park the panel in Loading forever.
class PreviewController extends ChangeNotifier
    implements ValueListenable<TemplatePreviewState> {
  PreviewController({
    required TemplatesApi api,
    Duration debounce = const Duration(milliseconds: 400),
    Duration timeout = const Duration(seconds: 15),
  }) : _api = api,
       _debounce = debounce,
       _timeout = timeout;

  final TemplatesApi _api;
  final Duration _debounce;
  final Duration _timeout;

  TemplatePreviewState _value = const TemplatePreviewIdle();
  Timer? _timer;
  int _currentToken = 0;
  _PendingRequest? _last;
  bool _disposed = false;

  @override
  TemplatePreviewState get value => _value;

  /// Schedule a preview fetch. Coalesces with any pending request — the
  /// latest [template] / [subject] / [body] wins. Use [immediate] = true
  /// from `initState` (via `addPostFrameCallback`) so the first preview
  /// fires without waiting for the debounce window.
  ///
  /// [entity] / [entityId] bind the render to a real document; leave them
  /// empty (the default, used by Settings → Templates & Reminders) to let
  /// the server pick a generic sample. See [TemplatesApi] for why a caller
  /// that *has* a document must pass them.
  void schedule({
    required String template,
    required String subject,
    required String body,
    String entity = '',
    String entityId = '',
    bool immediate = false,
  }) {
    _last = _PendingRequest(
      template: template,
      subject: subject,
      body: body,
      entity: entity,
      entityId: entityId,
    );
    _timer?.cancel();
    if (immediate) {
      _fire();
      return;
    }
    _timer = Timer(_debounce, _fire);
  }

  Future<void> _fire() async {
    if (_disposed) return;
    final req = _last;
    if (req == null) return;
    final token = ++_currentToken;
    _value = const TemplatePreviewLoading();
    notifyListeners();
    try {
      final preview = await _api
          .render(
            template: req.template,
            subject: req.subject,
            body: req.body,
            entity: req.entity,
            entityId: req.entityId,
          )
          .timeout(_timeout);
      if (_disposed || token != _currentToken) return; // disposed or stale
      _value = TemplatePreviewLoaded(preview);
      notifyListeners();
    } catch (e, st) {
      if (_disposed || token != _currentToken) return;
      final kind = _classify(e);
      _log.warning('Template preview render failed (kind=$kind)', e, st);
      _value = TemplatePreviewError(kind: kind, message: e.toString());
      notifyListeners();
    }
  }

  /// Re-issue the last request (used by the error-state Retry button).
  /// Post-save refreshes should call `schedule(immediate: true)` from the
  /// caller instead, with fresh subject/body — `refresh` reuses the
  /// cached `_last` which may be stale.
  void refresh() {
    if (_last == null) return;
    _timer?.cancel();
    _fire();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  static TemplatePreviewErrorKind _classify(Object e) {
    if (e is TimeoutException) return TemplatePreviewErrorKind.timeout;
    if (e is SocketException || e is ClientException) {
      return TemplatePreviewErrorKind.network;
    }
    return TemplatePreviewErrorKind.server;
  }
}

class _PendingRequest {
  const _PendingRequest({
    required this.template,
    required this.subject,
    required this.body,
    required this.entity,
    required this.entityId,
  });

  final String template;
  final String subject;
  final String body;
  final String entity;
  final String entityId;
}
