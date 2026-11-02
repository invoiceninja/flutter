/// A request a home-screen widget queues for the app — see
/// `docs/home-screen-widgets.md` § The only write is a queued command.
///
/// Written by the widget's own code (an App Intent in the extension, a
/// non-exported receiver on Android) into storage only the app can reach —
/// never a URL, which any app or web page can fire. The app applies it the
/// next time it runs, through the outbox.
library;

/// The command kinds the app understands.
enum WidgetCommandKind {
  /// Stop a running timer at the time of the tap.
  stop('stop'),

  /// Start a task's timer. Queued by a tap that also opens the app, which
  /// opens the task and starts it there — a start can need a booking question
  /// only the app can ask.
  start('start');

  const WidgetCommandKind(this.wire);
  final String wire;
}

/// Commands older than this are dropped rather than applied: a stop from a
/// month ago would rewrite a month of someone's time log.
const Duration kWidgetCommandMaxAge = Duration(days: 7);

/// A start is applied as the app opens, seconds after the tap. One that waited
/// longer (the app never came up, the user cancelled a company switch) is
/// dropped: starting a timer an hour after the tap would bill an hour nobody
/// worked.
const Duration kWidgetStartMaxAge = Duration(minutes: 10);

class WidgetCommand {
  const WidgetCommand({
    required this.id,
    required this.kind,
    required this.userId,
    required this.companyId,
    required this.taskId,
    this.runningSince,
    required this.at,
  });

  /// Unique per tap; the file is named after it, and the app applies each id
  /// once.
  final String id;
  final WidgetCommandKind kind;
  final String userId;
  final String companyId;
  final String taskId;

  /// The running entry's start as the widget showed it — the stop is dropped
  /// if the task has been stopped or restarted elsewhere since. Always set for
  /// a stop; a start has none.
  final DateTime? runningSince;

  /// When the user tapped — the time a timer stops at.
  final DateTime at;

  /// Parses one queued command, or null for anything it can't trust: a
  /// different schema, an unknown kind, a missing field. Native code writes
  /// these, so nothing here may throw.
  static WidgetCommand? tryParse(Object? raw) {
    if (raw is! Map) return null;
    if (raw['v'] != 1) return null;
    final kind = WidgetCommandKind.values
        .where((k) => k.wire == raw['kind'])
        .firstOrNull;
    String? str(String key) {
      final v = raw[key];
      return v is String && v.isNotEmpty ? v : null;
    }

    DateTime? millis(String key) {
      final v = raw[key];
      return v is num
          ? DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true)
          : null;
    }

    final id = str('id');
    final userId = str('userId');
    final companyId = str('companyId');
    final taskId = str('taskId');
    final runningSince = millis('runningSince');
    final at = millis('at');
    if (kind == null ||
        id == null ||
        userId == null ||
        companyId == null ||
        taskId == null ||
        (kind == WidgetCommandKind.stop && runningSince == null) ||
        at == null) {
      return null;
    }
    return WidgetCommand(
      id: id,
      kind: kind,
      userId: userId,
      companyId: companyId,
      taskId: taskId,
      runningSince: runningSince,
      at: at,
    );
  }

  Map<String, Object?> toJson() => {
    'v': 1,
    'id': id,
    'kind': kind.wire,
    'userId': userId,
    'companyId': companyId,
    'taskId': taskId,
    if (runningSince != null)
      'runningSince': runningSince!.millisecondsSinceEpoch,
    'at': at.millisecondsSinceEpoch,
  };
}
