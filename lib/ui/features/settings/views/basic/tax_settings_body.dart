import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/mdi_icons.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/tax_config_api_model.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/subregion_edit_dialog.dart';
import 'package:admin/ui/features/settings/widgets/tax_rate_picker.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/tax_regions.dart';

/// Field labels exposed by the in-app settings search for the Tax Settings
/// page. Keep in sync with `kSettingsSearchCatalog['tax_settings']` —
/// `search_catalog_consistency_test` asserts every entry is actually
/// rendered.
const kTaxSettingsSearchKeys = <String>[
  'invoice_tax_rates',
  'invoice_item_tax_rates',
  'expense_tax_rates',
  'inclusive_taxes',
  'tax_name',
  'tax_rate',
  'calculate_taxes',
  'seller_subregion',
  'reduced_rate',
];

/// Body for Settings → Tax Settings. Mounted by [TaxSettingsScreen] inside
/// [CascadeSettingsScaffold] — the scaffold owns the cascade VM and provides
/// it via Provider.
///
/// Layout (mirroring React, with one UX divergence — see Section C):
///   * Section A — Tax Settings: three rate-count dropdowns + inclusive
///     toggle. Tax-rate-count + inclusive hide when Calculate Taxes is on.
///   * Section B — Default Tax Rates: picker rows for slots `1..enabledTaxRates`.
///     Visible when `enabledTaxRates >= 1`.
///   * Section B′ — Default Item Tax Rates: same picker shape, visible
///     when `enabledItemTaxRates >= 1 && enabledTaxRates == 0` (matches
///     React's `DefaultLineItemTaxes`).
///   * Section C — Calculate Taxes: a toggle + (when on) the regional
///     editor (seller subregion + per-region accordions).
class TaxSettingsBody extends StatelessWidget {
  const TaxSettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final scope = context.watch<SettingsLevelController>();
    final isCompany = scope.isCompany;
    // `draft` is the Company at company scope and null at client scope, where
    // the company-only sections (rate counts, Calculate Taxes) don't render.
    // `companyContext` carries the company-level fields the cascade sections
    // (default-rate pickers, decimal separator) still need at client scope —
    // see `SettingsDraftHost.companyContext`.
    final company = host.draft;
    final ctx = host.companyContext;
    final calculateTaxes = ctx?.calculateTaxes ?? false;
    final useComma = ctx?.useCommaAsDecimalPlace ?? false;
    final invoiceTaxRates = ctx?.enabledTaxRates ?? 0;
    final itemTaxRates = ctx?.enabledItemTaxRates ?? 0;
    final session = context.read<Services>().auth.session.value;

    return SettingsFormShell(
      sections: [
        // ── Section A — basic toggles ────────────────────────────────────
        FormSection(
          title: context.tr('tax_settings'),
          children: [
            // Tax-rate-count dropdowns are top-level company.* fields, not
            // settings — they have no cascade override at client/group
            // scope, so we hide them entirely outside company scope (where
            // `company`/`host.draft` is non-null).
            if (isCompany && company != null && !calculateTaxes)
              _RateCountDropdown(
                label: context.tr('invoice_tax_rates'),
                value: company.enabledTaxRates,
                onChanged: (v) =>
                    host.updateCompany((c) => c.copyWith(enabledTaxRates: v)),
              ),
            if (isCompany && company != null)
              _RateCountDropdown(
                label: context.tr('invoice_item_tax_rates'),
                value: company.enabledItemTaxRates,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(enabledItemTaxRates: v),
                ),
              ),
            if (isCompany && company != null)
              _RateCountDropdown(
                label: context.tr('expense_tax_rates'),
                value: company.enabledExpenseTaxRates,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(enabledExpenseTaxRates: v),
                ),
              ),
            if (!calculateTaxes)
              OverridableSwitchField(
                label: context.tr('inclusive_taxes'),
                apiKey: 'inclusive_taxes',
                subtitle: context.tr('exclusive_inclusive_tax_help'),
              ),
          ],
        ),

        // ── Section B — Default Tax Rates ────────────────────────────────
        // Slot count is the company's `enabled_tax_rates`, read via
        // `companyContext` so the per-client/group override rows still render
        // at client scope (where there's no `draft`). (`enabledTaxRates` is
        // forced to 0 when Calculate Taxes is on, so this self-hides then.)
        if (invoiceTaxRates >= 1)
          FormSection(
            title: context.tr('default_tax_rate'),
            children: [
              for (var slot = 1; slot <= invoiceTaxRates; slot++)
                TaxRatePicker(slot: slot, label: _slotLabel(context, slot)),
            ],
          ),

