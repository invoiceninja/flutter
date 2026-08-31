import 'package:admin/app/router.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_factories.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/domain/columns/ids/vendor_column_ids.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/l10n/localization.dart';

// Re-export the shared min width so vendor-screen code keeps the same
// single source as clients/products.
export 'package:admin/ui/core/list/entity_list_constants.dart'
    show kColumnFlexMinWidth;

// Id constants live in a leaf file the data layer can import without
// dragging this Widget-bearing registry (and the UI graph) along.
export 'package:admin/domain/columns/ids/vendor_column_ids.dart';

typedef VendorColumn = ColumnDefinition<Vendor>;

/// Default columns the legacy admin-portal exposes for the Vendor list
/// when the user has never customized — mirrors `vendor_presenter.dart`
/// `getDefaultTableFields` from `/Users/hillel/Code/admin-portal/lib/ui/
/// vendor/vendor_presenter.dart`. Order matters: the table renders
/// left-to-right.
const List<String> kDefaultVendorColumns = <String>[
  VendorFieldIds.name,
  VendorFieldIds.number,
  VendorFieldIds.city,
  VendorFieldIds.phone,
];

/// Every column the new app knows how to render for the vendor list.
///
/// Mirrors `kAllClientColumns` in shape — includes columns we can't yet
/// fully populate so a list saved here round-trips cleanly through the
/// admin-portal without losing entries.
final List<VendorColumn> kAllVendorColumns = <VendorColumn>[
  VendorColumn(
    id: VendorFieldIds.number,
    labelKey: 'number',
    width: 100,
    cellBuilder: (v, ctx) => cellLink(
      ctx,
      v.number,
      onTap: () => goEntityFullDetail(ctx, '/vendors', v.id),
    ),
    valueBuilder: (v) => cellNonZeroString(v.number),
  ),
  VendorColumn(
    id: VendorFieldIds.name,
    labelKey: 'name',
    cellBuilder: (v, _) =>
        cellText(v.name.isNotEmpty ? v.name : _fallbackName(v), bold: true),
    valueBuilder: (v) =>
        cellNonZeroString(v.name.isNotEmpty ? v.name : _fallbackName(v)),
  ),
  VendorColumn(
    id: VendorFieldIds.contactName,
    labelKey: 'contact_name',
    width: 160,
    cellBuilder: (v, _) {
      final c = _firstContact(v.contacts);
      if (c == null) return cellEmpty();
      final n = ('${c.firstName} ${c.lastName}').trim();
      return cellText(n);
    },
    valueBuilder: (v) {
      final c = _firstContact(v.contacts);
      if (c == null) return null;
      return cellNonZeroString(('${c.firstName} ${c.lastName}').trim());
    },
  ),
  VendorColumn(
    id: VendorFieldIds.contactEmail,
    labelKey: 'contact_email',
    width: 200,
    cellBuilder: (v, _) {
      final c = _firstContact(v.contacts);
      return cellText(c?.email ?? '');
    },
    valueBuilder: (v) =>
        cellNonZeroString(_firstContact(v.contacts)?.email ?? ''),
  ),
  VendorColumn(
    id: VendorFieldIds.contactPhone,
    labelKey: 'contact_phone',
    width: 140,
    cellBuilder: (v, _) {
      final c = _firstContact(v.contacts);
      return cellText(c?.phone ?? '');
    },
    valueBuilder: (v) =>
        cellNonZeroString(_firstContact(v.contacts)?.phone ?? ''),
  ),
  VendorColumn(
    id: VendorFieldIds.idNumber,
    labelKey: 'id_number',
    width: 120,
    cellBuilder: (v, _) => cellText(v.idNumber),
    valueBuilder: (v) => cellNonZeroString(v.idNumber),
  ),
  VendorColumn(
    id: VendorFieldIds.vatNumber,
    labelKey: 'vat_number',
    width: 120,
    cellBuilder: (v, _) => cellText(v.vatNumber),
    valueBuilder: (v) => cellNonZeroString(v.vatNumber),
  ),
  VendorColumn(
    id: VendorFieldIds.address1,
    labelKey: 'address1',
    width: 200,
    cellBuilder: (v, _) => cellText(v.address1),
    valueBuilder: (v) => cellNonZeroString(v.address1),
  ),
  VendorColumn(
    id: VendorFieldIds.address2,
    labelKey: 'address2',
    width: 160,
    cellBuilder: (v, _) => cellText(v.address2),
    valueBuilder: (v) => cellNonZeroString(v.address2),
  ),
  VendorColumn(
    id: VendorFieldIds.city,
    labelKey: 'city',
    width: 120,
    cellBuilder: (v, _) => cellText(v.city),
    valueBuilder: (v) => cellNonZeroString(v.city),
  ),
  VendorColumn(
    id: VendorFieldIds.state,
    labelKey: 'state',
    width: 100,
    cellBuilder: (v, _) => cellText(v.state),
    valueBuilder: (v) => cellNonZeroString(v.state),
  ),
  VendorColumn(
    id: VendorFieldIds.postalCode,
    labelKey: 'postal_code',
    width: 110,
    cellBuilder: (v, _) => cellText(v.postalCode),
    valueBuilder: (v) => cellNonZeroString(v.postalCode),
  ),
  VendorColumn(
    id: VendorFieldIds.phone,
    labelKey: 'phone',
    width: 130,
    cellBuilder: (v, _) => cellText(v.phone),
    valueBuilder: (v) => cellNonZeroString(v.phone),
  ),
  VendorColumn(
    id: VendorFieldIds.website,
    labelKey: 'website',
    width: 160,
    cellBuilder: (v, _) => cellText(v.website),
    valueBuilder: (v) => cellNonZeroString(v.website),
  ),
  VendorColumn(
    id: VendorFieldIds.classification,
    labelKey: 'classification',
    width: 130,
    cellBuilder: (v, ctx) =>
        cellText(v.classification.isEmpty ? '' : ctx.tr(v.classification)),
    valueBuilder: (v) => cellNonZeroString(v.classification),
  ),
  VendorColumn(
    id: VendorFieldIds.routingId,
    labelKey: 'routing_id',
    width: 120,
    cellBuilder: (v, _) => cellText(v.routingId),
    valueBuilder: (v) => cellNonZeroString(v.routingId),
  ),
  VendorColumn(
    id: VendorFieldIds.lastLogin,
    labelKey: 'last_login',
    width: 120,
    cellBuilder: (v, ctx) =>
        v.lastLogin == null ? cellEmpty() : cellDate(v.lastLogin!, ctx),
    valueBuilder: (v) => v.lastLogin?.toIso8601String(),
  ),
  VendorColumn(
    id: VendorFieldIds.publicNotes,
    labelKey: 'public_notes',
    width: 200,
    cellBuilder: (v, _) => cellText(v.publicNotes),
    valueBuilder: (v) => cellNonZeroString(v.publicNotes),
  ),
  VendorColumn(
    id: VendorFieldIds.privateNotes,
    labelKey: 'private_notes',
    width: 200,
    cellBuilder: (v, _) => cellText(v.privateNotes),
    valueBuilder: (v) => cellNonZeroString(v.privateNotes),
  ),
  // The company's own labels ('Region'), type-aware values and the
  // hiding of unconfigured slots are applied by
  // `decorateCustomFieldColumns` — see `custom_field_columns.dart`.
  ...customFieldColumns<Vendor>(
    prefix: 'vendor',
    ids: const [
      VendorFieldIds.custom1,
      VendorFieldIds.custom2,
      VendorFieldIds.custom3,
      VendorFieldIds.custom4,
    ],
    values: [
      (v) => v.customValue1,
      (v) => v.customValue2,
      (v) => v.customValue3,
      (v) => v.customValue4,
    ],
  ),
  VendorColumn(
    id: VendorFieldIds.createdAt,
    labelKey: 'created',
    width: 110,
    cellBuilder: (v, ctx) => cellDate(v.createdAt, ctx),
    valueBuilder: (v) => v.createdAt.toIso8601String(),
  ),
  colUpdatedAt<Vendor>(
    VendorFieldIds.updatedAt,
    (v) => v.updatedAt,
    width: 110,
  ),
  VendorColumn(
    id: VendorFieldIds.archivedAt,
    labelKey: 'archived',
    width: 110,
    cellBuilder: (v, ctx) =>
        v.archivedAt == null ? cellEmpty() : cellDate(v.archivedAt!, ctx),
    valueBuilder: (v) => v.archivedAt?.toIso8601String(),
  ),
  // ── Standard record metadata ──────────────────────────────────────────
  // Shared across every entity list; see `column_factories.dart`. Created /
  // archived / deleted are real Drift columns and sort; state, documents and
  // the two user columns are derived or payload-only and don't.
  colUserName<Vendor>(
    VendorFieldIds.assignedUserId,
    (v) => v.assignedUserId,
    labelKey: 'assigned_user',
    sortable: false,
  ),
  colEntityState<Vendor>(
    VendorFieldIds.entityState,
    archivedAt: (v) => v.archivedAt,
    isDeleted: (v) => v.isDeleted,
  ),
  colFlag<Vendor>(
    VendorFieldIds.isDeleted,
    (v) => v.isDeleted,
    labelKey: 'is_deleted',
  ),
  colDocumentsCount<Vendor>(
    VendorFieldIds.documents,
    (v) => v.documents.length,
  ),
  // Created by. `labelKey: 'user'` — NOT `created_by`, which is
  // "Created by :name" and would leak the raw placeholder.
  colUserName<Vendor>(VendorFieldIds.userId, (v) => v.userId, labelKey: 'user'),
  // Attached tags. Display-only (not a sortable Drift column).
  VendorColumn(
    id: VendorFieldIds.tagIds,
    labelKey: 'tags',
    sortable: false,
    width: 200,
    cellBuilder: (v, _) => v.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'vendor', tagIds: v.tagIds),
    valueBuilder: (v) => '',
  ),
];

final Map<String, VendorColumn> vendorColumnsById = {
  for (final c in kAllVendorColumns) c.id: c,
};

/// Resolve a list of wire ids to renderable column definitions. Unknown ids
/// are dropped here — but never dropped from the underlying storage list.
List<VendorColumn> resolveVendorColumns(List<String> ids) {
  final out = <VendorColumn>[];
  for (final id in ids) {
    final col = vendorColumnsById[id];
    if (col != null) out.add(col);
  }
  return out;
}

VendorContact? _firstContact(List<VendorContact> contacts) {
  if (contacts.isEmpty) return null;
  return contacts.first;
}

String _fallbackName(Vendor v) {
  final c = _firstContact(v.contacts);
  if (c == null) return '';
  final composed = ('${c.firstName} ${c.lastName}').trim();
  if (composed.isNotEmpty) return composed;
  return c.email;
}
