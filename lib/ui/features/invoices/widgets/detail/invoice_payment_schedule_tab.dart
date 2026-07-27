import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/notify_async.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/utils/formatting.dart';

/// Invoice detail → Payment Schedule tab. Mirrors React: the schedule is a
/// read-only projection embedded on the invoice (`invoice.schedule[]`,
/// populated only by a `?show_schedule=true` fetch — handled by
/// `InvoiceRepository.ensureLoaded`). Create/remove go through the outbox
/// to React's bespoke `/invoices/:id/payment_schedule` endpoints; the
/// dispatcher re-fetches the invoice so this list refreshes.

/// React `useTabs.tsx`: tab available on Draft / Sent, or Partial when the
/// user can view/edit the invoice. (`canViewOrEdit` resolved at the call
/// site from company permissions.)
bool invoiceSupportsPaymentSchedule(Invoice i, {required bool canViewOrEdit}) {
  if (i.isDeleted) return false;
  return i.statusId == InvoiceStatus.draft ||
      i.statusId == InvoiceStatus.sent ||
      (i.statusId == InvoiceStatus.partial && canViewOrEdit);
}

class InvoicePaymentScheduleTab extends StatelessWidget {
  const InvoicePaymentScheduleTab({required this.invoice, super.key});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final isTmp = invoice.id.startsWith('tmp_');
    final rows = invoice.schedule;

    if (rows.isEmpty) {
      return EmptyState(
        icon: Icons.event_repeat_outlined,
        title: context.tr('no_payment_schedule'),
        subtitle: isTmp ? context.tr('sync_first_generic') : null,
        action: isTmp
            ? null
            : FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                icon: const Icon(Icons.add),
                label: Text(context.tr('create_payment_schedule')),
                onPressed: () => _showCreateDialog(context, invoice),
              ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('payment_schedule'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                icon: Icon(Icons.delete_outline, color: tokens.overdue),
                label: Text(
                  context.tr('remove'),
                  style: TextStyle(color: tokens.overdue),
                ),
                onPressed: () => _remove(context, invoice),
              ),
            ],
          ),
          SizedBox(height: InSpacing.md(context)),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(r.date)),
                  Text(r.amount, style: moneyTextStyle()),
                  SizedBox(width: InSpacing.md(context)),
                  Icon(
                    r.autoBill ? Icons.bolt : Icons.bolt_outlined,
                    size: 16,
                    color: r.autoBill ? tokens.accent : tokens.ink3,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, Invoice invoice) async {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('remove')),
        content: Text(ctx.tr('are_you_sure')),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.tr('cancel')),
              ),
              const SizedBox(width: 8),
              PrimaryDialogAction(
                label: ctx.tr('remove'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await runMutationWithNotify(
      context,
      () => services.invoices.deletePaymentSchedule(
        companyId: companyId,
        id: invoice.id,
      ),
      successMsg: context.tr('deleted_schedule'),
    );
  }
}

Future<void> _showCreateDialog(BuildContext context, Invoice invoice) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CreatePaymentScheduleDialog(invoice: invoice),
  );
}

/// Number-of-payments flow (React's primary path): count + frequency +
/// first-payment date + auto-bill → `POST /invoices/:id/payment_schedule`.
class _CreatePaymentScheduleDialog extends StatefulWidget {
  const _CreatePaymentScheduleDialog({required this.invoice});

  final Invoice invoice;

  @override
  State<_CreatePaymentScheduleDialog> createState() =>
      _CreatePaymentScheduleDialogState();
}

/// One user-entered custom installment (date + fixed amount).
class _CustomRow {
  _CustomRow() : amount = TextEditingController();
  DateTime? date;
  final TextEditingController amount;
}

