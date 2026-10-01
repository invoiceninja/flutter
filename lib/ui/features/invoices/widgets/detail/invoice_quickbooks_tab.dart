import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/domain/quickbooks/quickbooks_invoice.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/app/router.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';

/// The localization key for a QuickBooks status / check outcome.
String _statusKey(String status) => 'qb_status_$status';

const _knownStatuses = {
  'syncable',
  'linkable',
  'synced',
  'data_mismatch',
  'amount_mismatch',
  'not_found',
  'voided',
};

String _actionKey(QuickbooksInvoiceAction a) => switch (a) {
  QuickbooksInvoiceAction.checkRecord => 'qb_check_record',
  QuickbooksInvoiceAction.forceLink => 'qb_force_link',
  QuickbooksInvoiceAction.forcePull => 'qb_force_pull',
  QuickbooksInvoiceAction.forcePush => 'qb_force_push',
};

/// An invoice's QuickBooks sync state, with the actions React offers for it
/// (invoiceninja/ui#3284). Shown only while the company is connected — the
/// detail screen gates the tab.
///
/// After a Check Record only Check Record stays on offer, as in React: the
/// report's own recommendations replace the generic buttons until the user
/// checks again.
class InvoiceQuickbooksTab extends StatefulWidget {
  const InvoiceQuickbooksTab({
    super.key,
    required this.invoice,
    required this.services,
    required this.companyId,
    required this.quickbooks,
  });

  final Invoice invoice;
  final Services services;
  final String companyId;

  /// `company.quickbooks`.
  final Map<String, dynamic>? quickbooks;

  @override
  State<InvoiceQuickbooksTab> createState() => _InvoiceQuickbooksTabState();
}

class _InvoiceQuickbooksTabState extends State<InvoiceQuickbooksTab> {
  QuickbooksInvoiceAction? _running;
  QuickbooksInvoiceCheck? _check;

  @override
  void didUpdateWidget(InvoiceQuickbooksTab old) {
    super.didUpdateWidget(old);
    // A report describes one invoice.
    if (old.invoice.id != widget.invoice.id) {
      _check = null;
      _running = null;
    }
  }

  Future<void> _run(QuickbooksInvoiceAction action) async {
    if (_running != null) return;
    final invoiceId = widget.invoice.id;
    final notify = Notify.capture(context);
    final queued = context.tr('qb_action_queued');
    final failed = context.tr('an_error_occurred');
    setState(() {
      _running = action;
      if (action == QuickbooksInvoiceAction.checkRecord) _check = null;
    });
    try {
      final check = await widget.services.quickbooks.invoiceAction(
        companyId: widget.companyId,
        invoiceId: invoiceId,
        action: action,
      );
      if (!mounted || widget.invoice.id != invoiceId) return;
      setState(() => _check = check);
      if (action != QuickbooksInvoiceAction.checkRecord) {
        notify?.success(queued);
      }
    } catch (e) {
      if (!mounted || widget.invoice.id != invoiceId) return;
      Notify.error(context, failed, error: e);
    } finally {
      if (mounted && widget.invoice.id == invoiceId) {
        setState(() => _running = null);
      }
    }
  }

  void _recommended(String wire) {
    final action = QuickbooksInvoiceAction.fromWire(wire);
    if (action != null) {
      unawaited(_run(action));
      return;
    }
    if (wire == 'change_invoice_number') {
      goEntityEdit(context, '/invoices', widget.invoice.id);
      return;
    }
    Notify.info(context, context.tr('qb_verify_invoice_help'));
  }

  String _recommendedLabel(BuildContext context, String wire) {
    final action = QuickbooksInvoiceAction.fromWire(wire);
    if (action != null) return context.tr(_actionKey(action));
    return switch (wire) {
      'change_invoice_number' => context.tr('qb_change_invoice_number'),
      _ => context.tr('qb_verify_invoice'),
    };
  }

  String _statusLabel(BuildContext context, String status) =>
      _knownStatuses.contains(status)
      ? context.tr(_statusKey(status))
      : (status.isEmpty ? context.tr('unknown') : status);

  ({Color fg, Color bg}) _tone(InTheme t, String status) => switch (status) {
    'synced' || 'syncable' => (fg: t.paid, bg: t.paidSoft),
    'linkable' => (fg: t.sent, bg: t.sentSoft),
    'data_mismatch' || 'amount_mismatch' => (fg: t.warning, bg: t.warningSoft),
    'not_found' || 'voided' => (fg: t.overdue, bg: t.overdueSoft),
    _ => (fg: t.draft, bg: t.draftSoft),
  };

