import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_list_card.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_record_row.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/pending_comment_row.dart';

/// Shared Activity tab body for every detail screen that has one — invoice,
/// quote, credit, purchase order, recurring invoice, payment, expense, vendor,
/// client, project and task. (Named for the billing docs it started on; it has
/// outgrown that.)
///
/// **The ViewModel is injected, not built here.** The detail screen owns it so
/// this tab, the comments-only tab and the Comments card all read one fetch —
/// which also means this widget must never dispose it.
///
/// [commentsOnly] narrows the list to human-written notes. Content only: the
/// rows render identically either way, because `ActivityRecordRow` keys its
/// note rendering on the row, not on the surface.
class EntityActivityTab extends StatefulWidget {
  const EntityActivityTab({
    super.key,
    required this.vm,
    this.formatter,
    this.actions = EntityNoteActions.none,
    this.commentsOnly = false,
    this.hostWireName,
  });

  final EntityActivityViewModel vm;

  /// Pre-resolved formatter from the parent screen. Pass null while the host's
  /// `loadFormatter` is still in flight; timestamps render as raw ISO until it
  /// arrives.
  final Formatter? formatter;

  /// Opens the add-comment prompt / log-a-call form and enqueues the mutation.
  /// `EntityNoteActions.none` hides both buttons — comments still flow through
  /// the entity's `⋯` menu where a repository supports them at all.
  final EntityNoteActions actions;

  /// Show only comments and logged calls.
  final bool commentsOnly;

  /// Forwarded to [ActivityRecordRow.hostWireName] so a note filed against
  /// another record names it.
  final String? hostWireName;

  @override
  State<EntityActivityTab> createState() => _EntityActivityTabState();
}

class _EntityActivityTabState extends State<EntityActivityTab> {
  // Deliberately no `kick()` here. The host always arms the VM from its
  // `bodyBuilder` (pinned by `test/lint/comments_surface_wiring_test.dart`),
  // and this tab is built *after* the Comments card — so a defensive call here
  // would only ever fire on a screen that forgot, at the one moment the card is
  // already listening, turning a lint-caught empty card into a mid-build
  // `setState` crash on a cache hit. See `EntityActivityViewModel.kick`.

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ActivityNoteButtons(actions: widget.actions),
          if (widget.actions.hasAny) SizedBox(height: InSpacing.md(context)),
          AnimatedBuilder(
            animation: widget.vm,
            builder: (context, _) =>
                ActivityListCard(child: _buildList(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final vm = widget.vm;
    final pending = vm.pendingRows;
    final rows = widget.commentsOnly ? vm.comments : vm.activities;

    if (vm.error != null && rows.isEmpty && pending.isEmpty) {
      return ErrorView(
        message: context
            .tr('failed_to_load_with_error')
            .replaceAll(':error', '${vm.error}'),
        onRetry: vm.refresh,
      );
    }
    if (vm.isLoading && rows.isEmpty && pending.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (pending.isEmpty && rows.isEmpty) return _empty(context);

    final total = pending.length + rows.length;
    final children = <Widget>[];
    var i = 0;
    for (final row in pending) {
      children.add(PendingCommentRow(row: row, isLast: i == total - 1));
      i++;
    }
    for (final activity in rows) {
      children.add(
        ActivityRecordRow(
          activity: activity,
          formatter: widget.formatter,
          isLast: i == total - 1,
          hostWireName: widget.hostWireName,
        ),
      );
      i++;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _empty(BuildContext context) {
    if (!widget.commentsOnly) {
      return EmptyState(
        icon: Icons.history_toggle_off_outlined,
        title: context.tr('no_records_found'),
      );
    }
    // This is where someone who has never commented meets the feature — the
    // card above the fold is, by definition, absent here — so it explains
    // rather than reporting "No records found", which is search copy.
    final onAddComment = widget.actions.onAddComment;
    return EmptyState(
      icon: Icons.comment_outlined,
      title: context.tr('no_comments_yet'),
      // No subtitle without an action: on a read-only entity it would tell the
      // user to do something this screen offers no way to do.
      subtitle: onAddComment == null ? null : context.tr('comments_hint'),
      action: onAddComment == null
          ? null
          : FilledButton.icon(
              // Without this the theme's `Size.fromHeight(44)` default —
              // infinite width — renders one edge-to-edge bar.
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: onAddComment,
              icon: const Icon(Icons.add_comment_outlined, size: 16),
              label: Text(context.tr('add_comment')),
            ),
    );
  }
}
