import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';

/// One thing a dashboard row can do. A `Future`, so the button can show that
/// it is working — the actions here fetch the record before they act on it.
typedef RecordRowCallback = Future<void> Function();

/// A button on a [DashboardRecordRow].
class RecordRowAction {
  const RecordRowAction({
    required this.icon,
    required this.tooltipKey,
    required this.onRun,
  });

  final IconData icon;

  /// What the action does, in full ("Send Reminder") — the button's tooltip
  /// and what a screen reader hears. Every action is an icon: a row is rarely
  /// wide enough for labelled buttons *and* the client's name, and where it
  /// was (one list across a whole desktop) the label sat 700 px from the name
  /// it acted on.
  final String tooltipKey;

  /// Null when this row may not do what its neighbours can. The button then
  /// keeps its place, invisible, so the column above and below stays aligned.
  final RecordRowCallback? onRun;
}

/// Vertical padding of a single-line row, top and bottom.
const double _kRowPadding = 6;

/// Row height floor. A floor, never a fixed height: a larger text size must be
/// able to grow the row.
///
/// **It is the action button's box plus the row's padding, exactly** — so a
/// row with a button and a row without are the same height. Two panels sit
/// side by side, one with buttons and one without, and a few pixels'
/// difference per row put their rows visibly out of step by the fifth.
///
/// The [stacked] form adds its first line above the action box; the same sum
/// whether or not a row has actions, so the hairlines of neighbouring columns
/// meet.
double dashboardRecordRowExtent({required bool compact, bool stacked = false}) {
  if (compact) return 60;
  final single = dashboardRowActionExtent() + 2 * _kRowPadding;
  return stacked ? single + _kStackedFirstLine : single;
}

/// Height of a stacked row's first line at the default text size.
const double _kStackedFirstLine = 20;

/// One action button's box: the touch target on touch, a compact 32 otherwise.
double dashboardRowActionExtent() =>
    Env.isTouchPrimary ? InSizes.touchTarget : 32;

/// A record on the dashboard: which one, where it stands, how much, and what
/// can be done about it.
///
/// Every list on the dashboard draws its rows with this — the needs-attention
/// band and each panel, on both layouts — so they share one grammar:
///
/// ```
/// 0042 · Acme Ltd      12 days late · viewed Oct 2      $1,200.00   [Remind]
/// ```
///
/// It replaced six-column tables whose cells were each their own tap target
/// (about thirty tab stops a panel), whose intrinsic-width columns could not
/// shrink into a half-width card, and whose last column was a `⋮` that opened
/// no menu. Here the row is **one** target that opens the record, and anything
/// else a row can do is a button on it.
///
/// [compact] is the phone's form: two lines, the amount at the end, and at
/// most one action. It is passed by the host rather than measured, because
/// these rows sit inside grid rows that are laid out with `IntrinsicHeight`,
/// where a `LayoutBuilder` cannot be used.
///
/// [stacked] is the form for a column of the needs-attention band on a wide
/// screen:
///
/// ```
/// 0042 · Acme Ltd                    $1,200.00
/// 12 days late · viewed Oct 2           ✆ ✉ $
/// ```
///
/// The amount ends the first line and **every** action sits under it as an
/// icon, so nothing a row can do is more than a column's width from the name
/// it acts on — and the form holds from 300 px, so it does not change shape
/// as lists come and go beside it.
class DashboardRecordRow extends StatefulWidget {
  const DashboardRecordRow({
    super.key,
    required this.number,
    required this.client,
    required this.lead,
    required this.amount,
    required this.onTap,
    required this.compact,
    this.stacked = false,
    this.leadIsLate = false,
    this.fact,
    this.actions = const [],
    this.leading,
  }) : assert(!(compact && stacked), 'compact and stacked are two forms');

  /// The record's number; a dash when it has none yet.
  final String number;
  final String client;

  /// Where it stands — "12 days late", "due in 3 days", a date. Empty when the
  /// record has nothing to say here: the slot is unlabelled, so a dash in it
  /// would be a mark with no meaning.
  final String lead;

  /// Draws [lead] in the overdue tone. Red is for what is already late; a
  /// deadline still ahead stays neutral.
  final bool leadIsLate;

  /// A second fact after [lead] — "viewed Oct 2".
  final String? fact;

  /// The formatted amount.
  final String amount;

  /// Opens the record.
  final VoidCallback onTap;

  final bool compact;

  /// Two lines with the amount ending the first and every action, as an icon,
  /// ending the second — see the class comment.
  final bool stacked;
  final List<RecordRowAction> actions;

  /// A widget ahead of the action buttons, in a fixed slot (the call button).
  /// First, so the buttons every row has keep one right edge whether or not
  /// this slot draws anything. Not shown in the [compact] form.
  final Widget? leading;

  @override
  State<DashboardRecordRow> createState() => _DashboardRecordRowState();
}

class _DashboardRecordRowState extends State<DashboardRecordRow> {
  /// Indices of [DashboardRecordRow.actions] currently running.
  final Set<int> _busy = {};

