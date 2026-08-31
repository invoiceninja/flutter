import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/settings_search_catalog.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/authorization_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/client_portal_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/customize_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/messages_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/registration_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/clients_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/company_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/expenses_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/invoices_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/payments_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/products_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/projects_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/tasks_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/users_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/vendors_screen.dart';
import 'package:admin/ui/features/settings/views/basic/device_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/keyboard_shortcuts_screen.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/address_screen.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/company_details_screen.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/defaults_screen.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/documents_screen.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/logo_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/danger_zone_screen.dart';
import 'package:admin/ui/features/settings/views/basic/backup_restore/widgets/backup_tab.dart';
import 'package:admin/ui/features/settings/views/basic/backup_restore/widgets/restore_tab.dart';
import 'package:admin/ui/features/settings/views/basic/expense_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/import_export_screen.dart';
import 'package:admin/ui/features/settings/views/basic/product_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/task_settings_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/email_settings/email_settings_body.dart';
import 'package:admin/ui/features/settings/views/basic/tax_settings_body.dart';
import 'package:admin/ui/features/settings/views/basic/workflow_settings/workflow_settings_invoices_body.dart';
import 'package:admin/ui/features/settings/views/basic/workflow_settings/workflow_settings_quotes_body.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/templates_reminders_body.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_edit_screen.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_list_screen.dart';

/// Verifies that the per-screen `kSearchKeys` constants stay in sync with the
/// fields actually rendered by each screen. The catch is simple: every key in
/// a screen's `kSearchKeys` must appear as either an `apiKey: '<key>'` or a
/// `context.tr('<key>')` reference in that screen's source. If a developer
/// removes a field but forgets to update the keys list, this test fails.
///
/// The test scans the source file as text rather than pumping the widget —
/// pumping a settings screen requires a full `Services` graph and is left to
/// follow-up work. The text scan still catches the dominant drift case
/// (stale key after field removal) without that scaffolding cost.
///
/// To extend coverage to a new screen: add a `_TabUnderTest` entry with the
/// screen's source path(s) and its `kSearchKeys` constant. `sourcePaths`
/// accepts multiple files for screens whose rendering surface spans more
/// than one widget (e.g. Tax Settings, where the body, picker, and
/// subregion dialog each render distinct labels).
void main() {
  group('search catalog consistency', () {
    test('kSettingsSearchCatalog[company_details] equals the union of '
        'per-tab kSearchKeys constants', () {
      final union = <String>[
        ...kCompanyDetailsDetailsSearchKeys,
        ...kCompanyDetailsAddressSearchKeys,
        ...kCompanyDetailsLogoSearchKeys,
        ...kCompanyDetailsDefaultsSearchKeys,
        ...kCompanyDetailsDocumentsSearchKeys,
      ];
      expect(
        kSettingsSearchCatalog['company_details'],
        union,
        reason:
            'kSettingsSearchCatalog["company_details"] must aggregate the '
            'per-tab constants via spread. Edit settings_search_catalog.dart '
            'to keep them in sync.',
      );
    });

    test('kSettingsSearchCatalog[custom_fields] equals the union of '
        'per-tab kSearchKeys constants', () {
      final union = <String>[
        'custom_fields',
        ...kCustomFieldsCompanySearchKeys,
        ...kCustomFieldsClientsSearchKeys,
        ...kCustomFieldsProductsSearchKeys,
        ...kCustomFieldsInvoicesSearchKeys,
        ...kCustomFieldsPaymentsSearchKeys,
        ...kCustomFieldsProjectsSearchKeys,
        ...kCustomFieldsTasksSearchKeys,
        ...kCustomFieldsVendorsSearchKeys,
        ...kCustomFieldsExpensesSearchKeys,
        ...kCustomFieldsUsersSearchKeys,
      ];
      expect(
        kSettingsSearchCatalog['custom_fields'],
        union,
        reason:
            'kSettingsSearchCatalog["custom_fields"] must aggregate the '
            'per-tab constants via spread. Edit settings_search_catalog.dart '
            'to keep them in sync.',
      );
    });

    test('kSettingsSearchCatalog[client_portal] equals the union of '
        'per-tab kSearchKeys constants', () {
      final union = <String>[
        ...kClientPortalSettingsSearchKeys,
        ...kClientPortalAuthorizationSearchKeys,
        ...kClientPortalRegistrationSearchKeys,
        ...kClientPortalMessagesSearchKeys,
        ...kClientPortalCustomizeSearchKeys,
      ];
      expect(
        kSettingsSearchCatalog['client_portal'],
        union,
        reason:
            'kSettingsSearchCatalog["client_portal"] must aggregate the '
            'per-tab constants via spread. Edit settings_search_catalog.dart '
            'to keep them in sync.',
      );
    });

    test('kSettingsSearchCatalog[workflow_settings] equals the union of '
        'per-tab kSearchKeys constants', () {
      final union = <String>[
        ...kWorkflowSettingsInvoicesSearchKeys,
        ...kWorkflowSettingsQuotesSearchKeys,
      ];
      expect(
        kSettingsSearchCatalog['workflow_settings'],
        union,
        reason:
            'kSettingsSearchCatalog["workflow_settings"] must aggregate the '
            'per-tab constants via spread. Edit settings_search_catalog.dart '
            'to keep them in sync.',
      );
    });

    for (final tab in _tabsUnderTest) {
      test('${tab.label}: every kSearchKeys entry is referenced in source', () {
        final source = tab.sourcePaths
            .map((p) => File(p).readAsStringSync())
            .join('\n');
        final referenced = _extractReferencedKeys(source);
        for (final key in tab.keys) {
          expect(
            referenced.contains(key),
            isTrue,
            reason:
                'kSearchKeys for ${tab.label} declares "$key" but no '
                'context.tr("$key") or apiKey: "$key" reference exists in '
                '${tab.sourcePaths.join(", ")}. Either render the field or '
                'drop the key.',
          );
        }
      });
    }
  });
}

