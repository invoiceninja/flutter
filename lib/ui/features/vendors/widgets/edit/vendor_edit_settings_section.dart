import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/labeled_switch_group.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_edit_view_model.dart';
import 'package:admin/ui/features/vendors/widgets/edit/vendor_edit_field_pair.dart';

/// "Settings" card on the vendor edit screen — currency / language /
/// classification / routing id / tax-exempt. Mirror of
/// `ClientEditSettingsSection` minus the client-only fields (payment terms,
/// task rate, industry, size, valid-VAT). Unlike clients, a vendor's
/// `currency_id` / `language_id` / `classification` live top-level, not under
/// a `settings` cascade — see `VendorApi`. The pickers are type-to-search
/// because the currency / language lists run past ~20 entries (Forms rule).
class VendorEditSettingsSection extends StatelessWidget {
  const VendorEditSettingsSection({super.key, required this.vm});

  final VendorEditViewModel vm;

  /// Server `classification` enum (React parity). Labels resolve via `tr`.
  static const List<String> _classifications = [
    'individual',
    'business',
    'company',
    'partnership',
    'trust',
    'charity',
    'government',
    'other',
  ];

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    final statics = context.read<Services>().statics;

    List<T> sorted<T>(Iterable<T> items, String Function(T) name) =>
        items.toList()..sort(
          (a, b) => name(a).toLowerCase().compareTo(name(b).toLowerCase()),
        );

    final currencies = sorted<Currency>(
      statics.currencies.values,
      (c) => c.name,
    );
    final languages = sorted<Language>(statics.languages.values, (l) => l.name);

    return DashboardCardShell(
      title: context.tr('settings'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          VendorEditFieldPair(
            left: SearchableDropdownField<Currency>(
              label: context.tr('currency'),
              items: currencies,
              initialValue: statics.currency(draft.currencyId),
              displayString: (c) => c.name,
              idOf: (c) => c.id,
              onChanged: (c) => vm.setCurrencyId(c?.id ?? ''),
            ),
            right: SearchableDropdownField<Language>(
              label: context.tr('language'),
              items: languages,
              initialValue: statics.language(draft.languageId),
              displayString: (l) => l.name,
              idOf: (l) => l.id,
              onChanged: (l) => vm.setLanguageId(l?.id ?? ''),
            ),
          ),
          VendorEditFieldPair(
            left: SearchableDropdownField<String>(
              label: context.tr('classification'),
              items: _classifications,
              initialValue: draft.classification.isEmpty
                  ? null
                  : draft.classification,
              displayString: (v) => context.tr(v),
              idOf: (v) => v,
              onChanged: (v) => vm.setClassification(v ?? ''),
            ),
            right: EntityEditField(
              label: context.tr('routing_id'),
              initial: draft.routingId,
              onChanged: vm.setRoutingId,
              autocorrect: false,
            ),
          ),
          SizedBox(height: InSpacing.sm),
          LabeledSwitchGroup(
            items: [
              LabeledSwitchItem(
                label: context.tr('tax_exempt'),
                value: draft.isTaxExempt,
                onChanged: vm.setIsTaxExempt,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
