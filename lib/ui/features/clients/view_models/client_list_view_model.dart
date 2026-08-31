import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';
import 'package:admin/ui/features/clients/widgets/client_bulk_update_dialog.dart';

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
  });

  final ClientRepository repo;

  /// When non-null, scopes the list to one group (the embedded
  /// clients-in-group tab). Drives a locked `group` filter + a forced
  /// `group_settings_id` predicate on the local watch.
  final String? groupSettingsId;

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
  }) {
    // Embedded clients-in-group tab: clients are already synced workspace-wide
    // (sidebar prefetch + main Clients list). Skip the network pull so a
    // `group=` server filter never advances — and corrupts — the shared
    // `client` delta cursor. Serve purely from the local Drift watch.
    if (groupSettingsId != null) return Future.value(false);
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
  Future<void> refreshAll() => repo.refreshAll(companyId: companyId);

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
