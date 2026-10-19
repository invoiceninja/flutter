import 'package:drift/drift.dart';

/// Maps one Invoice Ninja record to the device address-book contact this
/// install created for it (Settings → Device Settings → Contacts).
///
/// Purely device-local — never synced to the server, and wiped along with every
/// other table on logout. It is **the ownership record**: a device contact is
/// updated or deleted only through a row here, and only when
/// `ownsDeviceContact` clears it against [rawContactId]. `hash` lets a
/// reconcile skip a card whose mapped fields haven't moved. The label the cards
/// live in is display only — trusting its membership once deleted every
/// contact on the phone (see `docs/contacts-sync.md`).
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

  /// The entry this install inserted for the card: Android's raw contact id
  /// (iOS has no such level, so it is the contact id itself). It is what lets
  /// a delete or update tell our card from the user's own contact once
  /// Android has merged the two — see `ownsDeviceContact`.
  ///
  /// Null: the row predates schema v15 and hasn't been checked yet.
  /// `kUnidentifiedEntry` (`''`): the card was merged into another contact
  /// before we could tell which entry was ours, so it is never touched.
  /// Added in schema v15.
  TextColumn get rawContactId => text().named('raw_contact_id').nullable()();

  @override
  Set<Column> get primaryKey => {companyId, sourceId};
}