  Widget _pill(BuildContext context, String status) {
    final tone = _tone(context.inTheme, status);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: StatusPill(
        label: _statusLabel(context, status),
        fgColor: tone.fg,
        bgColor: tone.bg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final invoice = widget.invoice;
    final sync = QuickbooksInvoiceSync.fromJson(invoice.sync);
    final check = _check;
    final unsaved = invoice.id.startsWith('tmp_');
    final actions = unsaved
        ? const <QuickbooksInvoiceAction>[]
        : check != null
        ? const [QuickbooksInvoiceAction.checkRecord]
        : quickbooksInvoiceActions(sync, widget.quickbooks);
    final message = sync.message.isNotEmpty
        ? sync.message
        : (sync.status == 'amount_mismatch'
              ? context.tr('qb_amount_mismatch_help')
              : '');
    final gap = SizedBox(height: InSpacing.md(context));

    return ListView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      children: [
        DetailInfoRow(
          label: context.tr('qb_record_id'),
          value: sync.isLinked ? sync.qbId : context.tr('qb_not_linked'),
          copyable: sync.isLinked,
        ),
        _LabelledRow(
          label: context.tr('status'),
          child: _pill(context, sync.status),
        ),
        if (message.isNotEmpty)
          DetailInfoRow(
            label: context.tr('message'),
            value: message,
            copyable: false,
          ),
        gap,
        if (unsaved)
          Text(
            context.tr('qb_save_first'),
            style: TextStyle(color: tokens.ink3),
          )
        else
          Wrap(
            spacing: InSpacing.sm,
            runSpacing: InSpacing.sm,
            children: [
              for (final a in actions)
                OutlinedButton.icon(
                  key: ValueKey('qb_action_${a.wire}'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  onPressed: _running == null ? () => _run(a) : null,
                  icon: _running == a
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          a == QuickbooksInvoiceAction.checkRecord
                              ? Icons.fact_check_outlined
                              : Icons.sync_outlined,
                          size: 18,
                        ),
                  label: Text(context.tr(_actionKey(a))),
                ),
            ],
          ),
        if (check != null) ...[
          gap,
          const Divider(height: 1),
          gap,
          Text(
            context.tr('qb_check_result'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          gap,
          _LabelledRow(
            label: context.tr('status'),
            child: _pill(context, check.outcome),
          ),
          if (check.quickbooksId.isNotEmpty)
            DetailInfoRow(
              label: context.tr('qb_record_id'),
              value: check.quickbooksId,
            ),
          if (check.number case final n?)
            _ComparisonRow(
              label: context.tr('number'),
              comparison: n,
              format: (v) => v,
            ),
          if (check.total case final t?)
            // The client's currency, watched like every other money surface
            // on this screen.
            WatchBuilder<Client?>(
              cacheKey: (widget.companyId, invoice.clientId),
              initialData: widget.services.clients.peek(
                companyId: widget.companyId,
                id: invoice.clientId,
              ),
              create: () => widget.services.clients.watch(
                companyId: widget.companyId,
                id: invoice.clientId,
              ),
              builder: (context, clientSnap) => _ComparisonRow(
                label: context.tr('total'),
                comparison: t,
                format: (v) {
                  final f = widget.services.formatterIfReady(widget.companyId);
                  final d = Decimal.tryParse(v);
                  if (f == null || d == null) return v;
                  return f.money(
                    d,
                    clientCurrencyId: clientSnap.data?.currencyId,
                  );
                },
              ),
            ),
          if (check.message.isNotEmpty)
            DetailInfoRow(
              label: context.tr('message'),
              value: check.message,
              copyable: false,
            ),
          if (check.recommendedActions.isNotEmpty) ...[
            gap,
            Wrap(
              spacing: InSpacing.sm,
              runSpacing: InSpacing.sm,
              children: [
                for (final r in check.recommendedActions)
                  FilledButton.tonal(
                    key: ValueKey('qb_recommended_$r'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: _running == null ? () => _recommended(r) : null,
                    child: Text(_recommendedLabel(context, r)),
                  ),
              ],
            ),
          ],
        ],
      ],
    );
  }
}

/// A [DetailInfoRow]-shaped row whose value is a widget (a pill).
class _LabelledRow extends StatelessWidget {
  const _LabelledRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.label,
    required this.comparison,
    required this.format,
  });

  final String label;
  final QuickbooksComparison comparison;
  final String Function(String) format;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final ours = format(comparison.invoiceNinja);
    final theirs = format(comparison.quickbooks);
    return DetailInfoRow(
      label: label,
      value: comparison.matches ? ours : '$ours ≠ $theirs',
      valueColor: comparison.matches ? null : tokens.warning,
      copyable: false,
      trailing: Text(
        '  ${context.tr(comparison.matches ? 'qb_matches' : 'qb_differs')}',
        style: TextStyle(color: tokens.ink3),
      ),
    );
  }
}
