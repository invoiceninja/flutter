import 'package:admin/data/db/dao/document_dao.dart';
import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/data/repositories/document_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/document_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

/// List ViewModel for the Documents screen — every uploaded file in the
/// company, whatever record it hangs off.
///
/// No lifecycle: the server never archives or soft-deletes a document
/// (`docs/documents-list.md`), so there is no state filter, no status strip
/// and no Archive / Restore. A row hidden by `is_deleted` is a delete still
/// waiting in the outbox.
class DocumentListViewModel extends GenericListViewModel<DocumentRecord> {
  DocumentListViewModel({
    required this.repo,
    required this.canEdit,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
  }) {
    // The server's list names no parent, so link what the records already
    // cached can tell — each time the list opens, since browsing an invoice
    // in between is how a file learns its record. Cheap when nothing is
    // unlinked.
    repo.relinkParents(companyId: companyId);
  }

  final DocumentRepository repo;

  /// Whether the signed-in user may delete [DocumentRecord] — the screen
  /// passes `documentEditable` over the live session. Without it bulk Delete
  /// was offered on files the row menu hides it for, and the server refused
  /// each with a 403: `document` has no row in `kPermissionEntities`, so the
  /// scaffold's own permission gate lets the action through.
  final bool Function(DocumentRecord document) canEdit;

  @override
  EntityType get entityType => EntityType.document;

  @override
  List<ColumnDefinition<DocumentRecord>> get allColumns => kAllDocumentColumns;

  @override
  List<String> get defaultColumnIds => kDefaultDocumentColumns;

  /// Newest upload first — `created_at` only grows, so a file added on the
  /// web lands on page 1 (`docs/sync.md` § Lists sort newest-first).
  @override
  String get defaultSortField => DocumentFieldIds.createdAt;

  @override
  bool get defaultSortAscending => false;

  /// Must match the repo's page size — the Drift watch window is
  /// `pageSize * loadedPages`.
  @override
  int get pageSize => repo.pageSize;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(documentColumnsById, field);

  @override
  String idOf(DocumentRecord item) => item.id;

  @override
  bool isArchived(DocumentRecord item) => item.archivedAt != null;

  @override
  bool isDeleted(DocumentRecord item) => item.isDeleted;

  @override
  Stream<List<DocumentRecord>> watchPage() => repo.watchPage(
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    sortField: sortField,
    sortAscending: sortAscending,
  );

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) => repo.ensurePageLoaded(
    companyId: companyId,
    page: page,
    search: search,
    states: states,
    extraFilters: extraFilters,
    ignoreCursor: ignoreCursor,
  );

  @override
  Future<void> refreshAll() async {
    await repo.refreshAll(companyId: companyId);
    await repo.relinkParents(companyId: companyId);
  }

  @override
  Iterable<BulkAction<DocumentRecord>> get bulkActions => [
    // Selection-level: the per-id `apply` is a deliberate no-op — the
    // screen's `EntityListBulkAction.onSelection` sends ONE request for the
    // whole selection (the server zips and emails it). Same shape as the
    // Projects list's document download.
    BulkAction<DocumentRecord>(
      id: 'download',
      labelKey: 'bulk_download',
      eligible: (d) => !d.isDeleted && !d.id.startsWith('tmp_'),
      apply: (_) async {},
    ),
    BulkAction<DocumentRecord>(
      id: 'delete',
      labelKey: 'delete',
      eligible: canEdit,
      apply: (id) => repo.delete(companyId: companyId, id: id),
      requiresPassword: true,
    ),
  ];
}
