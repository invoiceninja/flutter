import 'package:flutter/material.dart';

// The gated-slug sets now live in the central gate module; re-exported here
// so existing `import '.../settings_search_catalog.dart'` call sites that
// reference `kProGatedSettings` / `kEnterpriseGatedSettings` keep compiling.
export 'package:admin/domain/plan_gate.dart'
    show kProGatedSettings, kEnterpriseGatedSettings;

import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/bank_accounts/views/bank_account_list_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/plan_screen.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/address_screen.dart';
import 'package:admin/ui/features/transaction_rules/views/transaction_rule_list_screen.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/company_details_screen.dart';
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
import 'package:admin/ui/features/settings/views/advanced/debug_panel_search_keys.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_body.dart';
import 'package:admin/ui/features/settings/views/advanced/email_settings/email_settings_body.dart';
import 'package:admin/ui/features/settings/views/advanced/schedules_screen.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/defaults_screen.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/documents_screen.dart';
import 'package:admin/ui/features/settings/views/basic/expense_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/company_details/logo_screen.dart';
import 'package:admin/ui/features/settings/views/basic/import_export_screen.dart';
import 'package:admin/ui/features/settings/views/basic/keyboard_shortcuts_screen.dart';
import 'package:admin/ui/features/settings/views/basic/localization/custom_labels_screen.dart';
import 'package:admin/ui/features/settings/views/basic/localization/localization_screen.dart';
import 'package:admin/ui/features/settings/views/basic/online_payments/online_payments_defaults_body.dart';
import 'package:admin/ui/features/settings/views/basic/online_payments/online_payments_emails_body.dart';
import 'package:admin/ui/features/settings/views/basic/online_payments/online_payments_general_body.dart';
import 'package:admin/ui/features/settings/views/basic/product_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/task_settings_screen.dart';
import 'package:admin/ui/features/settings/views/basic/tax_settings_body.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/connect_screen.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/details_screen.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/notifications_screen.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/password_screen.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/preferences_screen.dart';
import 'package:admin/ui/features/settings/views/basic/user_details/two_factor_screen.dart';
import 'package:admin/ui/features/settings/views/basic/workflow_settings/workflow_settings_invoices_body.dart';
import 'package:admin/ui/features/settings/views/basic/workflow_settings/workflow_settings_quotes_body.dart';
import 'package:admin/ui/features/settings/views/advanced/group_settings_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/templates_reminders_body.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_edit_screen.dart';
import 'package:admin/ui/features/payment_links/views/payment_link_list_screen.dart';
import 'package:admin/ui/features/settings/views/basic/device_settings_screen.dart';

/// Single source of truth for the settings sidebar layout and the in-app
/// settings search. `SettingsListSidebar` reads `kSettingsSections` to render
/// its tiles; `searchSettings` walks `kSettingsSearchCatalog` to surface
/// individual fields.
///
/// **Colocation pattern (preferred):** the per-screen search key lists live
/// next to the screens themselves (e.g. `kCompanyDetailsAddressSearchKeys` in
/// `address_screen.dart`). The catalog entry is then a spread of those
/// constants. Editing a field and forgetting to update keys now requires
/// editing the same file. Sections backed by placeholder screens keep their
/// keys inline below until the real screens land.
class SettingsSectionDef {
  const SettingsSectionDef({
    required this.slug,
    required this.titleKey,
    required this.icon,
    required this.route,
    required this.isBasic,
    this.clientEditable = true,
    this.enabledBy,
    this.adminOnly = false,
  });

  /// Stable identifier; matches the leading path segment after `/settings/`.
  final String slug;

  /// Localization key for the section's display name. Usually equals `slug`,
  /// but some routes intentionally diverge (e.g. slug `users` is displayed as
  /// "User Management").
  final String titleKey;

  final IconData icon;
  final String route;
  final bool isBasic;

  /// Whether this section appears in the sidebar when the user is editing
  /// settings scoped to a client. Sections that only make sense at the
  /// company level (e.g. Account Management, Backup, Device Settings) are
  /// marked `false` here and hidden by [SettingsListSidebar]. Mirrors
  /// admin-portal's `EntityType.client` filtering on company-only sections.
  final bool clientEditable;

