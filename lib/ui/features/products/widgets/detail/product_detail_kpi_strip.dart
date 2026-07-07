import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Shared money-style rendering for the product detail surfaces (KPI strip +
/// Inventory card): symbol-less (product money isn't client-scoped), fixed
/// 2 decimals so a 10.00 price never renders as "10", company separators via
/// [Formatter.decimal]. The locale-pattern fallback covers only the frames
/// before the screen's async Formatter resolves. One helper so the sibling
/// widgets on the same screen can't drift apart.
String formatProductAmount(Formatter? formatter, Decimal value) =>
    formatter?.decimal(value.toDouble(), minDecimals: 2, maxDecimals: 2) ??
    (NumberFormat.decimalPattern()
          ..minimumFractionDigits = 2
          ..maximumFractionDigits = 2)
        .format(value.toDouble());

/// KPI strip at the top of the product Overview tab — surfaces the four
/// numbers that matter most when scanning a product: price, cost, default
/// quantity, and (when inventory is tracked) in-stock quantity.
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

  static const double _wideBreakpoint = 1100;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(companyId),
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

    String fmt(Decimal value) => formatProductAmount(formatter, value);

    final inStockText = tracksInventory ? p.inStockQuantity.toString() : '—';

    final cells = <Widget>[
      _KpiCell(
        label: context.tr('price'),
        value: Text(
          fmt(p.price),
          style: theme.textTheme.titleLarge?.merge(
            moneyTextStyle(color: tokens.ink, fontWeight: FontWeight.w600),
          ),
        ),
        tokens: tokens,
      ),
      _KpiCell(
        label: context.tr('cost'),
        value: Text(
          fmt(p.cost),
          style: theme.textTheme.titleLarge?.merge(
            moneyTextStyle(color: tokens.ink, fontWeight: FontWeight.w600),
          ),
        ),
        tokens: tokens,
      ),
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
      _KpiCell(
        label: context.tr('in_stock_quantity'),
        value: Text(
          inStockText,
          style: theme.textTheme.titleLarge?.copyWith(
            color: inStockText == '—' ? tokens.ink3 : tokens.ink,
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= ProductDetailKpiStrip._wideBreakpoint) {
            return _HorizontalStrip(cells: cells, tokens: tokens);
          }
          return _Grid2x2(cells: cells);
        },
      ),
    );
  }
}

class _HorizontalStrip extends StatelessWidget {
  const _HorizontalStrip({required this.cells, required this.tokens});
  final List<Widget> cells;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: InSpacing.lg(context)),
            child: SizedBox(
              width: 1,
              height: 36,
              child: ColoredBox(color: tokens.border),
            ),
          ),
        );
      }
      children.add(Expanded(child: cells[i]));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

class _Grid2x2 extends StatelessWidget {
  const _Grid2x2({required this.cells});
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[0]),
            SizedBox(width: InSpacing.md(context)),
            Expanded(child: cells[1]),
          ],
        ),
        SizedBox(height: InSpacing.md(context)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[2]),
            SizedBox(width: InSpacing.md(context)),
            Expanded(child: cells[3]),
          ],
        ),
      ],
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
