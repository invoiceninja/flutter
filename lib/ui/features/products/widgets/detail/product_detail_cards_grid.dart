import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/domain/product_tax_categories.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/custom_fields_detail_card.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Detail-card grid for a single [Product]. Replaces the legacy
/// `ProductDetailCards`. At ≥1000 px renders a two-column grid (Details
/// left, Inventory + Taxes right); below the breakpoint stacks into a
/// single column. The price / cost / quantity / in-stock fields live in
/// [ProductDetailKpiStrip] above this widget — Details only carries the
/// remaining non-KPI fields (product key, max_quantity, image, notes).
class ProductDetailCardsGrid extends StatelessWidget {
  const ProductDetailCardsGrid({
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
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(companyId),
      builder: (context, snap) {
        final company = snap.data;
        final tracksInventory = company?.trackInventory ?? false;
        final enabledTaxSlots = company?.enabledItemTaxRates ?? 0;

        final hasInventory =
            tracksInventory ||
            product.inStockQuantity != Decimal.zero ||
            product.stockNotification ||
            product.stockNotificationThreshold != Decimal.zero;
        final hasTaxes =
            enabledTaxSlots >= 1 ||
            product.taxId.isNotEmpty ||
            product.taxName1.isNotEmpty ||
            product.taxRate1 != Decimal.zero ||
            product.taxName2.isNotEmpty ||
            product.taxRate2 != Decimal.zero ||
            product.taxName3.isNotEmpty ||
            product.taxRate3 != Decimal.zero;

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
            if (wide && (hasInventory || hasTaxes)) {
              return _wide(
                context,
                hasInventory: hasInventory,
                hasTaxes: hasTaxes,
                enabledTaxSlots: enabledTaxSlots,
              );
            }
            return CenteredFormColumn(
              child: _stacked(
                context,
                hasInventory: hasInventory,
                hasTaxes: hasTaxes,
                enabledTaxSlots: enabledTaxSlots,
              ),
            );
          },
        );
      },
    );
  }

  Widget _wide(
    BuildContext context, {
    required bool hasInventory,
    required bool hasTaxes,
    required int enabledTaxSlots,
  }) {
    final rightCards = <Widget>[
      if (hasInventory) _InventoryCard(product: product),
      if (hasTaxes) _TaxesCard(product: product, enabledSlots: enabledTaxSlots),
      if (_hasAnyCustomValue) _customFieldsCard(),
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _DetailsCard(product: product)),
          SizedBox(width: InSpacing.md(context)),
          Expanded(child: _stack(context, rightCards)),
        ],
      ),
    );
  }

  Widget _stacked(
    BuildContext context, {
    required bool hasInventory,
    required bool hasTaxes,
    required int enabledTaxSlots,
  }) {
    final cards = <Widget>[
      _DetailsCard(product: product),
      if (hasInventory) _InventoryCard(product: product),
      if (hasTaxes) _TaxesCard(product: product, enabledSlots: enabledTaxSlots),
      if (_hasAnyCustomValue) _customFieldsCard(),
    ];
    return _stack(context, cards);
  }

  bool get _hasAnyCustomValue =>
      product.customValue1.isNotEmpty ||
      product.customValue2.isNotEmpty ||
      product.customValue3.isNotEmpty ||
      product.customValue4.isNotEmpty;

  CustomFieldsDetailCard _customFieldsCard() => CustomFieldsDetailCard(
    companyId: companyId,
    prefix: 'product',
    values: [
      product.customValue1,
      product.customValue2,
      product.customValue3,
      product.customValue4,
    ],
    formatter: formatter,
  );

  Widget _stack(BuildContext context, List<Widget> cards) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) SizedBox(height: InSpacing.md(context)),
          cards[i],
        ],
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      title: context.tr('details'),
      child: DetailRowStack(
        children: [
          if (product.productKey.isNotEmpty)
            DetailInfoRow(
              label: context.tr('product'),
              value: product.productKey,
            ),
          if (product.maxQuantity != Decimal.zero)
            DetailInfoRow(
              label: context.tr('max_quantity'),
              value: product.maxQuantity.toString(),
              monospace: true,
            ),
          if (product.productImage.isNotEmpty)
            DetailInfoRow(
              label: context.tr('product_image'),
              value: product.productImage,
            ),
          if (product.notes.isNotEmpty)
            DetailInfoRow(label: context.tr('notes'), value: product.notes),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final stockValue = product.inStockQuantity * product.price;
    // Plain 2-decimal, no currency symbol — matches the KPI strip's price/cost
    // (product money isn't client-scoped, so the detail stays symbol-less).
    final numberFmt = NumberFormat.decimalPattern()
      ..minimumFractionDigits = 2
      ..maximumFractionDigits = 2;
    return DashboardCardShell(
      title: context.tr('inventory'),
      child: DetailRowStack(
        children: [
          DetailInfoRow(
            label: context.tr('in_stock_quantity'),
            value: product.inStockQuantity.toString(),
            monospace: true,
          ),
          // On-hand value (stock × price) — the per-product month-end figure.
          // Hidden when zero, per the detail-screen blank-row convention.
          if (stockValue != Decimal.zero)
            DetailInfoRow(
              label: context.tr('stock_value'),
              value: numberFmt.format(stockValue.toDouble()),
              monospace: true,
            ),
          DetailInfoRow(
            label: context.tr('stock_notifications'),
            value: context.tr(product.stockNotification ? 'yes' : 'no'),
            copyable: false,
          ),
          if (product.stockNotificationThreshold != Decimal.zero)
            DetailInfoRow(
              label: context.tr('notification_threshold'),
              value: product.stockNotificationThreshold.toString(),
              monospace: true,
            ),
        ],
      ),
    );
  }
}

