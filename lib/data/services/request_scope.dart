import 'dart:async';

/// The outbox row an HTTP request is being made for, carried in a [Zone].
///
/// `SyncRepository._attempt` runs each row's dispatch inside one, and
/// `ApiClient` reads it for every request the dispatch makes — including the
/// follow-up reads some handlers make, and whatever a future handler adds —
/// without threading a parameter through the ~70 API methods involved.
class RequestScope {
  RequestScope(
    this.companyId, {
    this.sourceRowId,
    this.sourceEntityType,
    this.sourceEntityId,
  });

  /// The outbox row being dispatched, and the record it is for. A server
  /// copy applied during the dispatch may only overwrite local edits OLDER
  /// than this row, and only when it is a copy of this same record
  /// (`BaseEntityRepository.hasNewerLocalEdit`).
  final int? sourceRowId;
  final String? sourceEntityType;
  final String? sourceEntityId;

  /// Whether this scope's row is for the record [entityType] / [entityId].
  bool isFor(String entityType, String entityId) =>
      sourceEntityType == entityType && sourceEntityId == entityId;

  /// The company the row belongs to. `ApiClient` refuses to send under any
  /// other company's credentials: a company switch can land between the
  /// drain's per-row check and the request, and the live credentials would
  /// then send one workspace's mutation with another's token.
  final String companyId;

  /// Whether a write — a non-GET the server answered 2xx — has already
  /// committed during this attempt. Once it has, the server has changed:
  /// whatever fails afterwards, re-sending the row may do the write twice.
  bool get committed => _committed;
  bool _committed = false;

  void markCommitted() => _committed = true;

  /// Whether a write — a non-GET — has started going out during this attempt:
  /// the transport began reading its body. Until one has, a failure proves
  /// the server was never asked to change anything (a follow-up read failing,
  /// a throw before the request), whatever the exception says. Once one has
  /// and has not [committed], its outcome is unknown.
  bool get writeSent => _writeSent;
  bool _writeSent = false;

  void markWriteSent() => _writeSent = true;

  /// Set by the drain when the device reported no connectivity just before
  /// this attempt. A transport failure then counts as "never sent" even
  /// where the transport itself can't prove it (web, where the body is read
  /// before `fetch`). Classification only — the attempt still goes ahead, so
  /// a platform that misreports "offline" costs nothing.
  bool offlineBeforeSend = false;

  static final Object _zoneKey = Object();

  /// The scope of the dispatch the calling code is running in, if any.
  static RequestScope? get current => Zone.current[_zoneKey] as RequestScope?;

  /// Run [body] with this scope current for everything it awaits.
  Future<T> run<T>(Future<T> Function() body) =>
      runZoned(body, zoneValues: {_zoneKey: this});
}
