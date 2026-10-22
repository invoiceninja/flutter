import 'package:flutter/material.dart';

// The gated-slug sets now live in the central gate module; re-exported here
// so existing `import '.../settings_search_catalog.dart'` call sites that
// reference `kProGatedSettings` / `kEnterpriseGatedSettings` keep compiling.
export 'package:admin/domain/plan_gate.dart'
    show kProGatedSettings, kEnterpriseGatedSettings;

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/bank_accounts/views/bank_account_list_screen.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/generated_numbers/bodies/settings_body.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/bodies/general_settings_body.dart';
import 'package:admin/ui/features/settings/views/advanced/tags_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/danger_zone_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/plan_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/quickbooks_screen.dart';
import 'package:admin/ui/features/settings/views/basic/backup_restore/widgets/backup_tab.dart';
import 'package:admin/ui/features/settings/views/basic/backup_restore/widgets/restore_tab.dart';
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
import 'package:admin/ui/core/widgets/spell_check.dart';
import 'package:admin/ui/features/settings/views/basic/device_settings_screen.dart';
import 'package:admin/ui/features/settings/widgets/contacts_sync_section.dart';
import 'package:admin/ui/features/settings/widgets/mobile_app_section.dart';

// Single source of truth for the settings sidebar layout and the in-app
// settings search. `SettingsListSidebar` reads `kSettingsSections` to render
// its tiles; `searchSettings` walks `kSettingsSearchCatalog` to surface
// sections, tabs and individual fields.
//
// **Colocation pattern (preferred):** the per-screen search key lists live
// next to the screens themselves (e.g. `kCompanyDetailsAddressSearchKeys` in
// `address_screen.dart`), and each catalog tab is that constant. Editing a
// field and forgetting to update keys now requires editing the same file. A
// few tabs whose screens never grew a list keep their keys inline below.

/// The public user guide.
const String kDocsBaseUrl = 'https://invoiceninja.github.io/docs';

