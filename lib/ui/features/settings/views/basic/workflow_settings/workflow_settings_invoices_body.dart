import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Invoices tab — field labels surfaced by the in-app search. Combined with
/// `kWorkflowSettingsQuotesSearchKeys` in `settings_search_catalog.dart` under
/// the `workflow_settings` section.
const kWorkflowSettingsInvoicesSearchKeys = <String>[
  'auto_email_invoice',
  'stop_on_unpaid',
  'auto_archive_paid_invoices',
  'auto_archive_cancelled_invoices',
  'lock_invoices',
  'global_tag_inheritance',
];

/// Invoice-side workflow toggles. Four cascade-aware booleans (`settings.*`)
/// plus the lock-invoices enum dropdown. The fifth row,
/// `stop_on_unpaid_recurring`, is a top-level `Company` field and only
/// renders at company scope.
///
/// A separate "Tags" section hosts the `global_tag_inheritance` toggle. The
/// server reads it company-level via `Company::getSetting()` (no client/group
/// cascade — the field isn't in `ClientSettings`/`GroupSettings`), so like
/// `stop_on_unpaid_recurring` it renders only at company scope. The server
/// applies the actual tag cascade on entity create; the client only persists
/// the flag.
///
/// `lock_invoices` is force-locked to `when_sent` when the Spanish VeriFactu
/// e-invoice integration is active (`settings.e_invoice_type == 'VERIFACTU'`)
/// — same rule the React client enforces.
class WorkflowSettingsInvoicesBody extends StatelessWidget {
  const WorkflowSettingsInvoicesBody({super.key});

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final scope = context.watch<SettingsLevelController>();
    final tokens = context.inTheme;

    final isCompanyScope = scope.isCompany;
    final isVerifactu = host.settings.eInvoiceType == 'VERIFACTU';
    final lockValue =
        host.settings.lockInvoices ?? (isVerifactu ? 'when_sent' : 'off');

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('invoice_workflow'),
          children: [
            OverridableSwitchField(
              label: context.tr('auto_email_invoice'),
              apiKey: 'auto_email_invoice',
              subtitle: context.tr('auto_email_invoice_help'),
            ),
            if (isCompanyScope)
              SwitchListTile(
                title: Text(context.tr('stop_on_unpaid')),
                subtitle: Text(context.tr('stop_on_unpaid_help')),
                value: host.draft?.stopOnUnpaidRecurring ?? false,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(stopOnUnpaidRecurring: v),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            const Divider(),
            // Label key is `auto_archive_paid_invoices` (the user-facing
            // string the legacy admin-portal and React clients show), not
            // `auto_archive_invoice` (the wire key). Settings cascade still
            // writes to the wire-keyed binding.
            OverridableSwitchField(
              label: context.tr('auto_archive_paid_invoices'),
              apiKey: 'auto_archive_invoice',
              subtitle: context.tr('auto_archive_paid_invoices_help'),
            ),
            OverridableSwitchField(
              label: context.tr('auto_archive_cancelled_invoices'),
              apiKey: 'auto_archive_invoice_cancelled',
              subtitle: context.tr('auto_archive_cancelled_invoices_help'),
            ),
            const Divider(),
            OverridableDropdownField<String>(
              label: context.tr('lock_invoices'),
              apiKey: 'lock_invoices',
              value: lockValue,
              items: _lockOptions(context),
              helperText: context.tr('lock_invoices_help'),
              // Null `onChanged` greys out the dropdown — VeriFactu locks the
              // value server-side so the field becomes read-only.
              onChanged: isVerifactu
                  ? null
                  : (v) =>
                        host.updateSettings((s) => s.copyWith(lockInvoices: v)),
            ),
            if (isVerifactu)
              Padding(
                padding: EdgeInsets.only(top: InSpacing.xs),
                child: Text(
                  context.tr('verifactu_locks_invoices'),
                  style: TextStyle(
                    color: tokens.ink3,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        // Company-scope only: the server reads this via `Company::getSetting()`
        // (no client/group cascade — the field isn't in ClientSettings /
        // GroupSettings), so a per-client override would be silently ignored.
        // Same company-only treatment as `stop_on_unpaid` above.
        if (isCompanyScope)
          FormSection(
            title: context.tr('tags'),
            children: [
              OverridableSwitchField(
                label: context.tr('global_tag_inheritance'),
                apiKey: 'global_tag_inheritance',
                subtitle: context.tr('global_tag_inheritance_help'),
              ),
            ],
          ),
      ],
    );
  }

  static const _lockValues = <String>[
    'off',
    'when_sent',
    'when_paid',
    'end_of_month',
  ];

  List<DropdownMenuItem<String>> _lockOptions(BuildContext context) => [
    for (final v in _lockValues)
      DropdownMenuItem<String>(value: v, child: Text(context.tr(v))),
  ];
}
