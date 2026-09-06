import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/view_models/company_details_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_text_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Searchable label keys rendered by this tab. See
/// `kCompanyDetailsDetailsSearchKeys` for the colocation pattern.
const kCompanyDetailsAddressSearchKeys = <String>[
  'address1',
  'address2',
  'city',
  'state',
  'postal_code',
  'country',
];

/// "Address" tab — every field on the company's mailing address. All are
/// settings keys, so all support the override-checkbox flow.
class CompanyDetailsAddressScreen extends StatelessWidget {
  const CompanyDetailsAddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('address'),
          children: [
            OverridableTextField(
              label: context.tr('address1'),
              apiKey: 'address1',
              textCapitalization: TextCapitalization.words,
              // The signed-in user's own record, so OS autofill is correct here.
              // A client / vendor / contact field must NEVER carry hints — the
              // platform would offer the admin's own details for someone else.
              autofillHints: const [AutofillHints.streetAddressLine1],
            ),
            OverridableTextField(
              label: context.tr('address2'),
              apiKey: 'address2',
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.streetAddressLine2],
            ),
            OverridableTextField(
              label: context.tr('city'),
              apiKey: 'city',
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.addressCity],
            ),
            OverridableTextField(
              label: context.tr('state'),
              apiKey: 'state',
              autofillHints: const [AutofillHints.addressState],
            ),
            OverridableTextField(
              label: context.tr('postal_code'),
              apiKey: 'postal_code',
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              autofillHints: const [AutofillHints.postalCode],
            ),
            _CountryField(),
          ],
        ),
      ],
    );
  }
}

class _CountryField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyDetailsViewModel>();
    final statics = context.read<Services>().statics;
    final countries = statics.countries.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return OverridableSearchableDropdownField<Country>(
      label: context.tr('country'),
      apiKey: 'country_id',
      value: vm.settings.countryId,
      items: countries,
      displayString: (c) => c.name,
      idOf: (c) => c.id,
      onChanged: (id) =>
          vm.updateSettings((s) => s.copyWith(countryId: id ?? '')),
    );
  }
}
