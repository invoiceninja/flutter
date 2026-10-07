import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/dashboard/helpers/needs_attention.dart';
import 'package:admin/ui/features/dashboard/helpers/when_text.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_record_row.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card_skeleton.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_badge.dart';
import 'package:admin/utils/formatting.dart';

/// One thing a band row can do — see [RecordRowCallback].
typedef AttentionAction = RecordRowCallback;

/// What the band's rows may do, decided by the host.
///
/// Each function answers **per row** and returns null when that action is not
/// offered there — the user may lack the permission, or (for an invoice they
/// neither created nor are assigned) the server's own rule says no. The band
/// knows nothing of sessions; it draws the buttons it is handed.
class AttentionActions {
  const AttentionActions({
    required this.remindInvoice,
    required this.enterPayment,
    required this.remindQuote,
    this.callButton,
  });

  /// No actions at all — rows still open their record.
  static AttentionAction? _none(Object _) => null;
  static const AttentionActions none = AttentionActions(
    remindInvoice: _none,
    enterPayment: _none,
    remindQuote: _none,
  );

  final AttentionAction? Function(DashboardInvoiceRow row) remindInvoice;
  final AttentionAction? Function(DashboardInvoiceRow row) enterPayment;
  final AttentionAction? Function(DashboardQuoteRow row) remindQuote;

  /// Builds the call button for a row's client. Null when tap-to-call is off
  /// on this device, in which case no slot is kept for one; otherwise every
  /// row keeps the slot, and a client with no number simply leaves it blank.
  final Widget Function(BuildContext context, String clientId)? callButton;
}

/// Rows the band shows per list. In columns that is up to nine on screen at
/// once (and a single list runs two columns of them), which is why a taller
/// window no longer earns more: five stacked rows a column pushed the figures
/// off the first screen.
const int kAttentionRows = 3;

/// The dashboard's needs-attention band: what is past due, what falls due this
/// week and which quotes are about to lapse — each a tab with its count, the
/// rows behind it, and the actions that deal with them.
///
/// It leads the page on both layouts because it is the one part of the
/// dashboard that asks for something. The figures and the chart describe a
/// period; this describes *now*, and is why it ignores the date range.
///
/// **On a wide screen the lists sit side by side — no tabs.** Each list that
/// has something has its count and its own "View all", all on screen at once,
/// in columns that stay narrow: a list with more rows than fit one column
/// runs them over two or three. As one tabbed list the band was three short
/// rows stretched across 1,160 px, the Remind button 700 px from the name it
/// acts on, under a tab strip holding one chip and over a footer holding one
/// link. Who gets which columns is `attentionSlots`; where they do not fit…
///
/// **…tabs, where columns do not fit** — the phone ([compact]) and a pane too
/// narrow for them. A tab is not a link: tapping "Due Soon" swaps the rows in
/// place, so the invoices due this week can be acted on here rather than
/// after a trip to a filtered list; "View all" leads there for the rest.
///
/// **The band never claims more than it knows.** A count is the server's total
/// for the list, drawn as "50+" when only a full page is known. The past-due
/// sum appears only when every past-due invoice is in hand and they share a
/// currency (`needsAttention`). A bucket whose list has not loaded has no tab.
///
/// Takes plain values and callbacks — no `Services` — so it is pumped directly
/// in tests; the screen supplies the actions.
class NeedsAttentionBand extends StatefulWidget {
  const NeedsAttentionBand({
    super.key,
    required this.attention,
    required this.state,
    required this.formatter,
    required this.today,
    required this.compact,
    required this.actions,
    required this.onInvoiceTap,
    required this.onQuoteTap,
    required this.onViewAll,
    required this.onRetry,
    this.rowLimit = kAttentionRows,
    this.failedSaves = 0,
    this.onReviewFailedSaves,
  });

  final NeedsAttention attention;

  /// Where the past-due list itself stands: it decides between the skeleton,
  /// the retry and the rows when no bucket has anything yet.
  final ListSectionState state;

  final Formatter formatter;

  /// Passed in so "12 days late" and the list it was computed from agree on
  /// what day it is.
  final Date today;

