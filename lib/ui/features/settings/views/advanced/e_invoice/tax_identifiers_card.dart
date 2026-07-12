import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/tax_config_api_model.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Settings → E-Invoice — Additional Tax Identifiers card. Company-scope
/// only. Lists per-country VAT identifiers already configured under
/// `company.taxData.regions[*].subregions[*].vatNumber`; lets the user
/// add new entries (country dropdown + VAT text field) or remove
/// existing ones.
///
/// The add/remove operations fire their own outbox rows
/// (`peppolAddTaxIdentifier` / `peppolRemoveTaxIdentifier`); the page
/// Save button isn't involved. Server-applied response refreshes the
/// list automatically via the company watch stream.
class TaxIdentifiersCard extends StatelessWidget {
  const TaxIdentifiersCard({super.key});

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final company = host.draft;
    if (company == null) return const SizedBox.shrink();

    final entries = _collectEntries(company.taxData?.regions);

    return FormSection(
      title: context.tr('additional_tax_identifiers'),
      trailing: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
        icon: const Icon(Icons.add),
        label: Text(context.tr('add')),
        onPressed: () => _openAddDialog(context),
      ),
      children: [
        if (entries.isEmpty)
          EmptyState(
            icon: Icons.flag_outlined,
            title: context.tr('additional_tax_identifiers'),
            subtitle: context.tr('additional_tax_identifiers_help'),
          )
        else
          for (final entry in entries) _IdentifierRow(entry: entry),
      ],
    );
  }

  /// Walk the nested `regions → subregions` map and pull out every entry
  /// with a non-empty VAT number. Returns the (subregionKey, vatNumber)
  /// tuples in iteration order — admin-portal does the same.
  List<_IdentifierEntry> _collectEntries(Map<String, TaxRegionApi>? regions) {
    if (regions == null || regions.isEmpty) return const <_IdentifierEntry>[];
    final out = <_IdentifierEntry>[];
    for (final region in regions.values) {
      for (final entry in region.subregions.entries) {
        if (entry.value.vatNumber.isEmpty) continue;
        out.add(
          _IdentifierEntry(
            subregionKey: entry.key,
            vatNumber: entry.value.vatNumber,
          ),
        );
      }
    }
    return out;
  }

  Future<void> _openAddDialog(BuildContext context) async {
    final services = context.read<Services>();
    final host = context.read<SettingsDraftHost>();
    final companyId = host.draft?.id;
    if (companyId == null) return;

    final ownCountryId = host.settings.countryId;
    final countries =
        services.statics.countries.values
            .where(
              (c) => kPeppolCountries.contains(c.id) && c.id != ownCountryId,
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    final result = await showDialog<({String country, String vatNumber})>(
      context: context,
      builder: (ctx) => _AddIdentifierDialog(countries: countries),
    );
    if (result == null) return;

    try {
      await services.company.enqueuePeppolAddTaxIdentifier(
        companyId: companyId,
        country: result.country,
        vatNumber: result.vatNumber,
      );
      if (!context.mounted) return;
      Notify.success(context, context.tr('saved'));
    } catch (e) {
      if (!context.mounted) return;
      Notify.error(context, context.tr('could_not_save'), error: e);
    }
  }
}

class _IdentifierEntry {
  const _IdentifierEntry({required this.subregionKey, required this.vatNumber});

  /// ISO2 of the subregion the identifier is keyed under (e.g. `'AT'`).
  final String subregionKey;
  final String vatNumber;
}

class _IdentifierRow extends StatelessWidget {
  const _IdentifierRow({required this.entry});

  final _IdentifierEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              entry.subregionKey,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              entry.vatNumber,
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: context.tr('remove'),
            onPressed: () => _confirmRemove(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final services = context.read<Services>();
    final host = context.read<SettingsDraftHost>();
    final companyId = host.draft?.id;
    if (companyId == null) return;

    final removed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete_identifier')),
        content: Text(context.tr('delete_identifier_description')),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            variant: DialogActionVariant.destructive,
            label: context.tr('remove'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (removed != true) return;
    if (!context.mounted) return;

    // The server stores by country id, but the local typed model stores
    // by subregion (iso2). The server resolves either; we send the iso2
    // here to match admin-portal's outbound payload.
    try {
      await services.company.enqueuePeppolRemoveTaxIdentifier(
        companyId: companyId,
        country: entry.subregionKey,
        vatNumber: entry.vatNumber,
      );
      if (!context.mounted) return;
      Notify.success(context, context.tr('removed'));
    } catch (e) {
      if (!context.mounted) return;
      Notify.error(context, context.tr('could_not_save'), error: e);
    }
  }
}

class _AddIdentifierDialog extends StatefulWidget {
  const _AddIdentifierDialog({required this.countries});

  final List<Country> countries;

  @override
  State<_AddIdentifierDialog> createState() => _AddIdentifierDialogState();
}

class _AddIdentifierDialogState extends State<_AddIdentifierDialog> {
  Country? _country;
  final TextEditingController _vatController = TextEditingController();

  @override
  void dispose() {
    _vatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _country != null && _vatController.text.trim().isNotEmpty;
    return AlertDialog(
      title: Text(context.tr('new_identifier')),
      content: FormSaveScope(
        enabled: canSave,
        onSubmit: () => _submit(context),
        child: SizedBox(
          // Cap at 420 on desktop, but shrink to fit narrow phones — the
          // AlertDialog inset + content padding eat ~128px, so a fixed 420
          // overflows below ~360px wide.
          width: math.min(420.0, MediaQuery.sizeOf(context).width - 128),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SearchableDropdownField<Country>(
                label: context.tr('country'),
                items: widget.countries,
                initialValue: _country,
                displayString: (c) => c.name,
                idOf: (c) => c.id,
                onChanged: (c) => setState(() => _country = c),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (ctx) {
                  final scope = FormSaveScope.maybeOf(ctx);
                  return TextField(
                    controller: _vatController,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: context.tr('vat_number'),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: scope == null
                        ? null
                        : (_) => scope.trySubmit(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('save'),
          enabled: canSave,
          autofocus: false,
          onPressed: () => _submit(context),
        ),
      ],
    );
  }

  void _submit(BuildContext context) {
    if (_country == null) return;
    final vat = _vatController.text.trim();
    if (vat.isEmpty) return;
    Navigator.of(context).pop((country: _country!.id, vatNumber: vat));
  }
}
