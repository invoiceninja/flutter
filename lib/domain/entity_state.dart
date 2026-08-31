/// The lifecycle state of a server-side entity row.
///
/// Persisted on every entity table as two columns: `archived_at` (timestamp
/// or null) and `is_deleted` (bool). The three states map as:
///   * [active]   — `archivedAt == null && !isDeleted`
///   * [archived] — `archivedAt != null && !isDeleted`
///   * [deleted]  — `isDeleted == true` (overrides archived)
///
/// On the wire, `status=active,archived,deleted` is the lifecycle query param
/// the server accepts (`QueryFilters::status` — distinct from the per-entity
/// computed `client_status`); [serverName] is the value's canonical name.
enum EntityState {
  active,
  archived,
  deleted;

  /// The token the v2 server expects in the lifecycle `status` filter query
  /// string (`QueryFilters::status`).
  String get serverName => switch (this) {
    EntityState.active => 'active',
    EntityState.archived => 'archived',
    EntityState.deleted => 'deleted',
  };

  /// Localization key for the user-facing label, also used as the
  /// active-filter chip text. Resolve via `context.tr(state.labelKey)`.
  String get labelKey => switch (this) {
    EntityState.active => 'active',
    EntityState.archived => 'archived',
    EntityState.deleted => 'deleted',
  };
}

/// Derive the lifecycle state from the two persisted columns.
///
/// The mapping is documented on [EntityState] but had no implementation — the
/// `entity_state` list column needs one. (The Client and Vendor row pills still
/// derive it privately: they also model an `unsynced` state, which is a local
/// flag [EntityState] deliberately doesn't carry, so they can't delegate here
/// without widening this enum.) Deleted wins over archived, and
/// "archived" is `archivedAt != null` — the same predicate `entityStateFilter`
/// uses, so a row the filter calls active can never render as archived.
EntityState entityStateOf({
  required DateTime? archivedAt,
  required bool isDeleted,
}) {
  if (isDeleted) return EntityState.deleted;
  if (archivedAt != null) return EntityState.archived;
  return EntityState.active;
}
