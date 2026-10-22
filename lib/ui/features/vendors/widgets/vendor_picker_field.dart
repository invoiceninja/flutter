import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/session_permissions.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_inline_create.dart';

/// The vendor picker every form shares: resolves its selection by id (so a
/// `tmp_` vendor and one outside the loaded window both render), says "No
/// records found" for a company with none, and offers inline create — gated
/// on `create_vendor` — through [createVendorInline].
///
/// One widget so the create wiring, its duplicate rules and its permission
/// gate live in one place rather than in every form that picks a vendor.
class VendorPickerField extends StatelessWidget {
  const VendorPickerField({
    super.key,
    required this.companyId,
    required this.selectedId,
    required this.onChanged,
    this.errorText,
  });

  final String companyId;
  final String selectedId;
  final ValueChanged<Vendor?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return EntityPickerField<Vendor>(
      label: context.tr('vendor'),
      cacheKey: companyId,
      selectedId: selectedId,
      itemsStream: () =>
          services.vendors.watchPage(companyId: companyId, loadedPages: 100),
      watchById: (id) => services.vendors.watch(companyId: companyId, id: id),
      // Falls back to the id: now that an out-of-window or offline-created
      // vendor actually resolves, a nameless one would otherwise render an
      // empty field with not even an ✕ to signal it.
      displayString: (v) => v.name.isEmpty ? v.id : v.name,
      idOf: (v) => v.id,
      emptyHintKey: 'no_records_found',
      createLabelKey: 'new_vendor',
      onCreateRequested: sessionCan(context, 'create_vendor')
          ? (ctx, query) =>
                createVendorInline(ctx, companyId: companyId, query: query)
          : null,
      onChanged: onChanged,
      errorText: errorText,
    );
  }
}
