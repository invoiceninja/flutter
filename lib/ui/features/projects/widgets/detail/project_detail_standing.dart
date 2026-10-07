import 'dart:async';
import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_progress_math.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_rate_context.dart';
import 'package:admin/utils/formatting.dart';

/// Where a project stands: the hours logged against the hours budgeted, and
/// what has been worked and not yet invoiced.
///
/// It replaces the Progress card that used to lead the screen — four KPI
/// cells over a chart. Two of the four (Remaining, Projected) were dashes on
/// any project without a budget *and* a due date, and the chart made the card
/// several times the height of the header it now sits beside. The figures
/// that were worth their cells are here; the chart is one tab away.
///
/// * **Logged** and **Uninvoiced** are the two primary figures and always
///   print — on this card `0 h` and `$0.00` are answers. Two, not three: the
///   primary row is two to a line at this card's width, and a third figure
///   bought a second line that left the card towering over the header beside
///   it.
/// * **Budgeted** and **Projected** are secondary: each is drawn only when
///   there is one — a labelled zero under "Budgeted" reads as "budgeted at
///   nothing", and a projection needs a budget, a due date and a day of
///   history to be derived from. What *remains* of the budget is not a third
///   figure: the bar draws it and the percentage beside it says it, and three
///   secondary figures wrap to a second row on a phone.
/// * The line under the figures is the budget as a bar, with today marked on
///   it, and the one-word verdict the old card kept in its corner.
///
/// Every figure here is added up from the project's tasks, and so only from
/// **all** of them: [tasks] is null for a user who may not view tasks *and*
/// while this device is known to hold only some (`RelatedRowsProof`, which
/// then fetches the rest). Either way the card falls back to the server's
/// own running total (`Project.currentHours`, whole hours) and prints no
/// money figure — a sum of the first fifty tasks is a wrong number, not a
/// small one.
///
/// Amounts are priced with the task-rate cascade (`TaskRateContext`) and
/// formatted in the client's currency (`PartyCurrencyBuilder`), like the
/// invoice the Invoice action builds from the same tasks.
class ProjectDetailStanding extends StatefulWidget {
  const ProjectDetailStanding({
    super.key,
    required this.project,
    required this.tasks,
    required this.companyId,
    required this.formatter,
    required this.tabIds,
    required this.onOpenTab,
    this.showUninvoiced = true,
    this.tasksPending = false,
  });

  final Project project;

  /// The project's active tasks — all of them — or null when they cannot be
  /// added up: this user may not view tasks, or not all of them are here yet.
  final List<Task>? tasks;
  final String companyId;

  /// Null while it loads — the money figure is blank until it arrives.
  final Formatter? formatter;

  /// The related tabs on screen. A figure links to its tab only when that tab
  /// exists — the same set `ProjectDetailTabs` gates its strip on.
  final Set<String> tabIds;
  final ValueChanged<String> onOpenTab;

  /// False when the invoices module is off: there is nothing to invoice the
  /// time *to*, so a figure named for what has not been invoiced is noise.
  final bool showUninvoiced;

  /// True when [tasks] is null only because they are not all here *yet* —
  /// the first local read has not come back, or the missing pages are being
  /// fetched — for a user who may view them.
  ///
  /// The card then keeps the shape it is about to have: Logged from the
  /// server's running total, Uninvoiced as a blank figure, the budget below.
  /// Without this it drew the reduced card a user without `view_task` gets,
  /// and every project opened on one layout and snapped to another a frame
  /// later.
  final bool tasksPending;

  @override
  State<ProjectDetailStanding> createState() => _ProjectDetailStandingState();
}

class _ProjectDetailStandingState extends State<ProjectDetailStanding> {
  // Drift only emits when a row changes, so without a tick the today marker,
  // the days-left count and the projection would freeze on a screen left
  // open — and a running timer's hours would stand still. A minute while a
  // billable timer runs (the figures show a tenth of an hour), half an hour
  // otherwise.
  Timer? _ticker;
  bool _fast = false;
  DateTime _now = DateTime.now();

  bool get _hasRunning =>
      widget.tasks?.any(
        (t) => t.timeLog.any((TimeEntry e) => e.isRunning && e.billable),
      ) ??
      false;

  @override
  void initState() {
    super.initState();
    _arm(fast: _hasRunning);
  }

