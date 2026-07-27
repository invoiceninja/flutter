import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/payments/widgets/payment_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Sub-screen at `/payments/:id/refund`. Two modes:
///   * Full — auto-allocate the full refundable amount across paymentables
///     using `amount - refunded` per row. Collapses the editor.
///   * Custom — show the editable allocations table with a live
///     "$Y remaining" pill.
class PaymentRefundScreen extends StatefulWidget {
  const PaymentRefundScreen({super.key, required this.id});
  final String id;

  @override
  State<PaymentRefundScreen> createState() => _PaymentRefundScreenState();
}

class _PaymentRefundScreenState extends State<PaymentRefundScreen> {
  late final Services _services;
  late final String _companyId;

  bool get _useComma =>
      _services.formatterIfReady(_companyId)?.settings.useCommaAsDecimalPlace ??
      false;

  Formatter? get _formatter => _services.formatterIfReady(_companyId);

  /// Format an amount in the payment's currency, mirroring
  /// `payment_detail_kpi_strip.dart`. Falls back to the raw decimal until the
  /// formatter is ready.
  String _money(Decimal value) {
    final f = _formatter;
    return f == null
        ? value.toString()
        : f.money(value, clientCurrencyId: _payment?.currencyId ?? '');
  }

  /// Resolve an allocation's invoice id to its human-readable `#number` via
  /// the payment's lightweight invoice refs, falling back to the id when the
  /// number isn't available.
  String _invoiceLabel(Map<String, String> numbers, String invoiceId) {
    final number = numbers[invoiceId] ?? '';
    return number.isEmpty ? invoiceId : '#$number';
  }

  Payment? _payment;
  bool _loading = true;

  bool _fullRefund = true;
  Date? _date;
  bool _sendEmail = false;
  bool _gatewayRefund = false;

  /// Resolved from the gateway statics + company gateway after [_load]
  /// runs. Stays false for manually-entered payments (no companyGatewayId)
  /// and for gateway providers whose `options.<gatewayTypeId>.support_refunds`
  /// is false. Drives the gateway-refund toggle's enabled state.
  bool _supportsGatewayRefund = false;

