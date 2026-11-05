import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/home_widgets/home_widget_commands.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/task_repository.dart'
    show TimerStopResult;
import 'package:admin/data/services/home_widget_bridge.dart';
import 'package:admin/domain/home_widgets/widget_command.dart';

/// The queued-command consumer: a widget's Stop is applied once, at the time
/// of the tap, only for the user and company it was made in, and its file is
/// deleted only once it has been handled.

class _FakeBridge extends HomeWidgetBridge {
  _FakeBridge() : super(supported: true);

  final Map<String, Object?> files = {};
  final List<String> deleted = [];

  @override
  Future<List<({String fileId, WidgetCommand? command})>>
  takeCommands() async => [
    for (final e in files.entries)
      (fileId: e.key, command: WidgetCommand.tryParse(e.value)),
  ];

  @override
  Future<void> deleteCommand(String fileId) async {
    deleted.add(fileId);
    files.remove(fileId);
  }
}

class _Stop {
  _Stop(this.companyId, this.taskId, this.stopAt, this.runningSince);
  final String companyId;
  final String taskId;
  final DateTime stopAt;
  final DateTime runningSince;
}

AuthSession _session({String company = 'co1', String user = 'u1'}) =>
    AuthSession(
      baseUrl: '',
      isHosted: false,
      accountId: '',
      userId: user,
      currentCompanyId: company,
      companies: const [
        AuthCompany(
          id: 'co1',
          name: 'One',
          displayName: 'One',
          permissions: '',
          isAdmin: true,
          isOwner: false,
        ),
        AuthCompany(
          id: 'co2',
          name: 'Two',
          displayName: 'Two',
          permissions: '',
          isAdmin: true,
          isOwner: false,
        ),
      ],
    );

final _now = DateTime.utc(2026, 10, 14, 12);
final _start = DateTime.utc(2026, 10, 14, 9);
final _tap = DateTime.utc(2026, 10, 14, 11, 15);

Map<String, Object?> _cmd({
  String id = 'c1',
  String user = 'u1',
  String company = 'co1',
  DateTime? at,
}) => WidgetCommand(
  id: id,
  kind: WidgetCommandKind.stop,
  userId: user,
  companyId: company,
  taskId: 't1',
  runningSince: _start,
  at: at ?? _tap,
).toJson();

class _Rig {
  _Rig({AuthSession? session}) : session = ValueNotifier(session ?? _session());

  final bridge = _FakeBridge();
  final ValueNotifier<AuthSession?> session;
  final List<_Stop> stops = [];
  final List<WidgetCommandOutcome> outcomes = [];
  TimerStopResult stopResult = TimerStopResult.stopped;

  /// Runs inside the stop — lets a test sign out mid-pass.
  void Function()? onStop;
  Object? stopThrows;

  /// What the stop's `stillCurrent` answered after [onStop] ran.
  final List<bool> stillCurrentAfterStop = [];

  late final commands = HomeWidgetCommands(
    bridge: bridge,
    session: session,
    now: () => _now,
    stopTimer:
        ({
          required String companyId,
          required String taskId,
          required DateTime stopAt,
          required DateTime runningSince,
          required bool Function(Task task) only,
          required bool Function() stillCurrent,
        }) async {
          stops.add(_Stop(companyId, taskId, stopAt, runningSince));
          onStop?.call();
          stillCurrentAfterStop.add(stillCurrent());
          final thrown = stopThrows;
          if (thrown != null) throw thrown;
          return stopResult;
        },
    onOutcome: (_, outcome) => outcomes.add(outcome),
  );
}

