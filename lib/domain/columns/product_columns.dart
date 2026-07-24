import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/product_dao.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/product_tax_categories.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/features/products/widgets/inventory_scope.dart';

typedef ProductColumn = ColumnDefinition<Product>;

const List<String> kDefaultProductColumns = <String>[
  ProductFieldIds.productKey,
  ProductFieldIds.description,
  ProductFieldIds.price,
  ProductFieldIds.cost,
  ProductFieldIds.quantity,
  ProductFieldIds.updatedAt,
];

final List<ProductColumn> kAllProductColumns = <ProductColumn>[
  ProductColumn(
    id: ProductFieldIds.productKey,
    labelKey: 'product',
    cellBuilder: (p, ctx) => cellLink(
      ctx,
      p.productKey,
      bold: true,
      onTap: () => goEntityFullDetail(ctx, '/products', p.id),
    ),
    valueBuilder: (p) => cellNonZeroString(p.productKey),
  ),
  ProductColumn(
    id: ProductFieldIds.description,
    labelKey: 'description',
    width: 220,
    cellBuilder: (p, _) => cellText(p.notes),
    valueBuilder: (p) => cellNonZeroString(p.notes),
  ),
  ProductColumn(
    id: ProductFieldIds.price,
    labelKey: 'price',
    width: 120,
    align: ColumnAlign.end,
    cellBuilder: (p, context) => cellMoney(p.price, context),
    valueBuilder: (p) => cellMoneyValue(p.price),
  ),
  ProductColumn(
    id: ProductFieldIds.cost,
    labelKey: 'cost',
    width: 120,
    align: ColumnAlign.end,
    cellBuilder: (p, context) => cellMoney(p.cost, context),
    valueBuilder: (p) => cellMoneyValue(p.cost),
  ),
  ProductColumn(
    id: ProductFieldIds.quantity,
    labelKey: 'quantity',
    width: 100,
    align: ColumnAlign.end,
    cellBuilder: (p, _) => cellText(p.quantity.toString()),
    valueBuilder: (p) => p.quantity.toString(),
  ),
  ProductColumn(
    id: ProductFieldIds.updatedAt,
    labelKey: 'last_updated',
    width: 110,
    cellBuilder: (p, ctx) => cellDate(p.updatedAt, ctx),
    valueBuilder: (p) => p.updatedAt.toIso8601String(),
  ),
  // --- Optional columns (opt-in via the column picker) ---
  ProductColumn(
    id: ProductFieldIds.taxCategory,
    labelKey: 'tax_category',
    width: 140,
    cellBuilder: (p, ctx) {
      if (p.taxId.isEmpty) return cellEmpty();
      final key = kProductTaxCategories[p.taxId];
      return cellText(key == null ? p.taxId : ctx.tr(key));
    },
    valueBuilder: (p) => cellNonZeroString(p.taxId),
  ),
  ProductColumn(
    id: ProductFieldIds.taxName1,
    labelKey: 'tax_name1',
    width: 130,
    cellBuilder: (p, _) => cellText(p.taxName1),
    valueBuilder: (p) => cellNonZeroString(p.taxName1),
  ),
  ProductColumn(
    id: ProductFieldIds.taxRate1,
    labelKey: 'tax_rate1',
    width: 90,
    align: ColumnAlign.end,
    cellBuilder: (p, _) => _rateCell(p.taxRate1),
    valueBuilder: (p) => _decValue(p.taxRate1),
  ),
  ProductColumn(
    id: ProductFieldIds.taxName2,
    labelKey: 'tax_name2',
    width: 130,
    cellBuilder: (p, _) => cellText(p.taxName2),
    valueBuilder: (p) => cellNonZeroString(p.taxName2),
  ),
  ProductColumn(
    id: ProductFieldIds.taxRate2,
    labelKey: 'tax_rate2',
    width: 90,
    align: ColumnAlign.end,
    cellBuilder: (p, _) => _rateCell(p.taxRate2),
    valueBuilder: (p) => _decValue(p.taxRate2),
  ),
  ProductColumn(
    id: ProductFieldIds.taxName3,
    labelKey: 'tax_name3',
    width: 130,
    cellBuilder: (p, _) => cellText(p.taxName3),
    valueBuilder: (p) => cellNonZeroString(p.taxName3),
  ),
  ProductColumn(
    id: ProductFieldIds.taxRate3,
    labelKey: 'tax_rate3',
    width: 90,
    align: ColumnAlign.end,
    cellBuilder: (p, _) => _rateCell(p.taxRate3),
    valueBuilder: (p) => _decValue(p.taxRate3),
  ),
  ProductColumn(
    id: ProductFieldIds.inStockQuantity,
    labelKey: 'in_stock_quantity',
    width: 120,
    align: ColumnAlign.end,
    cellBuilder: (p, context) => _stockCell(p, context),
    valueBuilder: (p) => _decValue(p.inStockQuantity),
  ),
  ProductColumn(
    id: ProductFieldIds.stockNotificationThreshold,
    labelKey: 'notification_threshold',
    width: 120,
    align: ColumnAlign.end,
    cellBuilder: (p, _) => _decCell(p.stockNotificationThreshold),
    valueBuilder: (p) => _decValue(p.stockNotificationThreshold),
  ),
  ProductColumn(
    id: ProductFieldIds.maxQuantity,
    labelKey: 'max_quantity',
    width: 110,
    align: ColumnAlign.end,
    cellBuilder: (p, _) => _decCell(p.maxQuantity),
    valueBuilder: (p) => _decValue(p.maxQuantity),
  ),
  // Computed inventory value: on-hand stock × price. Opt-in (not a default
  // column); formats through the company Formatter like price/cost.
  ProductColumn(
    id: ProductFieldIds.stockValue,
    labelKey: 'stock_value',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (p, context) =>
        cellMoney(p.inStockQuantity * p.price, context),
    valueBuilder: (p) => cellMoneyValue(p.inStockQuantity * p.price),
  ),
  ProductColumn(
    id: ProductFieldIds.custom1,
    labelKey: 'custom1',
    width: 140,
    cellBuilder: (p, _) => cellText(p.customValue1),
    valueBuilder: (p) => cellNonZeroString(p.customValue1),
  ),
  ProductColumn(
    id: ProductFieldIds.custom2,
    labelKey: 'custom2',
    width: 140,
    cellBuilder: (p, _) => cellText(p.customValue2),
    valueBuilder: (p) => cellNonZeroString(p.customValue2),
  ),
  ProductColumn(
    id: ProductFieldIds.custom3,
    labelKey: 'custom3',
    width: 140,
    cellBuilder: (p, _) => cellText(p.customValue3),
    valueBuilder: (p) => cellNonZeroString(p.customValue3),
  ),
  ProductColumn(
    id: ProductFieldIds.custom4,
    labelKey: 'custom4',
    width: 140,
    cellBuilder: (p, _) => cellText(p.customValue4),
    valueBuilder: (p) => cellNonZeroString(p.customValue4),
  ),
  ProductColumn(
    id: ProductFieldIds.createdAt,
    labelKey: 'created',
    width: 110,
    cellBuilder: (p, ctx) => cellDate(p.createdAt, ctx),
    valueBuilder: (p) => p.createdAt.toIso8601String(),
  ),
  ProductColumn(
    id: ProductFieldIds.archivedAt,
    labelKey: 'archived',
    width: 110,
    cellBuilder: (p, ctx) =>
        p.archivedAt == null ? cellEmpty() : cellDate(p.archivedAt!, ctx),
    valueBuilder: (p) => p.archivedAt?.toIso8601String(),
  ),
  // Attached tags. Display-only (not a sortable Drift column) — tag ids live
  // only in the payload; the tag cache resolves names/colors for rendering.
  ProductColumn(
    id: ProductFieldIds.tagIds,
    labelKey: 'tags',
    width: 200,
    cellBuilder: (p, _) => p.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'product', tagIds: p.tagIds),
    valueBuilder: (p) => '',
  ),
];

