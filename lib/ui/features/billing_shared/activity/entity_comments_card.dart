import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_record_row.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/pending_comment_row.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// How many comments the card shows before deferring to the Comments tab.
///
/// **Flat, never branched on width.** A landscape phone is an ~890 px window
/// only 412 px tall, so a `>= Breakpoints.wide` branch would hand the taller
/// card to the shortest viewport there is — the trap CLAUDE.md records under
/// "A landscape phone is not a small desktop". Two rows plus a two-line body
/// clamp is what keeps this an index rather than a second feed.
const int kCommentsCardInlineLimit = 2;

/// The most recent comments on a record, shown high in the detail body.
///
/// This is the answer to invoiceninja/flutter#121: a comment was only ever
/// readable in the Activity tab — 14th of 14 on a client, at the bottom of a
/// page, mixed in with every system row. Measured on a 390×844 phone, a card
/// placed *below* the detail cards grid starts at ~732 px against a ~698 px
/// viewport for a typical client, i.e. just below the fold; above the grid it
/// starts at 232 px on every record.
///
/// **Always mounted, self-hiding, and it owns its own trailing gap.** That is
/// a deliberate departure from CLAUDE.md's "gate the entry, not the widget"
/// rule, for two reasons that only bite together: the visibility test is
/// asynchronous, so it has to live behind a `ListenableBuilder` — and a builder
/// returns one widget, so it cannot spread `...[card, gap]` into the host's
/// `Column`. Staying mounted is also the only way the [AnimatedSize] has a
/// prior size to grow from; one mounted on the flip would simply snap.
class EntityCommentsCard extends StatelessWidget {
  const EntityCommentsCard({
    super.key,
    required this.vm,
    this.formatter,
    this.actions = EntityNoteActions.none,
    this.onViewAll,
    this.hostWireName,
    this.matchFormColumn = false,
  });

  final EntityActivityViewModel vm;
  final Formatter? formatter;

  /// Only `onAddComment` is used. `Log call` keeps the Activity tab, the `⋯`
  /// menu and the post-call prompter — see [ActivityNoteButtons].
  final EntityNoteActions actions;

  /// Selects the Comments tab. Null hides the `View All` link.
  final VoidCallback? onViewAll;

  /// Forwarded to [ActivityRecordRow.hostWireName].
  final String? hostWireName;

  /// Match `ClientDetailCardsGrid`'s stacked branch, which wraps itself in a
  /// [CenteredFormColumn]. Without it this card runs edge-to-edge in the
  /// 820–1000 px band while the cards below it are centred. The billing screens
  /// have no such grid, and Payment already centres its whole body — passing
  /// true there would double-wrap.
  final bool matchFormColumn;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        // Loading and error render nothing on purpose: a spinner would make
        // every detail open jump, and a red panel on a dozen detail screens
        // whenever the network is down is worse than silence. The tab owns the
        // error and its Retry.
        final visible = vm.hasAnyComment;
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: visible
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _card(context),
                    SizedBox(height: InSpacing.lg(context)),
                  ],
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _card(BuildContext context) {
    final card = DashboardCardShell(
      title: context.tr('comments'),
      // A compact link, where two labelled buttons would overflow the header
      // `Row` — and the destination the overflow belongs in. An inline
      // expander would undo the height cap this card is built around, and is
      // one-way besides. Same shape as the dashboard's own Activity card.
      trailing: onViewAll == null
          ? null
          : DashboardCardFooterLink(
              label: context.tr('view_all'),
              onTap: onViewAll,
            ),
      // The rows bring their own inset and a full-bleed bottom border — they
      // are built for `ActivityListCard`, which supplies no padding. Zeroing
      // the body lines those borders up with the header's divider; the header
      // keeps its own inset, so the rows are told to match it.
      padding: EdgeInsets.zero,
      child: _body(context),
    );
    if (!matchFormColumn) return card;
    // Match the grid's branch, don't just cap unconditionally: the cards grids
    // centre themselves at 820 only *below*
    // `Breakpoints.entityFormMultiColumn` and go full-width multi-column above
    // it. Wrapping without the gate inverted the intent — at >=1000 the card
    // was the only inset element on an otherwise full-bleed page.
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= Breakpoints.entityFormMultiColumn
          ? card
          : CenteredFormColumn(child: card),
    );
  }

  Widget _body(BuildContext context) {
    final inset = InSpacing.lg(context);
    final pending = vm.pendingRows;
    final comments = vm.comments;
    final onAddComment = actions.onAddComment;

    final shownPending = pending.take(kCommentsCardInlineLimit).toList();
    final room = kCommentsCardInlineLimit - shownPending.length;
    final shownComments = room > 0
        ? comments.take(room).toList()
        : const <Activity>[];
    final total = shownPending.length + shownComments.length;
    // A row is last only when nothing follows it *inside the card*. The footer
    // usually does — which is what keeps a hovered last row off the shell's
    // rounded bottom corners without a `ClipRRect` — but a read-only host
    // (Project, Task: `EntityNoteActions.none`) has no footer, and there the
    // final row's border would otherwise float above empty card.
    bool isLast(int i) => onAddComment == null && i == total - 1;

    final children = <Widget>[];
    var i = 0;
    for (final row in shownPending) {
      children.add(
        PendingCommentRow(
          row: row,
          horizontalPadding: inset,
          bodyMaxLines: 2,
          isLast: isLast(i),
        ),
      );
      i++;
    }
    for (final activity in shownComments) {
      children.add(
        ActivityRecordRow(
          activity: activity,
          formatter: formatter,
          isLast: isLast(i),
          showIp: false,
          horizontalPadding: inset,
          bodyMaxLines: 2,
          hostWireName: hostWireName,
        ),
      );
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...children,
        if (onAddComment != null)
          Padding(
            padding: EdgeInsets.fromLTRB(
              inset,
              InSpacing.sm,
              inset,
              InSpacing.md(context),
            ),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: onAddComment,
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: Text(context.tr('add_comment')),
              ),
            ),
          )
        else
          SizedBox(height: InSpacing.sm),
      ],
    );
  }
}
