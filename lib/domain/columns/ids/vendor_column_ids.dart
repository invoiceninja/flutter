/// Vendor column / sort-field id constants.
///
/// **This file must import nothing** — leaf by design, so `VendorRepository`
/// and `VendorDao` can name a sort field without pulling the Widget-bearing
/// `vendor_columns.dart` (and with it the whole UI graph) into the data
/// layer. See `test/lint/layering_test.dart`.
///
/// `vendor_columns.dart` re-exports this file, so UI call sites are unchanged.
library;

/// Wire ids for sort + persisted column selection.
class VendorFieldIds {
  static const String name = 'name';
  static const String number = 'number';
  static const String contactName = 'contact_name';
  static const String contactEmail = 'contact_email';
  static const String contactPhone = 'contact_phone';
  static const String idNumber = 'id_number';
  static const String vatNumber = 'vat_number';
  static const String address1 = 'address1';
  static const String address2 = 'address2';
  static const String city = 'city';
  static const String state = 'state';
  static const String postalCode = 'postal_code';
  static const String phone = 'phone';
  static const String website = 'website';
  static const String currencyId = 'currency_id';
  static const String classification = 'classification';
  static const String routingId = 'routing_id';
  static const String lastLogin = 'last_login';
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
  static const String tagIds = 'vendor_tag_ids';
}

/// Every id `kAllVendorColumns` declares — the key set of `vendorColumnsById`,
/// available without importing the Widget-bearing registry.
///
/// `VendorDao._sortExpression` uses this as its "is this a known column id at
/// all" guard. Note [VendorFieldIds.currencyId] is deliberately **absent**: it
/// is a wire field with no column in the registry, so it was already rejected
/// by the `vendorColumnsById.containsKey` guard this set replaces. Kept in
/// lockstep with the registry by
/// `test/domain/columns/column_ids_match_registry_test.dart`.
const Set<String> kVendorColumnIds = <String>{
  VendorFieldIds.name,
  VendorFieldIds.number,
  VendorFieldIds.contactName,
  VendorFieldIds.contactEmail,
  VendorFieldIds.contactPhone,
  VendorFieldIds.idNumber,
  VendorFieldIds.vatNumber,
  VendorFieldIds.address1,
  VendorFieldIds.address2,
  VendorFieldIds.city,
  VendorFieldIds.state,
  VendorFieldIds.postalCode,
  VendorFieldIds.phone,
  VendorFieldIds.website,
  VendorFieldIds.classification,
  VendorFieldIds.routingId,
  VendorFieldIds.lastLogin,
  VendorFieldIds.publicNotes,
  VendorFieldIds.privateNotes,
  VendorFieldIds.custom1,
  VendorFieldIds.custom2,
  VendorFieldIds.custom3,
  VendorFieldIds.custom4,
  VendorFieldIds.createdAt,
  VendorFieldIds.updatedAt,
  VendorFieldIds.archivedAt,
  VendorFieldIds.tagIds,
};