  /// The stacked layout: two lines a row and one visible action. The narrow
  /// dashboard body passes true; it is not measured here, because the body
  /// already knows.
  final bool compact;

  final AttentionActions actions;
  final void Function(DashboardInvoiceRow row) onInvoiceTap;
  final void Function(DashboardQuoteRow row) onQuoteTap;

  /// "View all" for the selected tab — the matching filtered list.
  final void Function(AttentionTab tab) onViewAll;

  /// Retry the past-due fetch.
  final VoidCallback onRetry;

  /// Rows shown per tab.
  final int rowLimit;

  /// Changes that failed to save and are waiting on the user. Zero draws
  /// nothing; anything else is the first line of the band, because unsaved
  /// work outranks an unpaid invoice.
  final int failedSaves;
  final VoidCallback? onReviewFailedSaves;

  @override
  State<NeedsAttentionBand> createState() => _NeedsAttentionBandState();
}

class _NeedsAttentionBandState extends State<NeedsAttentionBand> {
  /// The tab the user picked. Null follows the first tab that has anything.
  AttentionTab? _picked;

  @override
  Widget build(BuildContext context) {
    final a = widget.attention;
    final alert = widget.failedSaves > 0 ? _alertLine(context) : null;

    if (a.isEmpty) {
      return switch (widget.state) {
        ListSectionState.loading => _card(context, [
          ?alert,
          Padding(
            padding: _statePadding(context),
            child: ListCardSkeleton(rowCount: widget.compact ? 1 : 2),
          ),
        ]),
        ListSectionState.failed => _card(context, [
          ?alert,
          _retryLine(context),
        ]),
        // Loaded, and nothing in any bucket.
        ListSectionState.empty ||
        ListSectionState.rows => _quiet(context, alert: alert),
      };
    }

    final tabs = a.tabs;
    if (widget.compact) return _tabbed(context, tabs, alert);
    // Measured here because it is the band's own width that decides — and this
    // is a direct child of the page's list, never inside an `IntrinsicHeight`
    // row, which is what makes a `LayoutBuilder` legal.
    return LayoutBuilder(
      builder: (context, constraints) {
        final slots = attentionSlots(
          width: constraints.maxWidth,
          counts: [for (final tab in tabs) _lengthOf(tab)],
        );
        return slots.isEmpty
            ? _tabbed(context, tabs, alert)
            : _lists(
                context,
                tabs,
                alert,
                slots,
                attentionMaxSlots(constraints.maxWidth),
              );
      },
    );
  }

  /// Rows in hand for [tab] — what can be drawn, not the server's total.
  int _lengthOf(AttentionTab tab) => switch (tab) {
    AttentionTab.pastDue => widget.attention.pastDue.length,
    AttentionTab.dueSoon => widget.attention.dueSoon.length,
    AttentionTab.quotesExpiring => widget.attention.quotesExpiring.length,
  };

  // ---------------------------------------------------------------------------
  // Side by side

  /// The lists in columns: [slots] of the band's [maxSlots] equal columns for
  /// each list in turn (`attentionSlots`).
  Widget _lists(
    BuildContext context,
    List<AttentionTab> tabs,
    Widget? alert,
    List<int> slots,
    int maxSlots,
  ) {
    final used = slots.fold<int>(0, (sum, n) => sum + n);
    return _card(context, [
      ?alert,
      if (widget.state == ListSectionState.failed) _retryLine(context),
      _ColumnsFrame(
        flexes: [...slots, if (used < maxSlots) maxSlots - used],
        columns: [
          for (var i = 0; i < tabs.length; i++)
            _list(context, tabs[i], slots[i]),
          // A column no list can use stays empty: sharing it out would only
          // push each row's amount and buttons away from its name again.
          if (used < maxSlots) const SizedBox.shrink(),
        ],
      ),
    ]);
  }

