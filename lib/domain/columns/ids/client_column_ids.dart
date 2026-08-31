/// Client column / sort-field id constants.
///
/// **This file must import nothing.** It is deliberately a leaf so the data
/// layer (`ClientRepository`, `ClientDao`) can name a sort field without
/// importing `client_columns.dart`, which builds Widgets and therefore drags
/// the entire UI graph into every data-layer compile. See
/// `test/lint/layering_test.dart`.
///
/// `client_columns.dart` re-exports this file, so UI call sites keep resolving
/// these names through their existing import.
library;

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

  /// Real Drift column — sortable.
  static const String assignedUserId = 'assigned_user_id';

  // ── Standard record metadata ────────────────────────────────────────
  /// Real Drift column (`EntityFlagColumns`) — sortable.
  static const String isDeleted = 'is_deleted';

  /// Derived from `archived_at` + `is_deleted`; no column to order by, so the
  /// column is display-only.
  static const String entityState = 'entity_state';

  /// Attachment count, read from the `documents` JSON column. Display-only.
  static const String documents = 'documents';

  /// Creator. Payload-only on every table — display-only.
  static const String userId = 'user_id';
}

/// Every id `kAllClientColumns` declares — the key set of `clientColumnsById`,
/// available without importing the Widget-bearing registry.
///
/// `ClientDao._sortExpression` uses this as its "is this a known column id at
/// all" guard. Kept in lockstep with the registry by
/// `test/domain/columns/column_ids_match_registry_test.dart`, which fails the
/// build if a column is added here and not there (or vice versa).
const Set<String> kClientColumnIds = <String>{
  ClientFieldIds.name,
  ClientFieldIds.number,
  ClientFieldIds.balance,
  ClientFieldIds.paidToDate,
  ClientFieldIds.creditBalance,
  ClientFieldIds.contactName,
  ClientFieldIds.contactEmail,
  ClientFieldIds.contactPhone,
  ClientFieldIds.lastLoginAt,
  ClientFieldIds.idNumber,
  ClientFieldIds.vatNumber,
  ClientFieldIds.address1,
  ClientFieldIds.address2,
  ClientFieldIds.city,
  ClientFieldIds.state,
  ClientFieldIds.postalCode,
  ClientFieldIds.phone,
  ClientFieldIds.website,
  ClientFieldIds.publicNotes,
  ClientFieldIds.privateNotes,
  ClientFieldIds.custom1,
  ClientFieldIds.custom2,
  ClientFieldIds.custom3,
  ClientFieldIds.custom4,
  ClientFieldIds.createdAt,
  ClientFieldIds.updatedAt,
  ClientFieldIds.archivedAt,
  ClientFieldIds.tagIds,
  ClientFieldIds.assignedUserId,
  ClientFieldIds.entityState,
  ClientFieldIds.isDeleted,
  ClientFieldIds.documents,
  ClientFieldIds.userId,
};