        // ── Section B′ — Default Item Tax Rates ─────────────────────────
        // Mirrors React `DefaultLineItemTaxes` (shown when
        // `enabled_item_tax_rates > 0 && !enabled_tax_rates`) — which stays
        // visible when Calculate Taxes is on (it sets item rates to 1), so we
        // deliberately do NOT gate this on `!calculateTaxes`.
        if (invoiceTaxRates == 0 && itemTaxRates >= 1)
          FormSection(
            title: context.tr('default_tax_rate'),
            children: [
              for (var slot = 1; slot <= itemTaxRates; slot++)
                TaxRatePicker(slot: slot, label: _slotLabel(context, slot)),
            ],
          ),

        // ── Section C — Calculate Taxes ─────────────────────────────────
        // Top-level company.* field; hidden outside company scope (no
        // cascade override semantics). Gated by country: the React app only
        // exposes the toggle for the 33 ISO codes in
        // `kCalculateTaxesSupportedCountries` (US, AU, EU/EEA). If the
        // active company's country isn't in that set we hide the section
        // entirely so the user isn't tempted to enable something the
        // server can't honor.
        //
        // `tax_data.*` server validation errors render inline: the seller
        // subregion field reads `host.fieldErrors['tax_data.seller_subregion']`,
        // and each subregion row filters `host.fieldErrors` by the
        // `tax_data.regions.<R>.subregions.<S>.` prefix to render an
        // indicator + re-open the dialog with `errorText` populated.
        // Plan-gated to match React (`isPaidOrSelfHost`) and the legacy app
        // (`isProPlan`): the toggle only shows for self-hosted or paid/trial
        // hosted accounts. `isFreePlan` is the trial-aware predicate
        // (`isHosted && !hasProAccess`). The `|| calculateTaxes` escape keeps
        // an already-enabled config visible/editable after a downgrade.
        if (isCompany &&
            company != null &&
            !(session?.isFreePlan ?? false) &&
            (_calculateTaxesAvailableFor(host.settings.countryId) ||
                calculateTaxes))
          FormSection(
            title: context.tr('calculate_taxes'),
            children: [
              _CalculateTaxesToggle(host: host),
              if (calculateTaxes) ...[
                SizedBox(height: InSpacing.md(context)),
                _CalculateTaxesRegional(host: host, useComma: useComma),
              ],
            ],
          ),
        FormSection(
          title: context.tr('tax_rates'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 44),
                ),
                onPressed: () => context.go('/settings/tax_rates'),
                icon: const Icon(Icons.percent_outlined, size: 16),
                label: Text(context.tr('configure_tax_rates')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// React parity gate: `useCalculateTaxesRegion()` checks whether the
  /// active company's country is in the supported list before exposing the
  /// Calculate Taxes toggle. The set is built from US + AU + EU/EEA ISO
  /// codes; see `lib/utils/tax_regions.dart`.
  bool _calculateTaxesAvailableFor(String? countryId) {
    if (countryId == null || countryId.isEmpty) return false;
    final iso = kCountryIdToIso3166Alpha2[countryId];
    if (iso == null) return false;
    return kCalculateTaxesSupportedCountries.contains(iso);
  }

  String _slotLabel(BuildContext context, int slot) {
    // The legacy admin-portal renders "Default Tax Rate" without a slot
    // number suffix — slot ordering is positional in the column. Match.
    return context.tr('default_tax_rate');
  }
}

class _RateCountDropdown extends StatelessWidget {
  const _RateCountDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // `initialValue:` is the canonical API on Material 3 + Flutter 3.33+
    // (the old `value:` is deprecated). The `ValueKey(value)` is defense
    // in depth: when an external cascade (e.g. enabling Calculate Taxes
    // resets `enabledTaxRates → 0`) flips the underlying field, the new
    // key forces the form-field state to rebuild against the fresh
    // `initialValue`.
    return DropdownButtonFormField<int>(
      key: ValueKey('rate-count-$label-$value'),
      decoration: InputDecoration(labelText: label),
      initialValue: value,
      items: [
        DropdownMenuItem(value: 0, child: Text(context.tr('disabled'))),
        DropdownMenuItem(value: 1, child: Text(context.tr('one_tax_rate'))),
        DropdownMenuItem(value: 2, child: Text(context.tr('two_tax_rates'))),
        DropdownMenuItem(value: 3, child: Text(context.tr('three_tax_rates'))),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _CalculateTaxesToggle extends StatelessWidget {
  const _CalculateTaxesToggle({required this.host});

  final SettingsDraftHost host;

  @override
  Widget build(BuildContext context) {
    final company = host.draft!;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.tr('calculate_taxes')),
      subtitle: Text(context.tr('calculate_taxes_help')),
      value: company.calculateTaxes,
      onChanged: (v) async {
        if (v) {
          final proceed = await _confirmEnable(context);
          if (proceed != true) return;
          // React's cascade on Continue: enable item taxes, disable total +
          // expense-as-counted taxes, zero default *rates*, force exclusive.
          // Note: only the rates are zeroed — the tax *names* are left intact
          // (matches React `CalculateTaxesNotificationModal.tsx`), so toggling
          // Calculate Taxes back off restores the user's configured names.
          host.updateCompany(
            (c) => c.copyWith(
              calculateTaxes: true,
              enabledTaxRates: 0,
              enabledItemTaxRates: 1,
              enabledExpenseTaxRates: 1,
            ),
          );
          host.updateSettings(
            (s) => s.copyWith(
              inclusiveTaxes: false,
              taxRate1: 0,
              taxRate2: 0,
              taxRate3: 0,
            ),
          );
        } else {
          host.updateCompany((c) => c.copyWith(calculateTaxes: false));
        }
      },
    );
  }

  Future<bool?> _confirmEnable(BuildContext context) {
    // Cancel + Continue side-by-side; `AlertDialog.actions` uses its own
    // `OverflowBar` for inter-button spacing, so a manual `SizedBox`
    // between actions would be a no-op.
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('calculate_taxes')),
        content: Text(context.tr('calculate_taxes_warning')),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: context.tr('continue'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }
}

class _CalculateTaxesRegional extends StatelessWidget {
  const _CalculateTaxesRegional({required this.host, required this.useComma});

