import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/products/widgets/inventory_scope.dart';
import 'package:admin/utils/formatting.dart';

/// Where a product stands: what it sells for, what it costs, and — for a
/// company that keeps stock — how much of it there is.
///
/// It replaces a four-cell strip of Price, Cost, Quantity and Stock Quantity.
/// Each figure follows the rule the strip arrived at one issue at a time
/// (`docs/row-actions-and-values.md` § A zero in a detail KPI cell):
///
/// * **Price always prints**, zero included — a free product is a real price.
/// * **Cost is drawn only when one was entered.** It is optional (a company
///   can switch the field off altogether), and an unentered cost shown as
///   `$0.00` — or as a dash under the word "Cost" — claims the product costs
///   nothing (invoiceninja/flutter#92).
/// * **Stock is drawn only for a company that tracks inventory**, or for a
///   product that carries a figure anyway: never hide a number the product
///   actually has (#91). It sits under the prices as a line of its own, led
///   by the same Low stock / Out of stock call the product list makes — in
///   words, so the state does not rest on colour alone.
/// * **Stock value** (stock × price) only when it is not zero.
///
/// The default quantity left this card for the Details card: it is a setting
/// for new line items, not something the product *has*.
///
/// Money is in the company's currency — a product has none of its own — and
/// blank until the formatter arrives.
class ProductDetailStanding extends StatelessWidget {
  const ProductDetailStanding({
    super.key,
    required this.product,
    required this.company,
    required this.formatter,
  });

  final Product product;

  /// For whether inventory is tracked and the company's low-stock threshold.
  /// Null while it loads, which reads as "not tracked" for that frame.
  final Company? company;

  /// Null while it loads — the figures are blank until it arrives.
  final Formatter? formatter;

  /// Whether the stock line is drawn at all — see the class doc.
  static bool showsStock(Product product, Company? company) =>
      (company?.trackInventory ?? false) ||
      product.inStockQuantity != Decimal.zero;

  @override
  Widget build(BuildContext context) {
    final p = product;
    String money(Decimal amount) => formatter?.money(amount) ?? '';
    final showStock = showsStock(p, company);
    final stockValue = p.inStockQuantity * p.price;
    return StandingCard(
      primary: [
        StandingFigure(label: context.tr('price'), value: money(p.price)),
        if (p.cost != Decimal.zero)
          StandingFigure(label: context.tr('cost'), value: money(p.cost)),
      ],
      secondary: [
        if (showStock && stockValue != Decimal.zero)
          StandingFigure(
            label: context.tr('stock_value'),
            value: money(stockValue),
          ),
      ],
      footnote: showStock
          ? _StockLine(
              quantity: p.inStockQuantity,
              status: stockStatusFor(
                p,
                trackInventory: company?.trackInventory ?? false,
                threshold: company?.inventoryNotificationThreshold ?? 0,
              ),
            )
          : null,
    );
  }
}

/// "Stock quantity 42", led by a pill when the stock is low or gone.
///
/// Owns its leading gap, as every standing footnote does.
class _StockLine extends StatelessWidget {
  const _StockLine({required this.quantity, required this.status});

  final Decimal quantity;
  final StockStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    // Sized like the status pill an expense's standing card carries, so the
    // state line reads the same from one record to the next.
    StatusPill pillOf(String labelKey, Color fg, Color bg) => StatusPill(
      label: context.tr(labelKey),
      fgColor: fg,
      bgColor: bg,
      dotSize: 8,
      textStyle: TextStyle(fontSize: 13, color: tokens.ink),
    );
    final pill = switch (status) {
      StockStatus.out => pillOf(
        'out_of_stock',
        tokens.overdue,
        tokens.overdueSoft,
      ),
      StockStatus.low => pillOf(
        'low_stock',
        tokens.warning,
        tokens.warningSoft,
      ),
      StockStatus.ok => null,
    };
    return Padding(
      padding: const EdgeInsets.only(top: kStandingFootnoteGap),
      child: Wrap(
        spacing: InSpacing.sm,
        runSpacing: InSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ?pill,
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('in_stock_quantity'),
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink2),
              ),
              const SizedBox(width: InSpacing.sm),
              Text(
                '$quantity',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w600)
                    .merge(moneyTextStyle()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
