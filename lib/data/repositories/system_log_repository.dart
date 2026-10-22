import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/system_log.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/system_logs_api.dart';

final _log = Logger('SystemLogRepository');

/// Outcome of a [SystemLogRepository.refresh] call. The UI uses this to
/// distinguish "empty because the server has no logs" from "empty because
/// the account isn't allowed to view them" — important on self-hosted
/// installs that disable the endpoint.
enum SystemLogRefreshResult { ok, forbidden, notFound, networkError }

/// Read-only repository for `/api/v1/system_logs`. Mirrors
/// [StaticsRepository]'s shape — no outbox, no mutation surface; the
/// server is the only writer.
class SystemLogRepository {
  SystemLogRepository({
    required AppDatabase db,
    required SystemLogsApi api,
    DateTime Function()? now,
  }) : _db = db,
       _api = api,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final SystemLogsApi _api;
  final DateTime Function() _now;

  /// In-memory fallback for `lastFetchedAt` when the cached row count is
  /// zero. The DAO derives the value from `MAX(fetched_at)` across rows,
  /// which is NULL when an account has no system logs at all — without this
  /// fallback, every screen open would re-pull the same empty page. Map
  /// resets on app restart (a fresh re-pull then is harmless).
  final Map<String, DateTime> _lastFetchedFallback = {};

