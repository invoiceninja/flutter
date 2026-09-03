import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';
import 'package:admin/ui/features/clients/widgets/client_bulk_update_dialog.dart';
import 'package:logging/logging.dart';

final _log = Logger('ClientListViewModel');

/// The `overdue` status tab / sidebar counter, spelled once. Matches the
/// `case` in `ClientDao.badgeModePredicate` — per-entity mode ids carry no
/// shared constants, and a typo here would silently disable the hydration
/// below without failing anything.
const String _kOverdueMode = 'overdue';

/// Invoice pages [ClientListViewModel._hydrateOverdueInvoices] will pull.
/// 5 x the invoice repo's page size = 250 overdue invoices, the same bound
/// (and the same literal) the other bounded in-VM walks use. The common case
/// is ONE request: an account with fewer than a page of overdue invoices comes
/// back short and stops. Beyond the bound the tab under-reports exactly as the
/// rest of the local-cache counter system does, and a Sync fixes it.
const int _kOverdueHydrationMaxPages = 5;

/// Drives the read-only Clients list screen.
///
/// All list-screen machinery — pagination, search, filter, sort, multiselect,
/// filter persistence, column selection — lives on [GenericListViewModel].
/// This subclass plugs in the client-specific bits: which column registry
/// to use, how to ask the repo for rows, and the bulk-action predicates.
/// When entity #2 (Invoice) lands, it follows the same shape with a swap of
/// repo and column registry.
class ClientListViewModel extends GenericListViewModel<Client> {
  ClientListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
    this.groupSettingsId,
    this.invoices,
  });

  final ClientRepository repo;

  /// The invoice repository, used for exactly one thing: pulling in the rows
  /// the `overdue` status tab's Drift predicate subqueries (#119).
  ///
  /// Optional so a test that doesn't exercise that tab needn't build one —
  /// null degrades the tab to its cache-only behaviour rather than breaking
  /// it. Production wiring always supplies it.
  final InvoiceRepository? invoices;

  /// When non-null, scopes the list to one group (the embedded
  /// clients-in-group tab). Drives a locked `group` filter + a forced
  /// `group_settings_id` predicate on the local watch.
  final String? groupSettingsId;

  /// One hydration per data generation, so switching away from the tab and
  /// back — or any later filter / search / sort change — doesn't re-pull a
  /// slice that is already in Drift. Re-armed by pull-to-refresh; a Sync makes
  /// it moot by sweeping every invoice in.
  ///
  /// Set BEFORE the first await as a **concurrency** guard: two page-1 fetches
  /// can overlap (a fast filter change while the first hydration is still in
  /// flight) and would otherwise both walk the pages. It is deliberately NOT a
  /// guard against the auto-chain, which cannot reach the hydration at all —
  /// `loadMore` fetches `loadedPages + 1`, always >= 2, and the call site is
  /// gated on `page == 1`. That is also why a FAILED attempt un-latches: with
  /// no loop to protect against, the worst case is one extra request per
  /// user-initiated reset, and the reward is that an offline blip heals on the
  /// user's next interaction instead of needing a pull-to-refresh.
  bool _overdueInvoicesHydrated = false;

  // ── Configuration ──────────────────────────────────────────────────

  @override
  Set<String> get lockedFilterKeyIds => {if (groupSettingsId != null) 'group'};

  @override
  EntityType get entityType => EntityType.client;

  @override
  List<ColumnDefinition<Client>> get allColumns => kAllClientColumns;

  @override
  List<String> get defaultColumnIds => kDefaultClientColumns;

  @override
  String get defaultSortField => ClientFieldIds.name;

  /// Must match the repo's page size — the Drift watch window is
  /// `pageSize * loadedPages` (see `GenericListViewModel.pageSize`).
  @override
  int get pageSize => repo.pageSize;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(clientColumnsById, field);

  @override
  String idOf(Client item) => item.id;

  @override
  bool isArchived(Client item) => item.archivedAt != null;

  @override
  bool isDeleted(Client item) => item.isDeleted;

  // ── Data-source hooks ──────────────────────────────────────────────

  @override
  Stream<List<Client>> watchPage() => repo.watchPage(
    badgeModeId: activeBadgeModeId,
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    sortField: sortField,
    sortAscending: sortAscending,
    customFilters: customFilters,
    extraFilters: _scopedExtraFilters(extraFilters),
  );

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) async {
    // Embedded clients-in-group tab: clients are already synced workspace-wide
    // (sidebar prefetch + main Clients list). Skip the network pull so a
    // `group=` server filter never advances — and corrupts — the shared
    // `client` delta cursor. Serve purely from the local Drift watch.
    if (groupSettingsId != null) return false;
    // #119: the `overdue` tab's Drift predicate is a subquery over the LOCAL
    // `invoices` table, and login prefetches page 1 only (the 50 newest by
    // `id DESC`) — so on any account whose overdue invoices aren't among those
    // 50 the tab read 0 over a false "No records found", AND, being local-only,
    // armed the auto-chain to page through clients for matches that could not
    // appear. Pull the slice the predicate reads before asking for clients.
    //
    // Gated on `page == 1` because every reset — initial load, tab select,
    // filter/search/sort change, saved view, nav_state restore, retry — funnels
    // through `fetchPage(page: 1, …)`, while `loadMore` and the auto-chain
    // don't. AWAITED rather than fired alongside: the base clears
    // `isLoadingPage` in its `finally`, so a late arrival would paint "No
    // records found" for a beat, and the auto-chain would meanwhile spend its
    // whole budget scanning clients against an empty invoice table.
    if (page == 1 && activeBadgeModeId == _kOverdueMode) {
      await _hydrateOverdueInvoices();
    }
    return repo.ensurePageLoaded(
      companyId: companyId,
      page: page,
      search: search,
      states: states,
      extraFilters: extraFilters,
      ignoreCursor: ignoreCursor,
    );
  }

  /// Force the group predicate onto the local watch when scoped. The locked
  /// `group` filter keeps the user from clearing it in the token search.
  Map<String, Set<String>> _scopedExtraFilters(Map<String, Set<String>> base) =>
      groupSettingsId == null
      ? base
      : {
          ...base,
          'group_settings_id': {groupSettingsId!},
        };

  @override
  Future<void> refreshAll() async {
    await repo.refreshAll(companyId: companyId);
    // Pull-to-refresh on Clients refreshes CLIENTS, so an invoice paid on
    // another device would leave its client sitting under Overdue. Re-arm and
    // re-pull inside the same spinner — the user asked to wait. (The Sync pass
    // needs no equivalent: it runs the invoice repo's own full `refreshAll`.)
    _overdueInvoicesHydrated = false;
    if (activeBadgeModeId == _kOverdueMode) await _hydrateOverdueInvoices();
  }

  /// One-shot, best-effort pull of the overdue invoices the `overdue` badge
  /// predicate subqueries (#119).
  ///
  /// Never throws: a failure leaves the tab exactly as it behaved before this
  /// existed — local cache only — which is strictly better than failing the
  /// clients list the user actually asked for. Nothing needs to be notified
  /// afterwards either: drift puts a subquery's table in the outer query's
  /// `readsFrom` set, so the clients watch and the tab's count stream both
  /// re-emit on the invoice upsert by themselves.
  Future<void> _hydrateOverdueInvoices() async {
    final invoiceRepo = invoices;
    if (invoiceRepo == null || _overdueInvoicesHydrated) return;
    _overdueInvoicesHydrated = true;
    try {
      for (var page = 1; page <= _kOverdueHydrationMaxPages; page++) {
        final more = await invoiceRepo.ensurePageLoaded(
          companyId: companyId,
          page: page,
          // The client subquery counts ACTIVE invoices only, so archived and
          // deleted rows are dead weight. Deliberately NOT the clients list's
          // own `states`: someone browsing archived clients still needs live
          // invoices to know which of them are late.
          states: const {EntityState.active},
          // The exact filter Invoices → Overdue already sends.
          // `InvoiceFilters::overdue()` is a no-arg method the dispatcher runs
          // whenever the key is present (the value is ignored), and its clause
          // is a SUPERSET of `invoiceOverdueFilter` — so the subquery gets
          // everything it needs.
          extraFilters: const {
            'overdue': {'true'},
          },
          // A non-empty `extraFilters` already makes this a narrowed fetch, so
          // the shared invoice delta cursor is neither read nor advanced.
          // Explicit anyway: the intent must not rest on `isNarrowedFetch`
          // keeping that shape.
          ignoreCursor: true,
        );
        if (!more) break;
      }
    } on NetworkException catch (e) {
      // Best-effort, same policy as the sidebar prefetch: an offline blip is
      // expected here and must not pollute the WARNING+ diagnostics log.
      _overdueInvoicesHydrated = false;
      _log.fine('overdue-invoice hydration skipped: ${e.message}');
    } catch (e, st) {
      _overdueInvoicesHydrated = false;
      _log.warning('overdue-invoice hydration failed', e, st);
    }
  }

  @override
  Stream<List<String>> watchDistinctCustomValues(int columnIndex) =>
      repo.watchDistinctCustomValues(
        companyId: companyId,
        columnIndex: columnIndex,
      );

  // ── Bulk actions ───────────────────────────────────────────────────

  @override
  Iterable<BulkAction<Client>> get bulkActions => [
    ...standardCrudBulkActions(
      isArchived: isArchived,
      isDeleted: isDeleted,
      archive: (id) => repo.archive(companyId: companyId, id: id),
      restore: (id) => repo.restore(companyId: companyId, id: id),
      delete: (id) => repo.delete(companyId: companyId, id: id),
    ),
    // Mass-edit one whitelisted field across the selection. The prep dialog
    // (showClientBulkUpdateDialog) supplies the `ClientBulkUpdate`; the repo
    // optimistically patches each client and enqueues a per-id mutation.
    BulkAction<Client>(
      id: 'bulk_update',
      labelKey: 'bulk_update',
      eligible: (c) => !isDeleted(c), // archived is editable; deleted isn't
      applyArg: (id, arg) {
        final update = arg as ClientBulkUpdate;
        final client = _clientById(id);
        if (client == null) return Future<void>.value();
        return repo.bulkUpdate(
          companyId: companyId,
          client: client,
          column: update.column,
          newValue: update.newValue,
        );
      },
    ),
  ];

  Client? _clientById(String id) {
    for (final c in items) {
      if (idOf(c) == id) return c;
    }
    return null;
  }

  /// Convenience wrappers for the multiselect AppBar — the same calls
  /// the existing UI already used, now backed by the generic engine.
  Future<({int ok, int skipped, int failed})> bulkArchive() =>
      applyBulkAction(bulkActionById('archive')!);

  Future<({int ok, int skipped, int failed})> bulkRestore() =>
      applyBulkAction(bulkActionById('restore')!);
}
