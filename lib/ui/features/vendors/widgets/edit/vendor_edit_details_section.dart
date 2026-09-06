import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_edit_view_model.dart';
import 'package:admin/ui/features/vendors/widgets/edit/vendor_edit_field_pair.dart';

/// "Details" card on the vendor edit screen — name + identifiers + custom
/// fields the company has configured under the `vendor1..4` slots.
/// Mirror of `ClientEditDetailsSection`.
class VendorEditDetailsSection extends StatelessWidget {
  const VendorEditDetailsSection({super.key, required this.vm});

  final VendorEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    final services = context.read<Services>();
    return DashboardCardShell(
      title: context.tr('details'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          VendorEditFieldPair(
            left: EntityEditField(
              label: context.tr('name'),
              initial: draft.name,
              onChanged: vm.setName,
              autofocus: vm.isCreate,
              errorText: vm.fieldErrorFor('name'),
              textCapitalization: TextCapitalization.words,
            ),
            right: EntityEditField(
              label: context.tr('number'),
              initial: draft.number,
              onChanged: vm.setNumber,
              errorText: vm.fieldErrorFor('number'),
              autocorrect: false,
            ),
          ),
          VendorEditFieldPair(
            left: EntityEditField(
              label: context.tr('id_number'),
              initial: draft.idNumber,
              onChanged: vm.setIdNumber,
              errorText: vm.fieldErrorFor('id_number'),
              autocorrect: false,
            ),
            right: EntityEditField(
              label: context.tr('vat_number'),
              initial: draft.vatNumber,
              onChanged: vm.setVatNumber,
              errorText: vm.fieldErrorFor('vat_number'),
              autocorrect: false,
            ),
          ),
          VendorEditFieldPair(
            left: EntityEditField(
              label: context.tr('website'),
              initial: draft.website,
              onChanged: vm.setWebsite,
              keyboardType: TextInputType.url,
              errorText: vm.fieldErrorFor('website'),
            ),
            right: EntityEditField(
              label: context.tr('phone'),
              initial: draft.phone,
              onChanged: vm.setPhone,
              keyboardType: TextInputType.phone,
              errorText: vm.fieldErrorFor('phone'),
            ),
          ),
          EntityCustomFieldsSection(
            keyPrefix: 'vendor',
            companyStream: services.company.watchCompany(vm.companyId),
            formatter: services.formatterIfReady(vm.companyId),
            values: [
              draft.customValue1,
              draft.customValue2,
              draft.customValue3,
              draft.customValue4,
            ],
            onChanged: [
              vm.setCustomValue1,
              vm.setCustomValue2,
              vm.setCustomValue3,
              vm.setCustomValue4,
            ],
          ),
          SizedBox(height: InSpacing.md(context)),
          EntityTagsField(
            entityType: 'vendor',
            selectedIds: draft.tagIds,
            onChanged: vm.setTagIds,
          ),
        ],
      ),
    );
  }
}
