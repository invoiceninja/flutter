import 'dart:async';

/// FOSS stub: no crash reporting — F-Droid tags Sentry as a tracker, so the
/// FOSS build leaves it out entirely and just runs the app.
Future<void> runWithCrashReporting({
  required String dsn,
  required String release,
  required bool Function() shouldSend,
  required FutureOr<void> Function() appRunner,
}) async {
  await appRunner();
}
