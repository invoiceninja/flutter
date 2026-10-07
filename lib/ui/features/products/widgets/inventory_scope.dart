import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/product.dart';

/// Per-product inventory health, derived from on-hand stock vs. the threshold
/// cascade. Drives the list's low/out highlight (amber / red).
enum StockStatus { ok, low, out }

/// Stock status for [product] under the company threshold cascade. Returns
/// [StockStatus.ok] when inventory isn't tracked (no highlight). `out` wins
/// over `low` (out is the worst case), so the two render as distinct colours.
/// Mirrors the backend `AdjustProductInventory` two-tier check: the product's
/// own threshold, or the company fallback ([threshold]) when the product's is
/// 0.
///
/// A plain function so the product record screen — which has the company in
/// hand and no list above it to provide an [InventoryScope] — reads the same
/// rule the list's highlight does.
StockStatus stockStatusFor(
  Product product, {
  required bool trackInventory,
  required int threshold,
}) {
  if (!trackInventory) return StockStatus.ok;
  final qty = product.inStockQuantity;
  if (qty <= Decimal.zero) return StockStatus.out;
  final effective = product.stockNotificationThreshold > Decimal.zero
      ? product.stockNotificationThreshold
      : Decimal.fromInt(threshold);
  if (effective > Decimal.zero && qty <= effective) return StockStatus.low;
  return StockStatus.ok;
}

/// Ambient inventory settings for the products list, so column cells (and the
/// narrow tile) can colour the on-hand-stock value without each one re-reading
/// the company. Provided once by the list's `tileBuilder` around every
/// [ProductListTile]; mirrors how `FormatterScope` exposes the active company
/// [Formatter]. Carries the company `track_inventory` flag and the company-level
/// `inventory_notification_threshold` fallback.
class InventoryScope extends InheritedWidget {
  const InventoryScope({
    super.key,
    required this.trackInventory,
    required this.threshold,
    required super.child,
  });

  final bool trackInventory;
  final int threshold;

  static InventoryScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<InventoryScope>();

  /// Stock status for [product] under the company threshold cascade — see
  /// [stockStatusFor], which this hands its two settings to.
  StockStatus statusFor(Product product) => stockStatusFor(
    product,
    trackInventory: trackInventory,
    threshold: threshold,
  );

  @override
  bool updateShouldNotify(InventoryScope oldWidget) =>
      trackInventory != oldWidget.trackInventory ||
      threshold != oldWidget.threshold;
}
