import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'package:admin/app/entity_modules.dart';
import 'package:admin/app/search_focus_registry.dart';
import 'package:admin/app/services_entity_wiring.dart';
import 'package:admin/app/shortcut_hint_controller.dart';
import 'package:admin/app/shortcuts/keyboard_shortcuts_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/bank_account_repository.dart';
import 'package:admin/data/repositories/bank_transaction_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/company_gateway_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/company_sync_dispatcher.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/repositories/group_setting_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/payment_repository.dart';
import 'package:admin/data/repositories/payment_term_repository.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/data/repositories/purchase_order_repository.dart';
import 'package:admin/data/repositories/calendar_connection_repository.dart';
import 'package:admin/data/repositories/quickbooks_repository.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/data/repositories/recurring_expense_repository.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/saved_views_repository.dart';
import 'package:admin/data/repositories/schedule_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/repositories/system_log_repository.dart';
import 'package:admin/data/repositories/payment_link_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/refresh_scheduler.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/data/repositories/tax_rate_repository.dart';
import 'package:admin/data/repositories/transaction_rule_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/repositories/two_factor_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/repositories/user_settings_sync_dispatcher.dart';
import 'package:admin/data/repositories/token_repository.dart';
import 'package:admin/data/repositories/user_sync_dispatcher.dart';
import 'package:admin/data/repositories/webhook_repository.dart';
import 'package:admin/data/services/activities_api.dart';
import 'package:admin/data/services/search_api.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/biometric_service.dart';
import 'package:admin/data/services/companies_api.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/device_contacts_service.dart';
import 'package:admin/domain/contacts_sync/contacts_sync_service.dart';
import 'package:admin/data/services/device_contacts_service_factory.dart';
import 'package:admin/data/services/documents_api.dart';
import 'package:admin/data/services/emails_api.dart';
import 'package:admin/data/services/dashboard_api.dart';
import 'package:admin/data/services/project_charts_api.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/data/services/system_api.dart';
import 'package:admin/data/services/system_logs_api.dart';
import 'package:admin/data/services/smtp_api.dart';
import 'package:admin/data/services/templates_api.dart';
import 'package:admin/data/services/support_api.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/data/services/token_storage_factory.dart';
import 'package:admin/data/services/two_factor_api.dart';
import 'package:admin/data/services/user_settings_api.dart';
import 'package:admin/data/services/users_api.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/app/accent_color_controller.dart';
import 'package:admin/app/app_locale_resolver.dart';
import 'package:admin/app/debug_capture_store.dart';
import 'package:admin/app/diagnostics_log.dart';
import 'package:admin/app/locale_controller.dart';
import 'package:admin/app/recently_viewed_controller.dart';
import 'package:admin/app/resync_controller.dart';
import 'package:admin/app/screenshot_window_controller.dart';
import 'package:admin/app/sidebar_badge_mode_controller.dart';
import 'package:admin/app/confirm_actions_controller.dart';
import 'package:admin/app/contacts_sync_controller.dart';
import 'package:admin/app/sidebar_controller.dart';
import 'package:admin/app/text_scale_controller.dart';
import 'package:admin/app/theme_controller.dart';

final Logger _servicesLog = Logger('Services');

/// Top-level helper so the prefetch can fire from the
/// `auth.onActiveCompanyChanged` wrap inside `Services.build` (where the
/// `Services` instance doesn't exist yet) AND from the instance method
/// [Services.prefetchSidebarEntities]. Both call sites use this same body.
Future<void> _prefetchSidebarOnCompanyChange(
  WiredEntities entities,
  String companyId,
) => _runSidebarPrefetch(entities.firstPagePrefetchers, companyId);

/// Max sidebar prefetchers running at once. The fan-out used to be an
/// unbounded `Future.wait` over every sidebar entity; on a company switch
/// that fired ~14 concurrent list fetches whose JSON decode each spawns a
/// `compute()` isolate. The simultaneous isolate-spawn storm starved the
/// decoders past `ApiClient._decodeTimeout`, surfacing as
/// `prefetch failed ... Response parse timed out` in the diagnostics log.
/// A small bound throttles both the isolate spawns and the HTTP burst.
const _kPrefetchConcurrency = 4;

Future<void> _runSidebarPrefetch(
  Map<EntityType, Future<bool> Function(String companyId)> prefetchers,
  String companyId,
) async {
  if (companyId.isEmpty) return;
  final jobs = <Future<void> Function()>[];
  for (final spec in kWiredEntityModules) {
    if (spec.sidebarSection == SidebarSection.none) continue;
    final prefetch = prefetchers[spec.type];
    if (prefetch == null) continue;
    jobs.add(
      () => prefetch(companyId).then<void>(
        (_) => null,
        onError: (Object e, StackTrace st) {
          // Best-effort prefetch: the sidebar falls back to on-demand loading,
          // so a transient network blip (timeout / offline) is harmless and
          // shouldn't pollute the WARNING+ diagnostics log. Unexpected errors
          // (parse failures, 5xx, …) stay at WARNING.
          if (e is NetworkException) {
            _servicesLog.fine(
              'prefetch skipped for ${spec.type.name}: ${e.message}',
            );
          } else {
            _servicesLog.warning(
              'prefetch failed for ${spec.type.name}',
              e,
              st,
            );
          }
        },
      ),
    );
  }
  var next = 0;
  Future<void> worker() async {
    while (true) {
      final i = next++;
      if (i >= jobs.length) return;
      await jobs[i]();
    }
  }

  await Future.wait([
    for (var w = 0; w < _kPrefetchConcurrency && w < jobs.length; w++) worker(),
  ]);
}

/// Test seam: drive [_runSidebarPrefetch] with a synthetic prefetcher map so a
/// test can assert the concurrency bound holds. Not used in app code.
@visibleForTesting
Future<void> runSidebarPrefetchForTest(
  Map<EntityType, Future<bool> Function(String companyId)> prefetchers,
  String companyId,
) => _runSidebarPrefetch(prefetchers, companyId);

/// Test seam: the configured prefetch concurrency bound.
@visibleForTesting
int get prefetchConcurrencyForTest => _kPrefetchConcurrency;

/// The bag of singletons the app builds on startup. Provided via
/// `Provider<Services>` so ViewModels can read what they need without
/// hand-wiring every constructor.
///
/// Not a service locator — anything beyond app bootstrap should still take
/// its dependencies via constructor injection (ViewModel ctors do this).
///
/// **Split trigger (fired — kept as the rationale):** at `>= 6` wired entity
/// modules the per-entity `<Entity>sApi` + `<Entity>Repository` +
/// `wire<…>(...)` blocks were hoisted out of `Services.build` into
/// `lib/app/services_entity_wiring.dart`. That first hoist moved them into a
/// single ~1,900-line `wireEntities()`, which at 28 entities had the same
/// problem one level down; they are now one top-level `_wire<Entity>(reg)`
/// function each. If a future bag of construction outgrows its home, split by
/// unit of change (one function or file per entity) rather than relocating the
/// pile.
class Services implements SidebarBadgeContext {
  Services._({
    required this.db,
    required this.auth,
    required this.clients,
    required this.products,
    required this.tasks,
    required this.taskStatuses,
    required this.tags,
    required this.projects,
    required this.vendors,
    required this.expenses,
    required this.recurringExpenses,
    required this.expenseCategories,
    required this.companyGateways,
    required this.paymentTerms,
    required this.taxRates,
    required this.designs,
    required this.groupSettings,
    required this.paymentLinks,
    required this.schedules,
    required this.invoices,
    required this.quotes,
    required this.credits,
    required this.purchaseOrders,
    required this.recurringInvoices,
    required this.bankAccounts,
    required this.bankTransactions,
    required this.transactionRules,
    required this.payments,
    required this.webhooks,
    required this.tokens,
    required this.company,
    required this.companies,
    required this.quickbooks,
    required this.calendarConnection,
    required this.dashboard,
    required this.projectCharts,
    required this.reports,
    required this.statics,
    required this.system,
    required this.systemLogs,
    required this.settings,
    required this.userSettings,
    required this.user,
    required this.savedViews,
    required this.twoFactor,
    required this.support,
    required this.smtp,
    required this.templates,
    required this.activities,
    required this.emails,
    required this.search,
    required this.documents,
    required this.sync,
    required this.refreshScheduler,
    required this.entityRegistry,
    required this.connectivity,
    required this.passwordCache,
    required this.apiClient,
    required this.biometric,
    required this.deviceContacts,
    required this.theme,
    required this.accentColor,
    required this.locale,
    required this.textScale,
    required this.keyboardShortcuts,
    required this.appLocale,
    required this.confirmActions,
    required this.contactsSync,
    required this.sidebar,
    required this.sidebarBadgeModes,
    required this.resync,
    required this.recentlyViewed,
    required this.settingsLevel,
    required this.serverVersion,
    required this.clientTooOld,
    required this.unsavedChangesGuard,
    required this.debugCaptureStore,
    required this.debugPanelRevealed,
    this.diagnosticsLog,
    required Map<EntityType, SidebarCountWatcher> countWatchers,
    required Map<EntityType, Future<bool> Function(String companyId)>
    firstPagePrefetchers,
  }) : _countWatchers = countWatchers,
       _firstPagePrefetchers = firstPagePrefetchers;