  /// Modules that keep this section visible. `null` ⇒ always visible. The
  /// section shows when **any** listed module is enabled (so a multi-tab
  /// shell like Workflow Settings stays as long as one of its tabs applies);
  /// it's hidden only when every listed module is off for the company.
  final List<EnabledModule>? enabledBy;

  /// When true, the section is visible only to admin/owner users — mirrors
  /// React's `Guard` on `/settings/system_logs`. Enforced at render time by
  /// the sidebar (`inScope`) and the settings search (`_buildResults`); the
  /// static catalog stays complete so search_catalog_consistency_test passes.
  final bool adminOnly;

  /// True when this section should appear for a company with the given
  /// [enabledModules] mask. Sections without [enabledBy] are always visible.
  /// A `0` mask means every module is off, so module-gated sections are hidden
  /// — matching `isEntityModuleEnabledForCompany`.
  bool isVisibleFor(int enabledModules) {
    final gates = enabledBy;
    if (gates == null || gates.isEmpty) return true;
    return gates.any((m) => isModuleEnabled(enabledModules, m));
  }
}

const kSettingsSections = <SettingsSectionDef>[
  // Basic
  SettingsSectionDef(
    slug: 'company_details',
    titleKey: 'company_details',
    icon: Icons.business_outlined,
    route: '/settings/company_details',
    isBasic: true,
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'user_details',
    titleKey: 'user_details',
    icon: Icons.person_outline,
    route: '/settings/user_details',
    isBasic: true,
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'localization',
    titleKey: 'localization',
    icon: Icons.language_outlined,
    route: '/settings/localization',
    isBasic: true,
  ),
  SettingsSectionDef(
    slug: 'online_payments',
    titleKey: 'payment_settings',
    icon: Icons.payments_outlined,
    route: '/settings/online_payments',
    isBasic: true,
  ),
  SettingsSectionDef(
    slug: 'tax_settings',
    titleKey: 'tax_settings',
    icon: Icons.percent_outlined,
    route: '/settings/tax_settings',
    isBasic: true,
  ),
  SettingsSectionDef(
    slug: 'product_settings',
    titleKey: 'product_settings',
    icon: Icons.inventory_2_outlined,
    route: '/settings/product_settings',
    isBasic: true,
    // Product settings are all top-level `company.*` fields with no per-client
    // override (the screen uses `SettingsCompanyScopedHost`). Company-only,
    // like Company Details — matches the React app.
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'task_settings',
    titleKey: 'task_settings',
    icon: Icons.task_alt_outlined,
    route: '/settings/task_settings',
    isBasic: true,
    enabledBy: [EnabledModule.tasks],
  ),
  // Tags span tasks + projects; company-level + admin-managed (the server
  // gates create/update to admins). The screen's toggle switches entity type.
  SettingsSectionDef(
    slug: 'tags',
    titleKey: 'tags',
    icon: Icons.local_offer_outlined,
    route: '/settings/tags',
    isBasic: true,
    enabledBy: [EnabledModule.tasks, EnabledModule.projects],
    clientEditable: false,
    adminOnly: true,
  ),
  SettingsSectionDef(
    slug: 'expense_settings',
    titleKey: 'expense_settings',
    icon: Icons.receipt_long_outlined,
    route: '/settings/expense_settings',
    isBasic: true,
    enabledBy: [EnabledModule.expenses],
    // Company-only (like Product Settings): all fields are top-level `company.*`
    // and the one `settings.*` key (default_expense_payment_type_id) is written
    // at company scope here. Its per-client override lives in Online Payments →
    // Defaults, so hide this entry while editing in client/group scope.
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'workflow_settings',
    titleKey: 'workflow_settings',
    icon: Icons.account_tree_outlined,
    route: '/settings/workflow_settings',
    isBasic: true,
    // Invoices + Quotes tabs — keep the section while either applies.
    enabledBy: [EnabledModule.invoices, EnabledModule.quotes],
  ),
  SettingsSectionDef(
    slug: 'account_management',
    titleKey: 'account_management',
    icon: Icons.manage_accounts_outlined,
    route: '/settings/account_management',
    isBasic: true,
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'backup_restore',
    titleKey: 'backup_restore',
    icon: Icons.backup_outlined,
    route: '/settings/backup_restore',
    isBasic: true,
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'import_export',
    titleKey: 'import_export',
    icon: Icons.import_export_outlined,
    route: '/settings/import_export',
    isBasic: true,
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'device_settings',
    titleKey: 'device_settings',
    icon: Icons.devices_outlined,
    route: '/settings/device_settings',
    isBasic: true,
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'keyboard_shortcuts',
    titleKey: 'keyboard_shortcuts',
    icon: Icons.keyboard_outlined,
    route: '/settings/keyboard_shortcuts',
    isBasic: true,
    clientEditable: false,
  ),
  // Advanced
  SettingsSectionDef(
    slug: 'invoice_design',
    titleKey: 'invoice_design',
    icon: Icons.design_services_outlined,
    route: '/settings/invoice_design',
    isBasic: false,
  ),
  SettingsSectionDef(
    slug: 'custom_fields',
    titleKey: 'custom_fields',
    icon: Icons.edit_note_outlined,
    route: '/settings/custom_fields',
    isBasic: false,
    // Custom Fields are company-wide; hide the sidebar entry while the user
    // is editing in client scope (the scope banner doesn't apply here).
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'generated_numbers',
    titleKey: 'generated_numbers',
    icon: Icons.format_list_numbered,
    route: '/settings/generated_numbers',
    isBasic: false,
  ),
  SettingsSectionDef(
    slug: 'client_portal',
    titleKey: 'client_portal',
    icon: Icons.web_outlined,
    route: '/settings/client_portal',
    isBasic: false,
  ),
  SettingsSectionDef(
    slug: 'e_invoice',
    titleKey: 'e_invoicing',
    icon: Icons.electric_bolt_outlined,
    route: '/settings/e_invoice',
    isBasic: false,
  ),
  SettingsSectionDef(
    slug: 'email_settings',
    titleKey: 'email_settings',
    icon: Icons.mail_outline,
    route: '/settings/email_settings',
    isBasic: false,
  ),
  SettingsSectionDef(
    slug: 'templates_and_reminders',
    titleKey: 'templates_and_reminders',
    icon: Icons.notifications_outlined,
    route: '/settings/templates_and_reminders',
    isBasic: false,
  ),
  SettingsSectionDef(
    slug: 'bank_accounts',
    titleKey: 'bank_accounts',
    icon: Icons.account_balance_outlined,
    route: '/settings/bank_accounts',
    isBasic: false,
  ),
  SettingsSectionDef(
    slug: 'group_settings',
    titleKey: 'group_settings',
    icon: Icons.group_work_outlined,
    route: '/settings/group_settings',
    isBasic: false,
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'payment_links',
    titleKey: 'payment_links',
    icon: Icons.link_outlined,
    route: '/settings/payment_links',
    isBasic: false,
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'schedules',
    titleKey: 'schedules',
    icon: Icons.schedule_outlined,
    route: '/settings/schedules',
    isBasic: false,
    clientEditable: false,
  ),
  // Slug intentionally diverges from titleKey: the route is `users` but the
  // user-facing label is "User Management".
  SettingsSectionDef(
    slug: 'users',
    titleKey: 'user_management',
    icon: Icons.supervised_user_circle_outlined,
    route: '/settings/users',
    isBasic: false,
    clientEditable: false,
  ),
  SettingsSectionDef(
    slug: 'system_logs',
    titleKey: 'system_logs',
    icon: Icons.terminal_outlined,
    route: '/settings/system_logs',
    isBasic: false,
    clientEditable: false,
    adminOnly: true,
  ),
];

