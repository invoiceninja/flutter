import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/certificate_card.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/payment_means_card.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/peppol_onboarding_card.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/peppol_preferences_card.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/tax_identifiers_card.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_radio_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Field labels exposed by the in-app settings search for the E-Invoice
/// page. Keep in sync with `kSettingsSearchCatalog['e_invoice']`. Every key
/// is rendered somewhere on the page: the cascade fields here, the rest in
/// the company-only cards — the three forward-email / skip keys live on
/// [PeppolPreferencesCard], `certificate_passphrase` on [CertificateCard],
/// `payment_means` on [PaymentMeansCard], the identifier keys on
/// [TaxIdentifiersCard]. (`e_invoice` is not yet in
/// `search_catalog_consistency_test`'s tab list, so this sync is by hand.)
const kEInvoiceSearchKeys = <String>[
  'e_invoice_type',
  'enable_e_invoice',
  'merge_e_invoice_to_pdf',
  'e_quote_type',
  'e_invoice_forward_email',
  'e_expense_forward_email',
  'skip_automatic_email_with_peppol',
  'certificate_passphrase',
  'payment_means',
  'additional_tax_identifiers',
  'act_as_sender',
  'act_as_receiver',
  'france_reporting_enabled',
  'france_reporting_schedule',
];

/// Body for Settings → E-Invoice. Mounted by [EInvoiceScreen] inside
/// [CascadeSettingsScaffold] — the scaffold owns the cascade VM and provides
/// it via Provider.
///
/// Layout mirrors admin-portal `lib/ui/settings/e_invoice_settings.dart` and
/// React `pages/settings/e-invoice/EInvoice.tsx`, with two UX improvements:
///   * The type dropdown uses [OverridableSearchableDropdownField] — the
///     option list is ~20 entries long, past the project rule's
///     type-to-search threshold.
///   * The body opens with a [LinkText] linking to the user-guide docs so
///     users can find background on the field set in one tap.
///
/// Five sub-features live on this page. The cascade-friendly fields
/// (type, enable-toggle, merge-to-PDF, quote type, forward emails, skip
/// email) bind through `Overridable*` widgets and ride the page Save
/// button. The four company-only blocks ([CertificateCard],
/// [PeppolOnboardingCard] / [PeppolPreferencesCard], [PaymentMeansCard],
/// [TaxIdentifiersCard]) gate themselves with `scope.isCompany` and fire
/// their own outbox rows on action.
class EInvoiceBody extends StatelessWidget {
  const EInvoiceBody({super.key});

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final scope = context.watch<SettingsLevelController>();
    final settings = host.settings;
    final company = host.draft;
    final isCompany = scope.isCompany;

    final eInvoiceType = settings.eInvoiceType ?? kEInvoiceTypeEN16931;
    final isPeppol = eInvoiceType == kEInvoiceTypePEPPOL;
    final isVerifactu = eInvoiceType == kEInvoiceTypeVERIFACTU;
    final enableEInvoice = settings.enableEInvoice ?? false;

    // Gate the PEPPOL + VERIFACTU options to match React's
    // `shouldShowPEPPOLOption` / `shouldShowVERIFACTUOption`: PEPPOL needs
    // Enterprise access + a PEPPOL-network country; VERIFACTU needs the build
    // flag + hosted + Spain. The page's `PlanGateBanner` is only an
    // informational nudge (it doesn't disable the fields), so the option-level
    // gate is what actually keeps an unentitled / wrong-country user from
    // picking a standard that won't work. Already-selected values stay visible
    // so the user can switch away. See `visibleEInvoiceTypes`.
    final session = context.read<Services>().auth.session.value;
    final dropdownItems = visibleEInvoiceTypes(
      selectedType: settings.eInvoiceType,
      countryId: settings.countryId,
      hasEnterpriseAccess: session?.hasEnterpriseAccess ?? false,
      isHosted: session?.isHosted ?? false,
      verifactuFlagEnabled: Env.enableVerifactu,
    );

