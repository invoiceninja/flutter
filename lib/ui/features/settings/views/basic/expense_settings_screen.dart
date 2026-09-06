import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/payment_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/view_models/expense_settings_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/plain_radio_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_company_scoped_host.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_page_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_switch_tile.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';

/// Searchable label keys rendered by this screen. Aggregated into
/// `kSettingsSearchCatalog['expense_settings']` so the in-app search surfaces
/// these fields. `search_catalog_consistency_test` verifies every key here
/// appears as a `context.tr('…')` reference in this file.
const kExpenseSettingsSearchKeys = <String>[
  'should_be_invoiced',
  'mark_paid',
  'default_expense_payment_type',
  'convert_currency',
  'add_documents_to_invoice',
  'notify_vendor_when_paid',
  'expense_mailbox_active',
  'expense_mailbox',
  'inbound_mailbox_allow_company_users',
  'inbound_mailbox_allow_vendors',
  'inbound_mailbox_allow_clients',
  'inbound_mailbox_whitelist',
  'inbound_mailbox_blacklist',
  'inbound_mailbox_allow_unknown',
  'enter_taxes',
  'inclusive_taxes',
  'configure_categories',
];

/// Settings → Expense Settings. Company-only page (like Product Settings): all
/// fields are top-level `company.*` expense flags (`mark_expenses_*`,
/// `notify_vendor_when_paid`, the inbound-mailbox block, the expense-tax pair)
/// except `settings.defaultExpensePaymentTypeId`, which is written at company
/// scope here. The per-client/group override for that one key lives in Online
/// Payments → Defaults (which is cascade-aware) — so this screen carries no
/// scope selector and is hidden from the sidebar in client/group scope via
/// `clientEditable: false` in the settings catalog.
class ExpenseSettingsScreen extends StatelessWidget {
  const ExpenseSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return SettingsCompanyScopedHost<ExpenseSettingsViewModel>(
      create: (companyId) {
        final vm = ExpenseSettingsViewModel(
          repo: services.company,
          companyId: companyId,
        );
        unawaited(vm.load());
        return vm;
      },
      builder: (context, vm) => SettingsPageScaffold<ExpenseSettingsViewModel>(
        titleKey: 'expense_settings',
        viewModel: vm,
        body: const _ExpenseSettingsBody(),
      ),
    );
  }
}

class _ExpenseSettingsBody extends StatelessWidget {
  const _ExpenseSettingsBody();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExpenseSettingsViewModel>();
    final draft = vm.draft;
    if (draft == null) return const SizedBox.shrink();