  /// One list: its header across the columns it was given, and under it its
  /// rows, filled column by column.
  Widget _list(BuildContext context, AttentionTab tab, int columns) {
    final rows = _rows(
      context,
      tab,
      stacked: true,
      limit: columns * widget.rowLimit,
    );
    final flow = attentionFlow(rows.length, columns);
    var at = 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ListHeader(
          label: context.tr(_tabLabelKey(tab)),
          count: widget.attention.countFor(tab),
          danger: tab == AttentionTab.pastDue,
          sum: _provenSum(tab),
          onViewAll: () => widget.onViewAll(tab),
        ),
        _ColumnsFrame(
          // As many columns as the list was given, even when its rows fill
          // fewer — so a column is the same width in every list.
          flexes: List<int>.filled(columns, 1),
          columns: [
            for (var c = 0; c < columns; c++)
              c < flow.length
                  ? DashboardRecordRows(rows: rows.sublist(at, at += flow[c]))
                  : const SizedBox.shrink(),
          ],
        ),
      ],
    );
  }

  /// What is late across the past-due list, formatted — null for the other
  /// lists and whenever the sum is not proven (`NeedsAttention.pastDueSum`).
  String? _provenSum(AttentionTab tab) {
    final a = widget.attention;
    final sum = tab == AttentionTab.pastDue ? a.pastDueSum : null;
    return sum == null ? null : _money(sum, a.pastDueCurrencyId);
  }

  // ---------------------------------------------------------------------------
  // Tabbed

  Widget _tabbed(BuildContext context, List<AttentionTab> tabs, Widget? alert) {
    final a = widget.attention;
    final selected = tabs.contains(_picked) ? _picked! : tabs.first;
    // The tallest tab sets the floor, so switching to a shorter one does not
    // pull the rest of the page up under the pointer.
    final tallest = [
      a.pastDue.length,
      a.dueSoon.length,
      a.quotesExpiring.length,
    ].reduce(math.max);
    final reserved = math.min(widget.rowLimit, tallest);

    return _card(context, [
      ?alert,
      if (widget.state == ListSectionState.failed) _retryLine(context),
      _tabStrip(context, tabs, selected),
      ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              reserved * dashboardRecordRowExtent(compact: widget.compact),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _rows(context, selected, limit: widget.rowLimit),
        ),
      ),
      _footer(context, selected),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Chrome

  Widget _card(BuildContext context, List<Widget> children) =>
      DashboardCardShell(
        title: context.tr('needs_your_attention'),
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  EdgeInsets _statePadding(BuildContext context) => EdgeInsets.symmetric(
    horizontal: InSpacing.lg(context),
    vertical: InSpacing.md(context),
  );

  /// Nothing past due, nothing due soon, no quote expiring. One line, not a
  /// card with an empty state in it: a good day should cost the page almost
  /// nothing, and still say what comes next.
  Widget _quiet(BuildContext context, {Widget? alert}) {
    final tokens = context.inTheme;
    final next = widget.attention.nextDue;
    final nextOn = next == null ? null : nextDueDate(next, widget.today);
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.shadow1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?alert,
            Padding(
              padding: _statePadding(context),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: InSpacing.sm,
                runSpacing: 4,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: tokens.paid,
                  ),
                  Text(
                    context.tr('nothing_past_due'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (next != null && nextOn != null)
                    LinkText(
                      label:
                          '${context.tr('next_due')}: '
                          '${_identity(next.number, next.clientName)} · '
                          '${dueText(context, nextOn, widget.today)}',
                      onTap: () => widget.onInvoiceTap(next),
                      style: TextStyle(fontSize: 13, color: tokens.ink2),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "2 changes could not be saved · Review".
  Widget _alertLine(BuildContext context) {
    final tokens = context.inTheme;
    final count = widget.failedSaves;
    final onTap = widget.onReviewFailedSaves;
    return Material(
      color: tokens.warningSoft,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 40,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: InSpacing.lg(context)),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: tokens.ink),
                const SizedBox(width: InSpacing.sm),
                Expanded(
                  child: Text(
                    context.tr(
                      count == 1
                          ? 'failed_saves_count_singular'
                          : 'failed_saves_count_plural',
                      {'count': '$count'},
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ),
                if (onTap != null) ...[
                  Text(
                    context.tr('review'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: tokens.ink),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _retryLine(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: _statePadding(context),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: tokens.overdue),
          const SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              '${context.tr('could_not_load_label')} · '
              '${context.tr('past_due')}',
              style: TextStyle(fontSize: 13, color: tokens.ink2),
            ),
          ),
          TextButton(
            onPressed: widget.onRetry,
            child: Text(context.tr('retry')),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tabs

  Widget _tabStrip(
    BuildContext context,
    List<AttentionTab> tabs,
    AttentionTab selected,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.md(context),
        InSpacing.sm,
        InSpacing.md(context),
        0,
      ),
      // Wrapped, not scrolled: each tab carries a count, and a tab pushed off
      // the edge hides a number rather than a destination
      // (`docs/dashboard-panels.md` § A strip of counts is payload).
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final tab in tabs)
            _AttentionTabButton(
              key: ValueKey(tab),
              label: context.tr(_tabLabelKey(tab)),
              count: widget.attention.countFor(tab),
              // Red is for what is already late; a deadline still ahead is not
              // an alarm.
              tone: tab == AttentionTab.pastDue
                  ? SidebarBadgeTone.danger
                  : SidebarBadgeTone.neutral,
              active: tab == selected,
              onTap: () => setState(() => _picked = tab),
            ),
        ],
      ),
    );
  }

  static String _tabLabelKey(AttentionTab tab) => switch (tab) {
    // `past_due`, never `overdue`: the French bundle renders that one "unpaid".
    AttentionTab.pastDue => 'past_due',
    AttentionTab.dueSoon => 'attention_due_soon',
    AttentionTab.quotesExpiring => 'attention_quotes_expiring',
  };

  // ---------------------------------------------------------------------------
  // Rows

  /// The first [limit] rows of [tab]. [stacked] is the column form of the
  /// side-by-side band; otherwise the form follows [widget.compact].
  List<Widget> _rows(
    BuildContext context,
    AttentionTab tab, {
    required int limit,
    bool stacked = false,
  }) {
    final a = widget.attention;
    final actions = widget.actions;
    final call = actions.callButton;

    RecordRowAction remind(AttentionAction? run) => RecordRowAction(
      icon: Icons.mail_outline,
      tooltipKey: 'send_reminder_label',
      onRun: run,
    );
    RecordRowAction pay(AttentionAction? run) => RecordRowAction(
      icon: Icons.payments_outlined,
      tooltipKey: 'enter_payment',
      onRun: run,
    );
    DashboardRecordRow row({
      required Key key,
      required String number,
      required String client,
      required String clientId,
      required String lead,
      required bool late,
      required String? fact,
      required String amount,
      required VoidCallback onTap,
      required List<RecordRowAction> buttons,
    }) => DashboardRecordRow(
      key: key,
      number: number,
      client: client,
      lead: lead,
      leadIsLate: late,
      fact: fact,
      amount: amount,
      onTap: onTap,
      compact: widget.compact && !stacked,
      stacked: stacked,
      actions: buttons,
      leading: call?.call(context, clientId),
    );

    final List<Widget> rows;
    switch (tab) {
      case AttentionTab.pastDue:
        final list = a.pastDue.take(limit).toList();
        // A button is drawn on every row of a tab or on none, so a row that
        // may not do what its neighbours can keeps the column aligned.
        final anyRemind = list.any((r) => actions.remindInvoice(r) != null);
        final anyPay = list.any((r) => actions.enterPayment(r) != null);
        rows = [
          for (final r in list)
            row(
              key: ValueKey('invoice:${r.id}'),
              number: r.number,
              client: r.clientName,
              clientId: r.clientId,
              lead: lateText(context, daysLate(r, widget.today)),
              late: true,
              fact: _factText(context, attentionFact(r)),
              amount: _money(lateAmountOfRow(r, widget.today), r.currencyId),
              onTap: () => widget.onInvoiceTap(r),
              buttons: [
                if (anyRemind) remind(actions.remindInvoice(r)),
                if (anyPay) pay(actions.enterPayment(r)),
              ],
            ),
        ];
      case AttentionTab.dueSoon:
        final list = a.dueSoon.take(limit).toList();
        final anyPay = list.any((r) => actions.enterPayment(r) != null);
        rows = [
          for (final r in list)
            row(
              key: ValueKey('invoice:${r.id}'),
              number: r.number,
              client: r.clientName,
              clientId: r.clientId,
              lead: dueText(
                context,
                nextDueDate(r, widget.today)!,
                widget.today,
              ),
              late: false,
              fact: _factText(context, attentionFact(r)),
              amount: _money(_dueSoonAmount(r), r.currencyId),
              onTap: () => widget.onInvoiceTap(r),
              buttons: [if (anyPay) pay(actions.enterPayment(r))],
            ),
        ];
      case AttentionTab.quotesExpiring:
        final list = a.quotesExpiring.take(limit).toList();
        final anyRemind = list.any((q) => actions.remindQuote(q) != null);
        rows = [
          for (final q in list)
            row(
              key: ValueKey('quote:${q.id}'),
              number: q.number,
              client: q.clientName,
              clientId: q.clientId,
              lead: expiresText(context, q.validUntil!, widget.today),
              late: false,
              fact: null,
              amount: _money(q.amount, q.currencyId),
              onTap: () => widget.onQuoteTap(q),
              buttons: [if (anyRemind) remind(actions.remindQuote(q))],
            ),
        ];
    }
    return rows;
  }

  /// What falls due next on [r]: its deposit while that is what is coming up,
  /// otherwise the balance.
  Decimal _dueSoonAmount(DashboardInvoiceRow r) {
    final next = nextDueDate(r, widget.today);
    final partial = r.partial;
    if (partial != null &&
        partial > Decimal.zero &&
        next != null &&
        next == r.partialDueDate) {
      return partial < r.balance ? partial : r.balance;
    }
    return r.balance;
  }

  String _money(Decimal amount, String currencyId) => widget.formatter.money(
    amount,
    clientCurrencyId: currencyId.isEmpty ? null : currencyId,
  );

  static String _identity(String number, String client) {
    final n = number.isEmpty ? '—' : number;
    return client.isEmpty ? n : '$n · $client';
  }

  String? _factText(BuildContext context, AttentionFact? fact) {
    if (fact == null) return null;
    final date = fact.date == null
        ? ''
        : widget.formatter.date(fact.date!.toIso());
    return switch (fact.kind) {
      AttentionFactKind.reminded => context.tr('reminded_on_date', {
        'date': date,
      }),
      AttentionFactKind.viewed => context.tr('viewed_on_date', {'date': date}),
      AttentionFactKind.notOpened => context.tr('not_opened_label'),
    };
  }

  // ---------------------------------------------------------------------------
  // Footer

  Widget _footer(BuildContext context, AttentionTab tab) {
    final tokens = context.inTheme;
    final a = widget.attention;
    final sum = tab == AttentionTab.pastDue ? a.pastDueSum : null;
    final count = a.countFor(tab);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context) - 6,
        vertical: 4,
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          if (sum != null)
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '${context.tr('past_due')}: '),
                    TextSpan(
                      text: _money(sum, a.pastDueCurrencyId),
                      style: moneyTextStyle(
                        fontWeight: FontWeight.w600,
                        color: tokens.ink,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: tokens.ink2),
              ),
            )
          else
            const Spacer(),
          DashboardCardFooterLink(
            label: '${context.tr('view_all')} ($count)',
            onTap: () => widget.onViewAll(tab),
            touchFloor: true,
          ),
        ],
      ),
    );
  }
}

