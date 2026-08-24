import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/products/view_models/product_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Core product fields — product key, price, cost, quantity, notes. The
/// always-shown card on every product edit; sibling cards (Inventory,
/// Taxes) layer in on top.
///
/// Cost and Default Quantity are gated on the top-level company flags
/// `enable_product_cost` / `enable_product_quantity` (NOT under `.settings`) —
/// matches the React (`ProductForm.tsx`) and legacy edit forms, which hide
/// those inputs entirely when the company disables them.
class ProductEditDetailsSection extends StatelessWidget {
  const ProductEditDetailsSection({super.key, required this.vm});

  final ProductEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(vm.companyId),
      builder: (context, snap) {
        final showCost = snap.data?.enableProductCost ?? false;
        final showQuantity = snap.data?.enableProductQuantity ?? false;
        // The eye lands on the currency mark before the digits, which is what
        // stops Price / Cost reading as just two more numbers next to Quantity
        // and Stock Quantity (invoiceninja/flutter#90). Empty until the
        // statics resolve, so the field simply has no prefix for a frame
        // rather than flashing a placeholder.
        final symbol = services.formatterIfReady(vm.companyId)?.currencySymbol;
        final moneyPrefix = (symbol == null || symbol.isEmpty)
            ? null
            : '$symbol ';
        return DashboardCardShell(
          title: context.tr('details'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              EntityEditField(
                label: context.tr('product'),
                initial: vm.draft.productKey,
                onChanged: vm.setProductKey,
                autofocus: vm.isCreate,
                errorText: vm.fieldErrorFor('product_key'),
              ),
              EntityEditField(
                label: context.tr('price'),
                prefixText: moneyPrefix,
                initial: decimalInputText(vm.draft.price),
                onChanged: vm.setPrice,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                errorText: vm.fieldErrorFor('price'),
              ),
              if (showCost)
                EntityEditField(
                  label: context.tr('cost'),
                  prefixText: moneyPrefix,
                  initial: decimalInputText(vm.draft.cost),
                  onChanged: vm.setCost,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  errorText: vm.fieldErrorFor('cost'),
                ),
              if (showQuantity)
                EntityEditField(
                  label: context.tr('quantity'),
                  initial: decimalInputText(vm.draft.quantity),
                  onChanged: vm.setQuantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  errorText: vm.fieldErrorFor('quantity'),
                ),
              EntityEditField(
                label: context.tr('notes'),
                initial: vm.draft.notes,
                onChanged: vm.setNotes,
                minLines: 2,
                maxLines: null,
              ),
              SizedBox(height: InSpacing.md(context)),
              EntityTagsField(
                entityType: 'product',
                selectedIds: vm.draft.tagIds,
                onChanged: vm.setTagIds,
              ),
            ],
          ),
        );
      },
    );
  }
}