  final AppDatabase db;
  final AuthRepository auth;
  final ClientRepository clients;
  final ProductRepository products;

  /// Time tracking — backs the Tasks list/detail/edit screens, the kanban
  /// board, and the global running-timer pill mounted in `AppShell`.
  final TaskRepository tasks;

  /// User-defined task statuses (the kanban columns). Edited under
  /// Settings → Advanced → Task Statuses.
  final TaskStatusRepository taskStatuses;

  /// User-defined tags (name + color), scoped per entity type (task/project).
  /// Fetched on company-activate via [TagRepository.refreshAll]; managed under
  /// Settings → Tags; attached to tasks/projects via the tag picker.
  final TagRepository tags;

  /// Projects — the umbrella entity that groups a client's tasks. Owns
  /// `task_rate` / `budgeted_hours` and is the parent of every task picked
  /// from the Task edit form.
  final ProjectRepository projects;

  /// Vendors — top-level CRUD entity, document-bearing. Parent of every
  /// expense via `vendor_id`. Owns its own contacts list (carried inside
  /// the payload JSON, mirroring Client).
  final VendorRepository vendors;

  /// Expenses — top-level CRUD entity, document-bearing. Links to vendor,
  /// client, project, category, and (optionally) an invoice generated from
  /// the expense. Money fields are `Decimal`; tax tier rates respect
  /// `enabled_expense_tax_rates` from company settings.
  final ExpenseRepository expenses;

  /// Recurring expenses — superset of Expense with frequency / cycles /
  /// next-send-date / stored `status_id`. Start / Stop ride dedicated
  /// `MutationKind.start` / `.stop` outbox rows that route through
  /// `?start=true` / `?stop=true` query params.
  final RecurringExpenseRepository recurringExpenses;

  /// Expense categories — small bundled reference list (id + name + color)
  /// delivered via the `/refresh?first_load=true` envelope alongside the
  /// company AND paginated through `/api/v1/expense_categories` for offline
  /// edits. Settings-only entity reached via Settings → Advanced.
  final ExpenseCategoryRepository expenseCategories;

  /// Payment provider connections (Stripe, PayPal, Authorize.Net, …). Edited
  /// under Settings → Online Payments → Configure Gateways.
  final CompanyGatewayRepository companyGateways;

  /// User-defined payment terms (Net 7, Net 30, …). Edited under Settings →
  /// Advanced → Payment Terms; surfaced as a dropdown on Online Payments →
  /// Defaults. Bundled in the `/refresh` envelope alongside the company.
  final PaymentTermRepository paymentTerms;

  /// Tax rates — small bundled reference list, populates the default-tax
  /// pickers on Settings → Tax Settings. Loaded via `/refresh?first_load=true`
  /// alongside `payment_terms` / `task_statuses`. No CRUD screen yet — the
  /// entity sits in `kDisabledEntityModules` until that page lands.
  final TaxRateRepository taxRates;

  /// Invoice / quote / credit / purchase-order design templates. Bundled via
  /// `/refresh?first_load=true` (data[N].company.designs) — the Invoice
  /// Design pickers and the upcoming Custom Designs CRUD read from this repo.
  final DesignRepository designs;

  final GroupSettingRepository groupSettings;

  /// Payment Links — small bundled reference list delivered via
  /// `/refresh?first_load=true` alongside the company AND paginated
  /// through `/api/v1/subscriptions` for offline edits. Wire name is
  /// `subscription`; we use `payment_link` everywhere internally to
  /// match the user-facing label. Settings-only entity reached via
  /// Settings → Advanced → Payment Links.
  final PaymentLinkRepository paymentLinks;

  /// Schedules ("task schedulers") — bundled settings entity reached via
  /// Settings → Advanced → Schedules. Server includes
  /// `company.task_schedulers` in the `/refresh?first_load=true` envelope;
  /// `ScheduleRepository.applyBundle` upserts into the local table on
  /// every login/refresh.
  final ScheduleRepository schedules;

  /// Invoices — top-level CRUD entity, document-bearing. Line items live as
  /// nested JSON inside the payload (no separate `line_items` table); the
  /// `LineItem` value type is shared with future Quote / Credit /
  /// PurchaseOrder / RecurringInvoice. Custom actions (markSent / markPaid
  /// / email / scheduleEmail / cloneTo{Invoice|Quote|Credit|Recurring|PO}
  /// / autoBill / cancel / runTemplate) ride dedicated `MutationKind`
  /// values routed through `customActions` in `services_entity_wiring`.
  final InvoiceRepository invoices;

  /// Quotes — mirrors Invoice's shape (line items, invitations, taxes,
  /// design, exchange rate) with a quote-specific status enum (Draft /
  /// Sent / Approved / Converted) and the three conversion actions
  /// (`approve`, `convertToInvoice`, `convertToProject`).
  final QuoteRepository quotes;

  /// Credits — mirrors Invoice's shape (line items, invitations, taxes,
  /// design, exchange rate) with a credit-specific status enum (Draft /
  /// Sent / Partial / Applied) and a `paid_to_date` tracker for partial
  /// applications across invoices.
  final CreditRepository credits;

  /// Purchase Orders — vendor-centric mirror of Quote (line items,
  /// invitations, taxes, design, exchange rate). Status lifecycle is
  /// Draft / Sent / Accepted / Received / Cancelled. Owns the `accept`
  /// and `convert_to_expense` custom actions in addition to the usual
  /// mark_sent / email / schedule_email / clone_to_* / run_template /
  /// addComment / cancelEntity surface.
  final PurchaseOrderRepository purchaseOrders;

  /// Recurring Invoices — invoice-shaped template that the server uses to
  /// spawn invoices on a schedule. Owns the `start` / `stop` lifecycle
  /// actions in addition to the usual mark_sent / email / clone_to_* /
  /// run_template surface. Status lifecycle: Draft / Active / Paused /
  /// Completed (with `pending` computed when next_send_date is future).
  final RecurringInvoiceRepository recurringInvoices;

  /// Bank integrations (Yodlee / Nordigen / manual). Edited under
  /// Settings → Bank Accounts. Owns the `refresh_accounts` custom action
  /// that pings the upstream provider for fresh balances.
  final BankAccountRepository bankAccounts;

  /// Bank transactions — top-level workspace entity at `/transactions`.
  /// Owns the four `match` variants (CREDIT/DEBIT × create/link) and the
  /// two bulk actions (`convert_matched`, `unlink`) that move rows
  /// through Unmatched → Matched → Converted.
  final BankTransactionRepository bankTransactions;