void main() {
  _startTests();

  // The app's stop awaits a refresh of the task before saving it; a sign-out
  // landing in that wait wiped the database, the refresh then wrote the task
  // back, and the save queued an outbox row for the outgoing user into the
  // database the next user signs into. `stillCurrent` is what the stop checks
  // just before saving (`Services.build`).
  group('stillCurrent', () {
    test('true while the same user and company are active', () async {
      final rig = _Rig();
      rig.bridge.files['f1'] = _cmd();
      await rig.commands.run();
      expect(rig.stillCurrentAfterStop, [true]);
    });

    test('false once the user signs out during the stop', () async {
      final rig = _Rig()..onStop = () {};
      rig.onStop = () => rig.session.value = null;
      rig.bridge.files['f1'] = _cmd();
      await rig.commands.run();
      expect(rig.stillCurrentAfterStop, [false]);
    });

    test('false once the company switches during the stop', () async {
      final rig = _Rig();
      rig.onStop = () => rig.session.value = _session(company: 'co2');
      rig.bridge.files['f1'] = _cmd();
      await rig.commands.run();
      expect(rig.stillCurrentAfterStop, [false]);
    });

    test(
      'a stop abandoned for it keeps its file for the next session',
      () async {
        final rig = _Rig()..stopThrows = const WidgetSessionEndedException();
        rig.bridge.files['f1'] = _cmd();
        await rig.commands.run();
        expect(rig.bridge.deleted, isEmpty);
        expect(rig.outcomes, [WidgetCommandOutcome.failed]);
      },
    );
  });

  test(
    'stops the timer at the time of the tap, then deletes the file',
    () async {
      final rig = _Rig();
      rig.bridge.files['f1'] = _cmd();
      await rig.commands.run();
      expect(rig.stops.single.stopAt, _tap);
      expect(rig.stops.single.runningSince, _start);
      expect(rig.bridge.deleted, ['f1']);
      expect(rig.outcomes, [WidgetCommandOutcome.applied]);
    },
  );

  test("another user's command is discarded unapplied", () async {
    final rig = _Rig();
    rig.bridge.files['f1'] = _cmd(user: 'someone-else');
    await rig.commands.run();
    expect(rig.stops, isEmpty);
    expect(rig.bridge.deleted, ['f1']);
    expect(rig.outcomes, [WidgetCommandOutcome.discarded]);
  });

  test('a command for another company waits until it is active', () async {
    final rig = _Rig();
    rig.bridge.files['f1'] = _cmd(company: 'co2');
    await rig.commands.run();
    expect(rig.stops, isEmpty);
    expect(rig.bridge.deleted, isEmpty);
    expect(rig.outcomes, [WidgetCommandOutcome.deferred]);

    rig.session.value = _session(company: 'co2');
    await rig.commands.run();
    expect(rig.stops.single.companyId, 'co2');
    expect(rig.bridge.deleted, ['f1']);
  });

  test('a timer changed elsewhere since the tap is reported', () async {
    final rig = _Rig()..stopResult = TimerStopResult.changedElsewhere;
    rig.bridge.files['f1'] = _cmd();
    await rig.commands.run();
    expect(rig.bridge.deleted, ['f1']);
    expect(rig.outcomes, [WidgetCommandOutcome.changedElsewhere]);
  });

  test('a second tap on Stop (already stopped) is skipped quietly', () async {
    final rig = _Rig()..stopResult = TimerStopResult.notRunning;
    rig.bridge.files['f1'] = _cmd();
    await rig.commands.run();
    expect(rig.bridge.deleted, ['f1']);
    expect(rig.outcomes, [WidgetCommandOutcome.skipped]);
  });

  test(
    'a stop that throws is kept for the next pass, and the pass goes on',
    () async {
      final rig = _Rig()..stopThrows = StateError('drift');
      rig.bridge.files['f1'] = _cmd();
      rig.bridge.files['f2'] = _cmd(id: 'c2');
      await rig.commands.run();
      expect(
        rig.stops,
        hasLength(2),
        reason: 'one failure does not stop the pass',
      );
      expect(
        rig.bridge.deleted,
        isEmpty,
        reason: 'kept: the widget said it would sync',
      );
      expect(rig.outcomes, everyElement(WidgetCommandOutcome.failed));
      // The next pass, with the database back, applies them.
      rig.stopThrows = null;
      await rig.commands.run();
      expect(rig.bridge.deleted, containsAll(['f1', 'f2']));
    },
  );

  test('a sign-out during a pass stops it before the next command', () async {
    final rig = _Rig();
    rig.onStop = () => rig.session.value = null;
    rig.bridge.files['f1'] = _cmd();
    rig.bridge.files['f2'] = _cmd(id: 'c2');
    await rig.commands.run();
    expect(rig.stops, hasLength(1));
    expect(
      rig.bridge.files,
      contains('f2'),
      reason: 'left for the next user check',
    );
  });

  test('a command older than a week expires, unapplied and reported', () async {
    final rig = _Rig();
    rig.bridge.files['f1'] = _cmd(at: _now.subtract(const Duration(days: 8)));
    await rig.commands.run();
    expect(rig.stops, isEmpty);
    expect(rig.bridge.deleted, ['f1']);
    expect(rig.outcomes, [WidgetCommandOutcome.expired]);
  });

  test('an unreadable file is deleted', () async {
    final rig = _Rig();
    rig.bridge.files['f1'] = {'v': 1, 'kind': 'explode'};
    await rig.commands.run();
    expect(rig.stops, isEmpty);
    expect(rig.bridge.deleted, ['f1']);
  });

  test('the same id is applied once even if its delete failed', () async {
    final rig = _Rig();
    rig.bridge.files['f1'] = _cmd();
    await rig.commands.run();
    // The file came back (a delete that failed natively).
    rig.bridge.files['f1'] = _cmd();
    await rig.commands.run();
    expect(rig.stops, hasLength(1));
  });

  test('signed out, nothing is touched', () async {
    final rig = _Rig()..session.value = null;
    rig.bridge.files['f1'] = _cmd();
    await rig.commands.run();
    expect(rig.stops, isEmpty);
    expect(rig.bridge.deleted, isEmpty);
  });

  test('a run during a run is folded into one more pass', () async {
    final rig = _Rig();
    rig.bridge.files['f1'] = _cmd();
    final first = rig.commands.run();
    rig.bridge.files['f2'] = _cmd(id: 'c2');
    unawaited(rig.commands.run());
    await first;
    await Future<void>.delayed(Duration.zero);
    await rig.commands.run();
    expect(rig.bridge.deleted, containsAll(['f1', 'f2']));
  });
}

