import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:admin/ui/core/detail/kpi_strip_layout.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Symbol-less money rendering for product detail surfaces: fixed 2 decimals
/// so a 10.00 price never renders as "10", company separators via
/// [Formatter.decimal]. The locale-pattern fallback covers only the frames
/// before the screen's async Formatter resolves.
///
/// Used by the Inventory card's derived figures (stock value) and as the KPI
/// strip's pre-Formatter fallback. The strip's own Price / Cost cells carry
/// the currency symbol — see [ProductDetailKpiStrip].
String formatProductAmount(Formatter? formatter, Decimal value) =>
    formatter?.decimal(value.toDouble(), minDecimals: 2, maxDecimals: 2) ??
    (NumberFormat.decimalPattern()
          ..minimumFractionDigits = 2
          ..maximumFractionDigits = 2)
        .format(value.toDouble());

/// KPI strip at the top of the product Overview tab — the numbers that matter
/// most when scanning a product: price, cost, default quantity, and in-stock
/// quantity when the company tracks inventory (or the product carries one).
///
/// Layout switches at 1100 px (mirrors `ExpenseDetailKpiStrip`).
class ProductDetailKpiStrip extends StatelessWidget {
  const ProductDetailKpiStrip({
    super.key,
    required this.product,
    required this.companyId,
    this.formatter,
  });

  final Product product;
  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return WatchBuilder<Company?>(
      cacheKey: companyId,
      create: () => services.company.watchCompany(companyId),
      builder: (context, snap) {
        final tracksInventory = snap.data?.trackInventory ?? false;
        return _Strip(
          product: product,
          tracksInventory: tracksInventory,
          formatter: formatter,
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.product,
    required this.tracksInventory,
    required this.formatter,
  });

  final Product product;
  final bool tracksInventory;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final p = product;

    // Money with its symbol, matching the Products list (which has always
    // shown one) — on the detail screen the eye was landing on Quantity /
    // Stock Quantity instead, because nothing marked Price and Cost as money
    // (invoiceninja/flutter#90).
    String money(Decimal value) =>
        formatter?.money(value) ?? formatProductAmount(formatter, value);

    Widget moneyCell(
      String labelKey,
      Decimal value, {
      bool dashIfZero = false,
    }) {
      final blank = dashIfZero && value == Decimal.zero;
      return _KpiCell(
        label: context.tr(labelKey),
        value: Text(
          blank ? '—' : money(value),
          style: theme.textTheme.titleLarge?.merge(
            moneyTextStyle(
              color: blank ? tokens.ink3 : tokens.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        tokens: tokens,
      );
    }

    // In-stock is data the company may not keep; the Inventory card below
    // already hides itself on the same test, so the strip agreeing with it
    // beats a permanently dashed cell (invoiceninja/flutter#91). Kept when a
    // figure exists regardless — never hide a number the product actually has.
    final showInStock = tracksInventory || p.inStockQuantity != Decimal.zero;

    final cells = <Widget>[
      moneyCell('price', p.price),
      // Cost is optional metadata (it is gated off entirely for companies that
      // don't use it), so an unentered one reads as blank rather than as a
      // product that costs nothing (invoiceninja/flutter#92). Price does not
      // get the same treatment — a zero price is a real price.
      moneyCell('cost', p.cost, dashIfZero: true),
      _KpiCell(
        label: context.tr('quantity'),
        value: Text(
          p.quantity.toString(),
          style: theme.textTheme.titleLarge?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        tokens: tokens,
      ),
      if (showInStock)
        _KpiCell(
          label: context.tr('in_stock_quantity'),
          value: Text(
            p.inStockQuantity.toString(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          tokens: tokens,
        ),
    ];

    return DashboardCardShell(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.lg(context),
      ),
      child: KpiStripLayout(cells: cells),
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.label,
    required this.value,
    required this.tokens,
  });

  final String label;
  final Widget value;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: tokens.ink3,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        value,
      ],
    );
  }
}
