import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/services/activities_api.dart';
import 'package:admin/domain/phone/call_note.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_list_card.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_record_row.dart';
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_view_model.dart';

/// Shared Activity tab body for billing-doc detail screens (invoice,
/// quote, credit, purchase order, recurring invoice). Mirrors the client
/// activity tab — renders pending outbox `addComment` rows above the
/// synced activity stream. `onAddComment` and `onLogCall` are optional; pass
/// null to hide that affordance (both actions are also reachable via the
/// per-entity actions menu). Task and Project mount this tab but must pass
/// null for both: neither repository has an `addComment`, so there is nothing
/// for the buttons to call.
class BillingDocActivityTab extends StatefulWidget {
  const BillingDocActivityTab({
    super.key,
    required this.entityWireName,
    required this.entityId,
    required this.companyId,
    required this.activitiesApi,
    required this.outboxDao,
    this.formatter,
    this.onAddComment,
    this.onLogCall,
  });

  final String entityWireName;
  final String entityId;
  final String companyId;
  final ActivitiesApi activitiesApi;
  final OutboxDao outboxDao;

  /// Pre-resolved formatter from the parent screen. Pass null while the
  /// host's `loadFormatter` is still in flight; timestamps render as raw
  /// ISO until it arrives.
  final Formatter? formatter;

  /// Callback that opens the add-comment prompt + enqueues the mutation.
  /// When null, the add-comment button is hidden — comments still flow
  /// through the entity's actions menu.
  final Future<void> Function()? onAddComment;

  /// Callback that opens the log-a-call form + enqueues the mutation
  /// (invoiceninja/flutter#120). Same contract as [onAddComment]; a logged
  /// call is an ordinary comment carrying a marker, so it rides the identical
  /// outbox kind and shows the same optimistic pending row.
  final Future<void> Function()? onLogCall;

  @override
  State<BillingDocActivityTab> createState() => _BillingDocActivityTabState();
}

class _BillingDocActivityTabState extends State<BillingDocActivityTab> {
  late final BillingDocActivityViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = BillingDocActivityViewModel(
      api: widget.activitiesApi,
      outbox: widget.outboxDao,
      companyId: widget.companyId,
      entityWireName: widget.entityWireName,
      entityId: widget.entityId,
    );
    unawaited(_vm.ensureLoaded());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ActivityNoteButtons(
            onLogCall: widget.onLogCall,
            onAddComment: widget.onAddComment,
          ),
          if (widget.onLogCall != null || widget.onAddComment != null)
            SizedBox(height: InSpacing.md(context)),
          AnimatedBuilder(
            animation: _vm,
            builder: (context, _) => StreamBuilder<List<OutboxRow>>(
              stream: _vm.pending,
              builder: (context, snapshot) {
                final pending = snapshot.data ?? const <OutboxRow>[];
                return ActivityListCard(child: _buildList(context, pending));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<OutboxRow> pending) {
    if (_vm.error != null && _vm.activities.isEmpty && pending.isEmpty) {
      return ErrorView(
        message: context
            .tr('failed_to_load_with_error')
            .replaceAll(':error', '${_vm.error}'),
        onRetry: _vm.refresh,
      );
    }
    if (_vm.isLoading && _vm.activities.isEmpty && pending.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (pending.isEmpty && _vm.activities.isEmpty) {
      return EmptyState(
        icon: Icons.history_toggle_off_outlined,
        title: context.tr('no_records_found'),
      );
    }
    final total = pending.length + _vm.activities.length;
    final children = <Widget>[];
    var i = 0;
    for (final row in pending) {
      children.add(_PendingCommentRow(row: row, isLast: i == total - 1));
      i++;
    }
    for (final activity in _vm.activities) {
      children.add(
        ActivityRecordRow(
          activity: activity,
          formatter: widget.formatter,
          isLast: i == total - 1,
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
}

class _PendingCommentRow extends StatelessWidget {
  const _PendingCommentRow({required this.row, this.isLast = false});

  final OutboxRow row;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final notes = _extractNotes(row.payload);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kEntityListRowHeight),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast ? BorderSide.none : BorderSide(color: tokens.border),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: tokens.ink3,
                ),
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The same two-tier body the synced row will use — the
                  // outbox payload is the raw composed note, so printing it
                  // flat made a logged call change shape as it landed.
                  if (notes.isNotEmpty)
                    if (isCallNoteText(notes))
                      ...callNoteBody(context, notes)
                    else
                      Text(notes, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('in_flight'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.ink3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _extractNotes(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['notes'] is String) {
        return decoded['notes'] as String;
      }
    } catch (_) {}
    return '';
  }
}
