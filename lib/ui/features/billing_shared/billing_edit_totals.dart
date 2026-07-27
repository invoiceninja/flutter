import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/client_settings_cascade.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/billing_shared/totals_widget.dart';

/// Reactive totals block for billing-doc edit screens.
///
/// Resolves the active currency from the selected client (or, for purchase
/// orders, the vendor), looks up that currency's decimal precision via the
/// `Formatter` cascade, computes the totals at that precision, and renders a
/// [TotalsWidget] formatted in the same currency. This keeps the live edit
/// preview consistent with the saved / PDF totals for non-2-decimal
/// currencies (JPY 0 dp, BHD / KWD 3 dp) — `invoice_detail_screen._Overview`
/// does the identical resolution for the read-only view; the edit screens
/// previously hardcoded precision 2 and rendered money with no currency.
///
/// The currency stream is hoisted into state (keyed by the source id) so it is
/// NOT rebuilt on every keystroke — a fresh `watch()` per `build` would make
/// the inner `StreamBuilder` snap back to a null snapshot mid-edit and flicker
/// the precision (the "stable stream" rule).
class BillingEditTotals extends StatefulWidget {
  BillingEditTotals({
    required this.totalsAt,
    required this.discount,
    required this.discountIsAmount,
    Decimal? partial,
    this.clientId,
    this.vendorId,
    this.surchargeAmounts = const <Decimal>[],
    this.dense = false,
    this.slim = false,
    this.bordered = true,
    super.key,
  }) : partial = partial ?? Decimal.zero;

  /// Computes the totals at a given currency precision — pass
  /// `vm.totalsAt` (precision-aware, cached).
  final BillingTotalsResult Function(int precision) totalsAt;
  final Decimal discount;
  final bool discountIsAmount;

  /// Partial-payment amount (invoices only; zero for the other docs).
  final Decimal partial;

  /// The four invoice-level custom surcharge amounts, in slot order. Labels
  /// are resolved here from `company.customFields['surcharge1'..'4']` so call
  /// sites stay one line. `computeTotals` already folds these into `total`, so
  /// without the rows the footer showed a Total that didn't reconcile with the
  /// lines above it.
  final List<Decimal> surchargeAmounts;

  /// Currency source for client-billed docs (invoice / quote / credit /
  /// recurring). Empty / null falls back to the company default currency.
  final String? clientId;

  /// Currency source for purchase orders. When non-empty it takes precedence
  /// over [clientId] (a PO carries no client).
  final String? vendorId;

  final bool dense;
  final bool slim;
  final bool bordered;

  @override
  State<BillingEditTotals> createState() => _BillingEditTotalsState();
}

class _BillingEditTotalsState extends State<BillingEditTotals> {
  Stream<String?>? _currencyId;
  String? _sourceKey;

  /// Hoisted so a keystroke-driven rebuild doesn't resubscribe (stable-stream
  /// rule). Only needed for the surcharge labels.
  Stream<Company?>? _company;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureStream();
  }

  @override
  void didUpdateWidget(covariant BillingEditTotals old) {
    super.didUpdateWidget(old);
    _ensureStream();
  }

  /// (Re)build the currency stream only when the source id actually changes.
  void _ensureStream() {
    final services = context.read<Services>();
    final companyId = services.auth.currentCompanyId ?? '';
    final vendorId = widget.vendorId ?? '';
    final clientId = widget.clientId ?? '';
    // Lazy: only a doc that actually carries a surcharge needs the company
    // (for its labels), and this keeps the widget usable without a Services
    // provider in tests.
    if (_company == null &&
        widget.surchargeAmounts.any((a) => a != Decimal.zero)) {
      _company = services.company.watchCompany(companyId);
    }
    final key = vendorId.isNotEmpty ? 'v:$vendorId' : 'c:$clientId';
    if (key == _sourceKey && _currencyId != null) return;
    _sourceKey = key;
    if (vendorId.isEmpty && clientId.isEmpty) {
      // No party selected yet → company default currency / precision.
      _currencyId = Stream<String?>.value(null);
    } else if (vendorId.isNotEmpty) {
      _currencyId = services.vendors
          .watch(companyId: companyId, id: vendorId)
          .map((v) => v?.currencyId);
    } else {
      // Client → GROUP → company. Resolving only the client's own override
      // here rendered a grouped client's totals in the company currency, with
      // the wrong symbol AND precision, while the PDF used the group's.
      _currencyId = watchEffectiveClientCurrency(
        clients: services.clients,
        groups: services.groupSettings,
        companyId: companyId,
        clientId: clientId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Edit screens don't provide a FormatterScope (only list/detail do), so
    // fall back to the company formatter — otherwise TotalsWidget renders the
    // totals with no currency symbol at all. The resolved party currencyId is
    // still passed explicitly below, so totals show the vendor/client currency.
    final services = context.read<Services>();
    final formatter =
        FormatterScope.maybeOf(context) ??
        services.formatterIfReady(services.auth.currentCompanyId ?? '');
    return StreamBuilder<String?>(
      stream: _currencyId,
      builder: (context, snap) {
        final raw = snap.data;
        final currencyId = (raw != null && raw.isNotEmpty) ? raw : null;
        // Resolved party currency (client or vendor) → explicit slot, so the
        // precision is right for vendor docs (purchase orders) as well.
        final precision = formatter?.precisionFor(currencyId: currencyId) ?? 2;
        final companyStream = _company;
        if (companyStream == null) {
          return _totals(
            formatter,
            currencyId,
            precision,
            const <TotalsSurcharge>[],
          );
        }
        return StreamBuilder<Company?>(
          stream: companyStream,
          builder: (context, companySnap) {
            final surchargeRows = buildSurchargeRows(
              customFields: companySnap.data?.customFields,
              amounts: widget.surchargeAmounts,
            );
            return _totals(formatter, currencyId, precision, surchargeRows);
          },
        );
      },
    );
  }

  Widget _totals(
    Formatter? formatter,
    String? currencyId,
    int precision,
    List<TotalsSurcharge> surchargeRows,
  ) {
    return TotalsWidget(
      totals: widget.totalsAt(precision),
      discount: widget.discount,
      discountIsAmount: widget.discountIsAmount,
      partial: widget.partial,
      formatter: formatter,
      currencyId: currencyId,
      surcharges: surchargeRows,
      dense: widget.dense,
      slim: widget.slim,
      bordered: widget.bordered,
    );
  }
}