  /// Transaction rules — auto-categorize incoming bank transactions.
  /// Edited under Settings → Bank Accounts → Rules.
  final TransactionRuleRepository transactionRules;

  /// Payments — top-level CRUD entity, document-bearing. Two non-CRUD flows
  /// ride dedicated `MutationKind`s: `refundPayment` (`POST /payments/refund`)
  /// and `applyPayment` (`PUT /payments/{id}` with an `invoices` allocations
  /// array). `?email_receipt=…` query flag threads through the outbox via a
  /// synthetic `_send_email` payload key (see `PaymentsApi.create`).
  final PaymentRepository payments;

  /// API webhooks — settings-only entity. Edited under Settings →
  /// Integrations → API Webhooks. Bundled on `/refresh?first_load=true`.
  final WebhookRepository webhooks;

  /// API tokens — settings-only entity. Edited under Settings →
  /// Integrations → API Tokens. Bundled on `/refresh?first_load=true` via
  /// `tokens_hashed` (server returns masked token strings; raw bearer
  /// secret only on create response, see [TokenRepository.newSecrets]).
  final TokenRepository tokens;

  final CompanyRepository company;

  /// HTTP service for `/api/v1/companies` — exposed so screens (today: the
  /// Client Portal Settings tab's subdomain availability probe) can call
  /// endpoints outside the standard outbox flow without re-instantiating
  /// the service.
  final CompaniesApi companies;

  /// QuickBooks integration — Account Management → Integrations →
  /// QuickBooks. State lives on `company.quickbooks`; this repo just owns
  /// the connect / disconnect side-effects (one_time_token + authorize URL,
  /// disconnect endpoint).
  final QuickbooksRepository quickbooks;

  /// Calendar connection (Google / Microsoft). Stateless integration repo —
  /// the connection lives on `user.settings` server-side and is read back via
  /// `status()`; events/calendars are live provider reads, never in Drift.
  final CalendarConnectionRepository calendarConnection;

  final DashboardRepository dashboard;

  /// Per-project analytics + burn-up charts. Read-only, live server reads
  /// (never persisted to Drift) — same status as the dashboard charts.
  final ProjectChartsApi projectCharts;

  /// Reports — queued-job endpoints (preview / export / email). Used only
  /// by the Reports screen at `/reports`; not part of the entity sync
  /// graph (no Drift table, no outbox row). Each Run POSTs, then polls
  /// the server's `/api/v1/reports/preview/<hash>` (or
  /// `/api/v1/exports/preview/<hash>`) for the materialized result.
  final ReportsRepository reports;

  final StaticsRepository statics;

  /// Self-hosted server diagnostic endpoints (`/health_check`, `/ping`,
  /// `/last_error`) behind the Health Check button in the About dialog.
  /// No persistence — the dialog fetches on open and discards on close.
  final SystemApi system;

  /// Read-only cache of `/api/v1/system_logs` backing Settings → System
  /// Logs. No outbox / mutation surface — the server is the only writer.
  final SystemLogRepository systemLogs;

  final SettingsRepository settings;
  final UserSettingsRepository userSettings;
  final ActivitiesApi activities;

  /// Read-only client email-history feed + the bounce-reactivation write.
  /// No Drift / outbox-backed entity — the ViewModel fetches live.
  final EmailsApi emails;
  final SearchApi search;

  /// Shared `/api/v1/documents` surface addressed by document id — bulk
  /// download (server-side zip+email export). Per-entity uploads live on
  /// each entity's own api (the URL is entity-scoped).
  final DocumentsApi documents;

  /// Reads/writes the authenticated user's profile (the row behind
  /// Settings > User Details). Distinct from [userSettings], which only
  /// handles the per-(user, company) table_columns flow against
  /// `/api/v1/company_users/{id}`.
  final UserRepository user;

  /// Local-only named snapshots of list-screen filter+sort+search state.
  /// Surfaced in the sidebar's "Saved" section and the bookmark sheet on
  /// each list screen.
  final SavedViewsRepository savedViews;

  final TwoFactorRepository twoFactor;
  final SupportApi support;

  /// One-off probe behind Settings → Email Settings → "Send Test Email"
  /// (calls `/api/v1/smtp/check`). Bypasses the outbox — see
  /// [SmtpApi] for why.
  final SmtpApi smtp;

  /// Live email-template rendering for Settings → Templates & Reminders.
  /// POSTs to `/api/v1/templates` with the user's draft subject + body,
  /// the server runs variable substitution, and the preview panel renders
  /// the returned HTML.
  final TemplatesApi templates;

  final SyncRepository sync;

  /// Foreground delta-refresh pump (periodic + on-resume). Lifecycle
  /// transitions are routed in by `SyncLifecycleObserver`.
  final RefreshScheduler refreshScheduler;

  /// Per-entity dispatchers + metadata. The sync engine, outbox screen,
  /// permissions checks, router branches, and shell navigation all read
  /// from here so adding a new entity is mechanical.
  final EntityRegistry entityRegistry;

  final ConnectivityWatcher connectivity;
  final PasswordCache passwordCache;
  final ApiClient apiClient;
  final BiometricService biometric;

  /// Reads a single contact from the device address book (iOS); a no-op stub on
  /// web / non-iOS so the client-edit "Add from contacts" button hides itself.
  final DeviceContactsService deviceContacts;
  final ThemeController theme;

  /// Per-(company, user) accent color resolver. Emits the current user's
  /// `companyUserSettings.accentColor` for the active company; `null` when
  /// the user hasn't picked an override. Listened to by `MaterialApp.router`
  /// so a swatch change or company switch repaints the theme.
  final AccentColorController accentColor;

  /// Device-local app-language override (Settings → User Details →
  /// Preferences). Drives [appLocale] as the top-priority input.
  final LocaleController locale;

  /// Device-local UI text-scale override (Settings → Device Settings). Merged
  /// into `MaterialApp`'s theme [Listenable] so a change rebuilds the app-wide
  /// `MediaQuery` `textScaler`.
  final TextScaleController textScale;

  /// Device-local keyboard-shortcut overrides (Settings → Keyboard Shortcuts).
  /// Resolves user overrides over the catalog defaults and feeds all three
  /// consumers at once: the shell's live `Shortcuts` map, the hold-modifier
  /// hint bar, and the `?` help dialog. Persists to `nav_state`, like [theme] /
  /// [textScale] — and, like them, **does not survive logout**: `logout()`
  /// wipes every Drift table, `nav_state` included, and nothing re-seeds the
  /// row. (The in-memory map outlives the wipe, so the UI keeps showing the
  /// custom bindings until the next launch — don't read that as persistence.)
  final KeyboardShortcutsController keyboardShortcuts;

  /// The locale `MaterialApp.locale` actually binds to — resolves the device
  /// override over the active company's `settings.language_id` (React parity).
  final AppLocaleResolver appLocale;

  /// Device-local "Confirm actions" preference — when on, risky entity actions
  /// (Approve, Mark Sent, Cancel, Archive, Delete, …) prompt "Are you sure?"
  /// first. Read it at tap time via `guardedOnTap` /
  /// `showConfirmActionDialog`, never cached into a built widget.
  final ConfirmActionsController confirmActions;

  /// Device-local "sync client contacts to this device's address book"
  /// preference plus the single-flight guard around a reconcile pass
  /// (Settings → Device Settings → Contacts). Native mobile only — on every
  /// other platform `deviceContacts.canSync` is false, the settings section
  /// hides itself and nothing here is ever driven.
  final ContactsSyncController contactsSync;

  final SidebarController sidebar;

  /// What each sidebar row's count badge counts (Settings → Device Settings →
  /// Sidebar counters, or a right-click on the row). Persists to `nav_state`
  /// like [theme] / [keyboardShortcuts] — and, like them, does not survive
  /// logout, which wipes every Drift table.
  final SidebarBadgeModeController sidebarBadgeModes;

