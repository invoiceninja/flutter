import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// Bracketed in-stock count (e.g. `[12]`, `[0]`) shown next to a product when
/// picking it for an **invoice** line item and the company tracks inventory.
/// Mirrors the old Flutter admin-portal's `Product [N]` selection affordance;
/// the React client shows the same at its product selector (invoices only).
///
/// Used by both product-selection surfaces — the bulk picker
/// (`line_item_picker_body.dart`) and the desktop inline typeahead
/// (`line_item_table_desktop.dart`) — so they render identically.
///
/// Rendered as a muted/secondary token normally, switching to the destructive
/// `overdue` red when out of stock (`<= 0`) so an unfulfillable pick stands out.
/// Returns an empty box when [show] is false, so callers can drop it in
/// unconditionally.
class ProductStockLabel extends StatelessWidget {
  const ProductStockLabel({
    super.key,
    required this.quantity,
    required this.show,
  });

  final Decimal quantity;

  /// `company.trackInventory && docTypeIsInvoice`, resolved by the caller.
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();
    final tokens = context.inTheme;
    final outOfStock = isOutOfStock(quantity);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Semantics(
        label: '$quantity ${context.tr('stock_quantity')}',
        child: Text(
          productStockText(quantity),
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: outOfStock ? tokens.overdue : tokens.ink3,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// The bracketed display string for a stock quantity — `[0]`, `[12]`, `[12.5]`.
///
/// Deliberately **not** `decimalInputText()` (which renders `''` for zero):
/// when inventory is tracked we want an explicit `[0]` to flag the out-of-stock
/// product, not a blank.
String productStockText(Decimal quantity) => '[$quantity]';

/// A product is out of stock once its in-stock quantity reaches zero (or, after
/// over-allocation, goes negative).
bool isOutOfStock(Decimal quantity) => quantity <= Decimal.zero;