/// A tab of the band: a label, its count, and a fill when selected. The same
/// vocabulary as the Invoices & Quotes panel's wrapped strip, so the two read
/// as one control.
class _AttentionTabButton extends StatelessWidget {
  const _AttentionTabButton({
    super.key,
    required this.label,
    required this.count,
    required this.tone,
    required this.active,
    required this.onTap,
  });

  final String label;
  final AttentionCount count;
  final SidebarBadgeTone tone;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // `MergeSemantics` outside, so the tab role and the `InkWell`'s tap action
    // land on one node — the role asserts the node carrying it can be tapped.
    return MergeSemantics(
      child: Semantics(
        role: SemanticsRole.tab,
        selected: active,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(InRadii.r2),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 0,
            ),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: InSpacing.md(context),
                vertical: InSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: active ? tokens.accentSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(InRadii.r2),
              ),
              child: Align(
                alignment: Alignment.center,
                widthFactor: 1,
                heightFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? tokens.ink : tokens.ink2,
                      ),
                    ),
                    const SizedBox(width: InSpacing.sm),
                    _CountBadge(count: count, tone: tone, active: active),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A list's count, in the badge the sidebar and the status tabs use. Red is
/// for what is already late; a zero or a deadline still ahead is neutral.
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.count,
    required this.tone,
    this.active = false,
  });

  final AttentionCount count;
  final SidebarBadgeTone tone;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final badge = SidebarBadge.colorsFor(tokens, tone, active: active);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: badge.bg,
        borderRadius: BorderRadius.circular(InRadii.r1),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badge.fg,
        ),
      ),
    );
  }
}

