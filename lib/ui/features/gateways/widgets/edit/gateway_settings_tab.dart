import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/gateway.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/gateways/view_models/company_gateway_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Settings tab: label, token billing, per-payment-type toggles, card
/// bitmask. Rendered on both create and edit flows once a gateway type is
/// selected.
class GatewaySettingsTab extends StatelessWidget {
  const GatewaySettingsTab({
    super.key,
    required this.vm,
    required this.gateway,
  });

  final CompanyGatewayEditViewModel vm;
  final Gateway gateway;

  @override
  Widget build(BuildContext context) {
    final statics = context.read<Services>().statics;
    final draft = vm.draft;
    final showTokenBilling = gateway.options.values.any(
      (o) => o.supportTokenBilling,
    );

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('identity_and_flow'),
          children: [
            TextFormField(
              initialValue: draft.label,
              decoration: InputDecoration(
                labelText: context.tr('label'),
                errorText: vm.fieldErrorFor('label'),
              ),
              onChanged: (v) => vm.mutate((g) => g.copyWith(label: v)),
            ),
            SwitchListTile(
              title: Text(context.tr('test_mode')),
              value: draft.testMode,
              onChanged: (v) => vm.mutate((g) => g.copyWith(testMode: v)),
              contentPadding: EdgeInsets.zero,
            ),
            if (showTokenBilling)
              DropdownButtonFormField<String>(
                // Guard the seed value: a stray `token_billing` outside the
                // four options would trip Flutter's "exactly one item"
                // assertion. Mirrors the config-form dropdown's guard.
                initialValue: kAutoBillOptions.contains(draft.tokenBilling)
                    ? draft.tokenBilling
                    : kAutoBillOff,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('token_billing'),
                  errorText: vm.fieldErrorFor('token_billing'),
                ),
                items: [
                  for (final opt in kAutoBillOptions)
                    DropdownMenuItem(value: opt, child: Text(context.tr(opt))),
                ],
                onChanged: (v) {
                  if (v != null) vm.mutate((g) => g.copyWith(tokenBilling: v));
                },
              ),
          ],
        ),
        if (gateway.options.isNotEmpty)
          FormSection(
            title: context.tr('payment_methods'),
            children: [
              for (final typeId in gateway.options.keys)
                SwitchListTile(
                  title: Text(_typeLabel(context, statics, typeId)),
                  // Card present is taken with the mobile app, never in the
                  // client portal (docs/in-person-payments.md).
                  subtitle: typeId == '32'
                      ? Text(context.tr('card_present_help'))
                      : null,
                  value: draft.feesAndLimits[typeId]?.isEnabled ?? false,
                  onChanged: (v) => vm.setTypeEnabled(typeId, v),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
      ],
    );
  }

  /// Localized name for a gateway type id. `GatewayType.name` is the
  /// localization key (`credit_card`, `bank_transfer`, …) defined in
  /// [kGatewayTypeLabelKey]; fall back to a raw "type N" if the server
  /// references an id we haven't cataloged yet.
  String _typeLabel(
    BuildContext context,
    StaticsRepository statics,
    String typeId,
  ) {
    final type = statics.gatewayType(typeId);
    if (type == null) return 'type $typeId';
    return context.tr(type.name);
  }
}