  /// invoice_id → allocated refund amount (Custom mode).
  final Map<String, Decimal> _allocations = {};

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _date = Date.today();
    _load();
  }

  Future<void> _load() async {
    final payment = await _services.payments
        .watch(companyId: _companyId, id: widget.id)
        .first;
    var supportsGatewayRefund = false;
    if (payment != null && payment.companyGatewayId.isNotEmpty) {
      // Look up the configured CompanyGateway → its gatewayKey → the
      // statics Gateway → its per-gatewayType refund capability.
      final companyGateway = await _services.companyGateways
          .watch(companyId: _companyId, id: payment.companyGatewayId)
          .first;
      final key = companyGateway?.gatewayKey ?? '';
      if (key.isNotEmpty) {
        final gateway = _services.statics.gateways[key];
        final options = gateway?.options[payment.gatewayTypeId];
        supportsGatewayRefund = options?.supportRefunds ?? false;
      }
    }
    if (!mounted) return;
    setState(() {
      _payment = payment;
      _loading = false;
      _supportsGatewayRefund = supportsGatewayRefund;
      if (payment != null) {
        for (final p in payment.paymentables) {
          if (p.invoiceId.isEmpty) continue;
          _allocations[p.invoiceId] = p.amount - p.refunded;
        }
      }
    });
  }

  Decimal get _allocatedTotal =>
      _allocations.values.fold(Decimal.zero, (sum, v) => sum + v);

  Decimal get _remaining {
    final p = _payment;
    if (p == null) return Decimal.zero;
    // Ceiling is the APPLIED total, not `refundable` (= amount − refunded),
    // which also counts unapplied funds this invoice-allocation-only flow can
    // never refund. Using the larger figure let an over-allocation pass the
    // local gate and get rejected by the server's `ValidRefundableInvoices`
    // after the user had already committed.
    return _fullRefundAmount(p) - _allocatedTotal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('refund_payment'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _payment == null
          ? EmptyState(
              icon: Icons.payments_outlined,
              title: context.tr('payment_not_found'),
            )
          : _body(context, _payment!),
    );
  }

  Widget _body(BuildContext context, Payment p) {
    final tokens = context.inTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, p),
          SizedBox(height: InSpacing.lg(context)),
          _modeToggle(context, p),
          SizedBox(height: InSpacing.lg(context)),
          if (!_fullRefund) _customEditor(context, p),
          if (!_fullRefund) SizedBox(height: InSpacing.lg(context)),
          _dateField(context),
          SizedBox(height: InSpacing.lg(context)),
          _options(context, p),
          SizedBox(height: InSpacing.lg(context)),
          if (!_fullRefund)
            Row(
              children: [
                Text(
                  context.tr('remaining'),
                  style: TextStyle(
                    color: tokens.ink3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _money(_remaining),
                  style: moneyTextStyle(
                    color: _remaining < Decimal.zero ? Colors.red : tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          SizedBox(height: InSpacing.lg(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => context.pop(),
                child: Text(context.tr('cancel')),
              ),
              SizedBox(width: InSpacing.md(context)),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                onPressed: _canSubmit ? () => _submit(context, p) : null,
                child: Text(context.tr('refund')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Payment p) {
    final tokens = context.inTheme;
    return Container(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#${p.number.isEmpty ? '—' : p.number}',
                  style: TextStyle(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                PaymentStatusPill(statusId: p.calculatedStatusId),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('refundable').toUpperCase(),
                style: TextStyle(
                  color: tokens.ink3,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _money(p.refundable),
                style: moneyTextStyle(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The amount Full mode actually refunds: the sum of the per-invoice
  /// allocations (`amount - refunded`), which equals the *applied* portion —
  /// NOT `p.refundable` (which includes unapplied funds the server won't refund
  /// through this allocation-only flow). Mirrors the Full-mode allocation loop.
  Decimal _fullRefundAmount(Payment p) => p.paymentables
      .where((pa) => pa.invoiceId.isNotEmpty)
      .fold(Decimal.zero, (sum, pa) => sum + (pa.amount - pa.refunded));

  Widget _modeToggle(BuildContext context, Payment p) {
    final hasAllocations = p.paymentables.any((pa) => pa.invoiceId.isNotEmpty);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: true,
              label: Text(
                '${context.tr('full_refund')} (${_money(_fullRefundAmount(p))})',
              ),
              // Server rejects refund-without-allocations; gray out Full
              // mode when there are no paymentables to refund against.
              enabled: hasAllocations,
            ),
            ButtonSegment(value: false, label: Text(context.tr('custom'))),
          ],
          selected: {_fullRefund},
          onSelectionChanged: (s) => setState(() {
            _fullRefund = s.first;
            if (_fullRefund) {
              _allocations.clear();
              for (final pa in p.paymentables) {
                if (pa.invoiceId.isEmpty) continue;
                _allocations[pa.invoiceId] = pa.amount - pa.refunded;
              }
            }
          }),
        ),
        if (!hasAllocations)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr('no_invoices_to_refund'),
              style: TextStyle(color: context.inTheme.ink3, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _customEditor(BuildContext context, Payment p) {
    final tokens = context.inTheme;
    final paymentables = p.paymentables.where((pa) => pa.invoiceId.isNotEmpty);
    final numbers = {for (final r in p.invoices) r.id: r.number};
    if (paymentables.isEmpty) {
      return Text(
        context.tr('no_invoices_to_refund'),
        style: TextStyle(color: tokens.ink3),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final pa in paymentables) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.tr('invoice')} '
                    '${_invoiceLabel(numbers, pa.invoiceId)}',
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextFormField(
                    initialValue: decimalInputText(
                      _allocations[pa.invoiceId] ?? Decimal.zero,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: context.tr('amount'),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _allocations[pa.invoiceId] =
                            parseDecimal(
                              v,
                              useCommaAsDecimalPlace: _useComma,
                            ) ??
                            Decimal.zero;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _dateField(BuildContext context) {
    return InDateField(
      labelText: context.tr('date'),
      value: _date?.toDateTime(),
      onChanged: (dt) => setState(
        () => _date = dt == null ? null : Date(dt.year, dt.month, dt.day),
      ),
    );
  }

  Widget _options(BuildContext context, Payment p) {
    // `_supportsGatewayRefund` is resolved by [_load] against the gateway's
    // static-data capability flag (`Gateway.options[gatewayTypeId]
    // .supportRefunds`). It's false for manual payments and for providers
    // whose API doesn't expose a refund endpoint.
    return Column(
      children: [
        SwitchListTile(
          title: Text(context.tr('send_email')),
          value: _sendEmail,
          onChanged: (v) => setState(() => _sendEmail = v),
        ),
        SwitchListTile(
          title: Text(context.tr('gateway_refund')),
          subtitle: _supportsGatewayRefund
              ? null
              : Text(context.tr('gateway_refund_unavailable')),
          value: _supportsGatewayRefund && _gatewayRefund,
          onChanged: _supportsGatewayRefund
              ? (v) => setState(() => _gatewayRefund = v)
              : null,
        ),
      ],
    );
  }

  bool get _canSubmit {
    final p = _payment;
    if (p == null) return false;
    final hasAllocations = p.paymentables.any((pa) => pa.invoiceId.isNotEmpty);
    if (!hasAllocations) return false;
    if (_fullRefund) return true;
    if (_remaining < Decimal.zero) return false;
    return _allocatedTotal > Decimal.zero;
  }

  Future<void> _submit(BuildContext context, Payment p) async {
    final entries = <Map<String, dynamic>>[];
    if (_fullRefund) {
      for (final pa in p.paymentables) {
        if (pa.invoiceId.isEmpty) continue;
        final amt = pa.amount - pa.refunded;
        if (amt <= Decimal.zero) continue;
        entries.add(<String, dynamic>{
          'invoice_id': pa.invoiceId,
          'amount': amt.toString(),
          'id': '',
        });
      }
    } else {
      _allocations.forEach((invoiceId, amt) {
        if (amt <= Decimal.zero) return;
        entries.add(<String, dynamic>{
          'invoice_id': invoiceId,
          'amount': amt.toString(),
          'id': '',
        });
      });
    }
    if (entries.isEmpty) {
      Notify.error(context, context.tr('please_enter_a_value'));
      return;
    }
    await _services.payments.refund(
      companyId: _companyId,
      paymentId: p.id,
      date: _date?.toIso() ?? Date.today().toIso(),
      invoices: entries,
      sendEmail: _sendEmail,
      gatewayRefund: _gatewayRefund,
    );
    if (!context.mounted) return;
    Notify.success(context, context.tr('refunded_payment'));
    context.pop();
  }
}