class _CreatePaymentScheduleDialogState
    extends State<_CreatePaymentScheduleDialog> {
  // 'count' = number-of-payments (React primary path); 'custom' = explicit
  // date/amount rows (React's custom path → POST /task_schedulers).
  String _mode = 'count';

  final _count = TextEditingController(text: '2');
  String _frequencyId = '5'; // monthly
  DateTime? _firstPayment;
  bool _autoBill = false;
  bool _busy = false;

  final List<_CustomRow> _rows = [_CustomRow()];

  // Decimal-separator setting drives parse of each custom installment amount so
  // a comma-locale user typing `100,50` isn't rejected (validity) and `1.234`
  // isn't sent wrong. `formatterIfReady` is the sync accessor the entity-edit
  // screens use (see tax_rates_edit_screen.dart).
  late final bool _useComma;

  @override
  void initState() {
    super.initState();
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    _useComma =
        services.formatterIfReady(companyId)?.settings.useCommaAsDecimalPlace ??
        false;
  }

  @override
  void dispose() {
    _count.dispose();
    for (final r in _rows) {
      r.amount.dispose();
    }
    super.dispose();
  }

  Decimal _rowAmount(_CustomRow r) =>
      parseDecimal(r.amount.text, useCommaAsDecimalPlace: _useComma) ??
      Decimal.zero;

  bool get _customValid =>
      _rows.isNotEmpty &&
      _rows.every((r) => r.date != null && _rowAmount(r) > Decimal.zero) &&
      // The server (StoreSchedulerRequest::validatePaymentScheduleTotal) rejects
      // an is_amount schedule whose installments don't sum to the invoice
      // amount — gate submit on it (React does the same) so the user fixes it
      // here instead of getting a success toast then a dead outbox row.
      _rows.fold<Decimal>(Decimal.zero, (acc, r) => acc + _rowAmount(r)) ==
          widget.invoice.amount;

  bool get _valid => _mode == 'count'
      ? (int.tryParse(_count.text.trim()) ?? 0) >= 1 && _firstPayment != null
      : _customValid;

  Future<void> _submit() async {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    setState(() => _busy = true);
    if (_mode == 'count') {
      final first = _firstPayment!;
      final body = <String, dynamic>{
        'template': kScheduleTemplatePaymentSchedule,
        'next_run': Date(first.year, first.month, first.day).toIso(),
        'remaining_cycles': int.parse(_count.text.trim()),
        'frequency_id': _frequencyId,
        'parameters': <String, dynamic>{
          'invoice_id': widget.invoice.id,
          'auto_bill': _autoBill,
          'schedule': <dynamic>[],
        },
      };
      await runMutationWithNotify(
        context,
        () => services.invoices.createPaymentSchedule(
          companyId: companyId,
          id: widget.invoice.id,
          body: body,
        ),
        successMsg: context.tr('created_schedule'),
      );
    } else {
      // The server validates a custom schedule's `next_run` as
      // `after_or_equal:today` in the SERVER timezone (UTC by default). Device-
      // local "today" is UTC-yesterday during Americas afternoons/evenings, so
      // it 422s after the success toast. Send the LATER of local-today and
      // UTC-today so it's valid regardless of the device offset.
      final nowLocal = DateTime.now();
      final nowUtc = nowLocal.toUtc();
      final localToday = Date(nowLocal.year, nowLocal.month, nowLocal.day);
      final utcToday = Date(nowUtc.year, nowUtc.month, nowUtc.day);
      final today = utcToday.toDateTime().isAfter(localToday.toDateTime())
          ? utcToday
          : localToday;
      final body = <String, dynamic>{
        'template': kScheduleTemplatePaymentSchedule,
        'next_run': today.toIso(),
        'parameters': <String, dynamic>{
          'invoice_id': widget.invoice.id,
          'auto_bill': _autoBill,
          // `is_amount: true` = fixed-amount installments (React's default;
          // percentage mode is intentionally out of scope for this v1).
          'schedule': [
            for (final r in _rows)
              <String, dynamic>{
                'date': Date(r.date!.year, r.date!.month, r.date!.day).toIso(),
                // Exact decimal string, like every other money field on the
                // wire (`Invoice.toApiJson` etc.) — never a binary double.
                'amount':
                    (parseDecimal(
                              r.amount.text,
                              useCommaAsDecimalPlace: _useComma,
                            ) ??
                            Decimal.zero)
                        .toString(),
                'is_amount': true,
              },
          ],
        },
      };
      await runMutationWithNotify(
        context,
        () => services.invoices.createCustomPaymentSchedule(
          companyId: companyId,
          id: widget.invoice.id,
          body: body,
        ),
        successMsg: context.tr('created_schedule'),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Widget _customRowTile(BuildContext context, int i) {
    final row = _rows[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: InDateField(
              value: row.date,
              labelText: context.tr('date'),
              onChanged: (d) => setState(() => row.date = d),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: row.amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.tr('amount'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          IconButton(
            tooltip: context.tr('remove'),
            icon: const Icon(Icons.close, size: 18),
            onPressed: (_busy || _rows.length <= 1)
                ? null
                : () {
                    final removed = _rows.removeAt(i);
                    setState(() {});
                    // Dispose after this frame: the removed row's TextField
                    // element is still mounted during the rebuild, so
                    // disposing its controller synchronously trips the
                    // "used after dispose" assert. The removed row is no
                    // longer in `_rows`, so `dispose()` won't double-free.
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => removed.amount.dispose(),
                    );
                  },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('create_payment_schedule')),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'count',
                    label: Text(context.tr('number_of_payments')),
                  ),
                  ButtonSegment(
                    value: 'custom',
                    label: Text(context.tr('custom')),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _busy
                    ? null
                    : (s) => setState(() => _mode = s.first),
              ),
              const SizedBox(height: 12),
              if (_mode == 'count') ...[
                TextField(
                  controller: _count,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: context.tr('number_of_payments'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _frequencyId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('frequency'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _frequencyId = v ?? _frequencyId),
                  items: [
                    for (final e in kScheduleFrequencies.entries)
                      DropdownMenuItem(
                        value: e.key,
                        child: Text(context.tr(e.value)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                InDateField(
                  value: _firstPayment,
                  labelText: context.tr('first_payment_date'),
                  onChanged: (d) => setState(() => _firstPayment = d),
                ),
              ] else ...[
                for (var i = 0; i < _rows.length; i++)
                  _customRowTile(context, i),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _rows.add(_CustomRow())),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr('add')),
                  ),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _autoBill,
                onChanged: (v) => setState(() => _autoBill = v),
                title: Text(context.tr('auto_bill')),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            const SizedBox(width: 8),
            PrimaryDialogAction(
              label: context.tr('create_payment_schedule'),
              onPressed: _submit,
              enabled: _valid,
              busy: _busy,
              // Disabled until a date is chosen + no field routes Enter to
              // submit — so no Enter hint.
              autofocus: false,
              showEnterHint: false,
            ),
          ],
        ),
      ],
    );
  }
}