  /// App-wide single-flight + progress state for the user-initiated "Sync" pass
  /// (see [syncNow]). Driven by the sidebar header's Sync button, Settings →
  /// Device Settings → Data → Sync, and Account Management → Force full sync,
  /// so the three can't start competing passes.
  ///
  /// Not to be confused with [sync], the outbox drain — this one *downloads*
  /// (and pushes first, via [syncNow]).
  final ResyncController resync;

  /// Recently-viewed entities backing the command palette's "Recent" group.
  /// Company-scoped (clears on company switch / logout).
  final RecentlyViewedController recentlyViewed;

  /// App-wide settings-edit scope. When a user navigates from a client into
  /// `/settings`, this is set to [SettingsLevel.client]; every settings page
  /// reads it (via the global Provider mounted in `main.dart`) to render
  /// override checkboxes and gate company-only sections. Reset on logout
  /// and company-switch.
  final SettingsLevelController settingsLevel;

  /// Latest `x-app-version` header value from the server. Set by [ApiClient]
  /// via `onServerVersion`; the Diagnostics screen shows it for support.
  final ValueNotifier<String?> serverVersion;

  /// Non-null when the server has rejected our client version. The router
  /// redirects to `/too-old` whenever this is set so the user sees a
  /// formatted "please update" screen instead of a raw exception.
  final ValueNotifier<({String minRequired, String current})?> clientTooOld;

  /// Tracks editors with unsaved in-memory edits so navigation entry points
  /// can prompt before discarding them. Editors opt in via
  /// `UnsavedChangesScope` (lib/ui/core/unsaved_changes/).
  final UnsavedChangesGuard unsavedChangesGuard;

  /// One-slot registry of the currently-mounted token search field's
  /// FocusNode. The global `/` shortcut reads this to focus search on the
  /// active list screen without coupling the shell to any specific list.
  /// Filled by `TokenSearchField.initState`, cleared in `dispose`; `null`
  /// when no list screen is mounted (e.g. Dashboard, Settings).
  final SearchFocusRegistry searchFocus = SearchFocusRegistry();

  /// App-wide toast queue, rendered by the global `ToastHost` mounted in
  /// `main.dart`. Context-free + always-alive so every `Notify.*` call lands
  /// regardless of where it fired (e.g. from a sheet that then pops). Cleared
  /// on logout. No DI deps, so it's field-initialized like [searchFocus].
  final ToastController toasts = ToastController();

  /// Registry + visibility for the hold-modifier shortcut hint bar, rendered
  /// by the global `ShortcutHintOverlay` in `main.dart`. Context-free +
  /// always-alive like [toasts]; `reset()` on logout.
  final ShortcutHintController shortcutHints = ShortcutHintController();

  /// Debug Panel screenshot tools: window sizing to App Store / Play Store
  /// pixel dimensions + hiding the native window buttons. Lives on `Services`
  /// (not panel state) so the chosen size / hidden buttons survive closing
  /// the panel for the actual capture. In-memory only — resets every launch,
  /// and the traffic lights default back to visible on each boot.
  final ScreenshotWindowController screenshotWindow =
      ScreenshotWindowController();

  /// Debug-only Claude-readable log of uncaught errors + WARNING/SEVERE
  /// Logger records, plus on-demand outbox snapshots. `null` in release
  /// builds and in unit-test wiring; see [DiagnosticsLog] for the format.
  final DiagnosticsLog? diagnosticsLog;

  /// In-memory capture of recent HTTP requests + errors. Off by default and
  /// reset on every app launch — used by the hidden Debug Panel surfaced via
  /// the About dialog's "Debug Panel" button. Lives in release builds so
  /// users can self-diagnose in prod.
  final DebugCaptureStore debugCaptureStore;

  /// Whether the hidden Debug Panel band is currently visible at the bottom
  /// of the authenticated app shell. Flipped on by the About dialog's
  /// "Debug Panel" button; flipped off by the Hide button in the panel
  /// toolbar. Lives on `Services` (not local screen state) so the panel
  /// survives navigation between routes.
  final ValueNotifier<bool> debugPanelRevealed;

  // -- Cross-branch create seed -------------------------------------------

  /// A clientId staged by a Client's "New X" action so the next create screen
  /// at that basePath opens pre-scoped to the client.
  ///
  /// go_router drops both `extra:` and query params on the cross-
  /// `StatefulShellRoute`-branch jump from `/clients` to a create route, AND
  /// reuses an already-mounted create screen without re-running its `buildVm`
  /// (verified at runtime). So the seed rides on this singleton — which the
  /// branch switch can't touch — and [seedGenTick]/[seedGenFor] drive a
  /// generation-keyed `KeyedSubtree` on the `/new` route so the screen is
  /// recreated (and re-reads the seed) on every stage.
  Object? _stagedDraft;
  String? _stagedDraftBasePath;
  final Map<String, int> _seedGen = {};

  /// Bumps whenever a create draft is staged. The `/new` route watches this so
  /// a stage recreates the create screen's State even when it was already
  /// mounted (go_router would otherwise reuse it and skip `buildVm`).
  final ValueNotifier<int> seedGenTick = ValueNotifier(0);

  /// Stage [draft] (a seed entity, e.g. an `Invoice`) to pre-fill the next
  /// create screen at [basePath] (e.g. `/invoices`), bumping that route's
  /// generation so the screen is recreated and its `buildVm` re-reads the seed.
  /// go_router drops route `extra:`/query on the cross-branch jump and reuses
  /// an already-mounted create screen, so the seed rides on this singleton
  /// instead. Pass null for a blank create (still bumps, clearing a stale seed).
  void stageCreateDraft(String basePath, Object? draft) {
    _stagedDraft = draft;
    _stagedDraftBasePath = draft == null ? null : basePath;
    _seedGen[basePath] = (_seedGen[basePath] ?? 0) + 1;
    seedGenTick.value++;
  }

  /// Monotonic stage counter for [basePath] — the `/new` route keys its
  /// content on this so a fresh stage forces a fresh create State.
  int seedGenFor(String basePath) => _seedGen[basePath] ?? 0;

  /// One-shot read of the staged draft for [basePath] as [T], clearing it.
  /// Null when nothing is staged or it was staged for a different route / type.
  T? takeCreateDraft<T>(String basePath) {
    final draft = _stagedDraft;
    final result = (_stagedDraftBasePath == basePath && draft is T)
        ? draft
        : null;
    if (result != null) {
      _stagedDraft = null;
      _stagedDraftBasePath = null;
    }
    return result;
  }

  // -- SidebarBadgeContext -------------------------------------------------

  @override
  Stream<int> watchEntityCount(
    EntityType type,
    String companyId, {
    String modeId = kBadgeModeTotal,
  }) {
    // Built once at construction (in `Services.build`) from the wired
    // entities' typed `watchBadgeCount` methods. Sidebar-visible entities are
    // present; settings-only / bundled-only / disabled ones return zero so
    // unwired sidebar rows degrade gracefully (the row just shows no badge).
    final watcher = _countWatchers[type];
    if (watcher == null) return Stream.value(0);
    // The `assigned_to_me` mode is the only one that needs a value from
    // outside the row, and `Services` is where the session lives — so resolve
    // it here rather than making every call site pass it. An empty id (no
    // session) counts nothing, never everything.
    return watcher(companyId, modeId, auth.session.value?.userId ?? '');
  }

  @override
  Stream<int> watchOutboxPending(String companyId) =>
      db.outboxDao.watchPendingCount(companyId: companyId);

  @override
  Stream<int> watchOutboxDead(String companyId) =>
      db.outboxDao.watchDeadCount(companyId: companyId);

  /// Sidebar count streams keyed by entity type. Populated once in
  /// [Services.build] from [WiredEntities.countWatchers] and read by
  /// [watchEntityCount]. Keyed by entity type; each entry takes
  /// `(companyId, modeId, currentUserId)`.
  final Map<EntityType, SidebarCountWatcher> _countWatchers;

