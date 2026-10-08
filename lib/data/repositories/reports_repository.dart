import 'package:logging/logging.dart';

import 'package:admin/data/models/api/report_preview_api_model.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/repositories/report_cache_store.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/reports_api.dart';

final _log = Logger('ReportsRepository');

/// Why a Run failed. Mapped from API exceptions in
/// [ReportsRepository.runPreview] so the VM can surface the right UI:
/// inline field errors on 422, password sheet on 412, plan-upgrade CTA on
/// 403-plan, "Keep waiting?" on timeout, etc.
enum ReportErrorKind {
  validation,
  unauthorized,
  passwordRequired,
  planRequired,
  timeout,
  cancelled,
  network,

  /// The server answered 429 — the report routes are throttled to twenty
  /// requests a minute. [ReportError.retryAfter] says how long to wait when
  /// the server said.
  rateLimited,

  /// The server emailed the report instead of returning it — see
  /// `ReportEmailedInstead`. Nothing to wait for and nothing to retry into.
  emailedInstead,
  serverError,
  unknown,
}

class ReportError implements Exception {
  const ReportError({
    required this.kind,
    this.fieldErrors,
    this.message,
    this.pollingHash,
    this.retryAfter,
  });

  final ReportErrorKind kind;

  /// 422 field errors `{fieldName: [msg, ...]}`. Routes to inline filter
  /// field errors in the Filters popover.
  final Map<String, List<String>>? fieldErrors;

  final String? message;

  /// Set on `timeout` errors so the UI's "Keep waiting?" affordance can
  /// re-poll the same hash without re-POSTing a duplicate job.
  final String? pollingHash;

  /// Set on `rateLimited` when the server named a wait.
  final Duration? retryAfter;

  @override
  String toString() =>
      'ReportError(${kind.name}${message == null ? "" : ": $message"})';
}

/// Glue around [ReportsApi]: builds the wire payload from the typed
/// [ReportPayload], parses the preview response into a [ReportPreview], and
/// maps every error path to a single [ReportError] taxonomy.
class ReportsRepository {
  ReportsRepository({required this.api, this.cache});

  final ReportsApi api;

  /// Where a result is remembered between sessions; null (tests) remembers
  /// nothing. See [ReportCacheStore].
  final ReportCacheStore? cache;

  /// The company whose token requests are going out under — bound by
  /// `Services.build`, as on every other repository. A result is filed under
  /// the company it was *asked for*, while the request carries whatever token
  /// is live, so a company switched mid-run would otherwise file one
  /// company's rows under another. Null (tests) disables the check.
  String? Function()? activeCompanyId;

  bool _stillActive(String companyId) {
    final live = activeCompanyId;
    return live == null || live() == companyId;
  }

  /// The last result of this exact request, if one was kept — the rows a
  /// report can show at once, before (or instead of) asking the server.
  /// [numberStyle] must be the one a live run would be parsed with.
  Future<({ReportPreview preview, DateTime fetchedAt})?> cachedPreview({
    required String companyId,
    required String reportIdentifier,
    required ReportPayload payload,
    FormattedNumberStyle? numberStyle,
  }) async {
    final store = cache;
    if (store == null || companyId.isEmpty) return null;
    final hit = await store.read(
      companyId: companyId,
      key: _cacheKey(reportIdentifier, payload),
    );
    if (hit == null) return null;
    try {
      return (
        preview: decodeReportPreview(hit.raw, numberStyle: numberStyle),
        fetchedAt: hit.fetchedAt,
      );
    } on FormatException catch (e) {
      _log.warning('Cached report did not decode', e);
      return null;
    }
  }

  static String _cacheKey(String reportIdentifier, ReportPayload payload) =>
      ReportCacheStore.keyFor(
        reportIdentifier,
        // Only what changes the rows: a template or an attachment switch
        // does not make it a different result.
        payload.forPreview.toJson(reportIdentifier: reportIdentifier),
      );