class _TaxesCard extends StatelessWidget {
  const _TaxesCard({required this.product, required this.enabledSlots});
  final Product product;
  final int enabledSlots;

  String _formatTaxRow(BuildContext context, String name, Decimal rate) {
    if (name.isEmpty && rate == Decimal.zero) return '—';
    final label = name.isEmpty ? context.tr('tax') : name;
    return '$label @ $rate%';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    if (product.taxId.isNotEmpty) {
      final key = kProductTaxCategories[product.taxId];
      rows.add(
        DetailInfoRow(
          label: context.tr('tax_category'),
          value: key == null ? product.taxId : context.tr(key),
          copyable: false,
        ),
      );
    }
    if ((enabledSlots >= 1 ||
            product.taxName1.isNotEmpty ||
            product.taxRate1 != Decimal.zero) &&
        !(product.taxName1.isEmpty && product.taxRate1 == Decimal.zero)) {
      rows.add(
        DetailInfoRow(
          label: '${context.tr('tax')} 1',
          value: _formatTaxRow(context, product.taxName1, product.taxRate1),
          copyable: false,
        ),
      );
    }
    if ((enabledSlots >= 2 ||
            product.taxName2.isNotEmpty ||
            product.taxRate2 != Decimal.zero) &&
        !(product.taxName2.isEmpty && product.taxRate2 == Decimal.zero)) {
      rows.add(
        DetailInfoRow(
          label: '${context.tr('tax')} 2',
          value: _formatTaxRow(context, product.taxName2, product.taxRate2),
          copyable: false,
        ),
      );
    }
    if ((enabledSlots >= 3 ||
            product.taxName3.isNotEmpty ||
            product.taxRate3 != Decimal.zero) &&
        !(product.taxName3.isEmpty && product.taxRate3 == Decimal.zero)) {
      rows.add(
        DetailInfoRow(
          label: '${context.tr('tax')} 3',
          value: _formatTaxRow(context, product.taxName3, product.taxRate3),
          copyable: false,
        ),
      );
    }
    return DashboardCardShell(
      title: context.tr('taxes'),
      child: DetailRowStack(children: rows),
    );
  }
}