Map<String, Object?> _startCmd({
  String id = 's1',
  String company = 'co1',
  DateTime? at,
}) => WidgetCommand(
  id: id,
  kind: WidgetCommandKind.start,
  userId: 'u1',
  companyId: company,
  taskId: 't9',
  at: at ?? _now.subtract(const Duration(seconds: 5)),
).toJson();

void _startTests() {
  group('start', () {
    test(
      'a start without runningSince parses; a stop without one does not',
      () {
        expect(
          WidgetCommand.tryParse(_startCmd())?.kind,
          WidgetCommandKind.start,
        );
        expect(WidgetCommand.tryParse(_startCmd())?.runningSince, isNull);
        final stop = _cmd()..remove('runningSince');
        expect(WidgetCommand.tryParse(stop), isNull);
      },
    );

    test('is handed to the app once, and its file deleted', () async {
      final rig = _Rig();
      final started = <String>[];
      rig.commands.startTask = (c) async => started.add(c.taskId);
      rig.bridge.files['f1'] = _startCmd();
      await rig.commands.run();
      // A second pass over a file that failed to delete applies nothing.
      rig.bridge.files['f1'] = _startCmd();
      await rig.commands.run();
      expect(started, ['t9']);
      expect(rig.bridge.deleted, ['f1', 'f1']);
      expect(rig.outcomes, [
        WidgetCommandOutcome.applied,
        WidgetCommandOutcome.skipped,
      ]);
    });

    test('for another company is handed over, not deferred — its link '
        'switches company', () async {
      final rig = _Rig();
      final started = <String>[];
      rig.commands.startTask = (c) async => started.add(c.companyId);
      rig.bridge.files['f1'] = _startCmd(company: 'co2');
      await rig.commands.run();
      expect(started, ['co2']);
      expect(rig.outcomes, [WidgetCommandOutcome.applied]);
    });

    test('waits in its file until the app can start a task', () async {
      final rig = _Rig();
      rig.bridge.files['f1'] = _startCmd();
      await rig.commands.run();
      expect(rig.bridge.deleted, isEmpty);
      expect(rig.outcomes, [WidgetCommandOutcome.deferred]);
    });

    test(
      'older than ten minutes is dropped, not started an hour late',
      () async {
        final rig = _Rig();
        final started = <String>[];
        rig.commands.startTask = (c) async => started.add(c.taskId);
        rig.bridge.files['f1'] = _startCmd(
          at: _now.subtract(const Duration(minutes: 11)),
        );
        await rig.commands.run();
        expect(started, isEmpty);
        expect(rig.bridge.deleted, ['f1']);
        expect(rig.outcomes, [WidgetCommandOutcome.expired]);
      },
    );

    test('a start that throws never breaks the pass', () async {
      final rig = _Rig();
      rig.commands.startTask = (c) async => throw StateError('boom');
      rig.bridge.files['f1'] = _startCmd();
      rig.bridge.files['f2'] = _cmd();
      await rig.commands.run();
      expect(rig.stops, hasLength(1));
    });
  });
}
