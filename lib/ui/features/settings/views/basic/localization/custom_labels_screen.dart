import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/company_label_overrides.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/l10n/company_labels_scope.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Predefined Custom Labels — the React `defaultLabels` list. Each value is a
/// localization key (e.g. `'invoice'` → "Invoice"); selecting one from the
/// dropdown adds a new overridable row backed by `settings.translations[key]`.
/// Users can also add free-form keys (`Add Custom`) and country aliases
/// (`Add Country`, key prefix `country_<name>`).
const kCustomLabelKeys = <String>[
  'address1',
  'address2',
  'amount',
  'balance',
  'country',
  'credit',
  'credit_card',
  'date',
  'description',
  'details',
  'discount',
  'due_date',
  'email',
  'from',
  'hours',
  'id_number',
  'invoice',
  'item',
  'line_total',
  'paid_to_date',
  'partial_due',
  'payment_date',
  'phone',
  'po_number',
  'product',
  'products',
  'quantity',
  'quote',
  'rate',
  'service',
  'statement',
  'subtotal',
  'surcharge',
  'tax',
  'taxes',
  'terms',
  'to',
  'total',
  'unit_cost',
  'valid_until',
  'vat_number',
  'website',
];

/// Localization "Custom Labels" tab — field labels surfaced by the in-app
/// search. Just the heading. [kCustomLabelKeys] stays out on purpose: those
/// are words the user *may* relabel (Amount, Address 1, …), not fields on this
/// page, and listing them would put a Custom Labels row under every search
/// for an ordinary word.
const kLocalizationCustomLabelsSearchKeys = <String>['custom_labels'];

const String _countryKeyPrefix = 'country_';

/// Custom Labels tab body. Lists the entity's `settings.translations` entries
/// as editable rows; the header row adds new entries via a dropdown of
/// predefined keys, an "Add Custom" dialog for free-form keys, and an
/// "Add Country" dialog that scopes the key under `country_<name>`.
///
/// Mounted by `LocalizationShell` inside `CascadeTabbedSettingsShell`; the
/// shell owns the cascade VM and provides it via Provider.
class LocalizationCustomLabelsBody extends StatelessWidget {
  const LocalizationCustomLabelsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final host = context.watch<SettingsDraftHost>();
    final translations = _readTranslations(host.settings);
    final existingKeys = translations.keys.toList()
      ..sort((a, b) {
        // Country rows sink below predefined / custom rows so the predefined
        // ones stay at the top.
        final aCountry = a.startsWith(_countryKeyPrefix);
        final bCountry = b.startsWith(_countryKeyPrefix);
        if (aCountry != bCountry) return aCountry ? 1 : -1;
        return a.compareTo(b);
      });

