import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/template_variable_probe.dart';
import 'package:admin/data/services/templates_api.dart';
import 'package:admin/domain/email_template_variables.dart';

final _log = Logger('TemplateVariableValuesController');

/// What each `$variable` resolves to for the document being emailed — the
/// values the Send Email subject's chips show (invoiceninja/flutter#139).
///
/// Exact, not estimated: it asks the server through
/// [resolveTemplateVariables], which renders the tokens with the same engine
/// and the same values the email will get. So it only exists when the
/// composer's preview is **bound** to the document (`emailPreviewBinding`):
/// unbound, the server substitutes another record's values (#31).
///
/// One probe on open covers the scope's whole catalog plus the subject's own
/// tokens — the engine computes every value anyway, so the extra tokens are
/// nearly free and the picker gets its values too. After that, only tokens
/// nobody asked about yet (typed or inserted) are probed, debounced.
///
/// Every failure is silent — the chips fall back to their labels. A permanent
/// one (no plan, no permission, a malformed response) stops probing for the
/// screen; a transient one lets the same tokens be asked again on the next
/// change, no sooner than [retryAfter] — a timestamp, never a `Timer`.
class TemplateVariableValuesController extends ChangeNotifier
    implements ValueListenable<Map<String, TemplateVariableValue>> {
  TemplateVariableValuesController({
    required TemplatesApi api,
    required String entity,
    required String entityId,
    required TemplateVariableScope scope,
    required String Function() template,
    Duration debounce = const Duration(milliseconds: 400),
    Duration timeout = const Duration(seconds: 15),
    Duration retryAfter = const Duration(seconds: 30),
    DateTime Function()? clock,
  }) : _api = api,
       _entity = entity,
       _entityId = entityId,
       _scope = scope,
       _template = template,
       _debounce = debounce,
       _timeout = timeout,
       _retryAfter = retryAfter,
       _clock = clock ?? DateTime.now;

  final TemplatesApi _api;
  final String _entity;
  final String _entityId;
  final TemplateVariableScope _scope;
  final String Function() _template;
  final Duration _debounce;
  final Duration _timeout;
  final Duration _retryAfter;
  final DateTime Function() _clock;

  Map<String, TemplateVariableValue> _value = const {};

  /// Tokens already probed, or in flight.
  final _asked = <String>{};
  final _pending = <String>{};
  Timer? _timer;
  DateTime? _retryNotBefore;
  bool _disabled = false;
  bool _disposed = false;

  @override
  Map<String, TemplateVariableValue> get value => _value;

  /// The one probe on open: the catalog plus [tokens].
  void start(Iterable<String> tokens) {
    _enqueue([
      for (final group in templateVariableGroups(_scope))
        for (final variable in group.variables) variable.token,
      ...tokens,
    ]);
    unawaited(_fire());
  }

  /// The text changed: probe any token in [text] not asked about yet.
  void noteText(String text) {
    _enqueue(findTemplateVariables(text).map((m) => m.token));
    if (_pending.isEmpty) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(_fire()));
  }

  void _enqueue(Iterable<String> tokens) {
    for (final token in tokens) {
      if (!_asked.contains(token)) _pending.add(token);
    }
  }

  Future<void> _fire() async {
    _timer?.cancel();
    _timer = null;
    if (_disabled || _disposed || _pending.isEmpty) return;
    final notBefore = _retryNotBefore;
    if (notBefore != null && _clock().isBefore(notBefore)) return;
    final batch = _pending.toList();
    _pending.clear();
    _asked.addAll(batch);
    try {
      final values = await resolveTemplateVariables(
        _api,
        template: _template(),
        entity: _entity,
        entityId: _entityId,
        tokens: batch,
      ).timeout(_timeout);
      if (_disposed) return;
      _retryNotBefore = null;
      if (values.isEmpty) return;
      _value = Map.unmodifiable({..._value, ...values});
      notifyListeners();
    } catch (e, st) {
      if (_disposed) return;
      if (_isPermanent(e)) {
        _disabled = true;
        // With the stack: this branch switches probing off for the rest of the
        // screen, so the log entry is the only trace it ever happened.
        _log.fine('Variable values unavailable; not probing again', e, st);
        return;
      }
      _asked.removeAll(batch);
      _retryNotBefore = _clock().add(_retryAfter);
      if (e is NetworkException || e is TimeoutException) {
        _log.fine('Variable value probe failed; will retry', e);
      } else {
        _log.warning('Variable value probe failed; will retry', e, st);
      }
    }
  }

  /// Deliberately **not** `ArgumentError`: `RangeError` and `IndexError` both
  /// extend it, so a plain index bug anywhere under the `try` would switch
  /// probing off for the screen and read as "the values just stopped coming".
  /// The probe's own unbound `ArgumentError` can't reach here — the composer
  /// builds this controller only for a bound document.
  static bool _isPermanent(Object e) =>
      e is PlanRequiredException ||
      e is UnauthorizedException ||
      e is NotFoundException ||
      (e is ServerException && const {401, 403, 404}.contains(e.statusCode)) ||
      e is FormatException;

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