  /// First-page prefetch callbacks keyed by entity type. Fired in parallel
  /// from [prefetchSidebarEntities] on every active-company change so the
  /// sidebar count badges populate before the user opens each list.
  final Map<EntityType, Future<bool> Function(String companyId)>
  _firstPagePrefetchers;

  /// Pull the first page of every workspace-sidebar entity for [companyId].
  /// Fired fire-and-forget on every login / refresh / company-switch /
  /// restore (via the `onActiveCompanyChanged` chain in [Services.build]).
  /// Each entity is dispatched in parallel; individual failures are caught +
  /// logged so a single 401 / network blip can't take down login. Cursor
  /// short-circuiting keeps subsequent fires cheap — only the first time a
  /// company is seen does this hit the network for every entity.
  Future<void> prefetchSidebarEntities(String companyId) =>
      _runSidebarPrefetch(_firstPagePrefetchers, companyId);

  /// Re-download every user-browsable ("own route") entity for [companyId] in a
  /// single user-initiated pass — the download half of the "Sync" / "Force full
  /// sync" action. Runs a full [AuthRepository.refresh] first (re-bundles the
  /// `first_load` reference data and advances the company `lastSyncAt` cursor),
  /// then a forced `refreshAll(full: true)` per entity.
  ///
  /// Skips entities whose module the company has switched off (Settings →
  /// Account Management → Enabled Modules) — they aren't browsable in the nav,
  /// so there's nothing to cache for offline use. The mask is read *after* the
  /// refresh so a just-changed module setting is honored. The covered set is the
  /// workspace-sidebar list entities (see [_resyncSteps] / [resyncEntityTypes]).
  ///
  /// Sequential by design: a large account's full pull shouldn't open dozens of
  /// parallel connections, and it keeps the load gentle on the server. Per-entity
  /// failures are caught and collected so one bad entity can't abort the rest —
  /// the returned list names the entities that failed (empty == all clean). A
  /// failing auth refresh throws (the pass is meaningless without it).
  ///
  /// Non-destructive: each `refreshAll` writes pages through
  /// `upsertAllPreservingDirty`, so unsynced offline edits (`is_dirty` rows) and
  /// their queued outbox payloads survive the refresh. Bundled/settings entities
  /// (task statuses, gateways, designs, payment terms, …) are intentionally
  /// omitted — `auth.refresh(fullSync: true)` already re-bundles those.
  ///
  /// [onProgress] reports `(completed, total)` over the module-filtered plan —
  /// `(0, n)` once the plan is known, then after each entity. [isCancelled] is
  /// polled at each entity boundary. Both are driven by [ResyncController];
  /// direct callers can omit them.
  Future<List<String>> resyncAllEntities({
    required String companyId,
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await auth.refresh(fullSync: true);
    // The full refresh re-locked the Account-Management gate. Pull the
    // canonical company back so it re-opens — otherwise the Overview toggles
    // stay disabled until the user navigates away and back. (This also used to
    // be how the ~29 envelope-omitted columns got restored; the envelope now
    // carries them, so it's the gate alone.) Best-effort: `company.refresh`
    // swallows errors.
    await company.refresh(companyId);
    final enabledModules =
        (await db.companiesDao.byId(companyId))?.enabledModules ?? 0;
    // Materialize the module-filtered plan up front so the reported step total
    // is exact — counting steps that are then skipped would misreport how far
    // along the pass is on a company with modules switched off.
    final planned = [
      for (final step in _resyncSteps(companyId))
        if (isEntityModuleEnabledForCompany(step.$1, enabledModules)) step,
    ];
    onProgress?.call(0, planned.length);
    final failed = <String>[];
    for (var i = 0; i < planned.length; i++) {
      // Cooperative cancellation (logout): that wipes every Drift table, and
      // the rest of this loop would keep writing rows into the wiped database.
      // Entity granularity only — `refreshAll` pages internally and can't be
      // interrupted, so the entity already in flight still completes.
      if (isCancelled?.call() ?? false) break;
      final (type, run) = planned[i];
      try {
        await run();
      } catch (e, st) {
        _servicesLog.warning('resyncAllEntities: "${type.name}" failed', e, st);
        failed.add(type.name);
      }
      onProgress?.call(i + 1, planned.length);
    }
    return failed;
  }

  /// One-tap "Sync": push any queued offline edits, then re-download everything
  /// ([resyncAllEntities]). Backs the sidebar header's Sync button and both
  /// Settings entry points, funnelled through [resync] so they single-flight.
  ///
  /// Push-before-pull is the meaningful order — the server sees the user's
  /// local edits before we re-download over them. The push is best-effort: a
  /// failed drain must not block the download, since the queued rows stay
  /// queued and retry on their own schedule (and conflicts / 412s raised by the
  /// drain surface through `SyncEventListener` as usual).
  Future<List<String>> syncNow({
    required String companyId,
    void Function(int completed, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    try {
      await sync.flushNow(companyId: companyId);
    } catch (e, st) {
      _servicesLog.warning('syncNow: outbox flush failed', e, st);
    }
    if (isCancelled?.call() ?? false) return const <String>[];
    return resyncAllEntities(
      companyId: companyId,
      onProgress: onProgress,
      isCancelled: isCancelled,
    );
  }

  /// The own-route entities a Sync pass re-pulls, each paired with the
  /// repo call that loads it — the single source of truth for
  /// [resyncAllEntities] and [resyncEntityTypes]. Covers exactly the
  /// workspace-sidebar ([SidebarSection.top]) list entities; the bank-feature
  /// config (`bankAccount`, `transactionRule`) is reached via Settings, not a
  /// browsable list, so it's excluded. `resync_coverage_test` guards this set
  /// against drift. Clients first so client-referencing entities resolve.
  List<(EntityType, Future<void> Function())> _resyncSteps(
    String companyId,
  ) => [
    (
      EntityType.client,
      () => clients.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.product,
      () => products.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.invoice,
      () => invoices.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.recurringInvoice,
      () => recurringInvoices.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.quote,
      () => quotes.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.credit,
      () => credits.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.payment,
      () => payments.refreshAll(companyId: companyId, full: true),
    ),
    (EntityType.task, () => tasks.refreshAll(companyId: companyId, full: true)),
    (
      EntityType.project,
      () => projects.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.expense,
      () => expenses.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.recurringExpense,
      () => recurringExpenses.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.vendor,
      () => vendors.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.purchaseOrder,
      () => purchaseOrders.refreshAll(companyId: companyId, full: true),
    ),
    (
      EntityType.transaction,
      () => bankTransactions.refreshAll(companyId: companyId, full: true),
    ),
  ];

  /// EntityTypes covered by [resyncAllEntities] (module-gating aside), derived
  /// from [_resyncSteps] so the list and the coverage set can't drift. The empty
  /// [companyId] is irrelevant here — only the types are read; the thunks are
  /// never invoked. `resync_coverage_test` asserts this set covers every
  /// workspace-sidebar list entity.
  Set<EntityType> get resyncEntityTypes => {
    for (final (type, _) in _resyncSteps('')) type,
  };

  /// Build a [Formatter] bound to the given company. Awaits
  /// `statics.ensureLoaded()` (idempotent — a no-op once warm) and reads the
  /// company's settings JSON from Drift.
  ///
  /// Memoized per-company: a detail screen that calls this once per money
  /// field doesn't hit Drift N times. Call [invalidateFormatter] when a
  /// company's settings are updated (e.g. SettingsRepository writes) so the
  /// next read rebuilds.
  ///
  /// Falls back to [CompanyFormatSettings.fallback] when the company row is
  /// missing — keeps the UI working on a stale/empty cache instead of
  /// throwing.
  Future<Formatter> formatterFor(String companyId) {
    final cached = _formatterCache[companyId];
    if (cached != null) return cached;
    final future = _buildFormatter(companyId);
    _formatterCache[companyId] = future;
    // Mirror the resolved [Formatter] into a sync map so callers in
    // initState / cell-commit paths can read it without awaiting.
    // Cleared alongside the Future cache by [invalidateFormatter].
    future.then(
      (f) => _formatterReady[companyId] = f,
      onError: (_) => _formatterCache.remove(companyId),
    );
    return future;
  }

  final Map<String, Formatter> _formatterReady = {};

  /// Sync accessor for an already-resolved [Formatter]. Returns null if
  /// [formatterFor] hasn't been called yet (or is still in flight).
  /// Used by inline-edit widgets that need locale-aware parsing on
  /// the very first keystroke (e.g. comma-decimal users typing into
  /// the line-item table) without paying for an async fetch each
  /// build.
  Formatter? formatterIfReady(String companyId) => _formatterReady[companyId];

  Future<Formatter> _buildFormatter(String companyId) async {
    await statics.ensureLoaded();
    final row = await db.companiesDao.byId(companyId);
    var settings = row == null
        ? CompanyFormatSettings.fallback
        : CompanyFormatSettings.fromCompanyJson(
            row.settings.isEmpty
                ? const {}
                : jsonDecode(row.settings) as Map<String, dynamic>,
          );
    if (row != null) {
      // first_month_of_year / first_day_of_week / use_comma_as_decimal_place
      // are top-level company columns, not part of the `settings` JSON blob —
      // overlay them from the row so the Formatter (and everything that reaches
      // date_ranges.dart through it) sees the persisted fiscal-year / week-start
      // / decimal-separator values.
      settings = settings.withCompanyColumns(
        firstMonthOfYear: int.tryParse(row.firstMonthOfYear) ?? 1,
        // Deliberately NOT `?? 0`: the server leaves this column blank until
        // the user picks a value, and collapsing that onto 0 makes "never
        // configured" indistinguishable from "explicitly Sunday" — which killed
        // the date-range calendar's locale fallback. See
        // `CompanyFormatSettings.configuredFirstDayOfWeek`; date MATH still
        // reads the non-null `.firstDayOfWeek` getter and gets 0.
        firstDayOfWeek: int.tryParse(row.firstDayOfWeek),
        useCommaAsDecimalPlace: row.useCommaAsDecimalPlace,
      );
    }
    return Formatter(
      settings: settings,
      currencies: statics.currencies,
      countries: statics.countries,
      dateFormats: statics.dateFormats,
    );
  }

  /// Drop the cached [Formatter] for [companyId]. Call after writing the
  /// company's settings or after a statics refresh so the next
  /// [formatterFor] rebuilds against fresh state. Cheap when no entry is
  /// cached.
  void invalidateFormatter(String companyId) {
    _formatterCache.remove(companyId);
    _formatterReady.remove(companyId);
  }

  /// Drop every cached [Formatter]. Called on logout (via [Services.build]'s
  /// teardown path) so a subsequent login can't observe the previous user's
  /// company-currency settings.
  void invalidateAllFormatters() {
    _formatterCache.clear();
    _formatterReady.clear();
  }

  final Map<String, Future<Formatter>> _formatterCache = {};

  /// Construct the full graph. The DB is passed in so `main.dart` can pick
  /// the open-with-recovery code path and surface a banner if needed.
  static Services build({
    required AppDatabase db,
    TokenStorage? tokenStorage,
    BiometricService? biometricService,
    DeviceContactsService? deviceContactsService,
    ConnectivityWatcher? connectivityWatcher,
    http.Client? httpClient,
    DiagnosticsLog? diagnosticsLog,
    DebugCaptureStore? debugCaptureStore,
  }) {
    final passwordCache = PasswordCache();
    final authService = AuthService(httpClient: httpClient);
    final tokenStore = tokenStorage ?? defaultTokenStorage();
    final auth = AuthRepository(
      db: db,
      authService: authService,
      tokenStorage: tokenStore,
      passwordCache: passwordCache,
    );
    final serverVersion = ValueNotifier<String?>(null);
    final clientTooOld = ValueNotifier<({String minRequired, String current})?>(
      null,
    );
    final debugStore = debugCaptureStore ?? DebugCaptureStore();
    final debugPanelRevealed = ValueNotifier<bool>(false);
    // Assigned a few lines below; the `onUnauthorized` closure captures the
    // variable (not its value) and only ever runs once a request has come
    // back 401 — long after construction completes.
    late final SyncRepository sync;
    final apiClient = ApiClient(
      credentials: auth.credentials,
      passwordCache: passwordCache,
      // A 401 ends the session involuntarily (token revoked, "end all
      // sessions" on another device, removed from the company). The default
      // `logout()` is DESTRUCTIVE — it wipes the whole Drift database, and
      // `outbox` is one of the tables — so handing `auth.logout` straight to
      // ApiClient silently destroyed every queued offline edit. Consult the
      // same predicate the idle-timeout re-lock uses: with unsynced work
      // pending, keep the encrypted DB (and set the re-lock gate) so the rows
      // survive to drain after re-auth.
      onUnauthorized: () async =>
          auth.logout(preserveLocalData: await sync.hasUnsyncedWork()),
      onServerVersion: (v) => serverVersion.value = v,
      onClientTooOld: (info) => clientTooOld.value = info,
      httpClient: httpClient,
      debugCaptureStore: debugStore,
    );
    // Close the construction cycle: auth.addCompany uses apiClient to POST
    // /companies + GET /refresh; apiClient already reads auth.credentials.
    auth.apiClient = apiClient;
    // Empty mutable shell — populated below once entity repos exist. The
    // sync engine can be built without a registry filled in yet because
    // dispatch only fires inside [drainOnce], which won't run until after
    // construction completes.
    final registry = EntityRegistry({});
    sync = SyncRepository(db: db, registry: registry);
    // Wired into every BaseEntityRepository's onEnqueued so a mutation
    // drains as soon as it lands in the outbox (instead of sitting until
    // the next user-driven trigger). Fire-and-forget — drainOnce returns a
    // Future the caller intentionally drops; failures are surfaced via the
    // SyncEvent stream the UI shell already listens to.
    void kickDrain(String companyId) {
      sync.drainOnce(companyId: companyId);
    }

    // Per-entity dispatcher registry — populated by [wireEntities] below and
    // by the non-entity blocks (company, user) further down.
    final dispatchers = <EntityType, SyncDispatcher>{};

    final activitiesApi = ActivitiesApi(apiClient);
    final emailsApi = EmailsApi(apiClient);
    final searchApi = SearchApi(apiClient);
    final documentsApi = DocumentsApi(apiClient);

    // Build every CRUD-list entity (api + repository + sync dispatcher
    // registration). One block per entity lives in services_entity_wiring.dart
    // — see the file header for the rationale. Adding a new entity touches
    // that file plus kWiredEntityModules; services.dart stays untouched.
    final entities = wireEntities(
      EntityWiringContext(
        apiClient: apiClient,
        db: db,
        activitiesApi: activitiesApi,
        documentsApi: documentsApi,
        emailsApi: emailsApi,
        kickDrain: kickDrain,
        dispatchers: dispatchers,
      ),
    );
    final companiesApi = CompaniesApi(apiClient);
    // Built at the end of this factory and returned directly, so the closures
    // below capture it via `late final` — they only run at runtime, long after
    // assignment (mirrors the "instance doesn't exist yet in build" handling
    // documented at the top of this file).
    late final Services services;
    final companyRepo = CompanyRepository(
      db: db,
      api: companiesApi,
      onEnqueued: kickDrain,
      // Drop the memoized per-company Formatter after a settings write so a
      // Date Format / currency / decimal-separator change takes effect
      // without a logout/restart. Also recompute the app locale so a
      // Localization → Language change re-localizes the app on save (React
      // parity) without waiting for the next login/refresh.
      onSettingsWritten: (companyId) {
        services.invalidateFormatter(companyId);
        services.appLocale.onSettingsWritten();
      },
    );
    final quickbooksRepo = QuickbooksRepository(
      apiClient: apiClient,
      auth: auth,
    );
    final calendarConnectionRepo = CalendarConnectionRepository(
      apiClient: apiClient,
      auth: auth,
    );
    final dashboardApi = DashboardApi(apiClient);
    final dashboardRepo = DashboardRepository(db: db, api: dashboardApi);
    final projectChartsApi = ProjectChartsApi(apiClient);
    final reportsApi = ReportsApi(apiClient);
    final reportsRepo = ReportsRepository(api: reportsApi);
    final statics = StaticsRepository(
      db: db,
      service: StaticsService(apiClient),
    );
    final systemApi = SystemApi(apiClient);
    final systemLogs = SystemLogRepository(
      db: db,
      api: SystemLogsApi(apiClient),
    );
    final settings = SettingsRepository(db: db);
    final userSettingsApi = UserSettingsApi(apiClient);
    final userSettingsRepo = UserSettingsRepository(
      db: db,
      onEnqueued: kickDrain,
    );
    final usersApi = UsersApi(apiClient);
    final userRepo = UserRepository(
      db: db,
      api: usersApi,
      onEnqueued: kickDrain,
    );
    final savedViewsRepo = SavedViewsRepository(
      db: db,
      userSettings: userSettingsRepo,
    );
    final twoFactorApi = TwoFactorApi(apiClient);
    final twoFactorRepo = TwoFactorRepository(api: twoFactorApi, auth: auth);
    final supportApi = SupportApi(apiClient);
    final smtpApi = SmtpApi(apiClient);
    final templatesApi = TemplatesApi(apiClient);

    // Assemble the registry from the static module specs. Wired modules
    // pick up the dispatcher [wireEntity] registered above; disabled
    // modules get a stub dispatcher that throws if invoked.
    final handlers = <EntityType, EntityHandlers>{};
    for (final spec in kWiredEntityModules) {
      final dispatcher = dispatchers[spec.type];
      assert(
        dispatcher != null,
        'Wired entity ${spec.type} has no dispatcher in services.dart',
      );
      handlers[spec.type] = spec.toHandlers(dispatcher!);
    }
    for (final spec in kDisabledEntityModules) {
      handlers[spec.type] = spec.toHandlers(
        DisabledEntityDispatcher(spec.type),
      );
    }
    // Non-entity registrations that exist only for sync (no list/detail UI,
    // not in the sidebar). These don't fit the EntityModuleSpec mould.
    handlers[EntityType.company] = EntityHandlers(
      type: EntityType.company,
      wireName: 'company',
      apiPath: '/api/v1/companies',
      routePath: '/settings/company_details',
      icon: Icons.business,
      sidebarSection: SidebarSection.none,
      dispatcher: CompanySyncDispatcher(
        api: companiesApi,
        repo: companyRepo,
        documentsApi: documentsApi,
      ),
    );
    handlers[EntityType.user] = EntityHandlers(
      type: EntityType.user,
      wireName: kUserSettingsWireName,
      // `'user'` rows (full-user PUTs from Settings > User Details) flow
      // through the same composite dispatcher; see [CompositeUserDispatcher].
      extraWireNames: const [kUserWireName],
      apiPath: '/api/v1/company_users',
      routePath: '/settings/account',
      icon: Icons.person,
      sidebarSection: SidebarSection.none,
      dispatcher: CompositeUserDispatcher(
        userSettings: UserSettingsSyncDispatcher(
          api: userSettingsApi,
          repo: userSettingsRepo,
        ),
        user: UserSyncDispatcher(api: usersApi, repo: userRepo, auth: auth),
      ),
    );
    registry.replaceAll(handlers, branchOrder: kBranchOrder);

    // Close the second construction cycle: logout needs to halt in-flight
    // sync before wiping Drift; SyncRepository itself reads from Drift only,
    // so it can be built without AuthRepository.
    auth.onBeforeLogout = sync.cancel;
    // Activating a company (login / restore / switch) is the resume point for
    // the sync engine — `cancel()` latches until here, and `logout()` re-arms
    // `_lastActivatedCompanyId` so a re-login always fires this.
    auth.onActiveCompanyChanged = (companyId) {
      sync.resume();
      kickDrain(companyId);
    };
    // Clear app-lifetime per-session repo state on logout so a second user on
    // the same install never inherits it (e.g. the previous user's connected
    // calendar email — cross-user leak).
    auth.onSessionReset = calendarConnectionRepo.resetSessionState;
    // Fan-out the bundled per-entity arrays the /refresh envelope carries
    // alongside the company. Each [wireEntities] block contributes its own
    // applier to [entities.bundleAppliers]; this loop runs them in order.
    auth.onPersistBundles =
        ({required companyId, required company, required fullSync}) async {
          // A full sync re-writes the companies row from the envelope. Re-lock
          // the Account-Management gate so it matches the fresh-session state
          // (nothing canonically fetched yet) — conservative rather than
          // load-bearing now that the envelope carries every top-level column
          // and the re-seed prunes instead of wiping (issue #29).
          if (fullSync) companyRepo.markCanonicalStale(companyId);
          // Seed the full company roster so assigned-user ids resolve to names
          // in list tables / detail / pickers. Upsert-only, cursor-neutral —
          // the User Management list keeps its own paginated GET /users sync.
          await userRepo.applyBundle(
            companyId: companyId,
            bundle: company.users,
          );
          for (final apply in entities.bundleAppliers) {
            await apply(
              companyId: companyId,
              company: company,
              fullSync: fullSync,
            );
          }
        };
    // Seed the static catalog from the /refresh envelope's `static` blob
    // instead of a separate GET /api/v1/statics. No-op on the empty map a
    // login response or a delta refresh carries; the 7-day TTL keeps the
    // cold-start network fallback in `statics.ensureLoaded()` intact.
    auth.onApplyStatic = statics.applyStatic;
    // Auto-drain on connectivity transitions to online — the offline edits
    // that piled up will all flush as soon as the radio comes back.
    final connectivity = connectivityWatcher ?? ConnectivityWatcher.live();
    connectivity.onOnline.listen((_) {
      final companyId = auth.session.value?.currentCompanyId;
      if (companyId == null || companyId.isEmpty) return;
      sync.drainOnce(companyId: companyId);
    });
    final theme = ThemeController(db: db);
    final accentColor = AccentColorController(auth: auth, users: userRepo);
    final locale = LocaleController(db: db);
    final textScale = TextScaleController(db: db);
    final keyboardShortcuts = KeyboardShortcutsController(db: db);
    // Resolves the UI locale: device override → active company's
    // settings.language_id → English. Listens to the override + auth.session,
    // and is recomputed on settings save via the onSettingsWritten hook above.
    final appLocale = AppLocaleResolver(
      override: locale,
      auth: auth,
      statics: statics,
      db: db,
    );
    final confirmActions = ConfirmActionsController(db: db);
    // One instance, shared by the picker (`services.deviceContacts`) and the
    // sync engine below — the native impl caches the device's contacts account,
    // and two of them would probe for it twice.
    final deviceContacts =
        deviceContactsService ?? defaultDeviceContactsService();
    // `late` so the engine can capture the controller that owns it: the
    // controller is the engine's `ContactsSyncGroupStore` (it holds the
    // device-local blob the group ids live in), which makes the reference a
    // cycle. Same deferred-capture shape as the `resync` runner below; the
    // getter only runs during a sync pass, long after this assignment.
    late final ContactsSyncController contactsSync;
    contactsSync = ContactsSyncController(
      db: db,
      engine: ContactsSyncService(
        device: deviceContacts,
        clients: entities.clients,
        db: db,
        // Read lazily — the statics bundle can land after this point, and a
        // country name missing from an early card would stick until the next
        // time that contact was edited.
        countries: () => statics.countries,
        currentUserId: () => auth.session.value?.userId ?? '',
        groupStore: () => contactsSync,
      ),
    );
    final sidebar = SidebarController(db: db);
    final sidebarBadgeModes = SidebarBadgeModeController(db: db);
    // Captures the deferred `late final Services services` declared above —
    // same pattern as `companyRepo.onSettingsWritten`. The runner only fires on
    // a user action, long after the assignment below.
    final resync = ResyncController(
      runner: ({required companyId, onProgress, isCancelled}) async {
        final failed = await services.syncNow(
          companyId: companyId,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        // Freshen the device address book off the back of the pass that just
        // refreshed the data it reads. This is the single choke point for all
        // three Sync surfaces (sidebar button, Device Settings → Data, Account
        // Management → Force full sync), so hooking it here covers them at
        // once. Awaited, not fire-and-forget, so the Sync spinner still
        // reflects work in progress — but its result can't fail the pass.
        if (contactsSync.enabled && !(isCancelled?.call() ?? false)) {
          // `refreshClients: false` — `syncNow` above already re-downloaded
          // every client. Letting the reconcile refresh again would page the
          // whole client list a second time, back to back, with the Sync
          // spinner up throughout.
          await contactsSync.run(companyId, refreshClients: false);
        }
        return failed;
      },
    );
    // Company-scoped — clears itself off `auth.session` changes, same as the
    // nav history. No `onActiveCompanyChanged` hook needed here.
    final recentlyViewed = RecentlyViewedController(
      db: db,
      session: auth.session,
    );
    final settingsLevel = SettingsLevelController();
    // Reset the settings scope whenever the user logs out or switches
    // company — otherwise the next login would inherit a stale clientId
    // from the previous session and the settings shell would render the
    // banner against a missing target.
    // Foreground delta-refresh pump. Stop it before logout (no ticks while
    // signed out); (re)start it whenever a company becomes active (login,
    // restore, switch). The periodic timer is also paused/resumed on
    // app background/foreground by `SyncLifecycleObserver`.
    final refreshScheduler = RefreshScheduler(
      auth: auth,
      // Each tick, also drain the active company's outbox so rows parked on
      // backoff after a transient failure retry while the app stays
      // continuously online + foregrounded.
      onTick: () {
        final companyId = auth.session.value?.currentCompanyId;
        if (companyId != null && companyId.isNotEmpty) kickDrain(companyId);
      },
    );
    final priorOnBeforeLogout = auth.onBeforeLogout;
    auth.onBeforeLogout = () async {
      // Logout wipes every Drift table, and the remaining entities of an
      // in-flight download would keep writing rows into it behind the login
      // screen. Synchronous and cooperative — see `ResyncController.cancel`:
      // this stops the *next* entity, not the one already paging, so it
      // narrows the window rather than closing it.
      resync.cancel();
      // Same cooperative stop for a reconcile in flight — it writes to the
      // link table, which is about to be wiped.
      contactsSync.cancel();
      settingsLevel.reset();
      refreshScheduler.stop();
      services.toasts.clearAll();
      services.shortcutHints.reset();
      if (priorOnBeforeLogout != null) await priorOnBeforeLogout();
    };
    // Only on the destructive logout path — an idle-timeout re-lock keeps the
    // database (and therefore the link table), so the user's synced cards
    // should survive it rather than being deleted and rebuilt on re-entry.
    auth.onBeforeDataWipe = contactsSync.removeAllCompanies;
    final priorOnActiveCompanyChanged = auth.onActiveCompanyChanged;
    auth.onActiveCompanyChanged = (companyId) {
      settingsLevel.reset();
      refreshScheduler.start();
      priorOnActiveCompanyChanged?.call(companyId);
      // Fire-and-forget: pull the first page of every workspace-sidebar
      // entity so the count badges populate before the user opens each
      // list. Errors are caught + logged per entity so a 401 / network
      // blip can't take down login.
      unawaited(_prefetchSidebarOnCompanyChange(entities, companyId));
      // Warm the per-company Formatter cache so `formatterIfReady` is reliably
      // non-null on every screen (product edit, tax-rate edit, …) instead of
      // silently falling back to dot-decimal / default formats while the
      // future resolves. Memoized + non-blocking; the company row and statics
      // are already loaded by the time this hook fires.
      unawaited(services.formatterFor(companyId));
      // Tags aren't bundled into the login envelope, so refresh them per
      // company here (both entity types). Fire-and-forget; the picker +
      // Settings → Tags read from the resulting `tags` Drift table. The
      // `_lastActivatedCompanyId` guard fires this once per actual change.
      // Guard the failure: a fire-and-forget refresh that throws (offline,
      // or the fail-fast test client) must not surface as an unhandled async
      // error — it's retried on the next company activate.
      unawaited(
        entities.tags
            .refreshAll(companyId: companyId)
            .catchError(
              (Object e, StackTrace s) => _servicesLog.fine(
                'tag prefetch failed (non-fatal; retried on next activate)',
                e,
                s,
              ),
            ),
      );
    };
    services = Services._(
      db: db,
      auth: auth,
      clients: entities.clients,
      products: entities.products,
      tasks: entities.tasks,
      taskStatuses: entities.taskStatuses,
      tags: entities.tags,
      projects: entities.projects,
      vendors: entities.vendors,
      expenses: entities.expenses,
      recurringExpenses: entities.recurringExpenses,
      expenseCategories: entities.expenseCategories,
      companyGateways: entities.companyGateways,
      paymentTerms: entities.paymentTerms,
      taxRates: entities.taxRates,
      designs: entities.designs,
      groupSettings: entities.groupSettings,
      paymentLinks: entities.paymentLinks,
      schedules: entities.schedules,
      invoices: entities.invoices,
      quotes: entities.quotes,
      credits: entities.credits,
      purchaseOrders: entities.purchaseOrders,
      recurringInvoices: entities.recurringInvoices,
      bankAccounts: entities.bankAccounts,
      bankTransactions: entities.bankTransactions,
      transactionRules: entities.transactionRules,
      payments: entities.payments,
      webhooks: entities.webhooks,
      tokens: entities.tokens,
      company: companyRepo,
      companies: companiesApi,
      quickbooks: quickbooksRepo,
      calendarConnection: calendarConnectionRepo,
      dashboard: dashboardRepo,
      projectCharts: projectChartsApi,
      reports: reportsRepo,
      statics: statics,
      system: systemApi,
      systemLogs: systemLogs,
      settings: settings,
      userSettings: userSettingsRepo,
      user: userRepo,
      savedViews: savedViewsRepo,
      twoFactor: twoFactorRepo,
      support: supportApi,
      smtp: smtpApi,
      templates: templatesApi,
      activities: activitiesApi,
      emails: emailsApi,
      search: searchApi,
      documents: documentsApi,
      sync: sync,
      refreshScheduler: refreshScheduler,
      entityRegistry: registry,
      connectivity: connectivity,
      passwordCache: passwordCache,
      apiClient: apiClient,
      biometric:
          biometricService ??
          (kIsWeb ? const WebBiometricService() : LocalAuthBiometricService()),
      deviceContacts: deviceContacts,
      theme: theme,
      accentColor: accentColor,
      locale: locale,
      textScale: textScale,
      keyboardShortcuts: keyboardShortcuts,
      appLocale: appLocale,
      confirmActions: confirmActions,
      contactsSync: contactsSync,
      sidebar: sidebar,
      sidebarBadgeModes: sidebarBadgeModes,
      resync: resync,
      recentlyViewed: recentlyViewed,
      settingsLevel: settingsLevel,
      serverVersion: serverVersion,
      clientTooOld: clientTooOld,
      unsavedChangesGuard: UnsavedChangesGuard(),
      debugCaptureStore: debugStore,
      debugPanelRevealed: debugPanelRevealed,
      diagnosticsLog: diagnosticsLog,
      countWatchers: entities.countWatchers,
      firstPagePrefetchers: entities.firstPagePrefetchers,
    );
    return services;
  }
}
