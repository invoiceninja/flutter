import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/database_opener.dart';
import 'package:admin/data/db/db_open_exception.dart';

import 'package:admin/data/db/dao/bank_account_dao.dart';
import 'package:admin/data/db/dao/bank_transaction_dao.dart';
import 'package:admin/data/db/dao/client_dao.dart';
import 'package:admin/data/db/dao/companies_dao.dart';
import 'package:admin/data/db/dao/company_gateway_dao.dart';
import 'package:admin/data/db/dao/product_dao.dart';
import 'package:admin/data/db/dao/dashboard_cache_dao.dart';
import 'package:admin/data/db/dao/drafts_dao.dart';
import 'package:admin/data/db/dao/expense_category_dao.dart';
import 'package:admin/data/db/dao/expense_dao.dart';
import 'package:admin/data/db/dao/credit_dao.dart';
import 'package:admin/data/db/dao/purchase_order_dao.dart';
import 'package:admin/data/db/dao/recurring_invoice_dao.dart';
import 'package:admin/data/db/dao/group_setting_dao.dart';
import 'package:admin/data/db/dao/id_remap_dao.dart';
import 'package:admin/data/db/dao/invoice_dao.dart';
import 'package:admin/data/db/dao/quote_dao.dart';
import 'package:admin/data/db/dao/nav_state_dao.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/db/dao/payment_dao.dart';
import 'package:admin/data/db/dao/payment_term_dao.dart';
import 'package:admin/data/db/dao/project_dao.dart';
import 'package:admin/data/db/dao/recurring_expense_dao.dart';
import 'package:admin/data/db/dao/saved_views_dao.dart';
import 'package:admin/data/db/dao/payment_link_dao.dart';
import 'package:admin/data/db/dao/schedule_dao.dart';
import 'package:admin/data/db/dao/statics_dao.dart';
import 'package:admin/data/db/dao/sync_state_dao.dart';
import 'package:admin/data/db/dao/system_log_dao.dart';
import 'package:admin/data/db/dao/tag_dao.dart';
import 'package:admin/data/db/dao/task_dao.dart';
import 'package:admin/data/db/dao/task_status_dao.dart';
import 'package:admin/data/db/dao/tax_rate_dao.dart';
import 'package:admin/data/db/dao/token_dao.dart';
import 'package:admin/data/db/dao/transaction_rule_dao.dart';
import 'package:admin/data/db/dao/user_dao.dart';
import 'package:admin/data/db/dao/webhook_dao.dart';
import 'package:admin/data/db/dao/user_settings_dao.dart';
import 'package:admin/data/db/dao/design_dao.dart';
import 'package:admin/data/db/dao/vendor_dao.dart';
import 'package:admin/data/db/tables/bank_accounts_table.dart';
import 'package:admin/data/db/tables/bank_transactions_table.dart';
import 'package:admin/data/db/tables/clients_table.dart';
import 'package:admin/data/db/tables/companies_table.dart';
import 'package:admin/data/db/tables/company_gateways_table.dart';
import 'package:admin/data/db/tables/dashboard_cache_table.dart';
import 'package:admin/data/db/tables/designs_table.dart';
import 'package:admin/data/db/tables/documents_table.dart';
import 'package:admin/data/db/tables/drafts_table.dart';
import 'package:admin/data/db/tables/expense_categories_table.dart';
import 'package:admin/data/db/tables/expenses_table.dart';
import 'package:admin/data/db/tables/group_settings_table.dart';
import 'package:admin/data/db/tables/id_remap_table.dart';
import 'package:admin/data/db/tables/credits_table.dart';
import 'package:admin/data/db/tables/purchase_orders_table.dart';
import 'package:admin/data/db/tables/recurring_invoices_table.dart';
import 'package:admin/data/db/tables/invoices_table.dart';
import 'package:admin/data/db/tables/quotes_table.dart';
import 'package:admin/data/db/tables/nav_state_table.dart';
import 'package:admin/data/db/tables/outbox_table.dart';
import 'package:admin/data/db/tables/payment_terms_table.dart';
import 'package:admin/data/db/tables/payments_table.dart';
import 'package:admin/data/db/tables/products_table.dart';
import 'package:admin/data/db/tables/projects_table.dart';
import 'package:admin/data/db/tables/recurring_expenses_table.dart';
import 'package:admin/data/db/tables/saved_views_table.dart';
import 'package:admin/data/db/tables/payment_links_table.dart';
import 'package:admin/data/db/tables/schedules_table.dart';
import 'package:admin/data/db/tables/statics_table.dart';
import 'package:admin/data/db/tables/sync_state_table.dart';
import 'package:admin/data/db/tables/system_logs_table.dart';
import 'package:admin/data/db/tables/tags_table.dart';
import 'package:admin/data/db/tables/task_statuses_table.dart';
import 'package:admin/data/db/tables/tasks_table.dart';
import 'package:admin/data/db/tables/tax_rates_table.dart';
import 'package:admin/data/db/tables/tokens_table.dart';
import 'package:admin/data/db/tables/transaction_rules_table.dart';
import 'package:admin/data/db/tables/user_settings_table.dart';
import 'package:admin/data/db/tables/user_table.dart';
import 'package:admin/data/db/tables/vendors_table.dart';
import 'package:admin/data/db/tables/webhooks_table.dart';