    return SettingsFormShell(
      sections: [
        // E-invoice is Enterprise on hosted (React `EInvoice.tsx` gates the
        // whole page at `enterprisePlan()`). Trial-aware; auto-hides on
        // access. The slug `e_invoice` is also in `kEnterpriseGatedSettings`
        // so the sidebar shows the lock + chip before the user taps in.
        const PlanGateBanner(
          style: PlanGateStyle.inset,
          level: PlanGateLevel.enterprise,
        ),
        // Help link — small, deliberate, sits above the first card. Same
        // affordance React ships at the top of EInvoice.tsx.
        const _HelpLinkRow(),

        // ── E-Invoice Type ─────────────────────────────────────────────
        FormSection(
          title: context.tr('e_invoice_type'),
          children: [
            OverridableSearchableDropdownField<String>(
              label: context.tr('e_invoice_type'),
              apiKey: 'e_invoice_type',
              value: settings.eInvoiceType ?? kEInvoiceTypeEN16931,
              items: dropdownItems,
              displayString: (t) => t,
              idOf: (t) => t,
              onChanged: (v) async {
                // Switch-type-away-while-connected guard. If the user
                // is moving off PEPPOL with an active legal entity bound
                // server-side, the binding would be orphaned — prompt
                // before committing.
                if (isPeppol &&
                    v != kEInvoiceTypePEPPOL &&
                    (company?.legalEntityId ?? 0) != 0) {
                  final proceed = await _confirmSwitchAwayFromPeppol(context);
                  if (proceed != true) return;
                }
                host.updateSettings((s) => s.copyWith(eInvoiceType: v));
              },
            ),
          ],
        ),

        // ── VERIFACTU info ──────────────────────────────────────────────
        // Spain-only standard; admin-portal shows a six-step authorization
        // instructions card alongside the dropdown. The dropdown above
        // already country-gates the VERIFACTU option to Spain (with a
        // carve-out for already-selected VERIFACTU), so this card mirrors
        // the user's current selection.
        if (isVerifactu && isCompany) const _VerifactuInfoCard(),

        // ── Enable E-Invoice + cascade-friendly toggles ────────────────
        if (!isPeppol)
          FormSection(
            title: context.tr('enable_e_invoice'),
            children: [
              OverridableSwitchField(
                label: context.tr('enable_e_invoice'),
                apiKey: 'enable_e_invoice',
              ),
              if (enableEInvoice) ...[
                OverridableSwitchField(
                  label: context.tr('merge_e_invoice_to_pdf'),
                  apiKey: 'merge_e_invoice_to_pdf',
                ),
                OverridableDropdownField<String>(
                  label: context.tr('e_quote_type'),
                  apiKey: 'e_quote_type',
                  value: settings.eQuoteType ?? kEQuoteTypeOrderX_Comfort,
                  items: kEQuoteTypes
                      .map(
                        (t) =>
                            DropdownMenuItem<String>(value: t, child: Text(t)),
                      )
                      .toList(),
                  onChanged: (v) =>
                      host.updateSettings((s) => s.copyWith(eQuoteType: v)),
                ),
                // Forward-email fields + the skip-automatic-email toggle used
                // to live here, but they are PEPPOL-specific: React surfaces
                // them only on the PEPPOL Preferences card once a legal entity
                // is bound. Moved to `PeppolPreferencesCard` for parity.
              ],
            ],
          ),

        // ── France e-reporting ───────────────────────────────────────
        // French e-reporting mandate. Company-scope only, France-only, and
        // shown whenever e-invoicing is active (toggle on OR PEPPOL) — the
        // `|| isPeppol` mirrors the Payment Means / Tax Identifiers gates so a
        // French PEPPOL company (where the enable toggle is hidden) still sees
        // it.
        if (isCompany &&
            settings.countryId == kFranceCountryId &&
            (enableEInvoice || isPeppol))
          const _FranceReportingSection(),

        // ── Certificate card ─────────────────────────────────────────
        if (isCompany && !isPeppol && enableEInvoice && company != null)
          const CertificateCard(),

        // ── PEPPOL onboarding / preferences ─────────────────────────
        if (isCompany && isPeppol && company != null)
          (company.legalEntityId == 0)
              ? const PeppolOnboardingCard()
              : const PeppolPreferencesCard(),

        // ── Payment Means ────────────────────────────────────────────
        if (isCompany && (enableEInvoice || isPeppol) && company != null)
          const PaymentMeansCard(),

        // ── Additional Tax Identifiers ──────────────────────────────
        if (isCompany && (enableEInvoice || isPeppol) && company != null)
          const TaxIdentifiersCard(),
      ],
    );
  }
}

/// Confirmation dialog shown when the user changes `eInvoiceType` away
/// from PEPPOL while a `legalEntityId` is still bound server-side.
/// Returns `true` when the user wants to commit the switch anyway,
/// `false` (or `null`) to cancel. Side-by-side actions per the design
/// system; destructive button uses `tokens.overdue`.
Future<bool?> _confirmSwitchAwayFromPeppol(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.tr('switch_away_from_peppol_title')),
      content: Text(context.tr('switch_away_from_peppol_message')),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          variant: DialogActionVariant.destructive,
          label: context.tr('switch_anyway'),
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
}

/// Single-row link to the e-invoicing user guide. Sits above the first
/// `FormSection` and renders inside the `SettingsFormShell`'s outer
/// padding. Reuses the project's `LinkText` for hover + cursor behavior.
class _HelpLinkRow extends StatelessWidget {
  const _HelpLinkRow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.lg(context)),
      child: Row(
        children: [
          Icon(Icons.help_outline, size: 18, color: tokens.ink2),
          SizedBox(width: InSpacing.sm),
          // Flexible so a long localized label wraps instead of overflowing
          // the Row on a narrow phone.
          Flexible(
            child: LinkText(
              label: context.tr('e_invoice_settings'),
              color: tokens.accent,
              style: theme.textTheme.bodyMedium,
              onTap: launchEInvoiceHelpUrl,
            ),
          ),
        ],
      ),
    );
  }
}