    final available = kCustomLabelKeys
        .where((k) => !translations.containsKey(k))
        .toList();

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('custom_labels'),
          children: [
            // Key ties the dropdown's internal state to the current
            // translations-count: after the user picks a label and we mutate
            // the map, the row remounts so the dropdown clears its visible
            // selection (which is no longer in `available`).
            _Notes(host: host),
            _AddRow(
              key: ValueKey('add_row_${existingKeys.length}'),
              host: host,
              services: services,
              available: available,
            ),
            if (existingKeys.isEmpty)
              _EmptyState()
            else
              for (final key in existingKeys) ...[
                _TranslationRow(
                  key: ValueKey('translation_$key'),
                  translationKey: key,
                  displayLabel: _resolveLabel(context, key),
                  onRemove: () => _removeLabel(host, key),
                ),
                _RelatedLabels(
                  key: ValueKey('related_$key'),
                  translationKey: key,
                  existing: translations.keys.toSet(),
                  host: host,
                ),
              ],
          ],
        ),
      ],
    );
  }

  /// The word this app ships for [key] — never the company's override of
  /// it, which the app now applies everywhere: the row would otherwise be
  /// labelled with the user's own wording, and say nothing about what it
  /// replaces.
  static String _resolveLabel(BuildContext context, String key) {
    if (key.startsWith(_countryKeyPrefix)) {
      // i18n ships localized country names keyed by `country_<name>` — the same
      // shape the server / legacy app store. Localize it; if the active locale
      // lacks the entry, fall back to the bare name (without the prefix).
      final bundled = context.trBundled(key);
      return bundled != key ? bundled : key.substring(_countryKeyPrefix.length);
    }
    return context.trBundled(key);
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({
    super.key,
    required this.host,
    required this.services,
    required this.available,
  });

  final SettingsDraftHost host;
  final Services services;
  final List<String> available;

  @override
  Widget build(BuildContext context) {
    // On a phone the dropdown + two text buttons squeeze the dropdown to a
    // sliver and long localized labels can overflow the row. Below the wide
    // breakpoint, collapse the two actions to icon-only (label → tooltip).
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < Breakpoints.wide;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SearchableDropdownField<String>(
                label: context.tr('add_label'),
                items: available,
                initialValue: null,
                displayString: (k) => context.trBundled(k),
                idOf: (k) => k,
                onChanged: (k) {
                  if (k == null) return;
                  // Predefined keys already in the map are filtered out of
                  // `available`, so this can't duplicate — ignore the result.
                  _addLabel(host, k);
                },
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            _addButton(
              context,
              icon: Icons.add,
              labelKey: 'add_custom',
              compact: compact,
              onPressed: () => _openCustomDialog(context),
            ),
            SizedBox(width: InSpacing.md(context)),
            _addButton(
              context,
              icon: Icons.public_outlined,
              labelKey: 'add_country',
              compact: compact,
              onPressed: () => _openCountryDialog(context),
            ),
          ],
        );
      },
    );
  }

  /// Add-action button: icon+label on wide layouts, icon-only (with a tooltip
  /// carrying the label) on narrow ones. Keeps the design-system rounded-rect
  /// shape via `OutlinedButton` (not the pill-shaped `IconButton.outlined`).
  Widget _addButton(
    BuildContext context, {
    required IconData icon,
    required String labelKey,
    required bool compact,
    required VoidCallback onPressed,
  }) {
    if (compact) {
      return Tooltip(
        message: context.tr(labelKey),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 40),
            padding: EdgeInsets.zero,
          ),
          onPressed: onPressed,
          child: Icon(icon),
        ),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(context.tr(labelKey)),
    );
  }

  Future<void> _openCustomDialog(BuildContext context) async {
    // Capture before the async gap so we don't touch `context` after `await`.
    final toasts = Notify.capture(context);
    final duplicateMessage = context.tr('label_already_added');
    final controller = TextEditingController();
    try {
      final key = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.tr('add_custom')),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: dialogContext.tr('property_name'),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.tr('cancel')),
            ),
            PrimaryDialogAction(
              label: dialogContext.tr('add'),
              autofocus: false,
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
            ),
          ],
        ),
      );
      if (key == null || key.isEmpty) return;
      if (!_addLabel(host, key)) {
        toasts?.warning(duplicateMessage);
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openCountryDialog(BuildContext context) async {
    // Capture before the async gap so we don't touch `context` after `await`.
    final toasts = Notify.capture(context);
    final duplicateMessage = context.tr('label_already_added');
    final countries = services.statics.countries.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final country = await showDialog<Country>(
      context: context,
      builder: (dialogContext) => _AddCountryDialog(countries: countries),
    );
    if (country == null) return;
    if (!_addLabel(host, '$_countryKeyPrefix${country.name}')) {
      toasts?.warning(duplicateMessage);
    }
  }
}

class _AddCountryDialog extends StatefulWidget {
  const _AddCountryDialog({required this.countries});

  final List<Country> countries;

  @override
  State<_AddCountryDialog> createState() => _AddCountryDialogState();
}

class _AddCountryDialogState extends State<_AddCountryDialog> {
  Country? _selected;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('add_country')),
      content: SizedBox(
        width: 360,
        child: SearchableDropdownField<Country>(
          label: context.tr('country'),
          items: widget.countries,
          initialValue: null,
          displayString: (c) => c.name,
          idOf: (c) => c.id,
          onChanged: (c) => setState(() => _selected = c),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('add'),
          enabled: _selected != null,
          autofocus: false,
          showEnterHint: false,
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}

/// What a label does, said once above the rows.
///
/// - **One exact word.** Relabelling `invoice` leaves "Invoices" and "New
///   Invoice" as they were — those are labels of their own — and someone who
///   renamed Invoice to Bill would otherwise read "Invoices" everywhere and
///   think the setting broken.
/// - **Not in another language.** The app shows a company's labels only
///   while it shows the company's language (`CompanyLabelOverrides`); with
///   the app set to another one they still reach PDFs and emails, and the
///   page says so rather than look ignored.
/// - **At a client or group, PDFs and emails only.** The app's own strings
///   follow the company.
class _Notes extends StatelessWidget {
  const _Notes({required this.host});

  final SettingsDraftHost host;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink3);
    final notes = <String>[
      context.tr('custom_labels_exact_word'),
      if (host.isCascadeScope)
        context.tr('custom_labels_documents_only')
      else if (_withheldForLanguage(context))
        context.tr('custom_labels_other_language'),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.md(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(note, style: style),
            ),
        ],
      ),
    );
  }

  /// Read off the notifier behind `CompanyLabelsScope`, which made the
  /// call — not recomputed here from the company's language and the device
  /// setting, which would be a second copy of the rule.
  static bool _withheldForLanguage(BuildContext context) {
    final labels = CompanyLabelsScope.notifierOf(context);
    return labels is CompanyLabelOverrides && labels.withheldForLanguage;
  }
}

/// The labels a relabelled word is part of — `invoice` → Invoices, New
/// Invoice, Invoice Number — offered one tap away, where the bundle has
/// them and they are not relabelled already.
class _RelatedLabels extends StatelessWidget {
  const _RelatedLabels({
    super.key,
    required this.translationKey,
    required this.existing,
    required this.host,
  });