  final SettingsDraftHost host;
  final bool useComma;

  @override
  Widget build(BuildContext context) {
    final company = host.draft!;
    final taxData = company.taxData ?? const TaxConfigApi();
    final countryId = host.settings.countryId;
    final subregionKind = sellerSubregionForCountryId(countryId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (taxData.regions.isEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: InSpacing.md(context)),
            child: Text(
              context.tr('tax_regions_initialize_hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        _SellerSubregionRow(host: host, kind: subregionKind, taxData: taxData),
        SizedBox(height: InSpacing.md(context)),
        for (final region in kTaxRegionOrder) ...[
          _RegionCard(host: host, regionKey: region, useComma: useComma),
          SizedBox(height: InSpacing.md(context)),
        ],
      ],
    );
  }
}

/// Renders the seller-subregion field — four conditional variants keyed off
/// the active company's `country_id`. The AU and GB branches auto-write
/// their literal ISO code into `tax_data.seller_subregion` on first render
/// when it's not yet set, mirroring React `SellerSubregion.tsx:29-36`.
///
/// Stateful so the auto-write fires once from `initState` rather than from
/// `build`. `host.updateCompany` notifies unconditionally — a write inside
/// `build` would loop (write → notify → rebuild → write again).
class _SellerSubregionRow extends StatefulWidget {
  const _SellerSubregionRow({
    required this.host,
    required this.kind,
    required this.taxData,
  });

  final SettingsDraftHost host;
  final SellerSubregionKind kind;
  final TaxConfigApi taxData;

  @override
  State<_SellerSubregionRow> createState() => _SellerSubregionRowState();
}

class _SellerSubregionRowState extends State<_SellerSubregionRow> {
  @override
  void initState() {
    super.initState();
    _maybeAutoWrite();
  }