part 'app_database.g.dart';

final _log = Logger('AppDatabase');

@DriftDatabase(
  tables: [
    Clients,
    Products,
    Outbox,
    IdRemap,
    SyncStateRows,
    Statics,
    Drafts,
    NavState,
    Companies,
    Accounts,
    Documents,
    UserSettings,
    Users,
    DashboardCache,
    SavedViews,
    GroupSettings,
    Tasks,
    TaskStatuses,
    Tags,
    Projects,
    CompanyGateways,
    PaymentTerms,
    TaxRates,
    ExpenseCategories,
    Vendors,
    Expenses,
    RecurringExpenses,
    Designs,
    PaymentLinks,
    Schedules,
    Invoices,
    Quotes,
    Credits,
    PurchaseOrders,
    RecurringInvoices,
    BankAccounts,
    BankTransactions,
    TransactionRules,
    Payments,
    SystemLogs,
    Webhooks,
    Tokens,
  ],
  daos: [
    ClientDao,
    ProductDao,
    CompanyGatewayDao,
    OutboxDao,
    IdRemapDao,
    SyncStateDao,
    StaticsDao,
    DraftsDao,
    NavStateDao,
    CompaniesDao,
    UserSettingsDao,
    UserDao,
    DashboardCacheDao,
    SavedViewsDao,
    GroupSettingDao,
    TaskDao,
    TaskStatusDao,
    TagDao,
    ProjectDao,
    PaymentTermDao,
    TaxRateDao,
    ExpenseCategoryDao,
    VendorDao,
    ExpenseDao,
    RecurringExpenseDao,
    DesignDao,
    PaymentLinkDao,
    ScheduleDao,
    InvoiceDao,
    QuoteDao,
    CreditDao,
    PurchaseOrderDao,
    RecurringInvoiceDao,
    BankAccountDao,
    BankTransactionDao,
    TransactionRuleDao,
    PaymentDao,
    SystemLogDao,
    WebhookDao,
    TokenDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // v1 is the shipped baseline (squashed pre-launch). The app is now in beta,
    // so installed databases hold real user data — every schema change from
    // here needs a real forward migration: bump `schemaVersion`, add an
    // `onUpgrade` step below, re-dump + re-generate, and extend the matrix test.
    // Skipping that is silent data loss — `isSchemaIntact()` (below) wipes any
    // DB whose columns don't match. Full workflow: `docs/migrations.md`.
    //
    // The company-scoped performance indexes and the Client filter indexes are
    // created imperatively (drift doesn't model them, so they're not part of
    // `createAll()`), hence the explicit calls here; `CREATE INDEX IF NOT
    // EXISTS` keeps this idempotent. NOTE: `onCreate` runs for fresh installs
    // only — `onUpgrade` re-runs both helpers so new indexes reach
    // already-installed databases.
    onCreate: (m) async {
      await m.createAll();
      await createPerformanceIndexes(this);
      await createClientFilterIndexes(this);
    },
    // v1 → v2: add `nav_state.keyboard_shortcuts_json` (device-local keyboard
    // shortcut overrides). A single nullable column — no data backfill needed
    // (null = "all defaults"). Manual `addColumn` (no versioned-schema
    // generation required for a plain column add).
    //
    // v2 → v3: add `nav_state.sidebar_badge_modes_json` (device-local sidebar
    // counter choices). Same shape — nullable, null = "every row on total".
    //
    // v3 → v4: add `nav_state.confirm_actions` (device-local "Confirm actions"
    // preference). Non-nullable with a `true` default, so SQLite's
    // `ADD COLUMN ... DEFAULT 1` backfills installed databases — existing users
    // get the guard switched on, matching a fresh install.
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(navState, navState.keyboardShortcutsJson);
      }
      if (from < 3) {
        await m.addColumn(navState, navState.sidebarBadgeModesJson);
      }
      if (from < 4) {
        await m.addColumn(navState, navState.confirmActions);
      }
      // Idempotent (CREATE INDEX IF NOT EXISTS) — re-run so any index a future
      // step adds reaches installed DBs. Cheap no-op for the current indexes.
      await createPerformanceIndexes(this);
      await createClientFilterIndexes(this);
    },
  );

  /// Wipe every table. Used by `logout()` and "Reset local data".
  ///
  /// Loops over [allTables] — Drift's generated list of every `@DriftTable`
  /// declared on the database — so a new entity added to the
  /// `@DriftDatabase(tables: …)` list is cleared automatically without
  /// touching this method.
  Future<void> wipe() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }

  /// Wipe rows for a single company across every `company_id`-scoped table.
  /// Used by Danger Zone → Purge / Delete so a destructive op on company A
  /// doesn't silently nuke pending edits on company B.
  ///
  /// Discovery is automatic: any `@DriftTable` whose `$columns` includes a
  /// column named `company_id` gets a `DELETE … WHERE company_id = ?` —
  /// adding a new company-scoped entity needs no edits here. The `companies`
  /// table itself is intentionally NOT scoped this way (the row belongs to
  /// the account record, not "to itself"), so it's never touched here. Use
  /// `companiesDao` if you need to remove the row.
  Future<void> wipeForCompany(String companyId) async {
    await transaction(() async {
      for (final table in allTables) {
        final hasCompanyId = table.$columns.any((c) => c.name == 'company_id');
        if (!hasCompanyId) continue;
        // `table.actualTableName` is the Drift-generated identifier from a
        // `@DriftTable` annotation — never user input — so the inline
        // interpolation here is safe. `companyId` is bound through the `?`
        // placeholder, so SQL injection there is impossible regardless.
        await customStatement(
          'DELETE FROM ${table.actualTableName} WHERE company_id = ?',
          [companyId],
        );
      }
    });
  }
}

