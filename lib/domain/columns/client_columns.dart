import 'package:admin/app/router.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';

// `kColumnFlexMinWidth` moved to `lib/ui/core/list/entity_list_constants.dart`
// so every entity's list screen can use the same value.
export 'package:admin/ui/core/list/entity_list_constants.dart'
    show kColumnFlexMinWidth;

typedef ClientColumn = ColumnDefinition<Client>;

/// Default columns the old admin-portal exposes when the user has never
/// customized — mirrors `admin-portal/lib/ui/client/client_presenter.dart`
/// `getDefaultTableFields`. Order matters: the table renders left-to-right.
const List<String> kDefaultClientColumns = <String>[
  ClientFieldIds.number,
  ClientFieldIds.name,
  ClientFieldIds.balance,
  ClientFieldIds.paidToDate,
  ClientFieldIds.contactName,
  ClientFieldIds.contactEmail,
  ClientFieldIds.lastLoginAt,
];

/// Wire ids — must match the snake_case constants in
/// `admin-portal/lib/data/models/client_model.dart:59-160` (`ClientFields`).
/// Renaming any of these breaks compatibility with the existing app.
class ClientFieldIds {
  static const String name = 'name';
  static const String number = 'number';
  static const String balance = 'balance';
  static const String paidToDate = 'paid_to_date';
  static const String creditBalance = 'credit_balance';
  static const String contactName = 'contact_name';
  static const String contactEmail = 'contact_email';
  static const String contactPhone = 'contact_phone';
  static const String lastLoginAt = 'last_login_at';
  static const String idNumber = 'id_number';
  static const String vatNumber = 'vat_number';
  static const String address1 = 'address1';
  static const String address2 = 'address2';
  static const String city = 'city';
  static const String state = 'state';
  static const String postalCode = 'postal_code';
  static const String phone = 'phone';
  static const String website = 'website';
  static const String publicNotes = 'public_notes';
  static const String privateNotes = 'private_notes';
  static const String custom1 = 'custom1';
  static const String custom2 = 'custom2';
  static const String custom3 = 'custom3';
  static const String custom4 = 'custom4';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
  static const String archivedAt = 'archived_at';
  // Display-only (tags live in the payload) — never add to sortOptions.
  static const String tagIds = 'client_tag_ids';
}