  @override
  void didUpdateWidget(_SellerSubregionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Country can change while the widget is mounted (user edits Country on
    // Company Details, then comes back). Re-evaluate the auto-write when
    // the kind transitions into AU/GB.
    if (oldWidget.kind != widget.kind) _maybeAutoWrite();
  }

  void _maybeAutoWrite() {
    final desired = switch (widget.kind) {
      SellerSubregionKind.australia => 'AU',
      SellerSubregionKind.britain => 'GB',
      SellerSubregionKind.andorra => 'AD',
      _ => null,
    };
    if (desired == null) return;
    if (widget.taxData.sellerSubregion == desired) return;
    // Defer to the next frame so we don't mutate the host while it's
    // still notifying listeners from the current build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _writeSeller(desired);
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = context.tr('seller_subregion');
    final errorText =
        widget.host.fieldErrors['tax_data.seller_subregion']?.firstOrNull;

    // AU / GB / AD are single-subregion sellers shown as a read-only field
    // pinned to a fixed ISO code. `initialValue` (not a `controller:`) avoids
    // leaking a fresh TextEditingController on every rebuild.
    final fixedCode = switch (widget.kind) {
      SellerSubregionKind.australia => 'AU',
      SellerSubregionKind.britain => 'GB',
      SellerSubregionKind.andorra => 'AD',
      _ => null,
    };
    if (fixedCode != null) {
      return TextFormField(
        key: ValueKey('seller-fixed-$fixedCode'),
        enabled: false,
        initialValue: fixedCode,
        decoration: InputDecoration(labelText: label, errorText: errorText),
      );
    }

    switch (widget.kind) {
      case SellerSubregionKind.us:
        return _IsoDropdown(
          label: label,
          value: widget.taxData.sellerSubregion,
          options: kUsStates,
          errorText: errorText,
          onChanged: (v) => _writeSeller(v ?? ''),
        );
      case SellerSubregionKind.eu:
        return _IsoDropdown(
          label: label,
          value: widget.taxData.sellerSubregion,
          options: kEuCalculateTaxesCountries,
          errorText: errorText,
          onChanged: (v) => _writeSeller(v ?? ''),
        );
      case SellerSubregionKind.none:
      case SellerSubregionKind.australia:
      case SellerSubregionKind.britain:
      case SellerSubregionKind.andorra:
        return const SizedBox.shrink();
    }
  }

  void _writeSeller(String value) {
    widget.host.updateCompany(
      (c) => c.copyWith(
        taxData: (c.taxData ?? const TaxConfigApi()).copyWith(
          sellerSubregion: value,
        ),
      ),
    );
  }
}

class _IsoDropdown extends StatelessWidget {
  const _IsoDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final entries = options.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return SearchableDropdownField<MapEntry<String, String>>(
      label: label,
      items: entries,
      initialValue: entries.cast<MapEntry<String, String>?>().firstWhere(
        (e) => e?.key == value,
        orElse: () => null,
      ),
      displayString: (e) => '${e.key} — ${e.value}',
      idOf: (e) => e.key,
      onChanged: (e) => onChanged(e?.key),
      errorText: errorText,
    );
  }
}

class _RegionCard extends StatefulWidget {
  const _RegionCard({
    required this.host,
    required this.regionKey,
    required this.useComma,
  });

  final SettingsDraftHost host;
  final String regionKey;
  final bool useComma;

  @override
  State<_RegionCard> createState() => _RegionCardState();
}

class _RegionCardState extends State<_RegionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final company = widget.host.draft!;
    final taxData = company.taxData ?? const TaxConfigApi();
    final region = taxData.regions[widget.regionKey] ?? const TaxRegionApi();
    final regionLabelKey =
        kTaxRegionLabelKeys[widget.regionKey] ?? widget.regionKey;
    final subregions = region.subregions;
    final total = subregions.length;
    final selectedCount = subregions.values.where((s) => s.applyTax).length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.inTheme.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.tr(regionLabelKey),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!region.taxAllSubregions && total > 0)
                Padding(
                  padding: EdgeInsets.only(right: InSpacing.md(context)),
                  child: Text(
                    context
                        .tr('selected_of')
                        .replaceFirst(':selected', '$selectedCount')
                        .replaceFirst(':total', '$total'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              IconButton(
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                tooltip: context.tr(_expanded ? 'hide' : 'show'),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(context.tr('apply_tax_to_all_subregions')),
            value: region.taxAllSubregions,
            onChanged: (v) =>
                _updateRegion((r) => r.copyWith(taxAllSubregions: v)),
          ),
          if (kTaxRegionsWithSalesThreshold.contains(widget.regionKey))
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(context.tr('sales_above_threshold')),
              value: region.hasSalesAboveThreshold,
              onChanged: (v) =>
                  _updateRegion((r) => r.copyWith(hasSalesAboveThreshold: v)),
            ),
          if (_expanded) ...[
            const Divider(),
            for (final entry in subregions.entries)
              _SubregionRow(
                host: widget.host,
                regionKey: widget.regionKey,
                subregionKey: entry.key,
                subregion: entry.value,
                disabled: region.taxAllSubregions,
                useComma: widget.useComma,
                onChanged: (next) => _updateSubregion(entry.key, next),
              ),
          ],
        ],
      ),
    );
  }

  void _updateRegion(TaxRegionApi Function(TaxRegionApi) edit) {
    final company = widget.host.draft!;
    final taxData = company.taxData ?? const TaxConfigApi();
    final regions = Map<String, TaxRegionApi>.from(taxData.regions);
    final base = regions[widget.regionKey] ?? const TaxRegionApi();
    regions[widget.regionKey] = edit(base);
    widget.host.updateCompany(
      (c) => c.copyWith(taxData: taxData.copyWith(regions: regions)),
    );
  }

  void _updateSubregion(String subregionKey, TaxSubregionApi next) {
    _updateRegion((r) {
      final subregions = Map<String, TaxSubregionApi>.from(r.subregions);
      subregions[subregionKey] = next;
      return r.copyWith(subregions: subregions);
    });
  }
}

