import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/client.dart';
import 'package:admin/ui/core/widgets/client_picker_field.dart';
import 'package:admin/ui/features/clients/widgets/client_create_dialog.dart';

/// A [ClientPickerField] whose "Create «x»" opens the New Client dialog — the
/// Client field for every form that isn't a billing document (those add an
/// invitation re-seed of their own in `BillingDocClientPicker`).
///
/// `ClientPickerField` itself stays in `core/` and can't import the dialog, so
/// this is the one place the two meet; the `create_client` gate lives inside
/// the field.
class ClientPickerFieldWithCreate extends StatelessWidget {
  const ClientPickerFieldWithCreate({
    super.key,
    required this.companyId,
    required this.selectedClientId,
    required this.onSelected,
    this.label,
    this.errorText,
    this.enabled = true,
  });

  final String companyId;
  final String selectedClientId;
  final ValueChanged<Client?> onSelected;
  final String? label;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ClientPickerField(
      companyId: companyId,
      selectedClientId: selectedClientId,
      onSelected: onSelected,
      label: label,
      errorText: errorText,
      enabled: enabled,
      onCreateRequested: (ctx, initialName) => showClientCreateDialog(
        ctx,
        companyId: companyId,
        initialName: initialName,
      ),
    );
  }
}
