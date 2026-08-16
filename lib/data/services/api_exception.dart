/// Typed errors thrown by [ApiClient].
///
/// The sync engine pattern-matches on these to decide whether to retry, mark
/// dead, or surface a UI prompt. Adding a new error case means updating both
/// `ApiClient._raiseFromResponse` and the corresponding sync-engine branch.
sealed class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Unauthorized'])
    : isStaleCredential = false;

  /// A 401 returned for a credential set that has since been replaced — a
  /// background request racing a company-switch / logout. The live session is
  /// still valid; `ApiClient._postFlight` deliberately swallows it rather than
  /// logging the user out, so callers treat it as an expected no-op, not a
  /// failure worth a WARNING in the diagnostics log.
  const UnauthorizedException.staleCredential()
    : isStaleCredential = true,
      super('Unauthorized');

  /// True when this 401 was discarded as stale-credential (see the named
  /// constructor); false for a genuine "session expired" 401.
  final bool isStaleCredential;
}

/// Server demands re-auth with the user's password (e.g. on delete / purge).
class PasswordRequiredException extends ApiException {
  const PasswordRequiredException([super.message = 'Password required']);
}

/// Server refused the request because the account's plan tier doesn't cover
/// the endpoint (e.g. Reports on a free plan). Raised by
/// [ApiClient._raiseFromResponse] when the server emits one of:
///   * HTTP 402 Payment Required
///   * HTTP 401/403 with `error_type: "plan_required"` in the JSON body
///
/// The sync engine marks dead — retrying won't upgrade the account. UIs
/// catch this to render an "Upgrade your plan" prompt instead of the
/// generic "Unauthorized" toast.
class PlanRequiredException extends ApiException {
  const PlanRequiredException([super.message = 'Plan upgrade required']);
}

/// 422 — validation failure. [fieldErrors] is `{ fieldName: [msg, ...] }`.
class ValidationException extends ApiException {
  const ValidationException(super.message, this.fieldErrors);
  final Map<String, List<String>> fieldErrors;
}

class ConflictException extends ApiException {
  const ConflictException([super.message = 'Conflict']);
}

/// The entity doesn't exist server-side. Subtype of [ConflictException]
/// so the create/update drain path (which catches `ConflictException`) keeps
/// treating it as a conflict ("the row was deleted under us — recreate /
/// discard"). The delete/purge/archive drain paths catch this *specific* type
/// and treat it as idempotent success: a destructive mutation whose target is
/// already gone has achieved its goal, so parking it as a conflict (and
/// offering "recreate") would be wrong.
///
/// **Not keyed on HTTP 404.** Invoice Ninja renders `ModelNotFoundException`
/// as **400** (`app/Exceptions/Handler.php`: `{"message":"No query results
/// for model [App\\Models\\Quote] &lt;id&gt;"}`) and reserves 404 for routing
/// mistakes (`"Route does not exist"` / `"Method not supported for this
/// route"`). See `ApiClient._raiseFromResponse` for the body sniff.
class NotFoundException extends ConflictException {
  const NotFoundException([super.message = 'Not found']);
}

/// The server refused to edit a **soft-deleted** record:
/// `{"message":"Record is deleted and cannot be edited. Restore the record to
/// enable editing"}` with HTTP 400, from `ChecksEntityStatus::disallowUpdate()`.
///
/// Distinct from [NotFoundException]: the row still exists, it's just in the
/// deleted state, and the server tells us exactly how to proceed — restore it.
/// Retrying the identical request fails forever, so the sync engine marks the
/// row dead and the failure surface offers **Restore** instead of a futile
/// Retry.
///
/// Note this guard fires on `is_deleted` only, never on `deleted_at`, so an
/// **archived** record is freely editable (verified against a live server —
/// `PUT` on an archived quote returns 200 and stays archived).
class RecordDeletedException extends ServerException {
  const RecordDeletedException(String message) : super(400, message);
}

/// Body fragment that identifies [RecordDeletedException] on the wire. Server
/// side it's a hardcoded English literal in `ChecksEntityStatus::disallowUpdate()`
/// (not `ctrans`), so it's locale-stable. Single source of truth for both the
/// live mapping in `ApiClient._raiseFromResponse` and
/// [isRecordDeletedRejection], which re-derives the classification from a
/// persisted outbox row.
const String kRecordDeletedMessageFragment = 'is deleted and cannot be edited';

/// Body fragment that identifies [NotFoundException] on the wire — Laravel's
/// `ModelNotFoundException`, which Invoice Ninja renders as HTTP 400.
const String kEntityMissingMessageFragment = 'no query results for model';

/// Whether a **persisted** failure (an outbox row's `last_status_code` +
/// `last_error`) is the record-deleted rejection. The exception object is long
/// gone by the time the Outbox screen or a reopened edit form renders, so both
/// re-classify from the stored pair. Keep in step with
/// `ApiClient._raiseFromResponse`.
bool isRecordDeletedRejection(int? statusCode, String? message) {
  if (statusCode != 400 || message == null) return false;
  return message.toLowerCase().contains(kRecordDeletedMessageFragment);
}

class ClientTooOldException extends ApiException {
  const ClientTooOldException({
    required this.minRequiredVersion,
    required this.currentVersion,
  }) : super('Client too old');
  final String minRequiredVersion;
  final String currentVersion;
}

class RateLimitedException extends ApiException {
  const RateLimitedException({this.retryAfter, String message = 'Rate limited'})
    : super(message);
  final Duration? retryAfter;
}

class ServerException extends ApiException {
  const ServerException(this.statusCode, [String message = 'Server error'])
    : super(message);
  final int statusCode;
}

class NetworkException extends ApiException {
  const NetworkException(super.message);
}

/// Demo builds short-circuit non-GET requests; this is the error the UI
/// surfaces to explain the no-op.
class DemoModeException extends ApiException {
  const DemoModeException() : super('Demo mode — changes are not saved.');
}

/// Thrown by `ApiClient.uploadMultipartChunked` when the caller's
/// `isCancelled` callback returns true between chunks. Treat as a silent
/// stop — the UI initiated it, no toast needed.
class UploadCancelledException extends ApiException {
  const UploadCancelledException() : super('Upload cancelled');
}

/// Whether [error] is a *transient* failure worth offering the user a "Retry":
/// network blips, rate limits, and 5xx server errors typically recover on a
/// second attempt. Validation (422), conflict/404 (409), auth (401),
/// password (412), plan (402), demo, and upload-cancelled do **not** — re-
/// sending the same request just fails again, so callers must never surface a
/// Retry for them. A non-[ApiException] throwable (timeout, unexpected I/O) is
/// treated as transient: a retry is harmless and often succeeds.
bool isTransientError(Object error) {
  if (error is NetworkException || error is RateLimitedException) return true;
  if (error is ServerException) return error.statusCode >= 500;
  if (error is! ApiException) return true;
  return false;
}
