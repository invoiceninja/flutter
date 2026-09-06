import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/features/clients/widgets/edit/client_edit_country_field.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/clients/widgets/edit/client_edit_field_pair.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// "Address" card on the client edit screen. Fields pair on wide widths and
/// stack on narrow.
class ClientEditAddressSection extends StatelessWidget {
  const ClientEditAddressSection({super.key, required this.vm});

  final ClientEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    return DashboardCardShell(
      title: context.tr('address'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          EntityEditField(
            label: context.tr('address1'),
            initial: draft.address1,
            onChanged: vm.setAddress1,
            textCapitalization: TextCapitalization.words,
          ),
          EntityEditField(
            label: context.tr('address2'),
            initial: draft.address2,
            onChanged: vm.setAddress2,
            textCapitalization: TextCapitalization.words,
          ),
          ClientEditFieldPair(
            left: EntityEditField(
              label: context.tr('city'),
              initial: draft.city,
              onChanged: vm.setCity,
              textCapitalization: TextCapitalization.words,
            ),
            right: EntityEditField(
              label: context.tr('state'),
              initial: draft.state,
              onChanged: vm.setState,
            ),
          ),
          ClientEditFieldPair(
            left: EntityEditField(
              label: context.tr('postal_code'),
              initial: draft.postalCode,
              onChanged: vm.setPostalCode,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
            ),
            right: ClientEditCountryField(
              initial: draft.countryId,
              onChanged: vm.setCountryId,
            ),
          ),
        ],
      ),
    );
  }
}
