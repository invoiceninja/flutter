import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';
import 'package:admin/ui/core/widgets/locked_entity_field_row.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

/// A vendor-addressed document's Vendor — today the purchase order's.
///
/// **Frozen once the document exists.** `UpdatePurchaseOrderRequest` pins it —
/// `$rules['vendor_id'] = ['bail','sometimes', Rule::in([$this->purchase_order->vendor_id])]`
/// — so a changed vendor 422s into a dead outbox row the user can only discard
/// (invoiceninja/flutter#158). Note this is the PO's `vendor_id` only: its
/// `client_id` is NOT frozen server-side, and neither is the `vendor_id` the
/// other four billing docs carry on their Settings tab.
///
/// The gate is `!vm.isCreate` alone — see `BillingDocClientPicker` for why an
/// empty-id fall-through to the live picker would be a lie rather than a
/// rescue.
class BillingDocVendorPicker extends StatelessWidget {
  const BillingDocVendorPicker({
    super.key,
    required this.vm,
    required this.companyId,
  });

  final BillingDocEditViewModel<BillingDocFields> vm;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    if (!vm.isCreate) {
      return LockedVendorFieldRow(
        vendorId: vm.draft.vendorId,
        // Clone is how you raise the same order against a different vendor.
        helperText: context.tr('locked_after_save_clone'),
        errorText: vm.fieldErrorFor('vendor_id'),
      );
    }
    final services = context.read<Services>();
    return EntityPickerField<Vendor>(
      label: context.tr('vendor'),
      cacheKey: companyId,
      selectedId: vm.draft.vendorId,
      itemsStream: () =>
          services.vendors.watchPage(companyId: companyId, loadedPages: 100),
      watchById: (id) => services.vendors.watch(companyId: companyId, id: id),
      // Falls back to the id like its two siblings: now that an out-of-window
      // or offline-created vendor actually resolves, a nameless one would
      // otherwise render an empty field with not even an ✕ to signal it.
      displayString: (v) => v.name.isEmpty ? v.id : v.name,
      idOf: (v) => v.id,
      onChanged: (v) => vm.setVendorId(v?.id ?? ''),
      errorText: vm.fieldErrorFor('vendor_id'),
    );
  }
}