  Future<void> _run(int index, RecordRowCallback action) async {
    if (_busy.contains(index)) return;
    setState(() => _busy.add(index));
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy.remove(index));
    }
  }

  /// The [DashboardRecordRow.stacked] form.
  Widget _stacked(
    Widget identity,
    Widget status,
    Widget money,
    List<Widget> actionWidgets,
  ) {
    final extent = dashboardRowActionExtent();
    // An icon is a glyph centred in a larger box, so the last glyph's edge
    // sits inside the row's. The amount takes the same inset, or the figure
    // and the icons under it end on two different lines.
    final inset = actionWidgets.isEmpty ? 0.0 : (extent - _kActionGlyph) / 2;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: identity),
            const SizedBox(width: InSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: money,
              ),
            ),
            SizedBox(width: inset),
          ],
        ),
        // The second line is the action box's height with or without actions:
        // a list that offers none keeps rows as tall as its neighbour's.
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: extent),
          child: Row(
            children: [
              Expanded(child: status),
              if (actionWidgets.isNotEmpty) const SizedBox(width: InSpacing.sm),
              for (var i = 0; i < actionWidgets.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                actionWidgets[i],
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final w = widget;

    final identity = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: w.number.isEmpty ? '—' : w.number,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (w.client.isNotEmpty) TextSpan(text: ' · ${w.client}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
    );

    final status = Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: w.lead,
            style: TextStyle(
              color: w.leadIsLate ? tokens.overdue : tokens.ink2,
              fontWeight: w.leadIsLate ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          if (w.fact != null)
            TextSpan(text: w.lead.isEmpty ? w.fact : ' · ${w.fact}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: tokens.ink2,
        fontSize: 12.5,
      ),
    );

    final money = Text(
      w.amount,
      maxLines: 1,
      softWrap: false,
      style: moneyTextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: tokens.ink,
      ),
    );

    final shownActions = w.compact ? w.actions.take(1).toList() : w.actions;
    final actionWidgets = <Widget>[
      if (w.leading != null && !w.compact)
        SizedBox(
          width: dashboardRowActionExtent(),
          height: dashboardRowActionExtent(),
          child: Center(child: w.leading),
        ),
      for (var i = 0; i < shownActions.length; i++)
        _RowActionButton(
          action: shownActions[i],
          busy: _busy.contains(i),
          onPressed: shownActions[i].onRun == null
              ? null
              : () => _run(i, shownActions[i].onRun!),
        ),
    ];

    final Widget content = w.stacked
        ? _stacked(identity, status, money, actionWidgets)
        : w.compact
        ? Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 2), status],
                ),
              ),
              const SizedBox(width: InSpacing.sm),
              money,
              if (actionWidgets.isNotEmpty) const SizedBox(width: 4),
              ...actionWidgets,
            ],
          )
        : Row(
            children: [
              // Three parts identity to two parts status. In a half-width
              // card on a 1280 px laptop that leaves the status about 118 px —
              // "Expired 04/Oct/2026" with nothing to spare — and everything
              // else to the client's name, which is what was being cut.
              Expanded(flex: 3, child: identity),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: status),
              const SizedBox(width: 12),
              // A fixed column, right-aligned, so amounts line up down the
              // card; a long one scales down rather than pushing the buttons.
              SizedBox(
                width: 100,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: money,
                ),
              ),
              if (actionWidgets.isNotEmpty) const SizedBox(width: 12),
              for (var i = 0; i < actionWidgets.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                actionWidgets[i],
              ],
            ],
          );

    return InkWell(
      onTap: w.onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: dashboardRecordRowExtent(
            compact: w.compact,
            stacked: w.stacked,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: w.compact ? InSpacing.sm : _kRowPadding,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Size of an action's glyph in its icon-only form.
const double _kActionGlyph = 18;

class _RowActionButton extends StatelessWidget {
  const _RowActionButton({
    required this.action,
    required this.busy,
    required this.onPressed,
  });

  final RecordRowAction action;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final extent = dashboardRowActionExtent();
    final Widget glyph = busy
        ? const SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(action.icon, size: _kActionGlyph);
    // A fixed box, whatever the button's own idea of its size: Material adds
    // to an icon button's footprint by platform density and tap-target
    // padding, and the row's height is promised above.
    final Widget boxed = SizedBox(
      width: extent,
      height: extent,
      child: IconButton(
        tooltip: context.tr(action.tooltipKey),
        onPressed: busy ? null : onPressed,
        icon: glyph,
        constraints: BoxConstraints.tightFor(width: extent, height: extent),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
    if (action.onRun != null) return boxed;
    // Not offered on this row: hold the space, show nothing, take no focus.
    return Visibility(
      visible: false,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: boxed,
    );
  }
}

/// The rows of a dashboard list, separated by hairlines.
class DashboardRecordRows extends StatelessWidget {
  const DashboardRecordRows({super.key, required this.rows});

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, color: tokens.border),
          rows[i],
        ],
      ],
    );
  }
}