final Map<String, SettingsSectionDef> kSettingsSectionsBySlug = {
  for (final s in kSettingsSections) s.slug: s,
};

// `kProGatedSettings` / `kEnterpriseGatedSettings` moved to
// `package:admin/domain/plan_gate.dart` (single source of truth) and are
// re-exported from this library (see the `export` directive above).

/// Searchable fields per section. Keys are section slugs from
/// `kSettingsSections`. Values are localization keys (the same keys you pass
/// to `context.tr(...)` when rendering the field's label).
///
/// **Keep this in sync** when you add or rename fields on a settings screen —
/// it's the only way search will surface them.
const kSettingsSearchCatalog = <String, List<String>>{
  'company_details': [
    ...kCompanyDetailsDetailsSearchKeys,
    ...kCompanyDetailsAddressSearchKeys,
    ...kCompanyDetailsLogoSearchKeys,
    ...kCompanyDetailsDefaultsSearchKeys,
    ...kCompanyDetailsDocumentsSearchKeys,
  ],
  'user_details': [
    ...kUserDetailsDetailsSearchKeys,
    ...kUserDetailsPasswordSearchKeys,
    ...kUserDetailsConnectSearchKeys,
    ...kUserDetailsTwoFactorSearchKeys,
    ...kUserDetailsNotificationsSearchKeys,
    ...kUserDetailsPreferencesSearchKeys,
  ],
  'localization': [
    ...kLocalizationSettingsSearchKeys,
    ...kLocalizationCustomLabelsSearchKeys,
  ],
  'online_payments': [
    ...kOnlinePaymentsGeneralSearchKeys,
    ...kOnlinePaymentsDefaultsSearchKeys,
    ...kOnlinePaymentsEmailsSearchKeys,
  ],
  'tax_settings': [...kTaxSettingsSearchKeys],
  'product_settings': [...kProductSettingsSearchKeys],
  'task_settings': [...kTaskSettingsSearchKeys],
  'expense_settings': [...kExpenseSettingsSearchKeys],
  'workflow_settings': [
    ...kWorkflowSettingsInvoicesSearchKeys,
    ...kWorkflowSettingsQuotesSearchKeys,
  ],
  'account_management': [
    // Plan — spread from the screen's own constant rather than duplicated by
    // hand, so `search_catalog_consistency_test` can hold the two ends
    // together. (The remaining tabs below have no co-located list yet.)
    ...kAccountManagementPlanSearchKeys,
    // Overview
    'account_id',
    'email',
    'set_default_company',
    'activate_company',
    'enable_pdf_markdown',
    'enable_email_markdown',
    'include_drafts',
    'include_deleted',
    'force_full_sync',
    // Enabled modules
    'enabled_modules',
    // Integrations hub tiles + the Analytics screen's GA / Matomo fields, now
    // reached via Account Management → Integrations → Analytics (the top-level
    // Integrations section was removed to match React).
    'api_tokens',
    'api_webhooks',
    'api_docs',
    'analytics',
    'google_analytics_tracking_id',
    'matomo_id',
    'matomo_url',
    'quickbooks',
    // Security
    'password_timeout',
    'web_session_timeout',
    'require_password_with_social_login',
    'end_all_sessions',
    // Referral
    'referral_program',
    'referral_code',
    // Danger zone
    'purge_data',
    'delete_company',
    'cancel_account',
  ],
  'backup_restore': [
    'backup',
    'restore',
    'export',
    'import_settings',
    'import_data',
    'company_backup_file',
  ],
  'import_export': [...kImportExportSearchKeys],
  'device_settings': [...kDeviceSettingsSearchKeys],
  'keyboard_shortcuts': [...kKeyboardShortcutsSearchKeys],
  'invoice_design': [
    // General Settings tab — design pickers
    'invoice_design',
    'quote_design',
    'credit_design',
    'purchase_order_design',
    'delivery_note_design',
    'statement_design',
    'payment_receipt_design',
    'payment_refund_design',
    // General Settings tab — layout / typography
    'page_layout',
    'page_size',
    'font_size',
    'logo_size',
    'primary_font',
    'secondary_font',
    'primary_color',
    'secondary_color',
    // General Settings tab — document options
    'show_paid_stamp',
    'show_shipping_address',
    'share_invoice_quote_columns',
    'empty_columns',
    'page_numbering',
    'page_numbering_alignment',
    'invoice_embed_documents',
    // PDF-variable tabs
    'client_details',
    'company_details',
    'company_address',
    'invoice_details',
    'quote_details',
    'credit_details',
    'vendor_details',
    'purchase_order_details',
    'product_columns',
    'quote_product_columns',
    'task_columns',
    'total_fields',
    'custom_designs',
    'template',
    // Phase 3d: WYSIWYG visual designer — discoverable from settings
    // search; routed via Custom Designs → + New → "Visual designer."
    'visual_designer',
    'document_settings',
    'page_margin',
    'embed_documents',
    'hide_empty_columns',
  ],
  'custom_fields': [
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
  ],
  'generated_numbers': [
    'number_padding',
    'number_pattern',
    'number_counter',
    'generate_number',
    'recurring_prefix',
    'reset_counter',
    'next_reset',
    'shared_invoice_quote_counter',
    'shared_invoice_credit_counter',
    'client_number',
    'invoice_number',
    'quote_number',
    'credit_number',
    'payment_number',
    'project_number',
    'task_number',
    'vendor_number',
    'purchase_order_number',
    'expense_number',
  ],
  'client_portal': [
    ...kClientPortalSettingsSearchKeys,
    ...kClientPortalAuthorizationSearchKeys,
    ...kClientPortalRegistrationSearchKeys,
    ...kClientPortalMessagesSearchKeys,
    ...kClientPortalCustomizeSearchKeys,
  ],
  'e_invoice': kEInvoiceSearchKeys,
  'email_settings': [...kEmailSettingsSearchKeys],
  'templates_and_reminders': kTemplatesRemindersSearchKeys,
  'bank_accounts': [
    ...kBankAccountsListSearchKeys,
    ...kTransactionRulesListSearchKeys,
  ],
  'group_settings': [...kGroupSettingsSearchKeys],
  'payment_links': [
    ...kPaymentLinksListSearchKeys,
    ...kPaymentLinkEditSearchKeys,
  ],
  'schedules': [...kSchedulesSearchKeys],
  'users': [
    'user_management',
    'new_user',
    'edit_user',
    'first_name',
    'last_name',
    'email',
    'phone',
    'permissions',
    'administrator',
    'notifications',
    'view_dashboard',
    'view_reports',
    'disable_emails',
    'resend_email',
    'remove_user',
  ],
  'system_logs': ['system_logs', ...kDebugPanelSearchKeys],
};