/// Every column the new app knows how to render for the client list.
///
/// Includes columns we can't yet fully populate (e.g. `country`, `language`,
/// `currency` — those need statics maps; rendered as empty for now) so a
/// list saved from this app round-trips cleanly through the old admin-portal
/// without losing entries. Unknown ids read from the server are not in this
/// list but are preserved in storage via `extraJson` (see UserSettings DAO).
final List<ClientColumn> kAllClientColumns = <ClientColumn>[
  ClientColumn(
    id: ClientFieldIds.number,
    labelKey: 'number',
    width: 100,
    cellBuilder: (c, ctx) => cellLink(
      ctx,
      c.number,
      onTap: () => goEntityFullDetail(ctx, '/clients', c.id),
    ),
    valueBuilder: (c) => cellNonZeroString(c.number),
  ),
  ClientColumn(
    id: ClientFieldIds.name,
    labelKey: 'name',
    cellBuilder: (c, _) =>
        cellText(c.displayName.isNotEmpty ? c.displayName : c.name, bold: true),
    valueBuilder: (c) =>
        cellNonZeroString(c.displayName.isNotEmpty ? c.displayName : c.name),
  ),
  ClientColumn(
    id: ClientFieldIds.balance,
    labelKey: 'balance',
    width: 120,
    align: ColumnAlign.end,
    cellBuilder: (c, context) => cellMoney(
      c.balance,
      context,
      cents: true,
      clientCurrencyId: c.currencyId,
    ),
    valueBuilder: (c) => cellMoneyValue(c.balance),
  ),
  ClientColumn(
    id: ClientFieldIds.paidToDate,
    labelKey: 'paid_to_date',
    width: 120,
    align: ColumnAlign.end,
    cellBuilder: (c, context) => cellMoney(
      c.paidToDate,
      context,
      cents: false,
      clientCurrencyId: c.currencyId,
    ),
    valueBuilder: (c) => cellMoneyValue(c.paidToDate),
  ),
  ClientColumn(
    id: ClientFieldIds.creditBalance,
    labelKey: 'credit_balance',
    width: 120,
    align: ColumnAlign.end,
    cellBuilder: (c, context) => cellMoney(
      c.creditBalance,
      context,
      cents: false,
      clientCurrencyId: c.currencyId,
    ),
    valueBuilder: (c) => cellMoneyValue(c.creditBalance),
  ),
  ClientColumn(
    id: ClientFieldIds.contactName,
    labelKey: 'contact_name',
    width: 160,
    cellBuilder: (c, _) {
      final ct = _primary(c.contacts);
      if (ct == null) return cellEmpty();
      final n = ('${ct.firstName} ${ct.lastName}').trim();
      return cellText(n);
    },
    valueBuilder: (c) {
      final ct = _primary(c.contacts);
      if (ct == null) return null;
      return cellNonZeroString(('${ct.firstName} ${ct.lastName}').trim());
    },
  ),
  ClientColumn(
    id: ClientFieldIds.contactEmail,
    labelKey: 'contact_email',
    width: 200,
    cellBuilder: (c, _) {
      final ct = _primary(c.contacts);
      return cellText(ct?.email ?? '');
    },
    valueBuilder: (c) => cellNonZeroString(_primary(c.contacts)?.email ?? ''),
  ),
  ClientColumn(
    id: ClientFieldIds.contactPhone,
    labelKey: 'contact_phone',
    width: 140,
    cellBuilder: (c, _) {
      final ct = _primary(c.contacts);
      return cellText(ct?.phone ?? '');
    },
    valueBuilder: (c) => cellNonZeroString(_primary(c.contacts)?.phone ?? ''),
  ),
  ClientColumn(
    id: ClientFieldIds.lastLoginAt,
    labelKey: 'last_login',
    width: 120,
    cellBuilder: (c, ctx) =>
        c.lastLogin == null ? cellEmpty() : cellDate(c.lastLogin!, ctx),
    valueBuilder: (c) => c.lastLogin?.toIso8601String(),
  ),
  ClientColumn(
    id: ClientFieldIds.idNumber,
    labelKey: 'id_number',
    width: 120,
    cellBuilder: (c, _) => cellText(c.idNumber),
    valueBuilder: (c) => cellNonZeroString(c.idNumber),
  ),
  ClientColumn(
    id: ClientFieldIds.vatNumber,
    labelKey: 'vat_number',
    width: 120,
    cellBuilder: (c, _) => cellText(c.vatNumber),
    valueBuilder: (c) => cellNonZeroString(c.vatNumber),
  ),
  ClientColumn(
    id: ClientFieldIds.address1,
    labelKey: 'address1',
    width: 200,
    cellBuilder: (c, _) => cellText(c.address1),
    valueBuilder: (c) => cellNonZeroString(c.address1),
  ),
  ClientColumn(
    id: ClientFieldIds.address2,
    labelKey: 'address2',
    width: 160,
    cellBuilder: (c, _) => cellText(c.address2),
    valueBuilder: (c) => cellNonZeroString(c.address2),
  ),
  ClientColumn(
    id: ClientFieldIds.city,
    labelKey: 'city',
    width: 120,
    cellBuilder: (c, _) => cellText(c.city),
    valueBuilder: (c) => cellNonZeroString(c.city),
  ),
  ClientColumn(
    id: ClientFieldIds.state,
    labelKey: 'state',
    width: 100,
    cellBuilder: (c, _) => cellText(c.state),
    valueBuilder: (c) => cellNonZeroString(c.state),
  ),
  ClientColumn(
    id: ClientFieldIds.postalCode,
    labelKey: 'postal_code',
    width: 110,
    cellBuilder: (c, _) => cellText(c.postalCode),
    valueBuilder: (c) => cellNonZeroString(c.postalCode),
  ),
  ClientColumn(
    id: ClientFieldIds.phone,
    labelKey: 'phone',
    width: 130,
    cellBuilder: (c, _) => cellText(c.phone),
    valueBuilder: (c) => cellNonZeroString(c.phone),
  ),
  ClientColumn(
    id: ClientFieldIds.website,
    labelKey: 'website',
    width: 160,
    cellBuilder: (c, _) => cellText(c.website),
    valueBuilder: (c) => cellNonZeroString(c.website),
  ),
  ClientColumn(
    id: ClientFieldIds.publicNotes,
    labelKey: 'public_notes',
    width: 200,
    cellBuilder: (c, _) => cellText(c.publicNotes),
    valueBuilder: (c) => cellNonZeroString(c.publicNotes),
  ),
  ClientColumn(
    id: ClientFieldIds.privateNotes,
    labelKey: 'private_notes',
    width: 200,
    cellBuilder: (c, _) => cellText(c.privateNotes),
    valueBuilder: (c) => cellNonZeroString(c.privateNotes),
  ),
  ClientColumn(
    id: ClientFieldIds.custom1,
    labelKey: 'custom1',
    width: 140,
    cellBuilder: (c, _) => cellText(c.customValue1),
    valueBuilder: (c) => cellNonZeroString(c.customValue1),
  ),
  ClientColumn(
    id: ClientFieldIds.custom2,
    labelKey: 'custom2',
    width: 140,
    cellBuilder: (c, _) => cellText(c.customValue2),
    valueBuilder: (c) => cellNonZeroString(c.customValue2),
  ),
  ClientColumn(
    id: ClientFieldIds.custom3,
    labelKey: 'custom3',
    width: 140,
    cellBuilder: (c, _) => cellText(c.customValue3),
    valueBuilder: (c) => cellNonZeroString(c.customValue3),
  ),
  ClientColumn(
    id: ClientFieldIds.custom4,
    labelKey: 'custom4',
    width: 140,
    cellBuilder: (c, _) => cellText(c.customValue4),
    valueBuilder: (c) => cellNonZeroString(c.customValue4),
  ),
  ClientColumn(
    id: ClientFieldIds.createdAt,
    labelKey: 'created',
    width: 110,
    cellBuilder: (c, ctx) => cellDate(c.createdAt, ctx),
    valueBuilder: (c) => c.createdAt.toIso8601String(),
  ),
  ClientColumn(
    id: ClientFieldIds.updatedAt,
    labelKey: 'last_updated',
    width: 110,
    cellBuilder: (c, ctx) => cellDate(c.updatedAt, ctx),
    valueBuilder: (c) => c.updatedAt.toIso8601String(),
  ),
  ClientColumn(
    id: ClientFieldIds.archivedAt,
    labelKey: 'archived',
    width: 110,
    cellBuilder: (c, ctx) =>
        c.archivedAt == null ? cellEmpty() : cellDate(c.archivedAt!, ctx),
    valueBuilder: (c) => c.archivedAt?.toIso8601String(),
  ),
  // Attached tags. Display-only (not a sortable Drift column).
  ClientColumn(
    id: ClientFieldIds.tagIds,
    labelKey: 'tags',
    sortable: false,
    width: 200,
    cellBuilder: (c, _) => c.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'client', tagIds: c.tagIds),
    valueBuilder: (c) => '',
  ),
];

final Map<String, ClientColumn> clientColumnsById = {
  for (final c in kAllClientColumns) c.id: c,
};

/// Resolve a list of wire ids to renderable column definitions. Unknown ids
/// are dropped here — but never dropped from the underlying storage list.
List<ClientColumn> resolveClientColumns(List<String> ids) {
  final out = <ClientColumn>[];
  for (final id in ids) {
    final col = clientColumnsById[id];
    if (col != null) out.add(col);
  }
  return out;
}

Contact? _primary(List<Contact> contacts) {
  if (contacts.isEmpty) return null;
  for (final ct in contacts) {
    if (ct.isPrimary) return ct;
  }
  return contacts.first;
}
