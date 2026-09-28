import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: only `lib/main.dart` turns hosted real-time updates on.
///
/// `Services.build(realtimeUpdates:)` defaults to `false` because every test,
/// the integration harnesses and the screenshot runner build the same graph.
/// With the flag on, a hosted login there would open a real websocket to
/// `socket.invoicing.co` and leave its reconnect / watchdog timers pending —
/// which fails `testWidgets` at best and, in a harness, quietly makes live
/// network calls at worst. Nothing in the type system notices a stray `true`,
/// so this does (docs/realtime-updates.md § Who opens the socket).
void main() {
  test('only lib/main.dart passes realtimeUpdates: true', () {
    final pattern = RegExp(r'realtimeUpdates:\s*true');
    final offenders = <String>[];
    var mainDoes = false;

    for (final root in const ['lib', 'test', 'integration_test']) {
      final dir = Directory(root);
      if (!dir.existsSync()) continue;
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        // This file names the pattern in its own source.
        if (path.endsWith('test/lint/realtime_opt_in_test.dart')) continue;
        if (!pattern.hasMatch(entity.readAsStringSync())) continue;
        if (path == 'lib/main.dart') {
          mainDoes = true;
        } else {
          offenders.add(path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Only the app entry point may open the real-time socket; tests and '
          'harnesses must leave `realtimeUpdates` at its default (false). '
          'Found: ${offenders.join(', ')}',
    );
    expect(
      mainDoes,
      isTrue,
      reason:
          'lib/main.dart no longer turns real-time updates on, so the shipped '
          'app never opens the socket (docs/realtime-updates.md).',
    );
  });
}
