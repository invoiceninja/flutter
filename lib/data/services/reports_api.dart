import 'dart:async';
import 'dart:typed_data';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_exception.dart';

/// The file type an export came back as.
///
/// **Detected, never requested.** The export endpoints take no format
/// parameter: the server renders what the report is (CSV for the entity
/// reports, a PDF when a `template_id` is set and for the project report, an
/// XLSX workbook for the tax-period report) and `ReportExportController`
/// labels the response by sniffing its own bytes. This enum used to be a menu
/// of three the user picked from, sent nowhere, and used only to decide which
/// content-type counted as "finished" — so two of the three choices could
/// never complete.
enum ReportExportFormat { pdf, csv, xlsx }

extension ReportExportFormatWire on ReportExportFormat {
  String get defaultExtension {
    switch (this) {
      case ReportExportFormat.pdf:
        return 'pdf';
      case ReportExportFormat.csv:
        return 'csv';
      case ReportExportFormat.xlsx:
        return 'xlsx';
    }
  }
}

const String _kPdfType = 'application/pdf';
const String _kXlsxType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Every media type the export endpoint answers a finished job with. The CSV
/// family is listed in full because what a proxy or an older server calls a
/// CSV varies; `text/html` is deliberately absent — that is an error page.
const Set<String> kReportExportContentTypes = {
  _kPdfType,
  _kXlsxType,
  'text/csv',
  'text/plain',
  'application/csv',
  'application/octet-stream',
};

/// What [bytes] are, by their own signature first and the response's
/// [contentType] second.
///
/// The signature wins because it is what the server itself goes by, and
/// because `application/octet-stream` says nothing. A PDF opens with `%PDF-`
/// (the server trims leading whitespace before checking, so this does too);
/// an XLSX is a zip, `PK\x03\x04`. Anything else is the CSV.
ReportExportFormat detectReportExportFormat(
  List<int> bytes, {
  String? contentType,
}) {
  var start = 0;
  while (start < bytes.length && _isAsciiWhitespace(bytes[start])) {
    start++;
  }
  bool startsWith(List<int> signature) {
    if (bytes.length - start < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[start + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0x25, 0x50, 0x44, 0x46, 0x2D])) {
    return ReportExportFormat.pdf;
  }
  if (startsWith(const [0x50, 0x4B, 0x03, 0x04])) {
    return ReportExportFormat.xlsx;
  }
  if (contentType == _kPdfType) return ReportExportFormat.pdf;
  if (contentType == _kXlsxType) return ReportExportFormat.xlsx;
  return ReportExportFormat.csv;
}

bool _isAsciiWhitespace(int byte) =>
    byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D;

/// Stop polling cleanly when the caller (VM) has lost interest — e.g. the
/// user clicked Cancel or the screen was disposed. Throw `false` and the
/// polling helpers translate into a [ReportPollingCancelled].
typedef ReportPollingCancellation = bool Function();

class ReportPollingCancelled implements Exception {
  const ReportPollingCancelled();
}

/// Thrown when polling exhausts its retry budget. The repository maps this
/// to `ReportErrorKind.timeout`; the UI surfaces a "Keep waiting?"
/// affordance that re-polls the same hash for another budget.
class ReportPollingTimeout implements Exception {
  const ReportPollingTimeout(this.hash);
  final String hash;
  @override
  String toString() => 'ReportPollingTimeout($hash)';
}

/// The server answered a request for a report's rows or file by emailing
/// the report instead — its reply was not a job id. It does that when the
/// request carries (or the server forces) `send_email: true`; the client
/// never asks for it on a preview or an export.
class ReportEmailedInstead implements Exception {
  const ReportEmailedInstead(this.reply);

  /// What the server said in place of a job id (`working...`).
  final String reply;

  @override
  String toString() => 'ReportEmailedInstead($reply)';
}

/// Thin HTTP service for the report endpoints. Does not extend
/// `BaseEntityApi` — these are queued-job endpoints, not list/CRUD.
///
/// Every method here is **read-only in effect** even when the wire verb is
/// POST (the server pre-aggregates from existing data). `readOnly: true`
/// keeps demo-mode short-circuits from rejecting them.
///
/// Three flows:
/// - [runPreview]: `POST <endpoint>?output=json` → hash → poll
///   `/api/v1/reports/preview/<hash>` → JSON rows.
/// - [runExport]: `POST <endpoint>` → hash → poll
///   `/api/v1/exports/preview/<hash>` → binary file.
/// - [sendEmail]: `POST <endpoint>` with `send_email: true` → 200 OK; server
///   queues + emails asynchronously. No polling.
///
/// Polling budgets are configurable so the VM can hand off a longer budget
/// when the user clicks "Keep waiting?" on a timeout.
class ReportsApi {
  ReportsApi(this.client);