/// VERIFACTU info / authorization pointer. Renders a description card
/// when the type dropdown is set to `VERIFACTU` — the standard is
/// Spain-specific and requires off-app registration with AEAT before
/// submissions go through. Admin-portal renders six numbered
/// authorization steps from Transifex (`tax_authority_authorization_step_1..6`);
/// those keys aren't in our bundle yet, so we ship a short description
/// + a docs link. When the keys land via import, fan them back out as
/// numbered list items.
class _VerifactuInfoCard extends StatelessWidget {
  const _VerifactuInfoCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return FormSection(
      title: 'VeriFactu',
      children: [
        Text(
          context.tr('verifactu_description'),
          style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: LinkText(
            label: context.tr('verifactu_learn_more'),
            color: tokens.accent,
            style: theme.textTheme.bodyMedium,
            onTap: launchEInvoiceHelpUrl,
          ),
        ),
      ],
    );
  }
}

/// Settings → E-Invoice → "Reporting": the French e-reporting toggle and, when
/// on, the transaction/payment reporting schedule + a VAT-exempt info note.
/// The caller gates this to French companies with e-invoicing active; it's
/// cascade-aware via `Overridable*` widgets, like the enable-e-invoice toggle
/// above. Schedule values come from `e_invoice_constants.dart`
/// (`ten_day` / `monthly`); a never-set schedule displays `ten_day` and the
/// server applies the same default, so no client-side seeding is needed.
class _FranceReportingSection extends StatelessWidget {
  const _FranceReportingSection();

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final settings = host.settings;
    final enabled = settings.franceReportingEnabled ?? false;
    final schedule = settings.franceReportingSchedule ?? kFranceReportingTenDay;

    return FormSection(
      title: context.tr('reporting'),
      children: [
        OverridableSwitchField(
          label: context.tr('france_reporting_enabled'),
          apiKey: 'france_reporting_enabled',
        ),
        if (enabled) ...[
          OverridableRadioField<String>(
            label: context.tr('france_reporting_schedule'),
            apiKey: 'france_reporting_schedule',
            value: schedule,
            options: [
              (
                value: kFranceReportingTenDay,
                label: context.tr('france_reporting_ten_day'),
              ),
              (
                value: kFranceReportingMonthly,
                label: context.tr('france_reporting_monthly'),
              ),
            ],
            subtitleOf: (value) => _reportingSummary(
              context,
              transactionValueKey: value == kFranceReportingMonthly
                  ? 'france_reporting_transaction_monthly'
                  : 'france_reporting_transaction_every_10_days',
              paymentValueKey: 'france_reporting_payment_monthly',
            ),
            onChanged: (v) => host.updateSettings(
              (s) => s.copyWith(franceReportingSchedule: v),
            ),
          ),
          const _VatExemptInfoCard(),
        ],
      ],
    );
  }
}

/// Informational (non-selectable) note that VAT-exempt French businesses
/// report bi-monthly. Rendered as a muted, bordered card with a leading icon
/// so it reads as guidance and can't be mistaken for a third schedule option.
class _VatExemptInfoCard extends StatelessWidget {
  const _VatExemptInfoCard();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    // Spacing above is owned by FormSection._interleave (InSpacing.lg between
    // children); no extra top padding here, or the gap reads uneven against the
    // radio above. The card's own border provides the visual separation.
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: tokens.ink2),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('france_reporting_vat_exempt_info_title'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: InSpacing.xs),
                _reportingSummary(
                  context,
                  transactionValueKey:
                      'france_reporting_transaction_bi_monthly',
                  paymentValueKey: 'france_reporting_payment_bi_monthly',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two muted "label: value" lines shared by the schedule radio subtitles and
/// the VAT-exempt note. The leading label segment is emphasized so the
/// transaction-vs-payment cadences stay scannable; lines wrap (no truncation)
/// for longer localized strings.
Widget _reportingSummary(
  BuildContext context, {
  required String transactionValueKey,
  required String paymentValueKey,
}) {
  final theme = Theme.of(context);
  final baseStyle = theme.textTheme.bodySmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
  final labelStyle = baseStyle?.copyWith(fontWeight: FontWeight.w500);

  Widget line(String labelKey, String valueKey) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: '${context.tr(labelKey)}: ', style: labelStyle),
        TextSpan(text: context.tr(valueKey)),
      ],
    ),
    style: baseStyle,
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      line('france_reporting_transaction_reports', transactionValueKey),
      line('france_reporting_payment_reports', paymentValueKey),
    ],
  );
}
