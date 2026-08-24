import 'package:drift/drift.dart';

/// Maps one Invoice Ninja record to the device address-book contact this
/// install created for it (Settings → Device Settings → Contacts).
///
/// Purely device-local — never synced to the server, and wiped along with every
/// other table on logout. It is an **incremental-sync index, not the ownership
/// record**: `hash` lets a reconcile skip a card whose mapped fields haven't
/// moved, and `deviceContactId` lets it update in place instead of churning the
/// user's address book. Ownership is the label/group the cards live in, so a
/// reconcile can still heal after this table is wiped (see
/// `ContactsSyncService.run`, step "heal against the group").
///
/// [sourceId] is the client contact's id, or `client:<clientId>` for the
/// single fallback card emitted for a client that has no usable contact of its
/// own. Added in schema v5.
@DataClassName('DeviceContactLinkRow')
class DeviceContactLinks extends Table {
  TextColumn get companyId => text().named('company_id')();
  TextColumn get sourceId => text().named('source_id')();
  TextColumn get deviceContactId => text().named('device_contact_id')();

  /// Content hash of the card last written for [sourceId]. Unchanged hash =>
  /// no write at all, which is what keeps a repeat sync near-free.
  TextColumn get hash => text()();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {companyId, sourceId};
}
