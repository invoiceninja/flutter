/// What it costs to lose a table's rows — the question every recovery path
/// has to answer before it may drop a table (`schema_repair.dart`).
///
/// The database mixes the user's own unsynced and local-only data with a
/// re-downloadable copy of the server, and a recovery that treats them alike
/// either keeps a broken cache or throws the user's work away. Every table is
/// classified in [kTableRetention]; `test/data/db/table_retention_test.dart`
/// fails the build on one that is not.
enum TableRetention {
  /// The user's own data, which exists nowhere else: queued and failed
  /// mutations, the temp-id map they rewrite through, local-only saved views
  /// and device preferences.
  durable,

  /// Re-downloadable, but `AuthRepository.restore()` needs these rows to
  /// resume the session at all — without them it signs the user out.
  anchor,

  /// A copy of server data, plus the caches and sync cursors derived from
  /// it. Losing the rows costs a re-download.
  cache,
}

/// Every table, by its SQL name. Anything missing here is treated as
/// [TableRetention.durable] — the safe answer for data nobody classified.
const Map<String, TableRetention> kTableRetention = {
  // The user's own data.
  'outbox': TableRetention.durable,
  'id_remap': TableRetention.durable,
  'saved_views': TableRetention.durable,
  'nav_state': TableRetention.durable,
  'drafts': TableRetention.durable,
  // What `restore()` resumes a session from.
  'accounts': TableRetention.anchor,
  'companies': TableRetention.anchor,
  'users': TableRetention.anchor,
  // Server copies, caches and cursors.
  'bank_accounts': TableRetention.cache,
  'bank_transactions': TableRetention.cache,
  'clients': TableRetention.cache,
  'company_gateways': TableRetention.cache,
  'credits': TableRetention.cache,
  'dashboard_cache': TableRetention.cache,
  'designs': TableRetention.cache,
  // Rebuildable only because the address-book group ids it hangs off live in
  // `nav_state.contacts_sync_json`, which is durable.
  'device_contact_links': TableRetention.cache,
  'documents': TableRetention.cache,
  'expense_categories': TableRetention.cache,
  'expenses': TableRetention.cache,
  'group_settings': TableRetention.cache,
  'invoices': TableRetention.cache,
  'payment_links': TableRetention.cache,
  'payment_terms': TableRetention.cache,
  'payments': TableRetention.cache,
  'products': TableRetention.cache,
  'projects': TableRetention.cache,
  'purchase_orders': TableRetention.cache,
  'quotes': TableRetention.cache,
  'recurring_expenses': TableRetention.cache,
  'recurring_invoices': TableRetention.cache,
  'schedules': TableRetention.cache,
  'statics': TableRetention.cache,
  'sync_state_rows': TableRetention.cache,
  'system_logs': TableRetention.cache,
  'tags': TableRetention.cache,
  'task_statuses': TableRetention.cache,
  'tasks': TableRetention.cache,
  'tax_rates': TableRetention.cache,
  'tokens': TableRetention.cache,
  'transaction_rules': TableRetention.cache,
  'user_settings': TableRetention.cache,
  'vendors': TableRetention.cache,
  'webhooks': TableRetention.cache,
};

TableRetention retentionOf(String tableName) =>
    kTableRetention[tableName] ?? TableRetention.durable;
