import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/resync_controller.dart';

/// Unit coverage for the app-wide single-flight + progress state behind the
/// sidebar Sync button and both Settings entry points (issue #14).
///
/// The runner is faked and gated on a [Completer] so each test controls exactly
/// when the pass finishes, and captures the `onProgress` / `isCancelled`
/// callbacks the controller hands it so they can be driven directly.

class _FakeRunner {
  final Completer<List<String>> completer = Completer<List<String>>();
  int calls = 0;
  String? lastCompanyId;
  void Function(int, int)? onProgress;
  bool Function()? isCancelled;

  /// Set to have the runner throw instead of completing via [completer].
  Object? throwSync;

  Future<List<String>> call({
    required String companyId,
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) {
    calls++;
    lastCompanyId = companyId;
    this.onProgress = onProgress;
    this.isCancelled = isCancelled;
    final err = throwSync;
    if (err != null) throw err;
    return completer.future;
  }
}

void main() {
  late _FakeRunner runner;
  late ResyncController controller;
  late int notifications;

  setUp(() {
    runner = _FakeRunner();
    controller = ResyncController(runner: runner.call);
    notifications = 0;
    controller.addListener(() => notifications++);
  });

  tearDown(() => controller.dispose());

  test('starts idle', () {
    expect(controller.isRunning, isFalse);
    expect(controller.value.phase, ResyncPhase.idle);
    expect(controller.value.companyId, isNull);
    expect(controller.value.fraction, isNull);
  });

  test('run() enters preparing synchronously, then idles when done', () async {
    final future = controller.run('c1');
    expect(controller.value.phase, ResyncPhase.preparing);
    expect(controller.value.companyId, 'c1');
    expect(controller.value.total, 0);
    expect(controller.value.fraction, isNull, reason: 'total unknown yet');
    expect(controller.value.isRunningFor('c1'), isTrue);
    expect(controller.value.isRunningFor('c2'), isFalse);

    runner.completer.complete(const <String>[]);
    final result = await future;

    expect(result.disposition, ResyncDisposition.completed);
    expect(result.isClean, isTrue);
    expect(controller.isRunning, isFalse);
    expect(controller.value, const ResyncProgress.idle());
  });

  test('progress callback publishes exact counts', () async {
    final future = controller.run('c1');
    runner.onProgress!(0, 3);
    expect(controller.value.phase, ResyncPhase.downloading);
    expect(controller.value.total, 3);
    expect(controller.value.completed, 0);
    expect(controller.value.fraction, 0.0);

    runner.onProgress!(1, 3);
    expect(controller.value.completed, 1);
    runner.onProgress!(3, 3);
    expect(controller.value.fraction, 1.0);

    runner.completer.complete(const <String>[]);
    await future;
  });

  test(
    'a second run for the same company joins instead of restarting',
    () async {
      final first = controller.run('c1');
      final second = controller.run('c1');
      expect(runner.calls, 1, reason: 'the runner must not be invoked twice');

      runner.completer.complete(const ['invoice']);
      final results = await Future.wait([first, second]);

      expect(results[0].disposition, ResyncDisposition.completed);
      expect(results[1].disposition, ResyncDisposition.joined);
      expect(results[0].failedEntities, ['invoice']);
      expect(
        results[1].failedEntities,
        ['invoice'],
        reason: 'the joiner settles with the same outcome',
      );
    },
  );

  test('a run for a different company is declined as busy', () async {
    final first = controller.run('c1');
    final second = await controller.run('c2');

    expect(second.disposition, ResyncDisposition.busy);
    expect(runner.calls, 1);
    expect(controller.value.companyId, 'c1', reason: 'state untouched');

    runner.completer.complete(const <String>[]);
    await first;
  });

  test('failed entities come back on the result', () async {
    final future = controller.run('c1');
    runner.completer.complete(const ['quote', 'task']);
    final result = await future;

    expect(result.disposition, ResyncDisposition.completed);
    expect(result.isClean, isFalse);
    expect(result.failedEntities, ['quote', 'task']);
    expect(result.error, isNull);
  });

  test('a throwing runner resolves as an error, never a rejection', () async {
    final future = controller.run('c1');
    runner.completer.completeError(StateError('boom'));
    final result = await future;

    expect(result.disposition, ResyncDisposition.completed);
    expect(result.error, isA<StateError>());
    expect(result.isClean, isFalse);
    expect(controller.isRunning, isFalse);
  });

  test(
    'a synchronously-throwing runner still releases the controller',
    () async {
      runner.throwSync = StateError('sync boom');
      final result = await controller.run('c1');
      expect(result.error, isA<StateError>());
      expect(controller.isRunning, isFalse);

      // The regression this guards: an in-flight slot cleared before it was
      // claimed would wedge the controller as permanently busy.
      runner.throwSync = null;
      final second = controller.run('c1');
      expect(runner.calls, 2, reason: 'a fresh pass must be startable');
      runner.completer.complete(const <String>[]);
      expect((await second).disposition, ResyncDisposition.completed);
    },
  );

  test('cancel() stops the pass at the next entity boundary', () async {
    final future = controller.run('c1');
    expect(runner.isCancelled!(), isFalse);

    controller.cancel();
    expect(runner.isCancelled!(), isTrue);

    // Progress emitted after cancellation must not resurrect the spinner.
    runner.onProgress!(2, 5);
    expect(controller.value.phase, ResyncPhase.preparing);

    runner.completer.complete(const <String>[]);
    final result = await future;
    expect(result.disposition, ResyncDisposition.cancelled);
    expect(controller.isRunning, isFalse);
  });

  test('cancel() while idle is a no-op', () async {
    controller.cancel();
    expect(controller.isRunning, isFalse);

    final future = controller.run('c1');
    expect(
      runner.isCancelled!(),
      isFalse,
      reason: 'an idle cancel must not leak into the next pass',
    );
    runner.completer.complete(const <String>[]);
    expect((await future).disposition, ResyncDisposition.completed);
  });

  test('equal progress values do not re-notify', () async {
    final future = controller.run('c1');
    final afterStart = notifications;

    runner.onProgress!(1, 4);
    final afterFirst = notifications;
    expect(afterFirst, greaterThan(afterStart));

    runner.onProgress!(1, 4);
    expect(
      notifications,
      afterFirst,
      reason: 'a repeated identical emission should not repaint the sidebar',
    );

    runner.onProgress!(2, 4);
    expect(notifications, greaterThan(afterFirst));

    runner.completer.complete(const <String>[]);
    await future;
  });

  test('isRunningFor is false for every company once idle', () async {
    final future = controller.run('c1');
    runner.completer.complete(const <String>[]);
    await future;

    expect(controller.value.isRunningFor('c1'), isFalse);
    expect(controller.value.isRunningFor(''), isFalse);
  });
}
