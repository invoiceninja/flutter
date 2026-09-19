import 'package:flutter/widgets.dart';

import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';

/// The sentence to show for a [TimeLogProblem] — one copy, because there are
/// three kinds and two surfaces that report them.
///
/// It exists because the weekly grid had its own reporting and got both halves
/// wrong: it captured *any* non-null problem and always said `time_log_overlap`,
/// so typing into a cell while a timer ran on another day of the same week
/// (`runningNotLast`, which `weekly_merge.dart` names as the reachable case)
/// announced an overlap that wasn't one — and it looked up that key with no
/// params, so the user read the template, `"Overlapping times: :from – :to"`,
/// placeholders and all. The lint that would normally catch a leaked
/// `:placeholder` cannot see a key reached through a variable, which is exactly
/// how the grid passed it.
///
/// [formatter] only decides 12- vs 24-hour; a null one falls back to 24-hour, as
/// everywhere else that formats a clock without a loaded company.
String timeLogProblemMessage(
  BuildContext context,
  TimeLogProblem problem, {
  Formatter? formatter,
}) {
  final military = formatter?.settings.enableMilitaryTime ?? false;
  String clock(DateTime? t) {
    final local = t?.toLocal();
    return local == null
        ? ''
        : formatTimeOfDay(local.hour, local.minute, military: military);
  }

  return switch (problem.kind) {
    TimeLogProblemKind.inverted => context.tr('time_log_inverted'),
    TimeLogProblemKind.runningNotLast => context.tr(
      'time_log_running_not_last',
    ),
    // The only kind that names a window — [TimeLogProblem.from] / `.to` are null
    // for the other two, which is why they get their own keys rather than a
    // blanked-out version of this one.
    TimeLogProblemKind.overlap => context.tr('time_log_overlap', {
      'from': clock(problem.from),
      'to': clock(problem.to),
    }),
  };
}
