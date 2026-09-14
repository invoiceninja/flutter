import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/domain/activity/activity_view_events.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/core/detail/activity_reveal_controller.dart';
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
    this.reveal,
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

  /// "Scroll to and flash the newest activity of this type", pushed by the
  /// detail header's `Viewed` status pill (invoiceninja/flutter#154).
  ///
  /// Passed only to the **full** tab, never the `commentsOnly` one. There is no
  /// race between the two even so: a view event is not a comment, so it can
  /// never appear in `vm.comments`.
  final ActivityRevealController? reveal;

  @override
  State<EntityActivityTab> createState() => _EntityActivityTabState();
}

class _EntityActivityTabState extends State<EntityActivityTab> {
  /// The row being flashed — held as the `Activity`, with its index derived at
  /// render time.
  ///
  /// **Not an id**: `Activity.id` is the server `hashed_id` but `ActivityApi.id`
  /// defaults to `''`, so against a server that omits it an id comparison would
  /// match *every* row.
  ///
  /// **And not a stored index**, which is the shape this started as and the
  /// reason it was wrong. `_buildList` re-reads `vm.pendingRows` and
  /// `vm.activities` on every notify, and the flash lasts 1600 ms — so an
  /// outbox drain retiring a pending comment, its follow-up refetch, or the
  /// user typing a new one all shift the rows out from under a frozen index,
  /// moving the highlight (and with it `ActivityRecordRow`'s self-scroll) onto
  /// a neighbour. `indexOf` at render is the same fix
  /// `entity_list_screen_scaffold.dart`'s scroll-to-row already uses, and it
  /// degrades correctly at both ends: freezed value equality returns the FIRST
  /// match, so content-identical rows still light exactly one, and a row that
  /// has dropped out of a refetched window answers `-1`, which no real index
  /// equals.
  Activity? _flashTarget;
  Timer? _flashTimer;

  /// The last [ActivityRevealRequest.seq] acted on, so a repeat tap on the same
  /// status re-flashes while an unrelated rebuild does not.
  int? _handledSeq;

  @override
  void initState() {
    super.initState();
    // Read the standing request as well as listening: on the first tap this
    // tab is built the frame *after* `select()`, so the notification for the
    // request that brought the user here fired before anything was listening.
    widget.reveal?.addListener(_onRevealChanged);
    widget.vm.addListener(_onVmChanged);
    // `notify: false` — `setState` is illegal this early, and the build that
    // is about to run reads `_flashIndex` anyway.
    _tryResolve(notify: false);
  }

  @override
  void didUpdateWidget(EntityActivityTab old) {
    super.didUpdateWidget(old);
    if (old.reveal != widget.reveal) {
      old.reveal?.removeListener(_onRevealChanged);
      widget.reveal?.addListener(_onRevealChanged);
    }
    if (old.vm != widget.vm) {
      old.vm.removeListener(_onVmChanged);
      widget.vm.addListener(_onVmChanged);
    }
  }

  @override
  void dispose() {
    // A bare `Timer` is not drained by `pumpAndSettle`, and one left pending at
    // teardown fails the test outright.
    _flashTimer?.cancel();
    widget.reveal?.removeListener(_onRevealChanged);
    widget.vm.removeListener(_onVmChanged);
    super.dispose();
  }

  void _onRevealChanged() => _tryResolve();

  /// The feed arriving is the other half of the trigger: a tap made before the
  /// debounced fetch lands has nothing to resolve against until it does.
  void _onVmChanged() {
    if (_handledSeq != widget.reveal?.request?.seq) _tryResolve();
  }

  void _tryResolve({bool notify = true}) {
    final request = widget.reveal?.request;
    if (request == null || widget.commentsOnly) return;
    if (_handledSeq == request.seq) return;
    final rows = widget.vm.activities;
    final target = newestActivityOfType(rows, request.activityTypeId);
    if (target == null) {
      // Keep hoping only while the fetch might still bring it. Once it has
      // settled the row genuinely is not in the window — the view event is
      // written once, on first view, so it is the oldest row in a capped feed
      // and the first to age out — and the honest outcome is the tab opening
      // with nothing highlighted. The caption already answered "when".
      if (widget.vm.hasSettled) _handledSeq = request.seq;
      return;
    }
    _handledSeq = request.seq;
    _flashTimer?.cancel();
    // Longer than the 900 ms the manage-cards sheet uses, because the eye has
    // further to travel: there the row appears in a short list already under
    // the cursor, here the whole page changed and the row lands mid-viewport
    // ~280 ms after the tap (200 ms strip reveal, then a 250 ms row scroll
    // overlapping a 250 ms colour ramp). 900 ms would leave well under a
    // second at full strength.
    _flashTimer = Timer(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _flashTarget = null);
    });
    if (!notify) {
      _flashTarget = target;
      return;
    }
    if (mounted) setState(() => _flashTarget = target);
  }

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

    // Resolved here, against the lists this build is actually rendering —
    // never stored. Pending comment rows are prepended, so the offset is
    // however many are in flight *right now*. See [_flashTarget].
    final flashIndex = _flashTarget == null
        ? null
        : pending.length + rows.indexOf(_flashTarget!);

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
          highlighted: i == flashIndex,
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
