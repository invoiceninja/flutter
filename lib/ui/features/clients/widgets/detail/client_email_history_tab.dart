import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/email_history.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/notify_async.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_list_card.dart';
import 'package:admin/ui/features/clients/view_models/client_email_history_view_model.dart';

/// Client Email-History tab — mirrors React's client "Email History" card.
/// Lists every email sent to the client's contacts grouped by send, with
/// per-event delivery status; bounced/spam events expose a Postmark-gated
/// "Reactivate email" action that rides the outbox.
class ClientEmailHistoryTab extends StatefulWidget {
  const ClientEmailHistoryTab({
    required this.client,
    required this.formatter,
    super.key,
  });

  final Client client;

  /// Pre-resolved formatter from the parent screen; null until it lands
  /// (timestamps render raw ISO meanwhile).
  final Formatter? formatter;

  @override
  State<ClientEmailHistoryTab> createState() => _ClientEmailHistoryTabState();
}

class _ClientEmailHistoryTabState extends State<ClientEmailHistoryTab> {
  late final ClientEmailHistoryViewModel _vm;
  late final Services _services;
  late final String _companyId;
  late final bool _isHosted;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    final session = _services.auth.session.value!;
    _companyId = session.currentCompanyId;
    _isHosted = session.isHosted;
    _vm = ClientEmailHistoryViewModel(
      api: _services.emails,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      clientId: widget.client.id,
    );
    unawaited(_vm.ensureLoaded());
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  Future<void> _reactivate(String messageId) async {
    await runQueuedActionWithNotify(
      context,
      services: _services,
      companyId: _companyId,
      enqueue: () => _services.clients.reactivateContactEmail(
        companyId: _companyId,
        clientId: widget.client.id,
        messageId: messageId,
      ),
      successMsg: context.tr('email_reactivated'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
      child: AnimatedBuilder(
        animation: _vm,
        builder: (context, _) => ActivityListCard(child: _buildBody(context)),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_vm.error != null && _vm.records.isEmpty) {
      return ErrorView(
        message: context
            .tr('failed_to_load_with_error')
            .replaceAll(':error', '${_vm.error}'),
        onRetry: _vm.refresh,
      );
    }
    if (_vm.isLoading && _vm.records.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_vm.records.isEmpty) {
      // This feed is the server's `SystemLog` mail log, which only a
      // webhook-capable ESP populates — so an empty result means either "no
      // mail yet" or "this sender reports nothing", and the tab cannot tell
      // which. It therefore states the neutral fact and explains the gate,
      // rather than asserting nothing was sent the way the billing docs'
      // Email History tab can (there the invitations are local truth).
      //
      // NOT branched on `isHosted`: hosted is not always Postmark.
      // `Email::MAIL_DRIVER_MAP` offers gmail / office365 / microsoft and the
      // `client_*` methods, and hosted free/trial routes to Mailgun — so a
      // hosted account sending through Gmail gets no webhook, an always-empty
      // feed, and would have been told its mail was never sent.
      //
      // `no_history` is not an option for the title: `fr.json` carries it as
      // Greek ("Κανένα Ιστορικό") and `zh_CN` falls back to English, and
      // `_app_pending.json` can only add a key, never override a
      // present-but-wrong locale value. `email_history_empty` stays the
      // SUBTITLE — `EmptyStateBody` gives the title no `textAlign`, so a
      // 90-character sentence there wraps ragged-left inside a centred
      // column. Both keys are translated in every bundle.
      return EmptyState(
        icon: Icons.outgoing_mail,
        title: context.tr('no_records_found'),
        subtitle: context.tr('email_history_empty'),
      );
    }
    final children = <Widget>[];
    for (var i = 0; i < _vm.records.length; i++) {
      children.add(
        _RecordBlock(
          record: _vm.records[i],
          formatter: widget.formatter,
          isHosted: _isHosted,
          pendingMessageIds: _vm.pendingMessageIds,
          onReactivate: _reactivate,
          isLast: i == _vm.records.length - 1,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _RecordBlock extends StatelessWidget {
  const _RecordBlock({
    required this.record,
    required this.formatter,
    required this.isHosted,
    required this.pendingMessageIds,
    required this.onReactivate,
    required this.isLast,
  });

  final EmailHistoryRecord record;
  final Formatter? formatter;
  final bool isHosted;
  final Set<String> pendingMessageIds;
  final Future<void> Function(String messageId) onReactivate;
  final bool isLast;

  String _fmt(String iso) {
    if (iso.isEmpty) return '';
    return formatter?.date(iso, showTime: true, showSeconds: false) ?? iso;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kEntityListRowHeight),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast ? BorderSide.none : BorderSide(color: tokens.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.subject.isEmpty ? context.tr('email') : record.subject,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
            if (record.recipients.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '${context.tr('recipients')}: ${record.recipients}',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
              ),
            ],
            for (final event in record.events)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _EventRow(
                  event: event,
                  dateLabel: _fmt(event.date),
                  isHosted: isHosted,
                  isReactivating: pendingMessageIds.contains(event.bounceId),
                  onReactivate: () => onReactivate(event.bounceId),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.dateLabel,
    required this.isHosted,
    required this.isReactivating,
    required this.onReactivate,
  });

  final EmailHistoryEvent event;
  final String dateLabel;
  final bool isHosted;
  final bool isReactivating;
  final VoidCallback onReactivate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final isBounce = event.canReactivate;
    final color = isBounce ? tokens.overdue : tokens.ink3;
    final meta = <String>[
      if (dateLabel.isNotEmpty) dateLabel,
      if (event.status.isNotEmpty) event.status,
      if (event.recipient.isNotEmpty) event.recipient,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isBounce ? Icons.error_outline : Icons.check_circle_outline,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                meta,
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
        if (event.deliveryMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text(
              event.deliveryMessage,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
            ),
          ),
        if (isBounce && isHosted)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: isReactivating ? null : onReactivate,
                icon: isReactivating
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tokens.ink3,
                        ),
                      )
                    : const Icon(Icons.mark_email_read_outlined, size: 18),
                label: Text(
                  context.tr(isReactivating ? 'in_flight' : 'reactivate_email'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
