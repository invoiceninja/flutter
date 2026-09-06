import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/data/models/value/industry.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/view_models/company_details_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_text_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Searchable label keys rendered by this tab. Aggregated into
/// `kSettingsSearchCatalog['company_details']` so the in-app search surfaces
/// these fields. Keep in sync when you add or remove a field below — the
/// `search_catalog_consistency_test` verifies every key here appears as a
/// `context.tr('…')` or `apiKey: '…'` reference in this file.
const kCompanyDetailsDetailsSearchKeys = <String>[
  'name',
  'id_number',
  'vat_number',
  'qr_iban',
  'besr_id',
  'website',
  'email',
  'phone',
  'classification',
  'size',
  'industry',
];

/// "Details" tab of the Company Details settings page. Holds the identity +
/// brand fields that live on `company.settings.*` (name, id_number, etc.)
/// plus the two truly-company-level fields (`size_id`, `industry_id`) that
/// don't pass through the cascade.
///
/// The shell ([CompanyDetailsShell]) owns the AppBar + Save button; this
/// widget is just the form body. Fields are grouped under section headings
/// (Identification / Contact / Business / Custom Fields) so the long form
/// stays scannable.
class CompanyDetailsScreen extends StatelessWidget {
  const CompanyDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyDetailsViewModel>();
    // The shell's spinner gates rendering until the draft is non-null, so
    // `vm.draft` is safe to dereference here.
    final draft = vm.draft!;
    // Legal entity id != 0 means an Invoice Ninja legal entity is bound
    // server-side and the id_number / vat_number are managed there.
    final legalEntityBound = draft.legalEntityId != 0;
    final isSwiss = draft.settings.countryId == '756';

    final services = context.read<Services>();
    // The custom-field VALUE inputs render by the company's configured type
    // (text / multi-line / switch / date / dropdown) via the shared
    // EntityCustomFieldsSection — the same type-aware widget every entity edit
    // screen and User Details use. Gate the section on at least one configured
    // slot so an empty "Custom Fields" card never shows for companies without
    // any (the inner widget self-collapses, but we suppress the outer card).
    final hasCompanyCustomFields = [1, 2, 3, 4].any(
      (i) => parseCustomField(draft.customFields['company$i']).label.isNotEmpty,
    );

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('identification'),
          children: [
            OverridableTextField(
              label: context.tr('name'),
              apiKey: 'name',
              textCapitalization: TextCapitalization.words,
              // The signed-in user's own record, so OS autofill is correct here.
              // A client / vendor / contact field must NEVER carry hints — the
              // platform would offer the admin's own details for someone else.
              autofillHints: const [AutofillHints.organizationName],
            ),
            OverridableTextField(
              label: context.tr('id_number'),
              apiKey: 'id_number',
              enabled: !legalEntityBound,
              autocorrect: false,
            ),
            OverridableTextField(
              label: context.tr('vat_number'),
              apiKey: 'vat_number',
              enabled: !legalEntityBound,
              autocorrect: false,
              // When a legal entity is bound (PEPPOL), the server manages
              // VAT / ID number — explain why the fields are disabled. Mirrors
              // React's note under VAT (Details.tsx).
              helperText: legalEntityBound
                  ? context.tr('changing_vat_and_id_number_note')
                  : null,
            ),
            _ClassificationField(),
            if (isSwiss) ...[
              OverridableTextField(
                label: context.tr('qr_iban'),
                apiKey: 'qr_iban',
                autocorrect: false,
              ),
              OverridableTextField(
                label: context.tr('besr_id'),
                apiKey: 'besr_id',
                autocorrect: false,
              ),
            ],
          ],
        ),
        FormSection(
          title: context.tr('contact'),
          children: [
            OverridableTextField(
              label: context.tr('website'),
              apiKey: 'website',
              keyboardType: TextInputType.url,
              autocorrect: false,
            ),
            OverridableTextField(
              label: context.tr('email'),
              apiKey: 'email',
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
            ),
            OverridableTextField(
              label: context.tr('phone'),
              apiKey: 'phone',
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
          ],
        ),
        // size_id and industry_id are truly company-level — they don't pass
        // through the settings cascade, so no PropertyCheckbox wrapper.
        FormSection(
          title: context.tr('business'),
          children: [_SizeField(), _IndustryField()],
        ),
        if (hasCompanyCustomFields)
          FormSection(
            title: context.tr('custom_fields'),
            children: [
              EntityCustomFieldsSection(
                keyPrefix: 'company',
                companyStream: services.company.watchCompany(vm.companyId),
                formatter: services.formatterIfReady(vm.companyId),
                wrapInCard: false,
                values: [
                  vm.settings.customValue1 ?? '',
                  vm.settings.customValue2 ?? '',
                  vm.settings.customValue3 ?? '',
                  vm.settings.customValue4 ?? '',
                ],
                onChanged: [
                  (v) => vm.updateSettings((s) => s.copyWith(customValue1: v)),
                  (v) => vm.updateSettings((s) => s.copyWith(customValue2: v)),
                  (v) => vm.updateSettings((s) => s.copyWith(customValue3: v)),
                  (v) => vm.updateSettings((s) => s.copyWith(customValue4: v)),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class _ClassificationField extends StatelessWidget {
  static const _options = [
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
    final vm = context.watch<CompanyDetailsViewModel>();
    final current = vm.settings.classification;
    return DropdownButtonFormField<String>(
      // `initialValue` only seeds the FormField once; re-key on the current
      // value so an external draft change (background refresh / company switch)
      // re-seeds the field instead of showing the stale first-seeded value.
      key: ValueKey('classification:$current'),
      decoration: InputDecoration(labelText: context.tr('classification')),
      initialValue: _options.contains(current) ? current : null,
      items: [
        for (final v in _options)
          DropdownMenuItem(value: v, child: Text(context.tr(v))),
      ],
      onChanged: (v) =>
          vm.updateSettings((s) => s.copyWith(classification: v ?? '')),
    );
  }
}

class _SizeField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyDetailsViewModel>();
    final statics = context.read<Services>().statics;
    // Size bands are short numeric ranges ("1 - 3", "4 - 10", …) — sort by
    // numeric id so they render in the natural small→large order.
    final sizes = statics.sizes.values.toList()
      ..sort((a, b) => (int.tryParse(a.id) ?? 0) - (int.tryParse(b.id) ?? 0));
    final current = vm.draft?.sizeId ?? '';
    return DropdownButtonFormField<String>(
      // See `_ClassificationField` — re-key so an external draft change
      // re-seeds the once-only `initialValue`.
      key: ValueKey('size:$current'),
      decoration: InputDecoration(labelText: context.tr('size')),
      initialValue: sizes.any((s) => s.id == current) ? current : null,
      disabledHint: sizes.isEmpty ? Text(context.tr('loading')) : null,
      items: [
        for (final s in sizes)
          DropdownMenuItem(value: s.id, child: Text(s.name)),
      ],
      onChanged: (v) => vm.updateCompany((c) => c.copyWith(sizeId: v ?? '')),
    );
  }
}

class _IndustryField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyDetailsViewModel>();
    final statics = context.read<Services>().statics;
    final industries = statics.industries.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final current = industries
        .where((i) => i.id == (vm.draft?.industryId ?? ''))
        .firstOrNull;
    return SearchableDropdownField<Industry>(
      label: context.tr('industry'),
      items: industries,
      initialValue: current,
      displayString: (i) => i.name,
      idOf: (i) => i.id,
      onChanged: (i) =>
          vm.updateCompany((c) => c.copyWith(industryId: i?.id ?? '')),
    );
  }
}
