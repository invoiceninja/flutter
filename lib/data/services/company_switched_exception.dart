/// Raised when work bound to one company would run under another company's
/// credentials — a company switch landed while it was in progress.
///
/// Two places raise it:
///   * a paged fetch that comes back after the active company changed, so its
///     rows were fetched under a *different* token than the `companyId` they
///     would be stamped with (`BaseEntityRepository.companyStillActive`);
///   * `ApiClient`, before sending a request made on behalf of an outbox row
///     whose company is no longer the active one (`RequestScope`) — nothing
///     has been sent when it throws.
///
/// Benign by nature — the work is simply abandoned or re-queued — so callers
/// treat it as a no-op rather than a failure: `GenericListViewModel` swallows
/// it without flashing an error (its `hasMore` is left untouched, so paging
/// stays armed), a `refreshAll` loop lets it end the sweep, and the outbox
/// drain puts the row back for its own company.
///
/// Lives in `lib/data/services/` so the transport can throw it;
/// `base_entity_repository.dart` re-exports it for its existing importers.
class CompanySwitchedException implements Exception {
  const CompanySwitchedException({
    required this.expected,
    required this.active,
    required this.entityType,
  });

  final String expected;
  final String? active;

  /// What was bound to [expected] — an entity type for a page, or a
  /// description of the request.
  final String entityType;

  @override
  String toString() =>
      'CompanySwitchedException: $entityType for $expected arrived while '
      '${active ?? "no company"} was active';
}