class _TabUnderTest {
  const _TabUnderTest({
    required this.label,
    required this.sourcePaths,
    required this.keys,
  });

  final String label;
  final List<String> sourcePaths;
  final List<String> keys;
}

final List<_TabUnderTest> _tabsUnderTest = [
  const _TabUnderTest(
    label: 'device_settings',
    // The six long-standing keys are rendered across the screen and its two
    // extracted tiles; the counter keys live in the section widget, and every
    // badge-mode label is a `labelKey:` literal in the domain catalog.
    sourcePaths: [
      'lib/ui/features/settings/views/basic/device_settings_screen.dart',
      'lib/ui/features/settings/widgets/customize_colors_section.dart',
      'lib/ui/features/settings/widgets/biometric_toggle_tile.dart',
      'lib/ui/features/settings/widgets/confirm_actions_tile.dart',
      'lib/ui/features/settings/widgets/contacts_sync_section.dart',
      'lib/ui/features/settings/widgets/list_status_tabs_section.dart',
      'lib/ui/features/settings/widgets/sidebar_counters_section.dart',
      'lib/domain/sidebar_badge_modes.dart',
    ],
    keys: kDeviceSettingsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'keyboard_shortcuts',
    // The per-action rows render `context.tr(def.labelKey)`, so the labels
    // live in the catalog rather than the screen — both files are the source.
    sourcePaths: [
      'lib/ui/features/settings/views/basic/keyboard_shortcuts_screen.dart',
      'lib/app/shortcuts/shortcut_catalog.dart',
    ],
    keys: kKeyboardShortcutsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'company_details/details',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/company_details/company_details_screen.dart',
    ],
    keys: kCompanyDetailsDetailsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'company_details/address',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/company_details/address_screen.dart',
    ],
    keys: kCompanyDetailsAddressSearchKeys,
  ),
  const _TabUnderTest(
    label: 'company_details/logo',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/company_details/logo_screen.dart',
    ],
    keys: kCompanyDetailsLogoSearchKeys,
  ),
  const _TabUnderTest(
    label: 'company_details/defaults',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/company_details/defaults_screen.dart',
    ],
    keys: kCompanyDetailsDefaultsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'company_details/documents',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/company_details/documents_screen.dart',
    ],
    keys: kCompanyDetailsDocumentsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'custom_fields/company',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/custom_fields/company_screen.dart',
      'lib/ui/features/settings/widgets/custom_field_row.dart',
    ],
    keys: kCustomFieldsCompanySearchKeys,
  ),
  const _TabUnderTest(
    label: 'custom_fields/clients',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/custom_fields/clients_screen.dart',
      'lib/ui/features/settings/widgets/custom_field_row.dart',
    ],
    keys: kCustomFieldsClientsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'custom_fields/products',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/custom_fields/products_screen.dart',
      'lib/ui/features/settings/widgets/custom_field_row.dart',
    ],
    keys: kCustomFieldsProductsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'custom_fields/invoices',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/custom_fields/invoices_screen.dart',
      'lib/ui/features/settings/widgets/custom_field_row.dart',
    ],
    keys: kCustomFieldsInvoicesSearchKeys,
  ),
  const _TabUnderTest(
    label: 'custom_fields/payments',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/custom_fields/payments_screen.dart',
      'lib/ui/features/settings/widgets/custom_field_row.dart',
    ],
    keys: kCustomFieldsPaymentsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'custom_fields/projects',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/custom_fields/projects_screen.dart',
      'lib/ui/features/settings/widgets/custom_field_row.dart',
    ],
    keys: kCustomFieldsProjectsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'custom_fields/tasks',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/custom_fields/tasks_screen.dart',
      'lib/ui/features/settings/widgets/custom_field_row.dart',
    ],
    keys: kCustomFieldsTasksSearchKeys,
  ),
  const _TabUnderTest(
    label: 'custom_fields/vendors',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/custom_fields/vendors_screen.dart',
      'lib/ui/features/settings/widgets/custom_field_row.dart',
    ],
    keys: kCustomFieldsVendorsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'custom_fields/expenses',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/custom_fields/expenses_screen.dart',
      'lib/ui/features/settings/widgets/custom_field_row.dart',
    ],
    keys: kCustomFieldsExpensesSearchKeys,
  ),
  const _TabUnderTest(
    label: 'custom_fields/users',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/custom_fields/users_screen.dart',
      'lib/ui/features/settings/widgets/custom_field_row.dart',
    ],
    keys: kCustomFieldsUsersSearchKeys,
  ),
  // Tax Settings — rendering surface spans the body widget + the slot
  // picker + the regional subregion edit dialog. The labels for `tax_name`,
  // `tax_rate`, and `reduced_rate` live in the dialog; everything else is
  // in the body.
  const _TabUnderTest(
    label: 'tax_settings',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/tax_settings_body.dart',
      'lib/ui/features/settings/widgets/tax_rate_picker.dart',
      'lib/ui/features/settings/widgets/subregion_edit_dialog.dart',
    ],
    keys: kTaxSettingsSearchKeys,
  ),
  // Email Settings — body + SMTP card + OAuth picker each render distinct
  // labels (host/port/encryption live in the SMTP card; the gmail/microsoft
  // user labels live in the OAuth picker; everything else is in the body).
  const _TabUnderTest(
    label: 'email_settings',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/email_settings/email_settings_body.dart',
      'lib/ui/features/settings/views/advanced/email_settings/widgets/smtp_mail_driver_card.dart',
      'lib/ui/features/settings/views/advanced/email_settings/widgets/oauth_user_picker.dart',
    ],
    keys: kEmailSettingsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'product_settings',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/product_settings_screen.dart',
    ],
    keys: kProductSettingsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'task_settings',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/task_settings_screen.dart',
    ],
    keys: kTaskSettingsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'expense_settings',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/expense_settings_screen.dart',
    ],
    keys: kExpenseSettingsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'workflow_settings/invoices',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/workflow_settings/workflow_settings_invoices_body.dart',
    ],
    keys: kWorkflowSettingsInvoicesSearchKeys,
  ),
  const _TabUnderTest(
    label: 'workflow_settings/quotes',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/workflow_settings/workflow_settings_quotes_body.dart',
    ],
    keys: kWorkflowSettingsQuotesSearchKeys,
  ),
  const _TabUnderTest(
    label: 'backup_restore/backup',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/backup_restore/widgets/backup_tab.dart',
    ],
    keys: kBackupTabSearchKeys,
  ),
  const _TabUnderTest(
    label: 'backup_restore/restore',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/backup_restore/widgets/restore_tab.dart',
    ],
    keys: kRestoreTabSearchKeys,
  ),
  const _TabUnderTest(
    label: 'import_export',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/import_export_screen.dart',
    ],
    keys: kImportExportSearchKeys,
  ),
  const _TabUnderTest(
    label: 'account_management/danger_zone',
    sourcePaths: [
      'lib/ui/features/settings/views/basic/account_management/danger_zone_screen.dart',
    ],
    keys: kAccountManagementDangerZoneSearchKeys,
  ),
  const _TabUnderTest(
    label: 'client_portal/settings',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/client_portal/client_portal_screen.dart',
      'lib/ui/features/settings/views/advanced/client_portal/widgets/subdomain_field.dart',
      'lib/ui/features/settings/views/advanced/client_portal/widgets/portal_url_display.dart',
    ],
    keys: kClientPortalSettingsSearchKeys,
  ),
  const _TabUnderTest(
    label: 'client_portal/authorization',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/client_portal/authorization_screen.dart',
    ],
    keys: kClientPortalAuthorizationSearchKeys,
  ),
  const _TabUnderTest(
    label: 'client_portal/registration',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/client_portal/registration_screen.dart',
      'lib/ui/features/settings/views/advanced/client_portal/widgets/portal_url_display.dart',
    ],
    keys: kClientPortalRegistrationSearchKeys,
  ),
  const _TabUnderTest(
    label: 'client_portal/messages',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/client_portal/messages_screen.dart',
    ],
    keys: kClientPortalMessagesSearchKeys,
  ),
  const _TabUnderTest(
    label: 'client_portal/customize',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/client_portal/customize_screen.dart',
    ],
    keys: kClientPortalCustomizeSearchKeys,
  ),
  // Templates & Reminders — body + reminder rule + variables card + preview
  // panel each render distinct labels. The template options table emits the
  // labelKey for each template via `kTemplateOptions`, so the picker source
  // file is included too.
  const _TabUnderTest(
    label: 'templates_and_reminders',
    sourcePaths: [
      'lib/ui/features/settings/views/advanced/templates_reminders/templates_reminders_body.dart',
      'lib/ui/features/settings/views/advanced/templates_reminders/template_options.dart',
      'lib/ui/features/settings/views/advanced/templates_reminders/widgets/reminder_rule_section.dart',
      'lib/ui/features/settings/views/advanced/templates_reminders/widgets/template_variables_card.dart',
      'lib/ui/features/settings/views/advanced/templates_reminders/widgets/template_preview_panel.dart',
    ],
    keys: kTemplatesRemindersSearchKeys,
  ),
  // Payment Links — list + 4-tab edit. Wire shape stays `subscription`
  // but the section is `payment_links` everywhere internal.
  const _TabUnderTest(
    label: 'payment_links',
    sourcePaths: [
      'lib/ui/features/payment_links/views/payment_link_list_screen.dart',
      'lib/ui/features/payment_links/views/payment_link_edit_screen.dart',
      'lib/ui/features/payment_links/widgets/edit/payment_link_overview_tab.dart',
      'lib/ui/features/payment_links/widgets/edit/payment_link_settings_tab.dart',
      'lib/ui/features/payment_links/widgets/edit/payment_link_webhook_tab.dart',
      'lib/ui/features/payment_links/widgets/edit/payment_link_steps_tab.dart',
    ],
    keys: [...kPaymentLinksListSearchKeys, ...kPaymentLinkEditSearchKeys],
  ),
];

// Match both `context.tr` and aliases like `ctx.tr` (used inside
// scaffold callbacks where the param is renamed) and `c.tr`.
final _trKey = RegExp(r"""\w+\.tr\(\s*['"]([\w]+)['"]""");
final _apiKey = RegExp(r"""apiKey:\s*['"]([\w]+)['"]""");
final _labelText = RegExp(r"""labelText:\s*\w+\.tr\(\s*['"]([\w]+)['"]""");
// Wrapper widgets (SettingsTextField, ColumnDefinition, SortOption,
// EntityListBulkAction, FileDropZone, ...) take a `labelKey: 'xxx'` /
// `idleLabelKey: 'xxx'` string and call `context.tr(labelKey)` internally.
// From the source-rendering check's perspective these are equivalent
// references.
final _labelKey = RegExp(r"""(?:idle)?[lL]abelKey:\s*['"]([\w]+)['"]""");

Set<String> _extractReferencedKeys(String source) {
  final keys = <String>{};
  for (final pattern in [_trKey, _apiKey, _labelText, _labelKey]) {
    for (final match in pattern.allMatches(source)) {
      keys.add(match.group(1)!);
    }
  }
  return keys;
}
