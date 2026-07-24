import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/features/clients/widgets/edit/client_edit_field_pair.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// "Details" card on the client edit screen — name + identifiers + any
/// custom-value fields the company has configured labels for.
///
/// Custom fields are NOT rendered when the company hasn't configured a
/// label for that slot (`company.customFields['client$i']` empty/missing)
/// — the [EntityCustomFieldsSection] short-circuits to `SizedBox.shrink()`.
/// There's no `Show custom fields` toggle: configured slots appear inline,
/// unconfigured ones are invisible. Matches the v2 design intent of a
/// clean form with zero noise when nothing's configured.
class ClientEditDetailsSection extends StatelessWidget {
  const ClientEditDetailsSection({super.key, required this.vm});

  final ClientEditViewModel vm;

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
          ClientEditFieldPair(
            left: EntityEditField(
              label: context.tr('name'),
              initial: draft.name,
              onChanged: vm.setName,
              autofocus: vm.isCreate,
              errorText: vm.fieldErrorFor('name'),
            ),
            right: EntityEditField(
              label: context.tr('number'),
              initial: draft.number,
              onChanged: vm.setNumber,
              errorText: vm.fieldErrorFor('number'),
            ),
          ),
          ClientEditFieldPair(
            left: EntityEditField(
              label: context.tr('id_number'),
              initial: draft.idNumber,
              onChanged: vm.setIdNumber,
              errorText: vm.fieldErrorFor('id_number'),
            ),
            right: EntityEditField(
              label: context.tr('vat_number'),
              initial: draft.vatNumber,
              onChanged: vm.setVatNumber,
              errorText: vm.fieldErrorFor('vat_number'),
            ),
          ),
          ClientEditFieldPair(
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
            keyPrefix: 'client',
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
            entityType: 'client',
            selectedIds: draft.tagIds,
            onChanged: vm.setTagIds,
          ),
        ],
      ),
    );
  }
}
