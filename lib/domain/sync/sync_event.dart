import 'package:admin/domain/sync/entity_type.dart' show EntityType;

/// Events the sync engine emits for the UI to react to. The shell subscribes
/// and routes each to the appropriate sheet/badge.
sealed class SyncEvent {
  const SyncEvent({required this.entityType, required this.entityId});
  final EntityType entityType;
  final String entityId;
}

/// 422 — the server permanently rejected the payload. The Outbox screen
/// shows the row; the user must edit or discard.
class ValidationFailedEvent extends SyncEvent {
  const ValidationFailedEvent({
    required super.entityType,
    required super.entityId,
    required this.fieldErrors,
    required this.message,
  });
  final Map<String, List<String>> fieldErrors;
  final String message;
}

/// Server rejected a queued mutation as a conflict — `ConflictResolutionSheet`
/// opens. Two flavors, distinguished by [isDeletedServerSide]:
///   * **stale data (409)** — the server has newer data (a genuine
///     concurrent-edit conflict). The sheet offers open / discard / use-mine.
///   * **entity gone** — the entity was deleted server-side while we held a
///     pending edit, so there's nothing left to update. The sheet shows a
///     "deleted on the server" message and offers discard-locally only
///     (re-submitting would fail forever).
class ConflictEvent extends SyncEvent {
  const ConflictEvent({
    required super.entityType,
    required super.entityId,
    required this.companyId,
    required this.message,
    required this.wireEntityType,
    this.statusCode,
    this.outboxRowId,
    this.isDeletedServerSide = false,
  });

  /// The parked row's company. The resolver MUST discard against this, not the
  /// session's current company: the sheet can be resolved after a company
  /// switch (especially now that overlapping conflicts are deferred + replayed),
  /// and discarding under the wrong company silently matches no rows — leaving
  /// the parked row immortal while the user believes it resolved.
  final String companyId;

  final String message;

  /// The parked outbox row's wire `entity_type` string — what
  /// `discardPendingForEntity` must match on. NOT derivable from
  /// [entityType]: a registry slot can serve several wire names (the user
  /// module's primary wireName is `user_settings` while full-user rows carry
  /// `user`), so resolving back through `handlers.wireName` silently missed
  /// those rows.
  final String wireEntityType;

  /// The **wire** status that parked the row, recorded verbatim for the Outbox
  /// row inspector and the diagnostics log. Deliberately NOT the discriminator
  /// between the two sheet variants: Invoice Ninja reports a missing entity as
  /// **400** (`"No query results for model …"`) and reserves 404 for routing
  /// mistakes, so keying the "deleted server-side" copy off `== 404` pointed it
  /// at the wrong failure. Use [isDeletedServerSide]. Null on legacy/unknown
  /// paths (treated as stale-data by the sheet).
  final int? statusCode;

  /// The parked outbox row's id, so the resolver can act on exactly that row
  /// (e.g. drop it on a deleted-server-side discard) without re-deriving it
  /// from the entity.
  final int? outboxRowId;

  /// True when the parked mutation can never succeed by retrying the same
  /// request — the entity is gone server-side. Drives the discard-only sheet
  /// variant, and the resolver's local hard-delete on discard, so it must only
  /// be set when the entity is genuinely gone.
  final bool isDeletedServerSide;
}

/// 403 password-required — `ConfirmPasswordSheet` opens.
class PasswordRequiredEvent extends SyncEvent {
  const PasswordRequiredEvent({
    required super.entityType,
    required super.entityId,
  });
}

/// Row reached a terminal failure — gave up after the max retry count, or
/// fail-fast on a permanent (4xx) error. Sits on the Outbox screen until the
/// user retries or discards.
///
/// [handledByCaller] is true when an `awaitRow` caller (an open edit form, or a
/// confirm-after-server action) is already surfacing this failure itself — the
/// shell then keeps a toast instead of popping a duplicate modal. When false,
/// the failure is a silent background death and the shell escalates to a modal
/// while the user is online.
class DeadEvent extends SyncEvent {
  const DeadEvent({
    required super.entityType,
    required super.entityId,
    required this.message,
    required this.statusCode,
    this.handledByCaller = false,
  });
  final String message;
  final int? statusCode;
  final bool handledByCaller;
}