    final services = context.read<Services>();
    // Default `isHosted` to true so unknown sessions never accidentally expose
    // the mailbox config (which is meaningless on hosted).
    final isSelfHosted = !(services.auth.session.value?.isHosted ?? true);

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('settings'),
          children: [
            SettingsSwitchTile(
              label: context.tr('should_be_invoiced'),
              help: context.tr('should_be_invoiced_help'),
              value: draft.markExpensesInvoiceable,
              onChanged: (v) => vm.updateCompany(
                (c) => c.copyWith(markExpensesInvoiceable: v),
              ),
            ),
            SettingsSwitchTile(
              label: context.tr('mark_paid'),
              help: context.tr('mark_paid_help'),
              value: draft.markExpensesPaid,
              onChanged: (v) =>
                  vm.updateCompany((c) => c.copyWith(markExpensesPaid: v)),
            ),
            // Default expense payment type only matters once expenses can be
            // marked paid — same gating as the old admin-portal.
            if (draft.markExpensesPaid)
              _DefaultPaymentTypePicker(vm: vm, services: services),
            SettingsSwitchTile(
              label: context.tr('convert_currency'),
              help: context.tr('convert_expense_currency_help'),
              value: draft.convertExpenseCurrency,
              onChanged: (v) => vm.updateCompany(
                (c) => c.copyWith(convertExpenseCurrency: v),
              ),
            ),
            SettingsSwitchTile(
              label: context.tr('add_documents_to_invoice'),
              help: context.tr('add_documents_to_invoice_help'),
              value: draft.invoiceExpenseDocuments,
              onChanged: (v) => vm.updateCompany(
                (c) => c.copyWith(invoiceExpenseDocuments: v),
              ),
            ),
            SettingsSwitchTile(
              label: context.tr('notify_vendor_when_paid'),
              help: context.tr('notify_vendor_when_paid_help'),
              value: draft.notifyVendorWhenPaid,
              onChanged: (v) =>
                  vm.updateCompany((c) => c.copyWith(notifyVendorWhenPaid: v)),
            ),
            // Inbound-mailbox config. Self-hosted only (meaningless on hosted).
            // Rendered inline in this section — not a separate card — so the
            // master toggle reads as one row instead of a card header that
            // duplicates its own label. Matches React's single-card layout.
            if (isSelfHosted) ...[
              SettingsSwitchTile(
                label: context.tr('expense_mailbox_active'),
                help: context.tr('expense_mailbox_active_help'),
                value: draft.expenseMailboxActive,
                onChanged: (v) => vm.updateCompany(
                  (c) => c.copyWith(expenseMailboxActive: v),
                ),
              ),
              if (draft.expenseMailboxActive) ...[
                SettingsTextField(
                  key: const ValueKey('expense_mailbox'),
                  labelText: context.tr('expense_mailbox'),
                  helperText: context.tr('expense_mailbox_help'),
                  helperMaxLines: 2,
                  initialValue: draft.expenseMailbox,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  onChanged: (v) =>
                      vm.updateCompany((c) => c.copyWith(expenseMailbox: v)),
                ),
                SettingsSwitchTile(
                  label: context.tr('inbound_mailbox_allow_company_users'),
                  help: context.tr('inbound_mailbox_allow_company_users_help'),
                  value: draft.inboundMailboxAllowCompanyUsers,
                  onChanged: (v) => vm.updateCompany(
                    (c) => c.copyWith(inboundMailboxAllowCompanyUsers: v),
                  ),
                ),
                SettingsSwitchTile(
                  label: context.tr('inbound_mailbox_allow_vendors'),
                  help: context.tr('inbound_mailbox_allow_vendors_help'),
                  value: draft.inboundMailboxAllowVendors,
                  onChanged: (v) => vm.updateCompany(
                    (c) => c.copyWith(inboundMailboxAllowVendors: v),
                  ),
                ),
                SettingsSwitchTile(
                  label: context.tr('inbound_mailbox_allow_clients'),
                  help: context.tr('inbound_mailbox_allow_clients_help'),
                  value: draft.inboundMailboxAllowClients,
                  onChanged: (v) => vm.updateCompany(
                    (c) => c.copyWith(inboundMailboxAllowClients: v),
                  ),
                ),
                SettingsTextField(
                  key: const ValueKey('inbound_mailbox_whitelist'),
                  labelText: context.tr('inbound_mailbox_whitelist'),
                  helperText: context.tr('inbound_mailbox_whitelist_help'),
                  helperMaxLines: 2,
                  initialValue: draft.inboundMailboxWhitelist,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  onChanged: (v) => vm.updateCompany(
                    (c) => c.copyWith(inboundMailboxWhitelist: v),
                  ),
                ),
                SettingsTextField(
                  key: const ValueKey('inbound_mailbox_blacklist'),
                  labelText: context.tr('inbound_mailbox_blacklist'),
                  helperText: context.tr('inbound_mailbox_blacklist_help'),
                  helperMaxLines: 2,
                  initialValue: draft.inboundMailboxBlacklist,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  onChanged: (v) => vm.updateCompany(
                    (c) => c.copyWith(inboundMailboxBlacklist: v),
                  ),
                ),
                SettingsSwitchTile(
                  label: context.tr('inbound_mailbox_allow_unknown'),
                  help: context.tr('inbound_mailbox_allow_unknown_help'),
                  value: draft.inboundMailboxAllowUnknown,
                  onChanged: (v) => vm.updateCompany(
                    (c) => c.copyWith(inboundMailboxAllowUnknown: v),
                  ),
                ),
              ],
            ],
          ],
        ),
        FormSection(
          title: context.tr('tax_settings'),
          children: [
            PlainRadioField<bool>(
              label: context.tr('enter_taxes'),
              value: draft.calculateExpenseTaxByAmount,
              options: [
                (value: false, label: context.tr('by_rate')),
                (value: true, label: context.tr('by_amount')),
              ],
              onChanged: (v) => vm.updateCompany(
                (c) => c.copyWith(calculateExpenseTaxByAmount: v),
              ),
            ),
            SettingsSwitchTile(
              label: context.tr('inclusive_taxes'),
              // Leading newline gives the formula examples vertical room under
              // the title — matches the old admin-portal subtitle.
              help:
                  '\n${context.tr('exclusive')}: 100 + 10% = 100 + 10\n'
                  '${context.tr('inclusive')}: 100 + 10% = 90.91 + 9.09',
              value: draft.expenseInclusiveTaxes,
              onChanged: (v) =>
                  vm.updateCompany((c) => c.copyWith(expenseInclusiveTaxes: v)),
            ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/settings/expense_categories'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            icon: const Icon(Icons.category_outlined, size: 18),
            label: Text(context.tr('configure_categories')),
          ),
        ),
      ],
    );
  }
}

/// Company-scope picker for `default_expense_payment_type_id`. A plain
/// [SearchableDropdownField] — not the cascade-aware `Overridable*` variant —
/// because this screen is company-only. Online Payments → Defaults keeps the
/// overridable picker for the same key, since that screen is cascade-aware and
/// is where per-client/group overrides are set.
class _DefaultPaymentTypePicker extends StatelessWidget {
  const _DefaultPaymentTypePicker({required this.vm, required this.services});

  final ExpenseSettingsViewModel vm;
  final Services services;

  @override
  Widget build(BuildContext context) {
    final paymentTypes = services.statics.paymentTypes.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final currentId = vm.settings.defaultExpensePaymentTypeId;
    PaymentType? selected;
    for (final p in paymentTypes) {
      if (p.id == currentId) {
        selected = p;
        break;
      }
    }
    final errs = vm.fieldErrors['default_expense_payment_type_id'];
    final errorText = (errs != null && errs.isNotEmpty) ? errs.first : null;
    return SearchableDropdownField<PaymentType>(
      // `default_expense_payment_type`, not `default_payment_type` — the latter
      // is the *invoice* default that Online Payments → Defaults edits.
      label: context.tr('default_expense_payment_type'),
      items: paymentTypes,
      initialValue: selected,
      displayString: (p) => p.name,
      idOf: (p) => p.id,
      errorText: errorText,
      onChanged: (item) => vm.updateSettings(
        (s) => s.copyWith(defaultExpensePaymentTypeId: item?.id),
      ),
    );
  }
}
