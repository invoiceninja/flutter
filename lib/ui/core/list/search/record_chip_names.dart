import 'dart:async';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/ensure_loaded_outcome.dart';

/// The `vendor_id → name` map a list's `nameSources` hands a `vendor:` key:
/// every cached vendor, archived and deleted included
/// (`VendorRepository.watchAllNames`) — see `ClientFilterKey.chipNames`.
Stream<Map<String, String>> vendorChipNames(
  Services services,
  String companyId,
) => _byId(services.vendors.watchAllNames(companyId: companyId));

/// The `project_id → name` map a list's `nameSources` hands a `project:` key;
/// the [vendorChipNames] twin.
Stream<Map<String, String>> projectChipNames(
  Services services,
  String companyId,
) => _byId(services.projects.watchAllNames(companyId: companyId));

Stream<Map<String, String>> _byId(
  Stream<List<({String id, String name})>> rows,
) => rows.map(
  (rows) => {
    for (final r in rows)
      if (r.name.isNotEmpty) r.id: r.name,
  },
);

/// Names a record-backed chip (`client:`, `vendor:`, `project:`) whose id the
/// cache has never held — a saved view, a deep link, a filter restored on
/// another device — by fetching that one record into Drift (the repository's
/// `ensureLoaded`). The chip then resolves through its key's live name map
/// like any other: the name reaches the UI from Drift, never from the
/// response.
///
/// [resolve] runs while chips build, so it is cheap to repeat: an id is asked
/// about once, and one that got no answer (offline) at most every
/// [retryAfter] — offline, the chip keeps its id.
class RecordChipNameHydrator {
  RecordChipNameHydrator(this._ensureLoaded);

  final Future<EnsureLoadedOutcome> Function(String id) _ensureLoaded;

  /// Ids with an answer — fetched, cached, gone or refused — never asked
  /// about again.
  final Set<String> _settled = {};

  /// When an id with no answer yet (offline) was last asked about.
  final Map<String, DateTime> _lastAsked = {};

  static const Duration retryAfter = Duration(seconds: 30);

  /// The chip text for [rawValue]: its name from [lookup], else the raw id.
  /// With no [lookup] a fetched name could never show, so nothing is fetched.
  String resolve(String rawValue, String? Function(String id)? lookup) {
    final resolved = lookup?.call(rawValue);
    if (resolved != null && resolved.isNotEmpty) return resolved;
    if (lookup != null) _hydrate(rawValue);
    return rawValue;
  }

  void _hydrate(String id) {
    if (id.isEmpty || id.startsWith('tmp_') || _settled.contains(id)) return;
    final now = DateTime.now();
    final last = _lastAsked[id];
    if (last != null && now.difference(last) < retryAfter) return;
    _lastAsked[id] = now;
    unawaited(
      _ensureLoaded(id).then((outcome) {
        if (!outcome.isRetryable) _settled.add(id);
      }, onError: (Object _) {}),
    );
  }
}
