import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_number_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';

/// Online Payments — General tab. Field labels surfaced by the in-app search.
const kOnlinePaymentsGeneralSearchKeys = <String>[
  'auto_bill_standard_invoices',
  'auto_bill_recurring_invoices',
  'auto_bill_on',
  'use_available_payments',
  'use_available_credits',
  'configure_gateways',
  'admin_initiated_payments',
  'client_initiated_payments',
  'minimum_payment_amount',
  'allow_over_payment',
  'allow_under_payment',
  'minimum_under_payment_amount',
  'convert_currency',
  'one_page_checkout',
  'unlock_invoice_documents_after_payment',
];

/// Returns a stacked column of one or two `FormSection`s — see CLAUDE.md's
/// "Mixing both kinds of fields on one screen" guidance:
///   * `settings` — cascade-aware `company.settings.*` fields. Always
///     rendered.
///   * `payment_settings` — the two top-level `Company.*` toggles
///     (`enable_applying_payments`, `convert_payment_currency`). Rendered
///     only at company scope, since `updateCompany` is a no-op on the
///     client VM and the user's edit would silently drop.
class OnlinePaymentsGeneralBody extends StatelessWidget {
  const OnlinePaymentsGeneralBody({super.key});

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final scope = context.watch<SettingsLevelController>();
    final isCompanyScope = scope.isCompany;
    final clientInitiated = host.settings.clientInitiatedPayments ?? false;
    final allowUnderPayment =
        host.settings.clientPortalAllowUnderPayment ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FormSection(
          title: context.tr('settings'),
          children: [
            OverridableSwitchField(
              label: context.tr('auto_bill_standard_invoices'),
              apiKey: 'auto_bill_standard_invoices',
            ),
            OverridableDropdownField<String>(
              label: context.tr('auto_bill_recurring_invoices'),
              apiKey: 'auto_bill',
              value: host.settings.autoBill,
              items: _autoBillOptions(context),
              onChanged: (v) =>
                  host.updateSettings((s) => s.copyWith(autoBill: v)),
            ),
            OverridableDropdownField<String>(
              label: context.tr('auto_bill_on'),
              apiKey: 'auto_bill_date',
              value: host.settings.autoBillDate,
              items: _autoBillDateOptions(context),
              onChanged: (v) =>
                  host.updateSettings((s) => s.copyWith(autoBillDate: v)),
            ),
            OverridableDropdownField<String>(
              label: context.tr('use_available_payments'),
              apiKey: 'use_unapplied_payment',
              value: host.settings.useUnappliedPayment,
              items: _alwaysOptionOff(context),
              onChanged: (v) => host.updateSettings(
                (s) => s.copyWith(useUnappliedPayment: v),
              ),
            ),
            OverridableDropdownField<String>(
              label: context.tr('use_available_credits'),
              apiKey: 'use_credits_payment',
              value: host.settings.useCreditsPayment,
              items: _alwaysOptionOff(context),
              onChanged: (v) =>
                  host.updateSettings((s) => s.copyWith(useCreditsPayment: v)),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () => context.go('/settings/company_gateways'),
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                ),
                label: Text(context.tr('configure_gateways')),
              ),
            ),
            OverridableSwitchField(
              label: context.tr('client_initiated_payments'),
              apiKey: 'client_initiated_payments',
              subtitle: context.tr('client_initiated_payments_help'),
            ),
            if (clientInitiated)
              OverridableNumberField(
                label: context.tr('minimum_payment_amount'),
                apiKey: 'client_initiated_payments_minimum',
              ),
            OverridableSwitchField(
              label: context.tr('allow_over_payment'),
              apiKey: 'client_portal_allow_over_payment',
              subtitle: context.tr('allow_over_payment_help'),
            ),
            OverridableSwitchField(
              label: context.tr('allow_under_payment'),
              apiKey: 'client_portal_allow_under_payment',
              subtitle: context.tr('allow_under_payment_help'),
            ),
            if (allowUnderPayment)
              OverridableNumberField(
                label: context.tr('minimum_under_payment_amount'),
                apiKey: 'client_portal_under_payment_minimum',
              ),
            OverridableSwitchField(
              label: context.tr('one_page_checkout'),
              apiKey: 'payment_flow',
              subtitle: context.tr('one_page_checkout_help'),
            ),
            OverridableSwitchField(
              label: context.tr('unlock_invoice_documents_after_payment'),
              apiKey: 'unlock_invoice_documents_after_payment',
              subtitle: context.tr(
                'unlock_invoice_documents_after_payment_help',
              ),
            ),
          ],
        ),
        if (isCompanyScope)
          FormSection(
            title: context.tr('payment_settings'),
            children: [
              _CompanyToggleTile(
                label: context.tr('admin_initiated_payments'),
                subtitle: context.tr('admin_initiated_payments_help'),
                value: host.draft!.enableApplyingPayments,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(enableApplyingPayments: v),
                ),
              ),
              _CompanyToggleTile(
                label: context.tr('convert_currency'),
                subtitle: context.tr('convert_payment_currency_help'),
                value: host.draft!.convertPaymentCurrency,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(convertPaymentCurrency: v),
                ),
              ),
            ],
          ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _autoBillOptions(BuildContext context) => [
    DropdownMenuItem(value: 'always', child: Text(context.tr('always'))),
    DropdownMenuItem(value: 'optout', child: Text(context.tr('optout'))),
    DropdownMenuItem(value: 'optin', child: Text(context.tr('optin'))),
    DropdownMenuItem(value: 'off', child: Text(context.tr('off'))),
  ];

  List<DropdownMenuItem<String>> _autoBillDateOptions(BuildContext context) => [
    DropdownMenuItem(
      value: 'on_send_date',
      child: Text(context.tr('on_send_date')),
    ),
    DropdownMenuItem(
      value: 'on_due_date',
      child: Text(context.tr('on_due_date')),
    ),
  ];

  List<DropdownMenuItem<String>> _alwaysOptionOff(BuildContext context) => [
    DropdownMenuItem(value: 'always', child: Text(context.tr('always'))),
    DropdownMenuItem(value: 'option', child: Text(context.tr('option'))),
    DropdownMenuItem(value: 'off', child: Text(context.tr('off'))),
  ];
}

/// Plain `SwitchListTile` for the two top-level `Company.*` toggles that
/// don't cascade (admin-initiated payments, convert currency). Rendered only
/// at company scope — at group/client scope `updateCompany` is a no-op on
/// the client VM and the user's edit would silently drop. Lives in its own
/// `FormSection` per CLAUDE.md's mixed-fields guidance.
class _CompanyToggleTile extends StatelessWidget {
  const _CompanyToggleTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }
}