final Map<String, ProductColumn> productColumnsById = {
  for (final c in kAllProductColumns) c.id: c,
};

/// Numeric cell that collapses zero to an em-dash, so products that don't
/// track inventory / max-quantity don't read as a wall of zeros.
Widget _decCell(Decimal v) =>
    v == Decimal.zero ? cellEmpty() : cellText(v.toString());

String? _decValue(Decimal v) => v == Decimal.zero ? null : v.toString();

/// Tax-rate cell — like [_decCell] but suffixes a percent sign.
Widget _rateCell(Decimal v) =>
    v == Decimal.zero ? cellEmpty() : cellText('$v%');

/// On-hand-stock cell. When the company tracks inventory the number is always
/// rendered — a red `0` flags out-of-stock, never collapsed to an em-dash
/// (mirrors `productStockText`'s deliberate `[0]`) — and tinted by
/// [StockStatus]: red + error icon when out, amber + warning icon when low,
/// default ink otherwise. The icon pairs with the colour so the state survives
/// for colour-blind users. Falls back to the plain zero-collapsing [_decCell]
/// when inventory isn't tracked or no [InventoryScope] is in the tree.
Widget _stockCell(Product p, BuildContext context) {
  final scope = InventoryScope.maybeOf(context);
  if (scope == null || !scope.trackInventory) {
    return _decCell(p.inStockQuantity);
  }
  final tokens = context.inTheme;
  final (Color color, IconData? icon) = switch (scope.statusFor(p)) {
    StockStatus.out => (tokens.overdue, Icons.error_outline),
    StockStatus.low => (tokens.warning, Icons.warning_amber_rounded),
    StockStatus.ok => (tokens.ink, null),
  };
  return _StockCell(
    text: p.inStockQuantity.toString(),
    color: color,
    icon: icon,
  );
}

/// Numeric stock cell with an optional leading status icon. Tabular figures so
/// digits line up across rows; the icon makes low/out distinguishable without
/// relying on colour alone.
class _StockCell extends StatelessWidget {
  const _StockCell({required this.text, required this.color, this.icon});

  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w500,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (icon == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(child: label),
      ],
    );
  }
}
