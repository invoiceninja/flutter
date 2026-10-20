import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/_search_fold.dart';
import 'package:admin/data/db/dao/_distinct_stream.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/tables/document_records_table.dart';

part 'document_dao.g.dart';

/// Stable field ids for the Documents list's columns and sort. The values
/// are admin-portal's `DocumentFields`, so a layout saved there (in
/// `user_settings.table_columns`) carries over.
class DocumentFieldIds {
  static const String name = 'name';
  static const String type = 'type';
  static const String size = 'size';
  static const String width = 'width';
  static const String height = 'height';

  /// "Private" — the inverse of `is_public`; sorts on the real column.
  static const String isPrivate = 'private';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String id = 'id';

  /// The record the file hangs off. Display-only: a name has to be resolved
  /// through the parent's own table, so there is nothing to order by.
  static const String linkedTo = 'linked_to';

  /// Content hash. Payload-only — display-only.
  static const String hash = 'hash';

  /// Uploader. Payload-only on every table — display-only.
  static const String userId = 'user_id';
}

/// One parent table the relink pass reads: its SQL name, the wire name it is
/// stored under in `document_records.parent_type`, and the column that scopes
/// it to a company (`companies` is keyed by the company id itself).
typedef _ParentTable = ({String table, String wireName, String companyColumn});

/// Every table with a `documents` JSON column, by the parent wire name in
/// `kDocumentParentWireNames`. Constant, so the table names spliced into the
/// relink SQL never come from data.
const List<_ParentTable> _kParentTables = [
  (table: 'clients', wireName: 'client', companyColumn: 'company_id'),
  (table: 'products', wireName: 'product', companyColumn: 'company_id'),
  (table: 'invoices', wireName: 'invoice', companyColumn: 'company_id'),
  (
    table: 'recurring_invoices',
    wireName: 'recurring_invoice',
    companyColumn: 'company_id',
  ),
  (table: 'quotes', wireName: 'quote', companyColumn: 'company_id'),
  (table: 'credits', wireName: 'credit', companyColumn: 'company_id'),
  (table: 'payments', wireName: 'payment', companyColumn: 'company_id'),
  (table: 'tasks', wireName: 'task', companyColumn: 'company_id'),
  (table: 'projects', wireName: 'project', companyColumn: 'company_id'),
  (table: 'expenses', wireName: 'expense', companyColumn: 'company_id'),
  (
    table: 'recurring_expenses',
    wireName: 'recurring_expense',
    companyColumn: 'company_id',
  ),
  (table: 'vendors', wireName: 'vendor', companyColumn: 'company_id'),
  (
    table: 'purchase_orders',
    wireName: 'purchase_order',
    companyColumn: 'company_id',
  ),
  (table: 'group_settings', wireName: 'group', companyColumn: 'company_id'),
  (table: 'companies', wireName: 'company', companyColumn: 'id'),
];