  final String translationKey;
  final Set<String> existing;
  final SettingsDraftHost host;

  @override
  Widget build(BuildContext context) {
    final k = translationKey;
    if (k.startsWith(_countryKeyPrefix)) return const SizedBox.shrink();
    final related = [
      for (final candidate in ['${k}s', 'new_$k', '${k}_number'])
        if (!existing.contains(candidate) &&
            context.trBundled(candidate) != candidate)
          candidate,
    ];
    if (related.isEmpty) return const SizedBox.shrink();
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: InSpacing.sm,
        children: [
          Text(
            context.tr('also_relabel'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
          ),
          for (final r in related)
            TextButton.icon(
              // A compact row with a pointer; the full target on touch
              // (CLAUDE.md § Touch targets are gated on the platform).
              style: TextButton.styleFrom(
                minimumSize: Size(
                  0,
                  Env.isTouchPrimary ? InSizes.touchTarget : 32,
                ),
              ),
              onPressed: () => _addLabel(host, r),
              icon: const Icon(Icons.add, size: 16),
              label: Text(context.trBundled(r)),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
      child: Center(
        child: Text(
          context.tr('no_custom_labels'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: context.inTheme.ink3),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _TranslationRow extends StatefulWidget {
  const _TranslationRow({
    required super.key,
    required this.translationKey,
    required this.displayLabel,
    required this.onRemove,
  });

  final String translationKey;
  final String displayLabel;
  final VoidCallback onRemove;

  @override
  State<_TranslationRow> createState() => _TranslationRowState();
}

class _TranslationRowState extends State<_TranslationRow> {
  late final TextEditingController _controller;
  late final SettingsBinding _binding;

  @override
  void initState() {
    super.initState();
    _binding = _bindingFor(widget.translationKey);
    final host = context.read<SettingsDraftHost>();
    _controller = TextEditingController(
      text: _binding.read(host.settings) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final hostValue = _binding.read(host.settings) ?? '';
    if (_controller.text != hostValue) {
      _controller.value = TextEditingValue(
        text: hostValue,
        selection: TextSelection.collapsed(offset: hostValue.length),
      );
    }

    final scope = FormSaveScope.maybeOf(context);
    final field = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: widget.displayLabel),
            onChanged: (v) => host.updateSettings((s) => _binding.write(s, v)),
            onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: context.tr('remove'),
          onPressed: widget.onRemove,
        ),
      ],
    );

    return OverridableField.bindInline(
      apiKey: 'translations.${widget.translationKey}',
      label: widget.displayLabel,
      binding: _binding,
      cascadedValueOnEnable: () => _binding.read(host.settings) ?? '',
      child: field,
    );
  }
}

// ── shared helpers ──────────────────────────────────────────────────────────

Map<String, String> _readTranslations(CompanySettings settings) {
  final raw = settings.translations;
  if (raw == null) return const <String, String>{};
  final out = <String, String>{};
  for (final entry in raw.entries) {
    final v = entry.value;
    if (v == null) continue;
    out[entry.key] = v.toString();
  }
  return out;
}

SettingsBinding _bindingFor(String key) => (
  read: (s) {
    final m = s.translations;
    if (m == null) return null;
    final v = m[key];
    return v?.toString();
  },
  write: (s, v) {
    final map = Map<String, dynamic>.of(s.translations ?? const {});
    if (v == null) {
      map.remove(key);
    } else {
      map[key] = v;
    }
    // Empty map → null here: this write path's v == null branch only fires
    // from the cascade-scope override checkbox (company scope renders these
    // rows without one), and at cascade scope the override must be REMOVED
    // from the sparse draft — persisting `translations: {}` would
    // permanently shadow every company custom label for that client on
    // server-rendered PDFs/emails. Company-scope last-label removal goes
    // through _removeLabel below, which keeps the explicit {}.
    return s.copyWith(translations: map.isEmpty ? null : map);
  },
);

/// Adds an empty entry for [key]. Returns `false` (without mutating) when the
/// key is blank or already present, so callers can surface a "duplicate" toast.
bool _addLabel(SettingsDraftHost host, String key) {
  if (key.isEmpty) return false;
  if ((host.settings.translations ?? const {}).containsKey(key)) return false;
  host.updateSettings((s) {
    final map = Map<String, dynamic>.of(s.translations ?? const {});
    map[key] = '';
    return s.copyWith(translations: map);
  });
  return true;
}

void _removeLabel(SettingsDraftHost host, String key) {
  host.updateSettings((s) {
    final map = Map<String, dynamic>.of(s.translations ?? const {});
    map.remove(key);
    // Sentinel by scope (see SettingsDraftHost.isCascadeScope): at company
    // scope an explicit {} survives the rawSettings PUT merge (a null map is
    // omitted by toJson and the removed label resurrects); at cascade scope
    // an empty map must become null — `translations: {}` would permanently
    // shadow every company custom label for that client server-side.
    return s.copyWith(
      translations: map.isEmpty && host.isCascadeScope ? null : map,
    );
  });
}