/// The head of one list in the side-by-side band: what it is, how many, what
/// is late in all (when that is proven), and the way to the rest.
///
/// It takes the place of three things the tabbed band spends a row each on —
/// the tab, the footer's sum and the footer's "View all".
class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.label,
    required this.count,
    required this.danger,
    required this.sum,
    required this.onViewAll,
  });

  final String label;
  final AttentionCount count;

  /// The past-due list: its badge takes the danger tone.
  final bool danger;

  /// The proven past-due sum, formatted; null on the other lists and whenever
  /// it is not proven.
  final String? sum;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      constraints: BoxConstraints(
        minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 40,
      ),
      padding: EdgeInsetsDirectional.only(
        start: InSpacing.lg(context),
        end: InSpacing.lg(context) - 6,
      ),
      child: Row(
        children: [
          // One node for a screen reader: "Past Due, 4, $1,500.00". It takes
          // every pixel the link leaves — sharing them with a spacer halved
          // its room and cut "Past Due" to "Past D…".
          Expanded(
            child: Semantics(
              header: true,
              label: [label, '$count', ?sum].join(', '),
              excludeSemantics: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible only as a safety valve — a long translation at a
                  // large text size ellipsises rather than overflowing. At the
                  // widths a column has, the name fits whole.
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: InSpacing.sm),
                  _CountBadge(
                    count: count,
                    tone: danger
                        ? SidebarBadgeTone.danger
                        : SidebarBadgeTone.neutral,
                  ),
                  if (sum != null) ...[
                    const SizedBox(width: InSpacing.sm),
                    Flexible(
                      child: Text(
                        sum!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: moneyTextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: tokens.ink2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: InSpacing.sm),
          DashboardCardFooterLink(
            label: context.tr('view_all'),
            onTap: onViewAll,
            touchFloor: true,
          ),
        ],
      ),
    );
  }
}

/// Columns divided by full-height hairlines, each as wide as its flex.
///
/// **The hairlines are an overlay, not `IntrinsicHeight` + `VerticalDivider`.**
/// A divider as tall as the tallest column needs that height before layout,
/// and asking for it means every descendant must answer an intrinsic-size
/// query — which is how the chart's row came to paint nothing
/// (`docs/dashboard-panels.md` § The chart draws the grouping that fits). A
/// `Stack` sizes itself to the columns and the positioned overlay then fills
/// it, so nothing here is ever asked.
class _ColumnsFrame extends StatelessWidget {
  const _ColumnsFrame({required this.columns, required this.flexes})
    : assert(columns.length == flexes.length);

  final List<Widget> columns;
  final List<int> flexes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns.length; i++)
              Expanded(flex: flexes[i], child: columns[i]),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < columns.length; i++)
                  Expanded(
                    flex: flexes[i],
                    child: i == 0
                        ? const SizedBox.shrink()
                        : Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: tokens.border,
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
