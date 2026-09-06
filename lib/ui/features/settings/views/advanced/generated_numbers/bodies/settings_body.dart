import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_date_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_text_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/utils/formatting.dart';

/// `apiKey` mapping for fields rendered on the global Settings tab.
/// Surfaced to in-app search via [kSettingsSearchCatalog].
const kGeneratedNumbersSettingsSearchKeys = <String>[
  'number_padding',
  'generate_number',
  'reset_counter',
  'next_reset',
  'recurring_prefix',
  'shared_invoice_quote_counter',
  'shared_invoice_credit_counter',
];

/// `reset_counter_frequency_id` options. Mirrors `kFrequencies` in
/// admin-portal (`lib/constants.dart:87-99`). Order matches the React app's
/// `RESECT_COUNTER_FREQUENCIES` array (`react/src/pages/settings/
/// generated-numbers/components/Settings.tsx:37-51`).
const _kFrequencyOptions = <(String, String)>[
  ('0', 'never'),
  ('1', 'freq_daily'),
  ('2', 'freq_weekly'),
  ('3', 'freq_two_weeks'),
  ('4', 'freq_four_weeks'),
  ('5', 'freq_monthly'),
  ('6', 'freq_two_months'),
  ('7', 'freq_three_months'),
  ('8', 'freq_four_months'),
  ('9', 'freq_six_months'),
  ('10', 'freq_annually'),
  ('11', 'freq_two_years'),
  ('12', 'freq_three_years'),
];

/// `counter_padding` options. The dropdown shows the rendered padding
/// (`'1'`, `'01'`, `'001'`, …) so users can preview what their counter
/// will look like.
List<DropdownMenuItem<String>> _paddingOptions() {
  return [
    for (var i = 1; i <= 10; i++)
      DropdownMenuItem<String>(value: '$i', child: Text('${'0' * (i - 1)}1')),
  ];
}

/// Settings tab body for Generated Numbers. Mounted by
/// [GeneratedNumbersShell] inside [CascadeTabbedSettingsShell].
///
/// Module-gated fields ([recurringNumberPrefix], [sharedInvoiceQuoteCounter],
/// [sharedInvoiceCreditCounter]) take their flags from the shell — the body
/// itself doesn't read `Company`, so it stays cascade-scope agnostic (the
/// `host.draft` is `Client?` at client scope, where the gate flags still
/// reflect the company's enabled modules).
class GeneratedNumbersSettingsBody extends StatefulWidget {
  const GeneratedNumbersSettingsBody({
    super.key,
    required this.companyId,
    required this.showRecurringPrefix,
    required this.showSharedQuoteCounter,
    required this.showSharedCreditCounter,
  });

  final String companyId;
  final bool showRecurringPrefix;
  final bool showSharedQuoteCounter;
  final bool showSharedCreditCounter;

  @override
  State<GeneratedNumbersSettingsBody> createState() =>
      _GeneratedNumbersSettingsBodyState();
}

class _GeneratedNumbersSettingsBodyState
    extends State<GeneratedNumbersSettingsBody> {
  Formatter? _formatter;

  @override
  void initState() {
    super.initState();
    // `formatterFor` is memoized in Services; the first call resolves
    // statics + company row, subsequent calls are cache hits. We load it
    // lazily here so the `Next Reset` date field can render the value in
    // the user's configured date format. Failures (e.g. statics not yet
    // loaded on a freshly booted test harness) leave `_formatter` null,
    // which keeps the date field hidden but lets the rest of the form
    // continue to work.
    final services = context.read<Services>();
    services.formatterFor(widget.companyId).then((f) {
      if (!mounted) return;
      setState(() => _formatter = f);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final frequency = host.settings.resetCounterFrequencyId;
    final showNextReset =
        frequency != null && frequency != 0 && _formatter != null;
    // VeriFactu (Spain's tax-authority e-invoicing) mandates when the number
    // is applied, so the server locks `counter_number_applied`. Mirror the
    // React app's `Settings.tsx:109` (`|| verifactuEnabled`) by greying the
    // dropdown — a null `onChanged` disables it per `OverridableDropdownField`.
    final isVerifactu = host.settings.eInvoiceType == kEInvoiceTypeVERIFACTU;
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('settings'),
          // Field order mirrors React's `generated-numbers/components/
          // Settings.tsx`: padding, generate, recurring prefix, shared
          // counters, then the reset-counter block last.
          children: [
            OverridableDropdownField<String>(
              label: context.tr('number_padding'),
              apiKey: 'counter_padding',
              // Display-only fallback to the server default (4) so a null/unset
              // value shows "0001" rather than blank (matches React). Never
              // written — onChanged below is the only writer.
              value: (host.settings.counterPadding ?? 4).toString(),
              items: _paddingOptions(),
              onChanged: (v) => host.updateSettings(
                (s) => s.copyWith(
                  counterPadding: v == null ? null : int.tryParse(v),
                ),
              ),
            ),
            OverridableDropdownField<String>(
              label: context.tr('generate_number'),
              apiKey: 'counter_number_applied',
              // Display-only fallback to the server default (matches React).
              value: host.settings.counterNumberApplied ?? 'when_saved',
              items: [
                DropdownMenuItem(
                  value: 'when_saved',
                  child: Text(context.tr('when_saved')),
                ),
                DropdownMenuItem(
                  value: 'when_sent',
                  child: Text(context.tr('when_sent')),
                ),
              ],
              onChanged: isVerifactu
                  ? null
                  : (v) => host.updateSettings(
                      (s) => s.copyWith(counterNumberApplied: v),
                    ),
            ),
            if (widget.showRecurringPrefix)
              OverridableTextField(
                label: context.tr('recurring_prefix'),
                apiKey: 'recurring_number_prefix',
                autocorrect: false,
              ),
            if (widget.showSharedQuoteCounter)
              OverridableSwitchField(
                label: context.tr('shared_invoice_quote_counter'),
                apiKey: 'shared_invoice_quote_counter',
              ),
            if (widget.showSharedCreditCounter)
              OverridableSwitchField(
                label: context.tr('shared_invoice_credit_counter'),
                apiKey: 'shared_invoice_credit_counter',
              ),
            OverridableDropdownField<String>(
              label: context.tr('reset_counter'),
              apiKey: 'reset_counter_frequency_id',
              // Display-only fallback to the server default 0 (Never) so an
              // unset value shows "Never" rather than blank (matches React).
              // `showNextReset` above reads the real model value, so this
              // fallback can't reveal the Next Reset field.
              value: (host.settings.resetCounterFrequencyId ?? 0).toString(),
              items: [
                for (final (id, labelKey) in _kFrequencyOptions)
                  DropdownMenuItem<String>(
                    value: id,
                    child: Text(context.tr(labelKey)),
                  ),
              ],
              onChanged: (v) => host.updateSettings((s) {
                final parsed = v == null ? null : int.tryParse(v);
                // Clearing the frequency → clear the date too (matches the
                // React app's `Settings.tsx:201-203`). Keeping a stale date
                // around would leave a half-configured reset behind on the
                // wire and re-arm the next save.
                if (parsed == null || parsed == 0) {
                  return s.copyWith(
                    resetCounterFrequencyId: parsed,
                    resetCounterDate: null,
                  );
                }
                return s.copyWith(resetCounterFrequencyId: parsed);
              }),
            ),
            if (showNextReset)
              OverridableDateField(
                label: context.tr('next_reset'),
                apiKey: 'reset_counter_date',
                formatter: _formatter!,
              ),
          ],
        ),
      ],
    );
  }
}