@DriftAccessor(tables: [DocumentRecords])
class DocumentDao
    extends BaseEntityDao<$DocumentRecordsTable, DocumentRecordRow>
    with _$DocumentDaoMixin {
  DocumentDao(super.db);

  @override
  $DocumentRecordsTable get table => documentRecords;
  @override
  GeneratedColumn<String> get idColumn => documentRecords.id;
  @override
  GeneratedColumn<String> get companyIdColumn => documentRecords.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => documentRecords.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => documentRecords.isDirty;
  @override
  GeneratedColumn<int>? get archivedAtColumn => documentRecords.archivedAt;
  @override
  GeneratedColumn<int>? get updatedAtColumn => documentRecords.updatedAt;

  /// A window of the list. There is no lifecycle filter to apply: the server
  /// never archives or soft-deletes a document, so the only row hidden is one
  /// flagged `is_deleted` locally — a delete still waiting in the outbox.
  ///
  /// [search] mirrors `DocumentFilters::filter` (`name LIKE %…%`), so the
  /// rows the server answers a search with are the rows shown.
  Stream<List<DocumentRecordRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    String sortField = DocumentFieldIds.createdAt,
    bool sortAscending = false,
  }) {
    final q = select(documentRecords)
      ..where((d) => d.companyId.equals(companyId) & d.isDeleted.equals(false));
    if (search != null && search.isNotEmpty) {
      q.where((d) => searchLike(d.name, search));
    }
    q.orderBy([
      (d) => OrderingTerm(
        expression: _sortExpression(d, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (d) => OrderingTerm(expression: d.id),
    ]);
    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(DocumentRecords d, String field) {
    switch (field) {
      case DocumentFieldIds.name:
        return d.name.lower();
      case DocumentFieldIds.type:
        return d.fileType.lower();
      case DocumentFieldIds.size:
        return d.size;
      case DocumentFieldIds.width:
        return d.width;
      case DocumentFieldIds.height:
        return d.height;
      case DocumentFieldIds.isPrivate:
        return d.isPublic.not();
      case DocumentFieldIds.createdAt:
        return d.createdAt;
      case DocumentFieldIds.updatedAt:
        return d.updatedAt;
      case DocumentFieldIds.id:
        return d.id;
      default:
        // A silent fallback would let a column without a case here paint a
        // sort arrow while ordering by something else — and it blinds
        // `sortable_columns_test`, which finds an unmapped column by catching
        // this throw.
        throw ArgumentError(
          'Unknown sort field "$field" for Document — add a case in '
          '_sortExpression or stop exposing it as a sort option.',
        );
    }
  }

  Future<DocumentRecordRow?> byId({
    required String companyId,
    required String id,
  }) =>
      (select(documentRecords)
            ..where((d) => d.companyId.equals(companyId) & d.id.equals(id)))
          .getSingleOrNull();

  /// The rows linked to any of [parentIds] (of whatever type): what the
  /// `/refresh` harvester compares each record's full `documents` array
  /// against. One query per chunk of ids rather than one per record — a delta
  /// after a long absence carries thousands of records, all inside the
  /// refresh transaction, and `parent_id` has no index. The caller matches
  /// `parentType` itself.
  Future<
    List<
      ({
        String id,
        String parentType,
        String parentId,
        int updatedAt,
        bool isDirty,
      })
    >
  >
  linkedToAny({
    required String companyId,
    required List<String> parentIds,
  }) async {
    final out =
        <
          ({
            String id,
            String parentType,
            String parentId,
            int updatedAt,
            bool isDirty,
          })
        >[];
    for (final chunk in chunkIdsForSqlIn(parentIds)) {
      final q = selectOnly(documentRecords)
        ..addColumns([
          documentRecords.id,
          documentRecords.parentType,
          documentRecords.parentId,
          documentRecords.updatedAt,
          documentRecords.isDirty,
        ])
        ..where(
          documentRecords.companyId.equals(companyId) &
              documentRecords.parentId.isIn(chunk),
        );
      for (final r in await q.get()) {
        out.add((
          id: r.read(documentRecords.id)!,
          parentType: r.read(documentRecords.parentType) ?? '',
          parentId: r.read(documentRecords.parentId) ?? '',
          updatedAt: r.read(documentRecords.updatedAt) ?? 0,
          isDirty: r.read(documentRecords.isDirty) ?? false,
        ));
      }
    }
    return out;
  }

  /// Every stored row's id and dirty flag — what a full sweep compares the
  /// ids it saw against.
  Future<List<({String id, bool isDirty})>> allIds({
    required String companyId,
  }) async {
    final q = selectOnly(documentRecords)
      ..addColumns([documentRecords.id, documentRecords.isDirty])
      ..where(documentRecords.companyId.equals(companyId));
    return [
      for (final r in await q.get())
        (
          id: r.read(documentRecords.id)!,
          isDirty: r.read(documentRecords.isDirty) ?? false,
        ),
    ];
  }

  /// The parent link stored for each of [ids] that has one.
  Future<Map<String, ({String type, String id})>> parentsOf({
    required String companyId,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return const {};
    final out = <String, ({String type, String id})>{};
    for (final chunk in chunkIdsForSqlIn(ids)) {
      final q = selectOnly(documentRecords)
        ..addColumns([
          documentRecords.id,
          documentRecords.parentType,
          documentRecords.parentId,
        ])
        ..where(
          documentRecords.companyId.equals(companyId) &
              documentRecords.id.isIn(chunk) &
              documentRecords.parentId.isNotNull(),
        );
      for (final r in await q.get()) {
        final type = r.read(documentRecords.parentType);
        final parent = r.read(documentRecords.parentId);
        if (type == null || parent == null) continue;
        out[r.read(documentRecords.id)!] = (type: type, id: parent);
      }
    }
    return out;
  }

  /// The optimistic half of a rename / visibility change: the new values,
  /// flagged dirty so no server copy overwrites them before the outbox row
  /// drains. Parent link and everything else stay as they were.
  Future<void> writeLocalEdit({
    required String companyId,
    required String id,
    required String name,
    required bool isPublic,
    required String payload,
  }) =>
      (update(
        documentRecords,
      )..where((d) => d.companyId.equals(companyId) & d.id.equals(id))).write(
        DocumentRecordsCompanion(
          name: Value(name),
          isPublic: Value(isPublic),
          payload: Value(payload),
          isDirty: const Value(true),
        ),
      );

  /// Link a row to its record without touching anything else — what the
  /// harvester writes when the record is new information but the server copy
  /// it came with is not newer than the row already stored.
  Future<void> setParent({
    required String companyId,
    required String id,
    required String parentType,
    required String parentId,
  }) =>
      (update(
        documentRecords,
      )..where((d) => d.companyId.equals(companyId) & d.id.equals(id))).write(
        DocumentRecordsCompanion(
          parentType: Value(parentType),
          parentId: Value(parentId),
        ),
      );

  /// The discard reconciliation: clear the dirty flag AND the pending-delete
  /// flag. The base `clearDirtyById` leaves `is_deleted` alone, which for an
  /// entity with a Deleted view is right — but this list has no such view, so
  /// a delete the user discarded would otherwise hide the file for good.
  Future<void> clearDirtyAndDeleted({
    required String companyId,
    required String id,
  }) =>
      (update(
        documentRecords,
      )..where((d) => d.companyId.equals(companyId) & d.id.equals(id))).write(
        const DocumentRecordsCompanion(
          isDirty: Value(false),
          isDeleted: Value(false),
        ),
      );

  /// Hard-delete [ids] — except a dirty one. The caller has already ruled
  /// out the rows an outbox row speaks for; the dirty check sits here, in the
  /// DELETE itself, so a rename saved between the caller's read and this
  /// write still can't take its row with it.
  Future<int> deleteByIds({
    required String companyId,
    required List<String> ids,
  }) async {
    var deleted = 0;
    for (final chunk in chunkIdsForSqlIn(ids)) {
      deleted +=
          await (delete(documentRecords)..where(
                (d) =>
                    d.companyId.equals(companyId) &
                    d.id.isIn(chunk) &
                    d.isDirty.equals(false),
              ))
              .go();
    }
    return deleted;
  }

  /// Every document id a cached record still lists in its `documents`
  /// column — files the device has evidence still exist.
  ///
  /// What the full-sweep prune must keep: `GET /documents` shows a user
  /// without `view_document` only the files they uploaded or are assigned,
  /// while the `/refresh` harvest also files the ones on every record they
  /// can see. Same `json_valid` guard as [relinkFromParentTables].
  Future<Set<String>> idsListedOnRecords({required String companyId}) async {
    final out = <String>{};
    for (final p in _kParentTables) {
      final rows = await customSelect(
        "SELECT json_extract(j.value, '\$.id') AS did "
        'FROM ${p.table} p, json_each('
        "  CASE WHEN json_valid(p.documents) THEN p.documents ELSE '[]' END"
        ') j '
        'WHERE p.${p.companyColumn} = ?1',
        variables: [Variable.withString(companyId)],
      ).get();
      for (final r in rows) {
        if (r.data['did'] case final String id when id.isNotEmpty) out.add(id);
      }
    }
    return out;
  }

  /// Fill `parent_type` / `parent_id` on rows that have no link yet, from the
  /// `documents` arrays already cached on the records themselves.
  ///
  /// An older server's list response names no parent (one with
  /// invoiceninja/invoiceninja#13365 does), so this is how a file seen first
  /// through `GET /documents` learns what it is attached to once its record
  /// has been loaded. One `UPDATE … FROM json_each(…)` per parent
  /// table; the `json_valid` guard matters because a row can hold `''` or
  /// NULL, and `json_each` throws on anything that isn't JSON. Returns how
  /// many rows gained a link.
  ///
  /// The statements carry no `updates:` — drift notifies watchers after
  /// every `customUpdate` that names a table, whether or not a row changed,
  /// and this runs each time the list opens. One notification at the end,
  /// and only when something was linked.
  Future<int> relinkFromParentTables({required String companyId}) async {
    var linked = 0;
    await transaction(() async {
      for (final p in _kParentTables) {
        linked += await customUpdate(
          'UPDATE document_records '
          'SET parent_type = ?2, parent_id = m.pid '
          'FROM ('
          '  SELECT p.id AS pid, json_extract(j.value, \'\$.id\') AS did '
          '  FROM ${p.table} p, json_each('
          '    CASE WHEN json_valid(p.documents) THEN p.documents ELSE \'[]\' END'
          '  ) j '
          '  WHERE p.${p.companyColumn} = ?1'
          ') m '
          'WHERE document_records.company_id = ?1 '
          '  AND document_records.parent_id IS NULL '
          '  AND document_records.id = m.did',
          variables: [
            Variable.withString(companyId),
            Variable.withString(p.wireName),
          ],
        );
      }
    });
    if (linked > 0) {
      notifyUpdates({
        TableUpdate.onTable(documentRecords, kind: UpdateKind.update),
      });
    }
    return linked;
  }

  /// Whether any row is still waiting for a parent link — lets the relink be
  /// skipped entirely when there is nothing to do.
  Future<bool> hasUnlinked({required String companyId}) async {
    final count = documentRecords.id.count();
    final q = selectOnly(documentRecords)
      ..addColumns([count])
      ..where(
        documentRecords.companyId.equals(companyId) &
            documentRecords.parentId.isNull(),
      );
    return ((await q.getSingle()).read(count) ?? 0) > 0;
  }
}