/// Open the app database with recovery if the underlying store is corrupt
/// or its schema has drifted from what the generated code expects.
///
/// Platform specifics live behind [openDatabaseExecutor] /
/// [destroyDatabaseStore] in `database_opener.dart`: an encrypted SQLCipher
/// file (keyed from the OS keychain) on native, an unencrypted IndexedDB /
/// OPFS store via drift WASM on web. This orchestrator — the `SELECT 1`
/// probe, the [isSchemaIntact] check, and the catch→reset flow — is
/// platform-agnostic and identical on every target.
///
/// Two failure modes trigger recovery (destroy the store + open fresh +
/// return `wasReset: true` so `main` routes the user to `/login`):
///   1. Open / probe fails (corrupt store, irreconcilable downgrade).
///   2. Open succeeds but a table is missing a column the code expects —
///      i.e. a prior schema migration didn't fully apply on this device.
///      Without this backstop a missing column surfaces as a fatal
///      `SqliteException` deep inside login (`_persistAndActivate` INSERT)
///      with no path forward for the user. Caught here, the user just sees
///      "/login" and a fresh sync.
Future<({AppDatabase db, bool wasReset})> openAppDatabase() async {
  Future<AppDatabase> openFresh() async =>
      AppDatabase(await openDatabaseExecutor());

  Future<({AppDatabase db, bool wasReset})> resetAndReopen() async {
    await destroyDatabaseStore();
    return (db: await openFresh(), wasReset: true);
  }

  try {
    final db = await openFresh();
    // Force a trivial query so a corrupt store (or wrong key — `PRAGMA key`
    // doesn't fail eagerly, the first read does) surfaces here, not later.
    // This also drives the lazy connection open + runs any pending
    // migrations.
    await db.customSelect('SELECT 1').getSingleOrNull();
    if (!await isSchemaIntact(db)) {
      _log.severe('Drift schema drift detected; resetting local data');
      await db.close();
      return resetAndReopen();
    }
    return (db: db, wasReset: false);
  } on KeyringUnavailableException {
    // The OS secret store is unreachable, so we couldn't get the encryption
    // key. Resetting can't help (destroying the DB file then reopening
    // re-throws here on the next key fetch — the Linux snap crash-loop), and
    // it would needlessly wipe the user's data over a transient/permission
    // issue. Propagate so main() can show an actionable error screen.
    rethrow;
  } catch (e, st) {
    _log.severe('Drift open failed; recovering by resetting local data', e, st);
    return resetAndReopen();
  }
}

