import 'dart:async';

import 'package:sentry_flutter/sentry_flutter.dart';

/// Runs [appRunner] under Sentry.
///
/// [release] is sent as both `release` and `dist`. [shouldSend] is asked for
/// every event at send time, and a `false` drops it (the per-account
/// `report_errors` opt-in, `lib/app/sentry_gate.dart`). The caller decides
/// whether to report at all; this only wires the SDK.
Future<void> runWithCrashReporting({
  required String dsn,
  required String release,
  required bool Function() shouldSend,
  required FutureOr<void> Function() appRunner,
}) {
  return SentryFlutter.init((o) {
    o.dsn = dsn;
    o.release = release;
    o.dist = release;
    o.beforeSend = (event, hint) => shouldSend() ? event : null;
  }, appRunner: appRunner);
}