  @override
  void didUpdateWidget(ProjectDetailStanding oldWidget) {
    super.didUpdateWidget(oldWidget);
    // New rows are new facts about *now* as well.
    _now = DateTime.now();
    final fast = _hasRunning;
    if (fast != _fast) _arm(fast: fast);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _arm({required bool fast}) {
    _fast = fast;
    _ticker?.cancel();
    _ticker = Timer.periodic(
      fast ? const Duration(minutes: 1) : const Duration(minutes: 30),
      (_) {
        if (mounted) setState(() => _now = DateTime.now());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    final tasks = widget.tasks;
    final tasksLinked = widget.tabIds.contains(DetailTabIds.tasks);
    StandingFigure figure(
      String labelKey,
      String value, {
      bool linked = false,
      Color? color,
    }) => StandingFigure(
      label: context.tr(labelKey),
      value: value,
      valueColor: color,
      onTap: linked && tasksLinked
          ? () => widget.onOpenTab(DetailTabIds.tasks)
          : null,
      semanticsHint: linked && tasksLinked ? context.tr('tasks') : null,
    );
    String hours(double h) => '${fmtHours(h)} h';

    final budgeted = p.budgetedHours;
    if (tasks == null && !widget.tasksPending) {
      // What the server itself last totalled, for a user with no tasks to add
      // up. No pace and no money: both are derived from the tasks.
      return StandingCard(
        primary: [
          figure('logged', hours(p.currentHours)),
          // The second primary here, where there is no money figure to be it.
          if (budgeted > 0) figure('budgeted', hours(budgeted)),
        ],
        footnote: budgeted > 0
            ? _BudgetLine(
                logged: p.currentHours,
                budgeted: budgeted,
                elapsed: _elapsedFraction(p, _now),
                dueDate: p.dueDate,
                status: ProgressStatus.unknown,
              )
            : null,
      );
    }

    // Not all here yet ([tasksPending]): the same card, with what can be
    // said honestly — the server's own total for the hours, and no verdict or
    // projection, both of which are worked out from the tasks.
    final createdAt = p.createdAt.toLocal();
    final double logged;
    final double? projected;
    final ProgressStatus status;
    if (tasks == null) {
      logged = p.currentHours;
      projected = null;
      status = ProgressStatus.unknown;
    } else {
      final series = buildCumulativeSeries(tasks, _now);
      logged = series.isEmpty ? 0.0 : series.last.hours;
      projected = computeProjected(logged, createdAt, p.dueDate, _now);
      status = deriveStatus(logged, budgeted, projected, dueDate: p.dueDate);
    }
    final tokens = context.inTheme;
    final hasLine = budgeted > 0 || p.dueDate != null;

    return TaskRateContextBuilder(
      companyId: widget.companyId,
      clientId: p.clientId,
      project: p,
      builder: (context, rates) => PartyCurrencyBuilder(
        clientId: p.clientId,
        builder: (context, currencyId) {
          return StandingCard(
            primary: [
              figure('logged', hours(logged), linked: true),
              if (widget.showUninvoiced)
                figure(
                  'uninvoiced',
                  // Blank — "not known yet" — until every task is here.
                  tasks == null
                      ? ''
                      : widget.formatter?.money(
                              uninvoicedAmount(tasks, rates, _now),
                              clientCurrencyId: currencyId,
                            ) ??
                            '',
                  linked: true,
                )
              else if (budgeted > 0)
                figure('budgeted', hours(budgeted)),
            ],
            secondary: [
              if (budgeted > 0 && widget.showUninvoiced)
                figure('budgeted', hours(budgeted)),
              if (budgeted > 0 && projected != null)
                figure(
                  'projected',
                  hours(projected),
                  // Red carries the overrun. No arrow: in a finance view an
                  // up-arrow reads as good news.
                  color: projected > budgeted ? tokens.overdue : null,
                ),
            ],
            footnote: hasLine
                ? _BudgetLine(
                    logged: logged,
                    budgeted: budgeted,
                    elapsed: _elapsedFraction(p, _now),
                    dueDate: p.dueDate,
                    status: status,
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// What the billable time worked on [tasks] and not yet invoiced comes to, at
/// each task's own resolved rate.
///
/// A running timer counts for what it has run so far. That is deliberately
/// more than the Invoice action would bill this second (it skips a running
/// task): this figure answers "how much unbilled work is on this project",
/// and work in progress is unbilled work.
Decimal uninvoicedAmount(
  List<Task> tasks,
  TaskRateContext rates,
  DateTime now,
) {
  var total = Decimal.zero;
  for (final task in tasks) {
    if (task.isInvoiced || task.isDeleted) continue;
    total += rates.amountFor(task, now);
  }
  return total;
}

/// How far through its own timeline the project is, 0 to 1 — created to the
/// end of its due day. Null without a due date, and when today falls outside
/// that span: a marker pinned to either end of the bar would claim a position
/// it does not have.
double? _elapsedFraction(Project p, DateTime now) {
  final due = p.dueDate;
  if (due == null) return null;
  final createdAt = p.createdAt.toLocal();
  final end = due.toDateTime().add(const Duration(days: 1));
  final span = end.difference(createdAt).inSeconds;
  if (span <= 0) return null;
  final fraction = now.difference(createdAt).inSeconds / span;
  if (fraction.isNaN || fraction < 0 || fraction > 1) return null;
  return fraction;
}

/// The budget as a bar and a line of verdict under the figures. **Owns its
/// leading gap** — see `StandingCard.footnote`.
class _BudgetLine extends StatelessWidget {
  const _BudgetLine({
    required this.logged,
    required this.budgeted,
    required this.elapsed,
    required this.dueDate,
    required this.status,
  });

  final double logged;
  final double budgeted;
  final double? elapsed;
  final Date? dueDate;
  final ProgressStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: tokens.ink2);
    final due = dueDate;
    // Date-space, never wall-clock: a date-only due date against `now` flips
    // "past due" a day late in the afternoon and across a DST change.
    final daysLeft = due?.differenceInDays(Date.today());
    final facts = <Widget>[
      ?_pill(context, tokens),
      if (budgeted > 0)
        Text(
          context.tr('pct_of_budget', {
            'pct': '${(logged / budgeted * 100).round()}',
          }),
          style: muted,
        ),
      if (daysLeft != null)
        daysLeft < 0
            ? Text(
                context.tr('past_due'),
                style: muted?.copyWith(
                  color: tokens.overdue,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Text(
                context.tr('days_remaining', {'count': '$daysLeft'}),
                style: muted,
              ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: kStandingFootnoteGap + InSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (budgeted > 0) ...[
            ProjectBudgetBar(
              logged: logged,
              budgeted: budgeted,
              elapsed: elapsed,
            ),
            const SizedBox(height: InSpacing.sm),
          ],
          Wrap(
            spacing: InSpacing.sm,
            runSpacing: InSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < facts.length; i++) ...[
                // A dot between two facts, not after a pill: the pill's own
                // shape already separates it.
                if (i > 0 && facts[i - 1] is! StatusPill)
                  Text('·', style: muted),
                facts[i],
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// A verdict is a pill; "no verdict" is nothing — the percentage and the
  /// days left beside it are facts and stay plain text.
  Widget? _pill(BuildContext context, InTheme tokens) => switch (status) {
    ProgressStatus.overBudget => StatusPill(
      label: context.tr('over_budget'),
      fgColor: tokens.overdue,
      bgColor: tokens.overdueSoft,
    ),
    ProgressStatus.offPace => StatusPill(
      label: context.tr('trending_over'),
      fgColor: tokens.sent,
      bgColor: tokens.sentSoft,
    ),
    ProgressStatus.onTrack => StatusPill(
      label: context.tr('on_track'),
      fgColor: tokens.paid,
      bgColor: tokens.paidSoft,
    ),
    ProgressStatus.unknown => null,
  };
}

/// Logged hours against the budget: accent up to the budget, the overrun in
/// red, and a tick where today falls between the project's start and its due
/// date — so "half the budget, three quarters of the time" reads at a glance.
///
/// The segments are scaled against `max(budgeted, logged)`, so an overrun
/// still fits the track: the bar then reads "of everything spent, this much
/// was over".
class ProjectBudgetBar extends StatelessWidget {
  const ProjectBudgetBar({
    super.key,
    required this.logged,
    required this.budgeted,
    this.elapsed,
  });

  final double logged;
  final double budgeted;

  /// 0 to 1, or null for no marker.
  final double? elapsed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final total = math.max(budgeted, logged);
    // Flex factors, in thousandths. A sliver of logged time still gets a
    // visible sliver of bar.
    int flex(double part) => total <= 0 || part <= 0
        ? 0
        : math.max(1, (part / total * 1000).round());
    final within = flex(math.min(budgeted, logged));
    final over = flex(math.max(0.0, logged - budgeted));
    final rest = math.max(0, 1000 - within - over);
    final mark = elapsed;
    return Semantics(
      label:
          '${context.tr('logged')} ${fmtHours(logged)} h, '
          '${context.tr('budgeted')} ${fmtHours(budgeted)} h',
      child: SizedBox(
        height: 14,
        child: Stack(
          children: [
            Positioned.fill(
              top: 3,
              bottom: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(InRadii.r1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (within > 0)
                      Expanded(
                        flex: within,
                        child: ColoredBox(color: tokens.accent),
                      ),
                    if (over > 0)
                      Expanded(
                        flex: over,
                        child: ColoredBox(color: tokens.overdue),
                      ),
                    if (rest > 0)
                      Expanded(
                        flex: rest,
                        // `border`, not `surfaceAlt`: on a card the alternate
                        // surface is too close to the card to read as a track.
                        child: ColoredBox(color: tokens.border),
                      ),
                  ],
                ),
              ),
            ),
            // Outside the clip so it stands a little proud of the track.
            if (mark != null)
              Align(
                alignment: Alignment(mark * 2 - 1, 0),
                child: Container(width: 2, color: tokens.ink2),
              ),
          ],
        ),
      ),
    );
  }
}
