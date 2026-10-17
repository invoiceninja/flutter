import 'package:drift/drift.dart';

import 'package:admin/data/db/tables/_entity_table_mixin.dart';

/// Drift table for the company-wide Documents list (`GET /api/v1/documents`)
/// — every uploaded file, whatever record it hangs off.
///
/// Not the `documents` table: that one is an M1 scaffold for an upload queue
/// that never shipped. Nothing reads or writes it, but it is in every
/// shipped schema dump, its NOT NULL columns have no defaults, and
/// `schema_additive_test` forbids dropping a shipped table — so the list got a
/// table of its own (schema v14).
///
/// `parent_type` / `parent_id` name the record the file is attached to when
/// the app knows it. The server's list response does not say
/// (BACKEND.md § Documents list), so they are filled from what the app sees
/// of the records themselves: the `/refresh` delta, a record tab's own
/// change, and a pass over the parent tables' cached `documents` columns —
/// see `docs/documents-list.md`. `parent_type` holds the wire name from
/// `kDocumentParentWireNames`.
@DataClassName('DocumentRecordRow')
class DocumentRecords extends Table
    with
        EntityIdColumns,
        EntityTimestampColumns,
        EntityFlagColumns,
        EntityPayloadColumn {
  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get fileType =>
      text().named('type').withDefault(const Constant(''))();
  IntColumn get size => integer().withDefault(const Constant(0))();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  BoolColumn get isPublic =>
      boolean().named('is_public').withDefault(const Constant(true))();
  TextColumn get parentType => text().named('parent_type').nullable()();
  TextColumn get parentId => text().named('parent_id').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (company_id, id)'];
}