/// Settings *fields* that only exist on the hosted platform. Filtered out of
/// search results for self-hosted sessions (issue #27) so a search for
/// "referral" can't lead to a tab that isn't there — `AccountManagementShell`
/// hides the Referral Program tab entirely on self-hosted.
///
/// The section-level gates (`enabledBy` / `adminOnly` / `clientEditable`)
/// can't express this: the owning section, Account Management, is always
/// visible. Filtering happens at query time — the static catalog stays
/// complete, same as for `adminOnly`.
const Set<String> kHostedOnlySettingsFields = {
  'referral_program',
  'referral_code',
};

/// A single field match returned by [searchSettings].
class SettingsSearchHit {
  const SettingsSearchHit({required this.fieldKey, required this.section});

  /// Localization key of the matching field (e.g. `'vat_number'`).
  final String fieldKey;

  /// Section that owns the field — used to render the subtitle/icon and to
  /// navigate when the result is tapped.
  final SettingsSectionDef section;
}

/// Returns every catalog entry whose *localized* label contains [query]
/// (case-insensitive). An empty / whitespace-only query returns the full
/// flattened catalog so the search list is discoverable when the user first
/// opens it.
List<SettingsSearchHit> searchSettings(String query, Localization l10n) {
  final q = query.trim().toLowerCase();
  final hits = <SettingsSearchHit>[];
  for (final entry in kSettingsSearchCatalog.entries) {
    final section = kSettingsSectionsBySlug[entry.key];
    if (section == null) continue;
    for (final fieldKey in entry.value) {
      if (q.isEmpty || l10n.lookup(fieldKey).toLowerCase().contains(q)) {
        hits.add(SettingsSearchHit(fieldKey: fieldKey, section: section));
      }
    }
  }
  return hits;
}