  final ApiClient client;

  /// Default preview budget: 30 retries × 2 s = 60 s. Wider than React's
  /// 10× because `invoice_item` / `ar_detail` over multi-year ranges
  /// routinely exceeds 20 s.
  static const Duration defaultPollInterval = Duration(seconds: 2);
  static const int defaultPreviewRetries = 30;
  static const int defaultExportRetries = 50;

  /// Preview flow. Returns the decoded JSON rows envelope.
  Future<Map<String, Object?>> runPreview({
    required String endpoint,
    required Map<String, dynamic> payload,
    int maxRetries = defaultPreviewRetries,
    Duration pollInterval = defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    final hash = await _postForHash(
      path: endpoint,
      payload: payload,
      query: const {'output': 'json'},
    );
    return _pollPreview(
      hash: hash,
      maxRetries: maxRetries,
      pollInterval: pollInterval,
      isCancelled: isCancelled,
    );
  }

  /// Continue polling an in-flight preview hash for another budget. Used
  /// when the user clicks "Keep waiting?" on a timeout error — the server
  /// caches the hash, so re-POSTing would just queue a duplicate job.
  Future<Map<String, Object?>> continuePreview({
    required String hash,
    int maxRetries = defaultPreviewRetries,
    Duration pollInterval = defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) {
    return _pollPreview(
      hash: hash,
      maxRetries: maxRetries,
      pollInterval: pollInterval,
      isCancelled: isCancelled,
    );
  }

  /// Export flow. `POST <endpoint>` → hash → poll
  /// `/api/v1/exports/preview/<hash>` until the binary file is ready.
  ///
  /// Mirrors [runPreview]'s retry/cancel/timeout discipline exactly: only a
  /// 404 (`ConflictException` = job still queued) or a 2xx JSON status
  /// envelope (`RawOrPending.isPending`) is retried; a real 4xx/5xx bubbles
  /// immediately so a failed job never burns the whole budget.
  ///
  /// The result says what the file turned out to be — see
  /// [ReportExportFormat].
  Future<ReportExportResult> runExport({
    required String endpoint,
    required Map<String, dynamic> payload,
    int maxRetries = defaultExportRetries,
    Duration pollInterval = defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    final hash = await _postForHash(path: endpoint, payload: payload);
    return _pollExport(
      hash: hash,
      maxRetries: maxRetries,
      pollInterval: pollInterval,
      isCancelled: isCancelled,
    );
  }

  /// Continue polling an in-flight export hash for another budget — the
  /// "Keep waiting?" affordance, same as [continuePreview].
  Future<ReportExportResult> continueExport({
    required String hash,
    int maxRetries = defaultExportRetries,
    Duration pollInterval = defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) {
    return _pollExport(
      hash: hash,
      maxRetries: maxRetries,
      pollInterval: pollInterval,
      isCancelled: isCancelled,
    );
  }

  Future<ReportExportResult> _pollExport({
    required String hash,
    required int maxRetries,
    required Duration pollInterval,
    required ReportPollingCancellation? isCancelled,
  }) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (isCancelled?.call() == true) {
        throw const ReportPollingCancelled();
      }
      try {
        final res = await client.postRawOrPending(
          '/api/v1/exports/preview/$hash',
          readOnly: true,
          acceptedContentTypes: kReportExportContentTypes,
        );
        final bytes = res.bytes;
        if (!res.isPending && bytes != null) {
          return ReportExportResult(
            bytes: bytes,
            hash: hash,
            format: detectReportExportFormat(
              bytes,
              contentType: res.contentType,
            ),
          );
        }
        // Pending JSON status envelope — fall through to wait + retry.
      } on ConflictException catch (_) {
        // 409 "Still working....." = the queued export job is still running.
        // Same semantics as _pollPreview; retry. Other ApiExceptions
        // (422/401/5xx) bubble.
      } on ServerException catch (e) {
        // See _pollPreview: the 404 tolerance is kept local to polling now
        // that a bare 404 is no longer globally a conflict.
        if (e.statusCode != 404) rethrow;
      }
      await Future<void>.delayed(pollInterval);
    }
    throw ReportPollingTimeout(hash);
  }

  /// Email flow. POSTs the same payload as [runExport] but with
  /// `send_email: true` on the payload — the server queues + sends async,
  /// the response is a plain 200. No hash to poll.
  ///
  /// Caller is responsible for setting `send_email: true` on the payload
  /// before calling. We don't munge it here so the wire shape stays
  /// transparent.
  Future<void> sendEmail({
    required String endpoint,
    required Map<String, dynamic> payload,
  }) async {
    await client.postJson(endpoint, body: payload, readOnly: true);
  }

  Future<String> _postForHash({
    required String path,
    required Map<String, dynamic> payload,
    Map<String, String>? query,
  }) async {
    final raw = await client.postJson(
      path,
      body: payload,
      query: query,
      readOnly: true,
    );
    final hash = _extractHash(raw);
    if (hash == null || hash.isEmpty) {
      throw const FormatException(
        'Report endpoint did not return a polling hash',
      );
    }
    // The same `message` key carries two different answers: a job id to
    // poll, or — when the server decided to email the report — the words
    // "working...". Polling that is a hundred seconds of 404s for a file
    // that is in the user's inbox.
    if (!_kJobId.hasMatch(hash)) throw ReportEmailedInstead(hash);
    return hash;
  }

  /// What a job id looks like: one token. Today's server writes a UUID
  /// (`Str::uuid()` in every report controller), but the test is for "a
  /// token" rather than "a UUID" on purpose — an older self-hosted server
  /// that wrote some other id must keep working, and the reply this exists
  /// to catch (`working...`) is not a token of any kind.
  static final _kJobId = RegExp(r'^[A-Za-z0-9_-]+$');

  static String? _extractHash(Object? raw) {
    if (raw is Map) {
      final msg = raw['message'];
      if (msg is String) return msg;
      // Some endpoints wrap into {data: {hash}} — defensive fallback.
      final data = raw['data'];
      if (data is Map && data['hash'] is String) return data['hash'] as String;
    }
    return null;
  }

  Future<Map<String, Object?>> _pollPreview({
    required String hash,
    required int maxRetries,
    required Duration pollInterval,
    required ReportPollingCancellation? isCancelled,
  }) async {
    for (var attempt = 0; attempt < maxRetries; attempt++) {
      if (isCancelled?.call() == true) {
        throw const ReportPollingCancelled();
      }
      try {
        final raw = await client.postJson(
          '/api/v1/reports/preview/$hash',
          readOnly: true,
        );
        // Only a payload carrying `columns` is the finished report. Guarding
        // on it (rather than "any Map is ready") future-proofs against a 200
        // "pending" envelope: anything without `columns` falls through to
        // wait + retry instead of being mis-parsed as an empty report.
        if (raw is Map && raw.containsKey('columns')) {
          return raw is Map<String, Object?>
              ? raw
              : raw.map((k, v) => MapEntry(k.toString(), v));
        }
      } on ConflictException catch (_) {
        // The report-preview hash endpoint returns 409 + `{"message":"Still
        // working....."}` while the queued job runs — `ReportPreviewController`
        // in the server source, verified against the live server. Exactly what
        // we want to retry on.
      } on ServerException catch (e) {
        // Belt-and-braces for a 404 from the hash endpoint. `ApiClient` used to
        // map every 404 to ConflictException, so this loop retried it for free;
        // that mapping is gone (a bare 404 now means a bad route/verb, see
        // `_raiseFromResponse`), and the retry is kept HERE, narrowly, rather
        // than globally. Harmless if the server never sends it — the loop is
        // bounded by maxRetries — and it keeps an older or proxied deployment
        // that answers "not ready" with a 404 from failing outright.
        if (e.statusCode != 404) rethrow;
      }
      // ValidationException, UnauthorizedException, RateLimitedException,
      // ServerException (5xx), and every other ApiException bubble up
      // through this loop unmodified — the repository's _mapError handles
      // them. Retrying a 422 / 401 would be wrong.
      await Future<void>.delayed(pollInterval);
    }
    throw ReportPollingTimeout(hash);
  }
}

class ReportExportResult {
  const ReportExportResult({
    required this.bytes,
    required this.hash,
    this.format = ReportExportFormat.csv,
  });
  final Uint8List bytes;
  final String hash;

  /// What [bytes] are — detected from the file, see [ReportExportFormat].
  final ReportExportFormat format;
}