class _SubregionRow extends StatelessWidget {
  const _SubregionRow({
    required this.host,
    required this.regionKey,
    required this.subregionKey,
    required this.subregion,
    required this.disabled,
    required this.useComma,
    required this.onChanged,
  });

  final SettingsDraftHost host;
  final String regionKey;
  final String subregionKey;
  final TaxSubregionApi subregion;
  final bool disabled;
  final bool useComma;
  final ValueChanged<TaxSubregionApi> onChanged;

  /// Server validation errors scoped to this subregion, with the
  /// `tax_data.regions.<regionKey>.subregions.<subregionKey>.` prefix
  /// stripped. Empty when the server hasn't flagged this subregion.
  /// The cascade VM clears all `fieldErrors` on the next `updateDraft`, so
  /// this view re-evaluates against the current map automatically.
  Map<String, List<String>> get _scopedErrors {
    final prefix = 'tax_data.regions.$regionKey.subregions.$subregionKey.';
    final out = <String, List<String>>{};
    for (final entry in host.fieldErrors.entries) {
      if (entry.key.startsWith(prefix)) {
        out[entry.key.substring(prefix.length)] = entry.value;
      }
    }
    return out;
  }

  /// Trims a rate for the summary row: `19.0` → `19`, with the company's
  /// decimal separator. `blankZero: false` keeps a literal `0` (a named
  /// zero-rated subregion should read "VAT 0%", not "VAT").
  String _fmt(double v) =>
      rateInputText(v, useCommaAsDecimalPlace: useComma, blankZero: false);

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (subregion.taxName.isNotEmpty) {
      parts.add('${subregion.taxName} ${_fmt(subregion.taxRate)}%');
    } else if (subregion.taxRate != 0) {
      parts.add('${_fmt(subregion.taxRate)}%');
    }
    if (subregion.reducedTaxRate != 0) {
      parts.add('${_fmt(subregion.reducedTaxRate)}%');
    }
    final body = parts.isEmpty ? '—' : parts.join(' • ');
    final scopedErrors = _scopedErrors;
    final firstError = scopedErrors.values
        .where((v) => v.isNotEmpty)
        .map((v) => v.first)
        .firstOrNull;
    final tokens = context.inTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Checkbox(
                value: subregion.applyTax,
                onChanged: disabled
                    ? null
                    : (v) =>
                          onChanged(subregion.copyWith(applyTax: v ?? false)),
              ),
              SizedBox(width: InSpacing.sm),
              SizedBox(
                width: 64,
                child: Text(
                  subregionKey,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              if (firstError != null)
                Icon(Icons.error_outline, size: 18, color: tokens.overdue),
              IconButton(
                icon: const Icon(MdiIcons.circleEditOutline),
                tooltip: context.tr('edit'),
                onPressed: () async {
                  final next = await SubregionEditDialog.show(
                    context,
                    subregionKey: subregionKey,
                    initial: subregion,
                    useComma: useComma,
                    fieldErrors: scopedErrors.isEmpty ? null : scopedErrors,
                  );
                  if (next != null) onChanged(next);
                },
              ),
            ],
          ),
          if (firstError != null)
            Padding(
              padding: EdgeInsets.only(left: 80, top: 2, bottom: InSpacing.xs),
              child: Text(
                firstError,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.overdue),
              ),
            ),
        ],
      ),
    );
  }
}