/// The docs URL of the settings section titled [titleKey], or null. Keyed on
/// the title because that is what every settings page hands its scaffold; a
/// drill-in page (a user's edit screen) carries its own title and so gets no
/// link. The slug matches too: Online Payments' page is titled
/// `online_payments` while its section's sidebar label is `payment_settings`.
String? settingsDocsUrlForTitle(String titleKey) {
  for (final s in kSettingsSections) {
    if (s.titleKey == titleKey || s.slug == titleKey) return s.docsUrl;
  }
  return null;
}

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
    this.docsPath,
  });

  /// This section's page in the public user guide, relative to [kDocsBaseUrl]
  /// (`user-guide/basic-settings#company_details`) — React's settings "Learn
  /// more" map (invoiceninja/ui#3391). Every path and anchor was checked
  /// against the live site; `settings_docs_links_test` pins the shape.
  final String? docsPath;

  /// The full docs URL, or null when the section has none.
  String? get docsUrl => docsPath == null ? null : '$kDocsBaseUrl/$docsPath';

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
    docsPath: 'user-guide/basic-settings#company_details',
  ),
  SettingsSectionDef(
    slug: 'user_details',
    titleKey: 'user_details',
    icon: Icons.person_outline,
    route: '/settings/user_details',
    isBasic: true,
    clientEditable: false,
    docsPath: 'user-guide/basic-settings#user_details',
  ),
  SettingsSectionDef(
    slug: 'localization',
    titleKey: 'localization',
    icon: Icons.language_outlined,
    route: '/settings/localization',
    isBasic: true,
    docsPath: 'user-guide/basic-settings#localization',
  ),
  SettingsSectionDef(
    slug: 'online_payments',
    titleKey: 'payment_settings',
    icon: Icons.payments_outlined,
    route: '/settings/online_payments',
    isBasic: true,
    docsPath: 'user-guide/gateways',
  ),
  SettingsSectionDef(
    slug: 'tax_settings',
    titleKey: 'tax_settings',
    icon: Icons.percent_outlined,
    route: '/settings/tax_settings',
    isBasic: true,
    docsPath: 'user-guide/taxes',
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
    docsPath: 'user-guide/basic-settings#product_settings',
  ),
  SettingsSectionDef(
    slug: 'task_settings',
    titleKey: 'task_settings',
    icon: Icons.task_alt_outlined,
    route: '/settings/task_settings',
    isBasic: true,
    enabledBy: [EnabledModule.tasks],
    docsPath: 'user-guide/basic-settings#task_settings',
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
    docsPath: 'user-guide/basic-settings#tag_settings',
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
    docsPath: 'user-guide/basic-settings#expense_settings',
  ),
  SettingsSectionDef(
    slug: 'workflow_settings',
    titleKey: 'workflow_settings',
    icon: Icons.account_tree_outlined,
    route: '/settings/workflow_settings',
    isBasic: true,
    // Invoices + Quotes tabs — keep the section while either applies.
    enabledBy: [EnabledModule.invoices, EnabledModule.quotes],
    docsPath: 'user-guide/advanced-settings#workflow_settings',
  ),
  SettingsSectionDef(
    slug: 'account_management',
    titleKey: 'account_management',
    icon: Icons.manage_accounts_outlined,
    route: '/settings/account_management',
    isBasic: true,
    clientEditable: false,
    docsPath: 'user-guide/basic-settings#account_management',
  ),
  SettingsSectionDef(
    slug: 'backup_restore',
    titleKey: 'backup_restore',
    icon: Icons.backup_outlined,
    route: '/settings/backup_restore',
    isBasic: true,
    clientEditable: false,
    docsPath: 'advanced-topics/import-and-export#backup-function',
  ),
  SettingsSectionDef(
    slug: 'import_export',
    titleKey: 'import_export',
    icon: Icons.import_export_outlined,
    route: '/settings/import_export',
    isBasic: true,
    clientEditable: false,
    docsPath: 'advanced-topics/import-and-export#import-data',
  ),
  SettingsSectionDef(
    slug: 'device_settings',
    titleKey: 'device_settings',
    icon: Icons.devices_outlined,
    route: '/settings/device_settings',
    isBasic: true,
    clientEditable: false,
    docsPath: 'user-guide/basic-settings#device_settings',
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
    docsPath: 'user-guide/advanced-settings#invoice_design',
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
    docsPath: 'user-guide/advanced-settings#custom_fields',
  ),
  SettingsSectionDef(
    slug: 'generated_numbers',
    titleKey: 'generated_numbers',
    icon: Icons.format_list_numbered,
    route: '/settings/generated_numbers',
    isBasic: false,
    docsPath: 'user-guide/advanced-settings#generated_numbers',
  ),
  SettingsSectionDef(
    slug: 'client_portal',
    titleKey: 'client_portal',
    icon: Icons.web_outlined,
    route: '/settings/client_portal',
    isBasic: false,
    docsPath: 'user-guide/client-portal',
  ),
  SettingsSectionDef(
    slug: 'e_invoice',
    titleKey: 'e_invoicing',
    icon: Icons.electric_bolt_outlined,
    route: '/settings/e_invoice',
    isBasic: false,
    // Company level only (React #3286): the standard, PEPPOL registration
    // and certificates are the company's, not a per-client override.
    clientEditable: false,
    docsPath: 'user-guide/einvoicing',
  ),
  SettingsSectionDef(
    slug: 'email_settings',
    titleKey: 'email_settings',
    icon: Icons.mail_outline,
    route: '/settings/email_settings',
    isBasic: false,
    docsPath: 'user-guide/advanced-settings#email_settings',
  ),
  SettingsSectionDef(
    slug: 'templates_and_reminders',
    titleKey: 'templates_and_reminders',
    icon: Icons.notifications_outlined,
    route: '/settings/templates_and_reminders',
    isBasic: false,
    docsPath: 'user-guide/advanced-settings#templates_and_reminders',
  ),
  SettingsSectionDef(
    slug: 'bank_accounts',
    titleKey: 'bank_accounts',
    icon: Icons.account_balance_outlined,
    route: '/settings/bank_accounts',
    isBasic: false,
    docsPath: 'user-guide/banking',
  ),
  SettingsSectionDef(
    slug: 'group_settings',
    titleKey: 'group_settings',
    icon: Icons.group_work_outlined,
    route: '/settings/group_settings',
    isBasic: false,
    clientEditable: false,
    docsPath: 'user-guide/advanced-settings#group_settings',
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
    docsPath: 'advanced-topics/schedules',
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
    docsPath: 'user-guide/advanced-settings#user_management',
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

/// One tab of a settings section — or the whole page, for a section with no
/// tabs — and the field labels search can find on it.
///
/// [path] is the route below the section (`'address'` →
/// `/settings/company_details/address`; `''` is the section's own page, which
/// every tabbed shell treats as its first tab). The shells already select a tab
/// from that URL (`tabbedSettingsRoutePair`), so a hit lands on the tab that
/// holds the field instead of the section's first page. `settings_search_route_test`
/// resolves every one of these through the real router.
///
/// The gates mirror what the shell itself hides. A shell falls back to its
/// first tab for a hidden slug, so an ungated hit for a hidden tab would open
/// the wrong page — not crash, but a lie the user has to notice.
class SettingsSearchTab {
  const SettingsSearchTab(
    this.path,
    this.keys, {
    this.titleKey,
    this.enabledBy,
    this.clientEditable = true,
    this.hostedOnly = false,
    this.keyGates = const {},
  });

  /// Route below the section; `''` for the section's own page.
  final String path;

  /// Localization keys of the labels rendered on this tab. Spread the screen's
  /// colocated `kFooSearchKeys` constant rather than retyping keys here —
  /// `search_catalog_consistency_test` scans the screen's source for each one.
  final List<String> keys;

  /// The tab's own label, shown as "Section › Tab" under a hit and searchable
  /// in its own right. Null for a section with a single page.
  final String? titleKey;

  /// Modules that keep the tab visible; `null` ⇒ always. Same `any` rule as
  /// [SettingsSectionDef.enabledBy].
  final List<EnabledModule>? enabledBy;

  /// False for a tab the shell renders only at company scope.
  final bool clientEditable;

  /// True for a tab the shell renders only on the hosted platform.
  final bool hostedOnly;

  /// The [keys] whose field renders only where its predicate holds — the same
  /// predicate the screen gates the field on (Spell check: only where the
  /// platform has a checker; Hide Peppol Sent Status: only for a company that
  /// sends by PEPPOL). A gated key is not offered elsewhere, so a hit never
  /// opens a page without the field it names. The scope is null when the
  /// caller passed none; a predicate that needs it then fails open.
  final Map<String, bool Function(SettingsSearchScope? scope)> keyGates;

  bool isVisibleFor(int enabledModules) {
    final gates = enabledBy;
    if (gates == null || gates.isEmpty) return true;
    return gates.any((m) => isModuleEnabled(enabledModules, m));
  }
}

/// Labels shared by every per-entity Generated Numbers tab. Listed on each tab
/// so a hit never names a tab the company has switched off; search collapses
/// the repeats into one row that opens the first visible tab.
const _kGeneratedNumbersEntityKeys = <String>[
  'number_pattern',
  'number_counter',
];

/// Searchable fields per section, tab by tab. Keys are section slugs from
/// `kSettingsSections`; values are localization keys (the same keys you pass to
/// `context.tr(...)` when rendering the field's label).
///
/// **Keep this in sync** when you add or rename fields on a settings screen —
/// it's the only way search will surface them. A key listed on more than one
/// tab of a section is shown once and opens the first visible tab.
/// The [kDeviceSettingsSearchKeys] whose card renders only somewhere, each
/// with the card's own condition, so a hit never opens Device Settings on a
/// card that isn't there. `settings_search_catalog_test` checks that every key
/// of a gated card is listed.
const _kDeviceSettingsKeyGates = <String, bool Function(SettingsSearchScope?)>{
  'spell_check': _spellCheckShown,
  // kContactsSyncSearchKeys
  'contacts': _contactsSyncShown,
  'sync_contacts_to_device': _contactsSyncShown,
  'sync_contacts_to_device_help': _contactsSyncShown,
  'all_clients': _contactsSyncShown,
  'assigned_to_me': _contactsSyncShown,
  'remove_synced_contacts': _contactsSyncShown,
  // kMobileAppSearchKeys
  'mobile_app_promo_section': _mobileAppShown,
  'mobile_app_promo_settings_body': _mobileAppShown,
  'mobile_app_promo_entry': _mobileAppShown,
  'hide_peppol_sent_status': _peppolStatusShown,
};

bool _spellCheckShown(SettingsSearchScope? _) => platformSupportsSpellCheck;

bool _contactsSyncShown(SettingsSearchScope? _) => contactsSyncSectionShown();

bool _mobileAppShown(SettingsSearchScope? scope) =>
    scope?.showsMobileApp ?? true;

bool _peppolStatusShown(SettingsSearchScope? scope) =>
    scope?.sendsPeppol ?? true;

const kSettingsSearchCatalog = <String, List<SettingsSearchTab>>{
  'company_details': [
    SettingsSearchTab(
      '',
      kCompanyDetailsDetailsSearchKeys,
      titleKey: 'details',
    ),
    SettingsSearchTab(
      'address',
      kCompanyDetailsAddressSearchKeys,
      titleKey: 'address',
    ),
    SettingsSearchTab('logo', kCompanyDetailsLogoSearchKeys, titleKey: 'logo'),
    SettingsSearchTab(
      'defaults',
      kCompanyDetailsDefaultsSearchKeys,
      titleKey: 'defaults',
    ),
    SettingsSearchTab(
      'documents',
      kCompanyDetailsDocumentsSearchKeys,
      titleKey: 'documents',
    ),
  ],
  'user_details': [
    SettingsSearchTab('', kUserDetailsDetailsSearchKeys, titleKey: 'details'),
    SettingsSearchTab(
      'password',
      kUserDetailsPasswordSearchKeys,
      titleKey: 'password',
    ),
    SettingsSearchTab(
      'connect',
      kUserDetailsConnectSearchKeys,
      titleKey: 'oauth_mail',
    ),
    SettingsSearchTab(
      'enable_two_factor',
      kUserDetailsTwoFactorSearchKeys,
      titleKey: 'enable_two_factor',
    ),
    SettingsSearchTab(
      'notifications',
      kUserDetailsNotificationsSearchKeys,
      titleKey: 'notifications',
    ),
    SettingsSearchTab(
      'preferences',
      kUserDetailsPreferencesSearchKeys,
      titleKey: 'preferences',
    ),
  ],
  'localization': [
    SettingsSearchTab(
      '',
      kLocalizationSettingsSearchKeys,
      titleKey: 'settings',
    ),
    // At group / client scope the shell drops its tabs and renders only the
    // Settings body (`localization_shell.dart`).
    SettingsSearchTab(
      'custom_labels',
      kLocalizationCustomLabelsSearchKeys,
      titleKey: 'custom_labels',
      clientEditable: false,
    ),
  ],
  // On a wide window the three tabs stack on one page and `:tab` is ignored,
  // which the field reveal handles: it finds the label wherever it renders.
  'online_payments': [
    SettingsSearchTab(
      '',
      kOnlinePaymentsGeneralSearchKeys,
      titleKey: 'settings',
    ),
    SettingsSearchTab(
      'defaults',
      kOnlinePaymentsDefaultsSearchKeys,
      titleKey: 'defaults',
    ),
    SettingsSearchTab(
      'emails',
      kOnlinePaymentsEmailsSearchKeys,
      titleKey: 'emails',
    ),
  ],
  'tax_settings': [SettingsSearchTab('', kTaxSettingsSearchKeys)],
  'product_settings': [SettingsSearchTab('', kProductSettingsSearchKeys)],
  'task_settings': [SettingsSearchTab('', kTaskSettingsSearchKeys)],
  'tags': [SettingsSearchTab('', kTagsSearchKeys)],
  'expense_settings': [SettingsSearchTab('', kExpenseSettingsSearchKeys)],
  // With only Quotes on, the shell renders the Quotes body at the bare path
  // and `/quotes` resolves to that same single page.
  'workflow_settings': [
    SettingsSearchTab(
      '',
      kWorkflowSettingsInvoicesSearchKeys,
      titleKey: 'invoices',
      enabledBy: [EnabledModule.invoices],
    ),
    SettingsSearchTab(
      'quotes',
      kWorkflowSettingsQuotesSearchKeys,
      titleKey: 'quotes',
      enabledBy: [EnabledModule.quotes],
    ),
  ],
  'account_management': [
    SettingsSearchTab('', kAccountManagementPlanSearchKeys, titleKey: 'plan'),
    SettingsSearchTab('overview', [
      'account_id',
      'email',
      'set_default_company',
      // Issue #104: the only searchable route to `auth.addCompany()`. The
      // `CompanyPicker` sheet's row can never be one, and that sheet's entry
      // point on a single-company mobile drawer is an unlabelled footer icon.
      'new_company',
      'activate_company',
      'enable_pdf_markdown',
      'enable_email_markdown',
      'include_drafts',
      'include_deleted',
    ], titleKey: 'overview'),
    // Slug is still `enabled_modules`; the tab is labelled Modules.
    SettingsSearchTab('enabled_modules', ['modules'], titleKey: 'modules'),
    // The Integrations hub and the screens it opens — reached via Account
    // Management → Integrations (the top-level Integrations section was
    // removed to match React).
    SettingsSearchTab('integrations', ['api_docs'], titleKey: 'integrations'),
    SettingsSearchTab('integrations/api_tokens', [
      'api_tokens',
    ], titleKey: 'api_tokens'),
    SettingsSearchTab('integrations/api_webhooks', [
      'api_webhooks',
    ], titleKey: 'api_webhooks'),
    SettingsSearchTab('integrations/analytics', [
      'analytics',
      'google_analytics_tracking_id',
      'matomo_id',
      'matomo_url',
    ], titleKey: 'analytics'),
    SettingsSearchTab(
      'integrations/quickbooks',
      kAccountManagementQuickbooksSearchKeys,
      titleKey: 'quickbooks',
    ),
    SettingsSearchTab('security_settings', [
      'password_timeout',
      'web_session_timeout',
      'require_password_with_social_login',
      'end_all_sessions',
    ], titleKey: 'security_settings'),
    // `AccountManagementShell` hides this tab on self-hosted (issue #27), so a
    // search for "referral" must not lead there.
    SettingsSearchTab(
      'referral_program',
      ['referral_program', 'referral_code'],
      titleKey: 'referral_program',
      hostedOnly: true,
    ),
    SettingsSearchTab(
      'danger_zone',
      kAccountManagementDangerZoneSearchKeys,
      titleKey: 'danger_zone',
    ),
  ],
  'backup_restore': [
    SettingsSearchTab('', kBackupTabSearchKeys, titleKey: 'backup'),
    SettingsSearchTab('restore', kRestoreTabSearchKeys, titleKey: 'restore'),
  ],
  'import_export': [SettingsSearchTab('', kImportExportSearchKeys)],
  'device_settings': [
    SettingsSearchTab(
      '',
      kDeviceSettingsSearchKeys,
      keyGates: _kDeviceSettingsKeyGates,
    ),
  ],
  'keyboard_shortcuts': [SettingsSearchTab('', kKeyboardShortcutsSearchKeys)],
  // Every tab but General is company-scope only (`invoice_design_shell.dart`).
  'invoice_design': [
    SettingsSearchTab(
      '',
      kInvoiceDesignGeneralSearchKeys,
      titleKey: 'general_settings',
    ),
    SettingsSearchTab(
      'custom_designs',
      [
        'custom_designs',
        'template',
        // The WYSIWYG visual designer and its panels — routed via Custom
        // Designs → + New → "Visual designer".
        'visual_designer',
        'document_settings',
        'hide_empty_columns',
      ],
      titleKey: 'custom_designs',
      clientEditable: false,
    ),
    SettingsSearchTab(
      'client_details',
      ['client_details'],
      titleKey: 'client_details',
      clientEditable: false,
    ),
    SettingsSearchTab(
      'company_details',
      ['company_details'],
      titleKey: 'company_details',
      clientEditable: false,
    ),
    SettingsSearchTab(
      'company_address',
      ['company_address'],
      titleKey: 'company_address',
      clientEditable: false,
    ),
    SettingsSearchTab(
      'invoice_details',
      ['invoice_details'],
      titleKey: 'invoice_details',
      enabledBy: [EnabledModule.invoices],
      clientEditable: false,
    ),
    SettingsSearchTab(
      'quote_details',
      ['quote_details'],
      titleKey: 'quote_details',
      enabledBy: [EnabledModule.quotes],
      clientEditable: false,
    ),
    SettingsSearchTab(
      'credit_details',
      ['credit_details'],
      titleKey: 'credit_details',
      enabledBy: [EnabledModule.credits],
      clientEditable: false,
    ),
    SettingsSearchTab(
      'vendor_details',
      ['vendor_details'],
      titleKey: 'vendor_details',
      enabledBy: [EnabledModule.vendors],
      clientEditable: false,
    ),
    SettingsSearchTab(
      'purchase_order_details',
      ['purchase_order_details'],
      titleKey: 'purchase_order_details',
      enabledBy: [EnabledModule.purchaseOrders],
      clientEditable: false,
    ),
    SettingsSearchTab(
      'product_columns',
      ['product_columns'],
      titleKey: 'product_columns',
      clientEditable: false,
    ),
    // Shown only while `share_invoice_quote_columns` is off — a setting search
    // can't see, so with it on this hit lands on General, as before.
    SettingsSearchTab(
      'product_quote_columns',
      ['quote_product_columns'],
      titleKey: 'quote_product_columns',
      clientEditable: false,
    ),
    SettingsSearchTab(
      'task_columns',
      ['task_columns'],
      titleKey: 'task_columns',
      enabledBy: [EnabledModule.tasks],
      clientEditable: false,
    ),
    // Wire key and slug are `total_columns`; the label reads "Total Fields".
    SettingsSearchTab(
      'total_columns',
      ['total_fields'],
      titleKey: 'total_fields',
      clientEditable: false,
    ),
  ],
  // Module gates match `custom_fields_shell.dart`; payments ride the Invoices
  // bit. The generic row labels (Label, Field Type, Date, …) repeat on every
  // tab and collapse to one hit on the Company tab.
  'custom_fields': [
    SettingsSearchTab('', kCustomFieldsCompanySearchKeys, titleKey: 'company'),
    SettingsSearchTab(
      'clients',
      kCustomFieldsClientsSearchKeys,
      titleKey: 'clients',
    ),
    SettingsSearchTab(
      'products',
      kCustomFieldsProductsSearchKeys,
      titleKey: 'products',
    ),
    SettingsSearchTab(
      'invoices',
      kCustomFieldsInvoicesSearchKeys,
      titleKey: 'invoices',
      enabledBy: [EnabledModule.invoices],
    ),
    SettingsSearchTab(
      'payments',
      kCustomFieldsPaymentsSearchKeys,
      titleKey: 'payments',
      enabledBy: [EnabledModule.invoices],
    ),
    SettingsSearchTab(
      'projects',
      kCustomFieldsProjectsSearchKeys,
      titleKey: 'projects',
      enabledBy: [EnabledModule.projects],
    ),
    SettingsSearchTab(
      'tasks',
      kCustomFieldsTasksSearchKeys,
      titleKey: 'tasks',
      enabledBy: [EnabledModule.tasks],
    ),
    SettingsSearchTab(
      'vendors',
      kCustomFieldsVendorsSearchKeys,
      titleKey: 'vendors',
      enabledBy: [EnabledModule.vendors],
    ),
    SettingsSearchTab(
      'expenses',
      kCustomFieldsExpensesSearchKeys,
      titleKey: 'expenses',
      enabledBy: [EnabledModule.expenses],
    ),
    SettingsSearchTab('users', kCustomFieldsUsersSearchKeys, titleKey: 'users'),
  ],
  // Module gates match `generated_numbers_shell.dart`. The `<entity>_number`
  // keys aren't rendered labels — the tab is titled by its entity — but they
  // are what someone looking for "invoice number" types.
  'generated_numbers': [
    SettingsSearchTab(
      '',
      kGeneratedNumbersSettingsSearchKeys,
      titleKey: 'settings',
    ),
    SettingsSearchTab('clients', [
      'client_number',
      ..._kGeneratedNumbersEntityKeys,
    ], titleKey: 'clients'),
    SettingsSearchTab(
      'invoices',
      ['invoice_number', ..._kGeneratedNumbersEntityKeys],
      titleKey: 'invoices',
      enabledBy: [EnabledModule.invoices],
    ),
    SettingsSearchTab(
      'recurring_invoices',
      _kGeneratedNumbersEntityKeys,
      titleKey: 'recurring_invoices',
      enabledBy: [EnabledModule.recurringInvoices],
    ),
    SettingsSearchTab(
      'payments',
      ['payment_number', ..._kGeneratedNumbersEntityKeys],
      titleKey: 'payments',
      enabledBy: [EnabledModule.invoices],
    ),
    SettingsSearchTab(
      'quotes',
      ['quote_number', ..._kGeneratedNumbersEntityKeys],
      titleKey: 'quotes',
      enabledBy: [EnabledModule.quotes],
    ),
    SettingsSearchTab(
      'credits',
      ['credit_number', ..._kGeneratedNumbersEntityKeys],
      titleKey: 'credits',
      enabledBy: [EnabledModule.credits],
    ),
    SettingsSearchTab(
      'projects',
      ['project_number', ..._kGeneratedNumbersEntityKeys],
      titleKey: 'projects',
      enabledBy: [EnabledModule.projects],
    ),
    SettingsSearchTab(
      'tasks',
      ['task_number', ..._kGeneratedNumbersEntityKeys],
      titleKey: 'tasks',
      enabledBy: [EnabledModule.tasks],
    ),
    SettingsSearchTab(
      'vendors',
      ['vendor_number', ..._kGeneratedNumbersEntityKeys],
      titleKey: 'vendors',
      enabledBy: [EnabledModule.vendors],
    ),
    SettingsSearchTab(
      'purchase_orders',
      ['purchase_order_number', ..._kGeneratedNumbersEntityKeys],
      titleKey: 'purchase_orders',
      enabledBy: [EnabledModule.purchaseOrders],
    ),
    SettingsSearchTab(
      'expenses',
      ['expense_number', ..._kGeneratedNumbersEntityKeys],
      titleKey: 'expenses',
      enabledBy: [EnabledModule.expenses],
    ),
    SettingsSearchTab(
      'recurring_expenses',
      _kGeneratedNumbersEntityKeys,
      titleKey: 'recurring_expenses',
      enabledBy: [EnabledModule.recurringExpenses],
    ),
  ],
  'client_portal': [
    SettingsSearchTab(
      '',
      kClientPortalSettingsSearchKeys,
      titleKey: 'settings',
    ),
    SettingsSearchTab(
      'authorization',
      kClientPortalAuthorizationSearchKeys,
      titleKey: 'authorization',
    ),
    SettingsSearchTab(
      'registration',
      kClientPortalRegistrationSearchKeys,
      titleKey: 'registration',
    ),
    SettingsSearchTab(
      'messages',
      kClientPortalMessagesSearchKeys,
      titleKey: 'messages',
    ),
    SettingsSearchTab(
      'customize',
      kClientPortalCustomizeSearchKeys,
      titleKey: 'customize',
    ),
  ],
  'e_invoice': [SettingsSearchTab('', kEInvoiceSearchKeys)],
  'email_settings': [SettingsSearchTab('', kEmailSettingsSearchKeys)],
  'templates_and_reminders': [
    SettingsSearchTab('', kTemplatesRemindersSearchKeys),
  ],
  'bank_accounts': [
    SettingsSearchTab(
      '',
      kBankAccountsListSearchKeys,
      titleKey: 'bank_accounts',
    ),
    SettingsSearchTab(
      'transaction_rules',
      kTransactionRulesListSearchKeys,
      titleKey: 'transaction_rules',
    ),
  ],
  'group_settings': [SettingsSearchTab('', kGroupSettingsSearchKeys)],
  // The edit form's keys stay on the list page: the form needs `/new` or a
  // record id, and its four tabs aren't in the URL.
  'payment_links': [
    SettingsSearchTab('', [
      ...kPaymentLinksListSearchKeys,
      ...kPaymentLinkEditSearchKeys,
    ]),
  ],
  'schedules': [SettingsSearchTab('', kSchedulesSearchKeys)],
  // Everything past the roster is on a user's detail / edit screen, which
  // needs an id — so it all opens User Management itself.
  'users': [
    SettingsSearchTab('', [
      // Not rendered as a field on that screen — it is the roster badge
      // (`user_management_screen.dart`). Catalogued so that someone who saw
      // "Verification Pending" and went looking lands on User Management,
      // where Resend Email is, rather than on the Device Settings toggle that
      // merely hides such users from Assigned User fields
      // (invoiceninja/flutter#150).
      'verification_pending',
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
      // `view_reports` has no string in any locale bundle — `permissions.dart`
      // maps it to `reports` for the real toggle, so the catalog must too or
      // the search list renders the raw slug.
      'reports',
      'disable_emails',
      'resend_email',
      'remove_user',
    ]),
  ],
  'system_logs': [
    SettingsSearchTab('', [
      // Feed filters (invoiceninja/flutter#60).
      'category',
      'status',
      ...kDebugPanelSearchKeys,
    ]),
  ],
};

/// Words someone types that no label on the page contains — "smtp" for Email
/// Settings, "2fa" for Two-Factor. Keyed by section slug, or by
/// `<section>/<tab path>` for one tab. They make the section (or tab) itself a
/// hit and are never displayed.
///
/// English only, like the server's own list these were seeded from
/// (`app/DataProviders/SettingsSearchMap.php`): product names and acronyms
/// don't translate, and every other word still matches through the localized
/// label. `settings_search_catalog_test` checks every key names a real section
/// or tab.
const kSettingsSearchKeywords = <String, String>{
  'company_details': 'business organisation organization website',
  'company_details/address': 'street city postcode zip state country location',
  'company_details/logo': 'branding image picture',
  'company_details/defaults': 'default terms footer notes',
  'company_details/documents': 'files attachments uploads',
  'user_details': 'profile account me',
  'user_details/password': 'security login credentials change password',
  'user_details/connect': 'oauth google microsoft gmail outlook social login',
  'user_details/enable_two_factor': '2fa mfa totp authenticator otp security',
  'user_details/notifications': 'alerts emails notify',
  'user_details/preferences': 'options accent colour color',
  'localization':
      'language currency timezone date format region locale first day of week',
  'localization/custom_labels': 'translations rename labels wording',
  'online_payments':
      'gateway stripe paypal gocardless mollie checkout braintree authorize '
      'razorpay payment methods',
  'tax_settings': 'vat gst sales tax rates inclusive percentage',
  'product_settings': 'items inventory stock',
  'task_settings': 'time tracking timer kanban statuses',
  'tags': 'labels keywords categorise categorize',
  'expense_settings': 'vendor bills costs categories',
  'workflow_settings': 'automation auto bill email send archive lock',
  'account_management': 'subscription plan billing upgrade',
  'account_management/overview': 'usage summary',
  'account_management/enabled_modules': 'features toggle',
  'account_management/integrations': 'zapier api third party accounting',
  'account_management/integrations/api_tokens': 'api keys secret token',
  'account_management/integrations/api_webhooks':
      'webhooks zapier callbacks events',
  'account_management/integrations/analytics':
      'google analytics matomo tracking measurement',
  'account_management/integrations/quickbooks': 'qbo accounting sync',
  'account_management/security_settings': 'password 2fa sessions timeout',
  'account_management/referral_program': 'affiliate rewards referrals invite',
  'account_management/danger_zone': 'delete purge cancel account close',
  'backup_restore': 'export import json archive download',
  'backup_restore/restore': 'import recover upload',
  'import_export': 'csv migration upload download quickbooks',
  'device_settings':
      'theme dark mode appearance colours colors density sidebar biometric',
  'keyboard_shortcuts': 'hotkeys keybindings keys',
  'invoice_design': 'pdf template layout theme fonts',
  'invoice_design/custom_designs': 'template html pdf custom layout',
  'custom_fields': 'extra fields metadata',
  'generated_numbers': 'invoice number counter pattern prefix sequence',
  'client_portal': 'customer portal self service domain',
  'client_portal/authorization': 'login password protect access',
  'client_portal/registration': 'signup self register',
  'client_portal/messages': 'text terms policy footer',
  'client_portal/customize': 'css branding styling header',
  'e_invoice': 'peppol einvoice e-invoice xml ubl storecove electronic',
  'email_settings': 'smtp mailgun postmark sending from name reply to bcc',
  'templates_and_reminders': 'reminders email templates dunning late fees',
  'bank_accounts':
      'banking transactions feeds yodlee nordigen plaid gocardless',
  'bank_accounts/transaction_rules': 'matching rules categorise transactions',
  'group_settings': 'groups client groups',
  'payment_links': 'subscriptions recurring plans checkout',
  'schedules': 'scheduled reports automation cron jobs',
  'users': 'team members staff permissions invite',
  'system_logs': 'audit logs activity history events',
};

/// Who is searching, as far as settings visibility goes: the same four facts
/// the sidebar's `inScope` reads. Built once per query by the settings screen
/// and the command palette, so the two can't disagree about what a user may
/// open — they used to carry copies of this filter.
class SettingsSearchScope {
  const SettingsSearchScope({
    required this.enabledModules,
    required this.isAdminOrOwner,
    required this.isCascade,
    required this.isHosted,
    this.showsMobileApp = true,
    this.sendsPeppol = true,
  });

  /// [session] null (not loaded yet) fails open on hosted, matching
  /// `AccountManagementShell`. [company] is the active company's full record,
  /// which only the PEPPOL gate reads; null (not loaded yet) fails open.
  factory SettingsSearchScope.from(
    AuthSession? session,
    SettingsLevelController level, {
    Company? company,
  }) {
    final me = session?.currentCompany;
    return SettingsSearchScope(
      enabledModules: me?.enabledModules ?? 0,
      isAdminOrOwner: me?.isAdmin == true || me?.isOwner == true,
      // Group and client are both non-company cascade levels.
      isCascade: level.isClient || level.isGroup,
      isHosted: session?.isHosted ?? true,
      showsMobileApp: mobileAppSectionShown(session),
      sendsPeppol: company == null || peppolStatusSectionShown(company),
    );
  }

  final int enabledModules;
  final bool isAdminOrOwner;

  /// Editing a client's or a group's settings. A company-only page opened
  /// from there renders under the "editing client X" banner with override
  /// boxes wired to the COMPANY draft, so the user's "per-client" edit would
  /// silently change the company-wide default.
  final bool isCascade;
  final bool isHosted;

  /// Whether Device Settings shows its Mobile App card here
  /// (`mobileAppSectionShown`).
  final bool showsMobileApp;

  /// Whether the active company sends by PEPPOL, the one case Device Settings
  /// shows Hide Peppol Sent Status (`peppolStatusSectionShown`).
  final bool sendsPeppol;

  bool allowsSection(SettingsSectionDef section) =>
      (!isCascade || section.clientEditable) &&
      section.isVisibleFor(enabledModules) &&
      (!section.adminOnly || isAdminOrOwner);

  bool allowsTab(SettingsSearchTab tab) =>
      (!isCascade || tab.clientEditable) &&
      tab.isVisibleFor(enabledModules) &&
      (isHosted || !tab.hostedOnly);
}

/// What a [SettingsSearchHit] names.
enum SettingsSearchHitKind {
  /// A whole section, matched on its title or keywords.
  section,

  /// A tab, matched on its title or keywords.
  tab,

  /// A field label on a tab.
  field,
}

/// One row of settings search results.
class SettingsSearchHit {
  const SettingsSearchHit({
    required this.fieldKey,
    required this.section,
    this.tab,
    this.kind = SettingsSearchHitKind.field,
    this.tabIsDistinct = true,
  });

  /// Localization key of the row's label — the field, the tab title, or the
  /// section title.
  final String fieldKey;

  /// Section that owns the row — its icon, its title, its plan gate.
  final SettingsSectionDef section;

  /// Tab the row opens; null for a section hit.
  final SettingsSearchTab? tab;

  final SettingsSearchHitKind kind;

  /// False when the same label is on several tabs of the section. The hit
  /// still opens the first of them, but naming that tab under it would be a
  /// guess — "Dropdown · Custom Fields › Company" for a choice every tab has.
  final bool tabIsDistinct;

  bool get isSection => kind == SettingsSearchHitKind.section;

  /// Where tapping the row goes.
  String get route {
    final path = tab?.path ?? '';
    return path.isEmpty ? section.route : '${section.route}/$path';
  }

  /// The tab to name under the row ("Section › Tab"), or null to name only
  /// the section.
  String? get tabTitleKey =>
      kind == SettingsSearchHitKind.field && tabIsDistinct
      ? tab?.titleKey
      : null;

  /// Whether arriving should scroll to and flash the label. A section or tab
  /// hit has no field to find — its title is in the chrome.
  bool get revealsField => kind == SettingsSearchHitKind.field;
}

// Ranking tiers, best first. A section whose name starts with the query
// outranks everything: someone typing "tax" most likely wants Tax Settings.
const _tierSectionPrefix = 0;
const _tierPrefix = 1;
const _tierWordStart = 2;
const _tierSubstring = 3;

/// Every query word is found, but spread across the label and its context
/// (tab title, section title, keywords), or only in the English label.
const _tierLoose = 4;

/// Returns the settings rows matching [query], best first.
///
/// Matching is case-insensitive on the *localized* label, and also on the
/// English one, so a non-English UI still answers to the English words the
/// docs and the support threads use. A multi-word query matches when every
/// word is found — in the label, or (with at least one word in the label) in
/// the tab and section titles, so "invoice number" and "number invoices" both
/// find Generated Numbers › Invoices. Section and tab rows also match their
/// [kSettingsSearchKeywords].
///
/// A label is listed once per section: a key on several tabs opens the first
/// one [scope] allows, and a field whose label is the section's own title
/// gives way to the section row. Pass [scope] to drop what the user cannot
/// open; without it every row is considered (tests, the consistency checks).
///
/// An empty or whitespace-only query returns nothing — the search UI shows
/// the section list until something is typed.
List<SettingsSearchHit> searchSettings(
  String query,
  Localization l10n, {
  SettingsSearchScope? scope,
}) {
  final q = _normalize(query);
  if (q.isEmpty) return const [];
  final words = q.split(' ');

  final ranked = <String, _Ranked>{};
  var order = 0;
  void offer(String label, SettingsSearchHit hit, int tier) {
    final id = '${hit.section.slug}\u0000${label.toLowerCase()}';
    final seen = ranked[id];
    if (seen == null) {
      ranked[id] = _Ranked(hit, tier, order++);
      return;
    }
    final sameRoute = seen.hit.route == hit.route;
    if (tier < seen.tier) {
      ranked[id] = _Ranked(
        sameRoute ? hit : _withTabNotDistinct(hit),
        tier,
        seen.order,
      );
    } else if (!sameRoute) {
      ranked[id] = _Ranked(
        _withTabNotDistinct(seen.hit),
        seen.tier,
        seen.order,
      );
    }
  }

  for (final section in kSettingsSections) {
    if (scope != null && !scope.allowsSection(section)) continue;
    final tabs = kSettingsSearchCatalog[section.slug] ?? const [];
    final sectionLabel = l10n.lookup(section.titleKey);
    final sectionEnglish = l10n.englishOf(section.titleKey);

    final sectionTier = _rank(
      [sectionLabel, ?sectionEnglish],
      q,
      words,
      context: kSettingsSearchKeywords[section.slug] ?? '',
      contextAlone: true,
    );
    if (sectionTier != null) {
      offer(
        sectionLabel,
        SettingsSearchHit(
          fieldKey: section.titleKey,
          section: section,
          kind: SettingsSearchHitKind.section,
        ),
        sectionTier == _tierPrefix ? _tierSectionPrefix : sectionTier,
      );
    }

    for (final tab in tabs) {
      if (scope != null && !scope.allowsTab(tab)) continue;
      final tabTitleKey = tab.titleKey;
      final tabLabel = tabTitleKey == null ? '' : l10n.lookup(tabTitleKey);
      final fieldContext = '$tabLabel $sectionLabel';

      // Fields before the tab row: when a field carries the tab's own title
      // (Password on the Password tab) the field wins the tie and the user
      // gets the scroll-and-flash.
      for (final key in tab.keys) {
        if (tab.keyGates[key]?.call(scope) == false) continue;
        final label = l10n.lookup(key);
        final tier = _rank(
          [label, ?l10n.englishOf(key)],
          q,
          words,
          context: fieldContext,
        );
        if (tier == null) continue;
        offer(
          label,
          SettingsSearchHit(fieldKey: key, section: section, tab: tab),
          tier,
        );
      }

      // A tab is a row of its own only below the section's first page —
      // that page is what the section row already opens.
      if (tabTitleKey == null || tab.path.isEmpty) continue;
      final tabKeywords =
          kSettingsSearchKeywords['${section.slug}/${tab.path}'] ?? '';
      final tier = _rank(
        [tabLabel, ?l10n.englishOf(tabTitleKey)],
        q,
        words,
        context: '$sectionLabel $tabKeywords',
        keywords: tabKeywords,
      );
      if (tier == null) continue;
      offer(
        tabLabel,
        SettingsSearchHit(
          fieldKey: tabTitleKey,
          section: section,
          tab: tab,
          kind: SettingsSearchHitKind.tab,
        ),
        tier,
      );
    }
  }

  final rows = ranked.values.toList()
    ..sort((a, b) {
      final byTier = a.tier.compareTo(b.tier);
      return byTier != 0 ? byTier : a.order.compareTo(b.order);
    });
  return [for (final r in rows) r.hit];
}

class _Ranked {
  const _Ranked(this.hit, this.tier, this.order);
  final SettingsSearchHit hit;
  final int tier;
  final int order;
}

SettingsSearchHit _withTabNotDistinct(SettingsSearchHit hit) =>
    SettingsSearchHit(
      fieldKey: hit.fieldKey,
      section: hit.section,
      tab: hit.tab,
      kind: hit.kind,
      tabIsDistinct: false,
    );

/// Lower-cased, trimmed, with runs of whitespace collapsed to one space.
String _normalize(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The best tier at which [labels] (localized first, then English) match the
/// query, or null for no match.
///
/// [context] is the text a multi-word query may spill into once one word has
/// landed in the label (tab and section titles). With [contextAlone] — a
/// section row — the context may carry the whole match, which is how a
/// keyword like "smtp" finds Email Settings. [keywords] does the same for a
/// tab row without letting its section title alone match it: a tab must not
/// surface just because the user typed its section's name.
int? _rank(
  List<String> labels,
  String q,
  List<String> words, {
  String context = '',
  bool contextAlone = false,
  String keywords = '',
}) {
  int? best;
  for (final (i, raw) in labels.indexed) {
    final label = raw.toLowerCase();
    int? tier;
    if (label.startsWith(q)) {
      tier = _tierPrefix;
    } else if (_hasWordStartingWith(label, q)) {
      tier = _tierWordStart;
    } else if (label.contains(q) ||
        (words.length > 1 && words.every(label.contains))) {
      tier = _tierSubstring;
    }
    // A match only in the English label sits below every localized one.
    if (tier != null && i > 0) tier = _tierLoose;
    if (tier != null && (best == null || tier < best)) best = tier;
  }
  if (best != null) return best;

  final lowerLabels = [for (final l in labels) l.toLowerCase()];
  final ctx = context.toLowerCase();
  bool inLabel(String w) => lowerLabels.any((l) => l.contains(w));
  if (words.any(inLabel) && words.every((w) => inLabel(w) || ctx.contains(w))) {
    return _tierLoose;
  }
  if (contextAlone && words.every((w) => inLabel(w) || ctx.contains(w))) {
    return _tierLoose;
  }
  final kw = keywords.toLowerCase();
  if (kw.isNotEmpty && words.every((w) => inLabel(w) || kw.contains(w))) {
    return _tierLoose;
  }
  return null;
}

/// Whether some word of [label] (after a non-alphanumeric boundary) starts
/// with [q].
bool _hasWordStartingWith(String label, String q) {
  var from = 0;
  while (true) {
    final at = label.indexOf(q, from);
    if (at < 0) return false;
    if (at == 0 || !_isWordChar(label.codeUnitAt(at - 1))) return true;
    from = at + 1;
  }
}

bool _isWordChar(int c) =>
    (c >= 0x30 && c <= 0x39) || // 0-9
    (c >= 0x41 && c <= 0x5A) || // A-Z
    (c >= 0x61 && c <= 0x7A) || // a-z
    c >= 0xC0; // letters outside ASCII
