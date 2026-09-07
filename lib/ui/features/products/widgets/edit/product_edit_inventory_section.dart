import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/products/view_models/product_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Inventory-related product fields. `max_quantity` is always shown; the
/// `in_stock_quantity` / `stock_notification` / `stock_notification_threshold`
/// trio is gated on the top-level `company.track_inventory` flag (NOT
/// `company.settings.*`, which the server never populates) — matches the
/// React edit form which hides those fields entirely when inventory tracking
/// is off (`ProductForm.tsx`).
class ProductEditInventorySection extends StatelessWidget {
  const ProductEditInventorySection({super.key, required this.vm});

  final ProductEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(vm.companyId),
      builder: (context, snap) {
        final tracksInventory = snap.data?.trackInventory ?? false;
        return DashboardCardShell(
          title: context.tr('inventory'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              EntityEditField(
                numeric: true,
                useCommaAsDecimalPlace: vm.useCommaAsDecimalPlace,
                label: context.tr('max_quantity'),
                initial: decimalInputText(vm.draft.maxQuantity),
                onChanged: vm.setMaxQuantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                errorText: vm.fieldErrorFor('max_quantity'),
              ),
              if (tracksInventory) ...[
                EntityEditField(
                  numeric: true,
                  useCommaAsDecimalPlace: vm.useCommaAsDecimalPlace,
                  label: context.tr('in_stock_quantity'),
                  initial: decimalInputText(vm.draft.inStockQuantity),
                  onChanged: vm.setInStockQuantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  errorText: vm.fieldErrorFor('in_stock_quantity'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.tr('stock_notifications')),
                    value: vm.draft.stockNotification,
                    onChanged: vm.setStockNotification,
                  ),
                ),
                EntityEditField(
                  numeric: true,
                  useCommaAsDecimalPlace: vm.useCommaAsDecimalPlace,
                  label: context.tr('notification_threshold'),
                  initial: decimalInputText(
                    vm.draft.stockNotificationThreshold,
                  ),
                  onChanged: vm.setStockNotificationThreshold,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  errorText: vm.fieldErrorFor('stock_notification_threshold'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