  /// Run a preview report. Returns the typed [ReportPreview]; throws a
  /// [ReportError] on any failure.
  ///
  /// - [reportKeys] is the user's visible-column selection, sent to the
  ///   server so the response only carries those columns. Empty list means
  ///   "use the server's default column set."
  /// - [isCancelled] is checked between polls; set it from the VM's
  ///   `_runEpoch` token so a cancelled run stops cleanly.
  /// - [numberStyle] is how the server writes numbers for this company (its
  ///   currency's separators and precision); see `decodeReportPreview`.
  Future<ReportPreview> runPreview({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    List<String> reportKeys = const [],
    FormattedNumberStyle? numberStyle,
    String? companyId,
    int maxRetries = ReportsApi.defaultPreviewRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    final wire = payload.toJson(
      reportIdentifier: reportIdentifier,
      reportKeys: reportKeys,
    );
    try {
      final raw = await api.runPreview(
        endpoint: endpoint,
        payload: wire,
        maxRetries: maxRetries,
        pollInterval: pollInterval,
        isCancelled: isCancelled,
      );
      final preview = decodeReportPreview(raw, numberStyle: numberStyle);
      // Remembered only once it has decoded, and only for the company it was
      // asked for (see [activeCompanyId]). [companyId] null — tests, or a
      // caller that wants no memory — skips it.
      final store = cache;
      if (store != null &&
          companyId != null &&
          companyId.isNotEmpty &&
          _stillActive(companyId)) {
        await store.write(
          companyId: companyId,
          key: _cacheKey(reportIdentifier, payload),
          raw: raw,
        );
      }
      return preview;
    } on ReportError {
      rethrow;
    } on Object catch (e, st) {
      throw _mapError(e, st);
    }
  }

  /// Continue polling an in-flight preview hash for another budget. Used
  /// by the "Keep waiting?" UX so we don't re-POST a duplicate job.
  Future<ReportPreview> continuePreview({
    required String hash,
    FormattedNumberStyle? numberStyle,
    int maxRetries = ReportsApi.defaultPreviewRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    try {
      final raw = await api.continuePreview(
        hash: hash,
        maxRetries: maxRetries,
        pollInterval: pollInterval,
        isCancelled: isCancelled,
      );
      return decodeReportPreview(raw, numberStyle: numberStyle);
    } on ReportError {
      rethrow;
    } on Object catch (e, st) {
      throw _mapError(e, st);
    }
  }

  /// Queued file export. Builds the wire payload, POSTs to the export
  /// endpoint, polls until the file is ready, and returns the raw bytes along
  /// with what they turned out to be — the server picks the type (see
  /// [ReportExportFormat]). Same [ReportError] taxonomy as [runPreview].
  Future<ReportExportResult> runExport({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    List<String> reportKeys = const [],
    String? groupBy,
    int maxRetries = ReportsApi.defaultExportRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    final wire = payload.toJson(
      reportIdentifier: reportIdentifier,
      reportKeys: reportKeys,
      groupBy: groupBy,
    );
    try {
      return await api.runExport(
        endpoint: endpoint,
        payload: wire,
        maxRetries: maxRetries,
        pollInterval: pollInterval,
        isCancelled: isCancelled,
      );
    } on ReportError {
      rethrow;
    } on Object catch (e, st) {
      throw _mapError(e, st);
    }
  }

  /// Continue an in-flight export hash for another budget ("Keep waiting?").
  Future<ReportExportResult> continueExport({
    required String hash,
    int maxRetries = ReportsApi.defaultExportRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    try {
      return await api.continueExport(
        hash: hash,
        maxRetries: maxRetries,
        pollInterval: pollInterval,
        isCancelled: isCancelled,
      );
    } on ReportError {
      rethrow;
    } on Object catch (e, st) {
      throw _mapError(e, st);
    }
  }

  /// Email export. Sets `send_email: true` on the wire payload and POSTs
  /// once — no polling. Caller surfaces a "Sent" toast on success.
  Future<void> sendEmail({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    List<String> reportKeys = const [],
    String? groupBy,
  }) async {
    final wire = payload
        .copyWith(sendEmail: true)
        .toJson(
          reportIdentifier: reportIdentifier,
          reportKeys: reportKeys,
          groupBy: groupBy,
        );
    try {
      await api.sendEmail(endpoint: endpoint, payload: wire);
    } on Object catch (e, st) {
      throw _mapError(e, st);
    }
  }

  /// Translate ApiException / polling errors to the [ReportError] taxonomy.
  ///
  /// Plan-gated endpoint detection:
  /// 1. **Primary** — `PlanRequiredException` from the API client. Raised
  ///    when the server emits HTTP 402 or a 401/403 with
  ///    `error_type: "plan_required"`. Authoritative; locale-independent.
  /// 2. **Fallback** — legacy English message sniff on 401/403 responses
  ///    that don't carry the structured signal. Kept until every
  ///    reachable Invoice Ninja server build emits the typed signal;
  ///    drop the sniff arms in a follow-up once that's verified.
  ///
  /// Real unauthorized landing here would be a stale permission cache —
  /// the sidebar is already gated on `can('view_reports')`.
  ReportError _mapError(Object e, StackTrace st) {
    if (e is ReportPollingCancelled) {
      return const ReportError(kind: ReportErrorKind.cancelled);
    }
    if (e is ReportPollingTimeout) {
      return ReportError(kind: ReportErrorKind.timeout, pollingHash: e.hash);
    }
    if (e is ReportEmailedInstead) {
      return const ReportError(kind: ReportErrorKind.emailedInstead);
    }
    if (e is ValidationException) {
      return ReportError(
        kind: ReportErrorKind.validation,
        fieldErrors: e.fieldErrors,
        message: e.message,
      );
    }
    if (e is PasswordRequiredException) {
      return ReportError(
        kind: ReportErrorKind.passwordRequired,
        message: e.message,
      );
    }
    if (e is PlanRequiredException) {
      return ReportError(
        kind: ReportErrorKind.planRequired,
        message: e.message,
      );
    }
    if (e is UnauthorizedException) {
      // Fallback path — see the doc comment above. Drop this arm once
      // the server emits `PlanRequiredException` on every build.
      if (_messageSuggestsPlanUpgrade(e.message)) {
        return ReportError(
          kind: ReportErrorKind.planRequired,
          message: e.message,
        );
      }
      return ReportError(
        kind: ReportErrorKind.unauthorized,
        message: e.message,
      );
    }
    if (e is ServerException) {
      // Fallback path — see the doc comment above. 403 with an upgrade
      // message lands here when the server hasn't been updated to emit
      // the typed `PlanRequiredException`. Only true 401s are typed as
      // `UnauthorizedException` by the client.
      if (e.statusCode == 403) {
        if (_messageSuggestsPlanUpgrade(e.message)) {
          return ReportError(
            kind: ReportErrorKind.planRequired,
            message: e.message,
          );
        }
        return ReportError(
          kind: ReportErrorKind.unauthorized,
          message: e.message,
        );
      }
      return ReportError(kind: ReportErrorKind.serverError, message: e.message);
    }
    if (e is NetworkException) {
      return ReportError(kind: ReportErrorKind.network, message: e.message);
    }
    if (e is RateLimitedException) {
      return ReportError(
        kind: ReportErrorKind.rateLimited,
        message: e.message,
        retryAfter: e.retryAfter,
      );
    }
    _log.warning('Unmapped report error', e, st);
    return ReportError(kind: ReportErrorKind.unknown, message: '$e');
  }

  /// Legacy heuristic for plan-gating: look for "plan" or "upgrade" in the
  /// server's English message. Used only when the authoritative typed
  /// signal ([PlanRequiredException]) wasn't raised — i.e. when talking
  /// to an older server build. Locale-fragile by definition; the primary
  /// path is the typed exception.
  bool _messageSuggestsPlanUpgrade(String message) {
    final msg = message.toLowerCase();
    return msg.contains('plan') || msg.contains('upgrade');
  }
}
