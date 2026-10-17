import 'package:admin/data/db/dao/document_dao.dart';
import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/column_factories.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/document_parent_label.dart';
import 'package:admin/utils/formatting.dart';

typedef DocumentColumn = ColumnDefinition<DocumentRecord>;

/// The Documents list's out-of-the-box layout — admin-portal's
/// `DocumentPresenter.getDefaultTableFields`, column for column, under its
/// ids, so a layout a user saved there carries over.
const List<String> kDefaultDocumentColumns = <String>[
  DocumentFieldIds.name,
  DocumentFieldIds.linkedTo,
  DocumentFieldIds.size,
  DocumentFieldIds.width,
  DocumentFieldIds.height,
  DocumentFieldIds.isPrivate,
  DocumentFieldIds.createdAt,
];

final List<DocumentColumn> kAllDocumentColumns = <DocumentColumn>[
  DocumentColumn(
    id: DocumentFieldIds.name,
    labelKey: 'name',
    width: 260,
    cellBuilder: (d, _) => cellText(d.displayName, bold: true),
    valueBuilder: (d) => cellNonZeroString(d.displayName),
  ),
  // Display-only: the name has to be resolved through the parent's own
  // table, so there is no column to order by.
  DocumentColumn(
    id: DocumentFieldIds.linkedTo,
    labelKey: 'linked_to',
    width: 200,
    sortable: false,
    cellBuilder: (d, _) =>
        DocumentParentLabel(parentType: d.parentType, parentId: d.parentId),
  ),
  DocumentColumn(
    id: DocumentFieldIds.size,
    labelKey: 'size',
    width: 90,
    align: ColumnAlign.end,
    cellBuilder: (d, _) =>
        d.size > 0 ? cellText(formatSize(d.size)) : cellEmpty(),
    valueBuilder: (d) => d.size > 0 ? formatSize(d.size) : null,
  ),
  // Pixels, for an image; an em dash for anything else.
  DocumentColumn(
    id: DocumentFieldIds.width,
    labelKey: 'width',
    width: 80,
    align: ColumnAlign.end,
    cellBuilder: (d, _) => d.width > 0 ? cellText('${d.width}') : cellEmpty(),
    valueBuilder: (d) => d.width > 0 ? '${d.width}' : null,
  ),
  DocumentColumn(
    id: DocumentFieldIds.height,
    labelKey: 'height',
    width: 80,
    align: ColumnAlign.end,
    cellBuilder: (d, _) => d.height > 0 ? cellText('${d.height}') : cellEmpty(),
    valueBuilder: (d) => d.height > 0 ? '${d.height}' : null,
  ),
  // "Private" rather than "Public": a private file is the exception worth
  // seeing at a glance, and it is what admin-portal's column said.
  DocumentColumn(
    id: DocumentFieldIds.isPrivate,
    labelKey: 'private',
    width: 90,
    cellBuilder: (d, ctx) => cellText(ctx.tr(d.isPublic ? 'no' : 'yes')),
    valueBuilder: (d) => d.isPublic ? null : 'true',
  ),
  colCreatedAt<DocumentRecord>(DocumentFieldIds.createdAt, (d) => d.createdAt),
  colUpdatedAt<DocumentRecord>(DocumentFieldIds.updatedAt, (d) => d.updatedAt),
  DocumentColumn(
    id: DocumentFieldIds.type,
    labelKey: 'file_type',
    width: 90,
    cellBuilder: (d, _) => cellText(d.type.toUpperCase()),
    valueBuilder: (d) => cellNonZeroString(d.type),
  ),
  // Payload-only — display-only.
  DocumentColumn(
    id: DocumentFieldIds.hash,
    labelKey: 'hash',
    width: 200,
    sortable: false,
    cellBuilder: (d, _) => cellText(d.hash),
    valueBuilder: (d) => cellNonZeroString(d.hash),
  ),
  DocumentColumn(
    id: DocumentFieldIds.id,
    labelKey: 'id',
    width: 120,
    cellBuilder: (d, _) => cellText(d.id),
    valueBuilder: (d) => cellNonZeroString(d.id),
  ),
  colUserName<DocumentRecord>(
    DocumentFieldIds.userId,
    (d) => d.userId,
    labelKey: 'user',
  ),
];

final Map<String, DocumentColumn> documentColumnsById = {
  for (final c in kAllDocumentColumns) c.id: c,
};
