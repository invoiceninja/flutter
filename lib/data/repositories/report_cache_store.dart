import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/dashboard_cache_dao.dart';

final _log = Logger('ReportCacheStore');

/// A report result read back from disk: the server's raw answer, and when it
/// was fetched.
class CachedReport {
  const CachedReport({required this.raw, required this.fetchedAt});

  /// The preview envelope exactly as `reports/preview/<hash>` returned it.
  final Map<String, Object?> raw;
  final DateTime fetchedAt;
}

/// The last results of the reports the reader has run, kept on disk so a
/// report opens on what it showed last time instead of on a spinner — and
/// still opens with no connection at all.
///
/// Stored in `dashboard_cache`, the table the dashboard keeps its own
/// server-backed figures in, under the kind [kind]: it is a cache-class
/// table, so there is no schema change, a repair may drop it, and a sign-out
/// wipes it with everything else. The raw JSON is stored, not the parsed
/// preview, so a release that parses it better reads old rows better too.
///
/// Bounded twice. A result larger than [maxPayloadLength] is not stored at
/// all (a fifty-thousand-row report is megabytes, and it is the one a reader
/// re-runs deliberately); and only the [maxEntries] most recent are kept.
class ReportCacheStore {
  ReportCacheStore({
    required this.db,
    int Function()? now,
    this.maxEntries = 12,
    this.maxPayloadLength = 2 * 1024 * 1024,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase db;
  final int Function() _now;
  final int maxEntries;
  final int maxPayloadLength;

  static const String kind = 'report';

  DashboardCacheDao get _dao => db.dashboardCacheDao;

  /// The key one request's result is filed under: the report, and the
  /// request itself in a canonical form (keys sorted).
  ///
  /// The request and not a digest of it: the key is then exact — two
  /// different requests can never be served each other's rows — and it reads
  /// as what it is in a database dump. It is a few hundred characters at
  /// most, in a table of a dozen rows.
  ///
  /// [request] is the wire payload **without** `report_keys` — the same
  /// report answers with the same rows whichever columns were asked for, and
  /// the newest answer is the one to keep.
  static String keyFor(String reportIdentifier, Map<String, dynamic> request) {
    final sorted = Map.fromEntries(
      request.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return '$reportIdentifier|${jsonEncode(sorted)}';
  }

  Future<CachedReport?> read({
    required String companyId,
    required String key,
  }) async {
    try {
      final row = await _dao.read(
        companyId: companyId,
        kind: kind,
        filterHash: key,
      );
      if (row == null) return null;
      final decoded = jsonDecode(row.payload);
      if (decoded is! Map) return null;
      return CachedReport(
        raw: decoded.map((k, v) => MapEntry('$k', v)),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(row.fetchedAt),
      );
    } catch (e, st) {
      // A cache that cannot be read is a cache miss.
      _log.warning('Could not read cached report $key', e, st);
      return null;
    }
  }

  /// File [raw] under [key], and drop what falls off the end of the history.
  /// Never throws: failing to remember a result must not fail the run that
  /// produced it.
  Future<void> write({
    required String companyId,
    required String key,
    required Map<String, Object?> raw,
  }) async {
    try {
      final payload = jsonEncode(raw);
      if (payload.length > maxPayloadLength) {
        // Too large to keep — and an older, smaller answer to the same
        // request must not be served as if it were this one.
        await _dao.deleteHashes(
          companyId: companyId,
          kind: kind,
          hashes: [key],
        );
        return;
      }
      await _dao.upsert(
        companyId: companyId,
        kind: kind,
        filterHash: key,
        payload: payload,
        fetchedAt: _now(),
      );
      final hashes = await _dao.hashesNewestFirst(
        companyId: companyId,
        kind: kind,
      );
      if (hashes.length > maxEntries) {
        await _dao.deleteHashes(
          companyId: companyId,
          kind: kind,
          hashes: hashes.skip(maxEntries),
        );
      }
    } catch (e, st) {
      _log.warning('Could not cache report $key', e, st);
    }
  }
}
