import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('perf');

/// Spans shorter than this are left out of the log (the timeline keeps them),
/// so a burst of small list pages does not bury the slow ones.
const _kLogFloorMs = 1;

/// Times the synchronous [body] as a `dart:developer` timeline span named
/// [name], and logs its duration at FINE on the `perf` logger.
///
/// For work that blocks the UI isolate: the timeline shows it in DevTools on a
/// profile build, the log shows it in a debug console. A release build runs
/// [body] directly and pays nothing. See `docs/startup-responsiveness.md`.
T traceSync<T>(String name, T Function() body, {Map<String, Object?>? args}) {
  if (kReleaseMode) return body();
  final stopwatch = Stopwatch()..start();
  try {
    return developer.Timeline.timeSync(name, body, arguments: args);
  } finally {
    _logSpan(name, stopwatch, args);
  }
}

/// [traceSync] for an asynchronous [body]. The duration covers the waits
/// inside it — a network round trip, the database isolate — not only the time
/// spent on the UI isolate.
Future<T> traceAsync<T>(
  String name,
  Future<T> Function() body, {
  Map<String, Object?>? args,
}) async {
  if (kReleaseMode) return body();
  final task = developer.TimelineTask()..start(name, arguments: args);
  final stopwatch = Stopwatch()..start();
  try {
    return await body();
  } finally {
    task.finish();
    _logSpan(name, stopwatch, args);
  }
}

void _logSpan(String name, Stopwatch stopwatch, Map<String, Object?>? args) {
  final ms = stopwatch.elapsedMilliseconds;
  if (ms < _kLogFloorMs) return;
  _log.fine(
    () => args == null || args.isEmpty
        ? '$name: ${ms}ms'
        : '$name: ${ms}ms $args',
  );
}
