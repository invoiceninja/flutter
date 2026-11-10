import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Runs [appRunner] under Sentry.
///
/// [release] is sent as both `release` and `dist`. [shouldSend] is asked for
/// every event at send time, and a `false` drops it (the per-account
/// `report_errors` opt-in, `lib/app/sentry_gate.dart`). [redact] — the same
/// scrubber the logs use (`lib/app/logging.dart`) — runs over every text an
/// event or breadcrumb carries before it leaves, and an event it can't
/// scrub is dropped. The caller decides whether to report at all; this only
/// wires the SDK.
///
/// The native SDKs' own network breadcrumbs and failed-request events are
/// off: they record other SDKs' traffic (Stripe Terminal's among them) and
/// never pass these callbacks. The app's own requests go through Dart, not
/// through them.
Future<void> runWithCrashReporting({
  required String dsn,
  required String release,
  required bool Function() shouldSend,
  required String Function(String) redact,
  required FutureOr<void> Function() appRunner,
}) {
  return SentryFlutter.init((o) {
    o.dsn = dsn;
    o.release = release;
    o.dist = release;
    o.recordHttpBreadcrumbs = false;
    o.captureFailedRequests = false;
    o.beforeBreadcrumb = (breadcrumb, hint) {
      if (breadcrumb == null) return null;
      try {
        _redactBreadcrumb(breadcrumb, redact);
        return breadcrumb;
      } catch (_) {
        return null;
      }
    };
    o.beforeSend = (event, hint) {
      if (!shouldSend()) return null;
      try {
        return _redacted(event, redact);
      } catch (_) {
        return null;
      }
    };
  }, appRunner: appRunner);
}

SentryEvent _redacted(SentryEvent event, String Function(String) redact) {
  final message = event.message;
  if (message != null) {
    message.formatted = redact(message.formatted);
    if (message.template case final template?) {
      message.template = redact(template);
    }
    if (message.params case final params?) {
      message.params = _redactValue(params, redact) as List<dynamic>;
    }
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    if (exception.value case final value?) exception.value = redact(value);
  }
  for (final breadcrumb in event.breadcrumbs ?? const <Breadcrumb>[]) {
    _redactBreadcrumb(breadcrumb, redact);
  }
  final contexts = event.contexts;
  for (final key in contexts.keys.toList()) {
    final value = contexts[key];
    if (value is String || value is Map || value is List) {
      contexts[key] = _redactValue(value, redact);
    }
  }
  return event;
}

void _redactBreadcrumb(Breadcrumb breadcrumb, String Function(String) redact) {
  if (breadcrumb.message case final text?) breadcrumb.message = redact(text);
  if (breadcrumb.data case final data?) {
    breadcrumb.data = _redactValue(data, redact) as Map<String, dynamic>;
  }
}

/// Strings, and the strings inside maps and lists, scrubbed; anything else
/// as it was.
Object? _redactValue(Object? value, String Function(String) redact) =>
    switch (value) {
      final String text => redact(text),
      final Map<String, dynamic> map => <String, dynamic>{
        for (final e in map.entries) e.key: _redactValue(e.value, redact),
      },
      final Map<dynamic, dynamic> map => {
        for (final e in map.entries) e.key: _redactValue(e.value, redact),
      },
      final List<dynamic> list => [
        for (final item in list) _redactValue(item, redact),
      ],
      _ => value,
    };
