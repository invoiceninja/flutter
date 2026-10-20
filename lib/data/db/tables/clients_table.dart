import 'package:drift/drift.dart';

import 'package:admin/data/db/tables/_entity_table_mixin.dart';

/// Drift table for Client rows.
///
/// `id` may be a `tmp_<uuid>` until the server assigns a real one (see
/// `id_remap`). `payload` carries the full JSON body so we can extend the
/// model in M2+ without a schema migration for every new field.
///
/// `@DataClassName('ClientRow')` keeps the generated row class from
/// colliding with the domain `Client` in `lib/data/models/domain/client.dart`.
@DataClassName('ClientRow')
class Clients extends Table
    with
        EntityIdColumns,
        EntityTimestampColumns,
        EntityCustomValueColumns,
        EntityFlagColumns,
        EntityDocumentsColumn,
        EntityPayloadColumn {
  TextColumn get name => text()();
  TextColumn get number => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text().named('display_name')();
  TextColumn get balance => text()();

  /// Denormalized filter columns. Nullable so the v54→v55 ALTER lands
  /// without a backfill blocking startup (the migration backfills them from
  /// `payload` via `json_extract`). They exist purely so the local list
  /// watch can mirror the server's `country_id`/`classification`/… filters
  /// (see `ClientDao.watchPage`); the domain model is still rebuilt from
  /// `payload` in `_fromRow`, so no overlay is needed. Values are stored in
  /// the API payload's id form (hashids for `group_settings_id` /
  /// `assigned_user_id`, plain ids for `country_id`/`industry_id`/`size_id`)
  /// — the FilterKey pickers emit the same form, so predicates match with
  /// no decode (identical to the existing `client_id` predicate).
  TextColumn get countryId => text().named('country_id').nullable()();
  TextColumn get industryId => text().named('industry_id').nullable()();
  TextColumn get sizeId => text().named('size_id').nullable()();
  TextColumn get classification => text().named('classification').nullable()();
  TextColumn get vatNumber => text().named('vat_number').nullable()();
  TextColumn get groupSettingsId =>
      text().named('group_settings_id').nullable()();
  TextColumn get idNumber => text().named('id_number').nullable()();
  TextColumn get assignedUserId =>
      text().named('assigned_user_id').nullable()();

  /// JSON-encoded `List<LocationApi>`. Client-only (no shared mixin —
  /// only clients carry locations). Nullable so the v52→v53 ALTER lands
  /// without a backfill; reads back as `const <Location>[]` via
  /// `decodeLocationsColumn` in the repository's `_fromRow` overlay.
  /// Locations are written via the standalone `/api/v1/locations` resource
  /// and read-embedded on the client — the domain `Client.toApiJson`
  /// deliberately omits them from the outbound wire, so (exactly like
  /// `documents`) they need their own column to survive a local
  /// `repo.save` round-trip.
  TextColumn get locations => text().nullable()();

  /// Every contact's first name, last name, email and phone run through `foldSearchText`, one value per
  /// line — what the list search matches a contact against, with an `instr`
  /// (`contactSearchMatches`). Written by both companion mappers; NULL on a
  /// row stored before v16 until `fillContactSearch` reaches it, and the
  /// search reads the payload's contacts for such a row instead
  /// (docs/local-search-matching.md).
  TextColumn get contactSearch => text().named('contact_search').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE (company_id, id)'];
}