/// Checks every declared table's column set against what SQLite reports
/// via `PRAGMA table_info`. Returns false if any expected column or table
/// is missing — i.e. a prior schema migration didn't land on this device.
///
/// Cheaper and more reliable than `SELECT col, col, ... LIMIT 0` probes:
/// SQLite's legacy "double-quoted string fallback" (a misspelled column in
/// `SELECT "foo"` silently resolves to the string literal `'foo'`) means
/// the SELECT-probe variant misses missing columns entirely.
///
/// Exposed (not private) so integration tests can verify the drift-detection
/// path without needing the platform-specific path_provider glue around the
/// real [openAppDatabase].
Future<bool> isSchemaIntact(AppDatabase db) async {
  try {
    for (final table in db.allTables) {
      final rows = await db
          .customSelect('PRAGMA table_info(${table.actualTableName})')
          .get();
      if (rows.isEmpty) {
        _log.severe('Table missing: ${table.actualTableName}');
        return false;
      }
      final actual = rows.map((r) => r.data['name'] as String).toSet();
      for (final expected in table.columnsByName.keys) {
        if (!actual.contains(expected)) {
          _log.severe('Column missing: ${table.actualTableName}.$expected');
          return false;
        }
      }
    }
    return true;
  } catch (e, st) {
    _log.severe('Drift schema validation failed', e, st);
    return false;
  }
}

/// Create the company-scoped list/sort/count indexes. Auto-discovers the
/// per-entity tables (any Drift table carrying a `company_id` column) so a
/// newly-added entity is covered without editing this list.
///
/// `(company_id, updated_at)` serves the company filter + the default
/// `updated_at` ordering + the keyset pagination cursor; `(company_id,
/// is_deleted)` serves the active/deleted state filter and the badge
/// `COUNT(*)`. Not part of `createAll()` (drift doesn't model these indexes),
/// so the migration strategy calls it explicitly; `IF NOT EXISTS` keeps it
/// safe to call on `onCreate` and on every subsequent boot.
Future<void> createPerformanceIndexes(AppDatabase db) async {
  for (final table in db.allTables) {
    final columns = table.$columns.map((c) => c.name).toSet();
    if (!columns.contains('company_id')) continue;
    final t = table.actualTableName;
    if (columns.contains('updated_at')) {
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_${t}_company_updated '
        'ON $t (company_id, updated_at)',
      );
    }
    if (columns.contains('is_deleted')) {
      await db.customStatement(
        'CREATE INDEX IF NOT EXISTS idx_${t}_company_deleted '
        'ON $t (company_id, is_deleted)',
      );
    }
  }
}

/// Targeted indexes for the high-cardinality Client filter columns
/// (`country_id` / `group_settings_id`) that the generic
/// [createPerformanceIndexes] loop doesn't cover (it only indexes
/// `updated_at` / `is_deleted`). Called from the migration strategy on fresh
/// installs; `IF NOT EXISTS` keeps it idempotent.
Future<void> createClientFilterIndexes(AppDatabase db) async {
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_clients_company_country '
    'ON clients (company_id, country_id)',
  );
  await db.customStatement(
    'CREATE INDEX IF NOT EXISTS idx_clients_company_group '
    'ON clients (company_id, group_settings_id)',
  );
}

/// Shared denormalized columns every entity table carries: id, company id,
/// tmp id, timestamps, dirty/deleted flags, and the four optional
/// `custom_value` columns Invoice Ninja exposes per entity. Entity tables
/// (Invoice, Quote, Payment, …) declare their per-entity columns alongside
/// these.
///
/// A column-contract reference, not a migration helper — concrete Drift table
/// classes mirror these column names/types.
class StandardEntityColumns {
  const StandardEntityColumns._();

  /// Documents the contract Invoice/Quote/Product/etc. tables follow. Concrete
  /// table classes mirror this list of columns by name and type. The
  /// `customFieldCount` parameter records the per-entity custom-field arity
  /// in the class doc rather than at runtime.
  static const List<String> requiredColumnNames = <String>[
    'id',
    'company_id',
    'temp_id',
    'updated_at',
    'created_at',
    'archived_at',
    'is_dirty',
    'is_deleted',
    'payload',
  ];

  static const List<String> customFieldColumnNames = <String>[
    'custom_value1',
    'custom_value2',
    'custom_value3',
    'custom_value4',
  ];
}