  /// Stream of cached system logs for [companyId], newest first.
  Stream<List<SystemLog>> watch(String companyId) {
    if (companyId.isEmpty) {
      return Stream<List<SystemLog>>.value(const []);
    }
    return _db.systemLogDao
        .watchForCompany(companyId: companyId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// Latest `fetched_at` for [companyId], or null if we have never
  /// successfully refreshed during this process lifetime. Prefers the DAO
  /// value (survives restarts when rows exist) and falls back to the
  /// in-memory map when the cache is empty.
  Future<DateTime?> lastFetchedAt(String companyId) async {
    if (companyId.isEmpty) return null;
    final fromDao = await _db.systemLogDao.lastFetchedAt(companyId);
    return fromDao ?? _lastFetchedFallback[companyId];
  }

  /// Fetch a fresh page and replace the cache for [companyId]. The 403 /
  /// 404 / 412 / network branches return the matching enum instead of
  /// throwing — most self-hosted installs gate this endpoint and the UI
  /// needs to render a different empty state.
  Future<SystemLogRefreshResult> refresh(String companyId) async {
    if (companyId.isEmpty) return SystemLogRefreshResult.ok;
    try {
      final list = await _api.fetchPage();
      final nowSeconds = _now().toUtc().millisecondsSinceEpoch ~/ 1000;
      final rows = list.data
          .map(
            (a) => SystemLogsCompanion.insert(
              id: a.id,
              companyId: companyId,
              userId: Value(a.userId),
              clientId: Value(a.clientId),
              eventId: a.eventId,
              categoryId: a.categoryId,
              typeId: a.typeId,
              log: Value(a.log),
              createdAt: a.createdAt,
              updatedAt: a.updatedAt,
              fetchedAt: nowSeconds,
            ),
          )
          .toList(growable: false);
      await _db.systemLogDao.replaceForCompany(
        companyId: companyId,
        rows: rows,
      );
      _lastFetchedFallback[companyId] = _now().toUtc();
      return SystemLogRefreshResult.ok;
    } catch (e) {
      final result = _classifyError(e, companyId);
      if (result == null) rethrow;
      // Cache terminal (permission / disabled) outcomes so we don't re-pull a
      // known-gated endpoint on every screen open or company switch. The cache
      // is empty in these cases, so without this `lastFetchedAt` stays null and
      // the auto-refresh fires every visit. Transient network errors are left
      // uncached so the next visit retries.
      if (result == SystemLogRefreshResult.forbidden ||
          result == SystemLogRefreshResult.notFound) {
        _lastFetchedFallback[companyId] = _now().toUtc();
      }
      return result;
    }
  }

  /// Fetch this client's system logs directly from the server, scoped via the
  /// server-side `client_id` filter, and return them **without** touching the
  /// company-wide Drift cache. Mirrors the read-only fetch-into-state pattern
  /// the client Activity tab uses — the per-client feed is ancillary detail
  /// data, not a watched/paginated entity list. Returns the typed outcome plus
  /// the logs (empty on any non-`ok` outcome).
  Future<(SystemLogRefreshResult, List<SystemLog>)> fetchForClient(
    String clientId,
  ) async {
    if (clientId.isEmpty) {
      return (SystemLogRefreshResult.ok, const <SystemLog>[]);
    }
    try {
      final list = await _api.fetchPage(clientId: clientId);
      final logs = list.data.map(SystemLog.fromApi).toList(growable: false);
      return (SystemLogRefreshResult.ok, logs);
    } catch (e) {
      final result = _classifyError(e, clientId);
      if (result == null) rethrow;
      return (result, const <SystemLog>[]);
    }
  }

  /// The newest [limit] logs whose `type_id` is one of [typeIds], fetched
  /// server-side (`SystemLogFilters::type_id`, one request per id) and merged
  /// newest first — read-only, like [fetchForClient], never touching the
  /// company-wide Drift cache. This is the per-gateway feed: the server's own
  /// `CompanyGateway::system_logs()` (what admin-portal read through
  /// `?include=system_logs`) is the company's logs of the provider's type id,
  /// newest 50. Filtering the company cache instead only ever sees the newest
  /// 200 logs of *every* kind, so a busy account's gateway history vanished
  /// behind its email and webhook rows. Any failed request fails the whole
  /// fetch — a half-merged feed would read as complete.
  Future<(SystemLogRefreshResult, List<SystemLog>)> fetchForTypes(
    Set<int> typeIds, {
    int limit = 50,
  }) async {
    if (typeIds.isEmpty) {
      return (SystemLogRefreshResult.ok, const <SystemLog>[]);
    }
    try {
      final pages = await Future.wait([
        for (final id in typeIds) _api.fetchPage(perPage: limit, typeId: id),
      ]);
      final seen = <String>{};
      final logs = [
        for (final page in pages)
          for (final a in page.data)
            if (seen.add(a.id)) SystemLog.fromApi(a),
      ];
      logs.sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
      return (
        SystemLogRefreshResult.ok,
        List<SystemLog>.unmodifiable(logs.take(limit)),
      );
    } catch (e) {
      final result = _classifyError(e, 'type_id ${typeIds.join(',')}');
      if (result == null) rethrow;
      return (result, const <SystemLog>[]);
    }
  }

  /// Maps a read-path exception to a [SystemLogRefreshResult], or null for an
  /// exception we don't recognize (the caller rethrows — only known API
  /// failures are swallowed). [scope] is a company or client id, for logging.
  SystemLogRefreshResult? _classifyError(Object e, String scope) {
    if (e is PasswordRequiredException) {
      // 412 — server demands password to view; treated like 403 since the
      // System Logs feed has no password prompt UI of its own.
      _log.info('System logs gated (412 password required) for $scope');
      return SystemLogRefreshResult.forbidden;
    }
    if (e is ServerException) {
      if (e.statusCode == 403) {
        _log.info('System logs forbidden (403) for $scope');
        return SystemLogRefreshResult.forbidden;
      }
      if (e.statusCode == 404) {
        _log.info('System logs endpoint not found (404) for $scope');
        return SystemLogRefreshResult.notFound;
      }
      _log.warning('System logs fetch failed (${e.statusCode}): ${e.message}');
      return SystemLogRefreshResult.networkError;
    }
    if (e is NetworkException) {
      _log.warning('System logs fetch: network error', e);
      return SystemLogRefreshResult.networkError;
    }
    if (e is ApiException) {
      _log.warning('System logs fetch: api exception', e);
      return SystemLogRefreshResult.networkError;
    }
    return null;
  }

  SystemLog _fromRow(SystemLogRow row) => SystemLog(
    id: row.id,
    companyId: row.companyId,
    userId: row.userId,
    clientId: row.clientId,
    eventId: row.eventId,
    categoryId: row.categoryId,
    typeId: row.typeId,
    log: row.log,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      row.createdAt * 1000,
      isUtc: true,
    ),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(
      row.updatedAt * 1000,
      isUtc: true,
    ),
  );
}
