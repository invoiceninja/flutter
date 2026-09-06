import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/features/clients/widgets/edit/client_edit_country_field.dart';
import 'package:admin/ui/features/clients/widgets/edit/client_edit_field_pair.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// "Shipping Address" card on the client edit screen — mirrors the billing
/// [ClientEditAddressSection], with a "Copy Billing" affordance in the card
/// header that fills the shipping fields from the billing address (React
/// parity). Fields pair on wide widths and stack on narrow.
class ClientEditShippingAddressSection extends StatelessWidget {
  const ClientEditShippingAddressSection({super.key, required this.vm});

  final ClientEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    return DashboardCardShell(
      title: context.tr('shipping_address'),
      trailing: TextButton.icon(
        onPressed: vm.copyBillingToShipping,
        icon: const Icon(Icons.copy_all_outlined, size: 18),
        label: Text(context.tr('copy_billing')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          EntityEditField(
            label: context.tr('address1'),
            initial: draft.shippingAddress1,
            onChanged: vm.setShippingAddress1,
            textCapitalization: TextCapitalization.words,
          ),
          EntityEditField(
            label: context.tr('address2'),
            initial: draft.shippingAddress2,
            onChanged: vm.setShippingAddress2,
            textCapitalization: TextCapitalization.words,
          ),
          ClientEditFieldPair(
            left: EntityEditField(
              label: context.tr('city'),
              initial: draft.shippingCity,
              onChanged: vm.setShippingCity,
              textCapitalization: TextCapitalization.words,
            ),
            right: EntityEditField(
              label: context.tr('state'),
              initial: draft.shippingState,
              onChanged: vm.setShippingState,
            ),
          ),
          ClientEditFieldPair(
            left: EntityEditField(
              label: context.tr('postal_code'),
              initial: draft.shippingPostalCode,
              onChanged: vm.setShippingPostalCode,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
            ),
            right: ClientEditCountryField(
              initial: draft.shippingCountryId,
              onChanged: vm.setShippingCountryId,
            ),
          ),
        ],
      ),
    );
  }
}
