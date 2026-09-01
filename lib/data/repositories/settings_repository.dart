import 'dart:convert';

import 'package:admin/data/db/app_database.dart';

/// Resolves effective settings for a client by walking the cascade
/// `client.settings → group.settings → company.settings`, matching
/// `admin-portal/lib/redux/settings/settings_state.dart:93-99`.
///
/// In M1 only the company-level layer is populated (no Groups yet). The
/// walker is structured so M2's Group entity drops in without changing
/// callers.
class SettingsRepository {
  SettingsRepository({required AppDatabase db}) : _db = db;
  final AppDatabase _db;

  /// Return the effective settings map for the given client. Keys later in
  /// the lookup chain are overridden by earlier ones.
  ///
  /// Always hits Drift — deliberately NOT memoized. Every gate that acts on
  /// settings (`InvoiceActions.dispatch`, the edit guard, `InvoiceRepository`'s
  /// save backstop) goes through here and must see the current value.
  /// [resolvedIfReady] is the seed-only sibling.
  Future<Map<String, dynamic>> resolved({
    required String companyId,
    String? clientId,
  }) async {
    final company = await _db.companiesDao.byId(companyId);
    final companySettings = company == null
        ? <String, dynamic>{}
        : _decodeOrEmpty(company.settings);
    _remember(_companyLayer, companyId, companySettings);

    final clientSettings = <String, dynamic>{};
    if (clientId != null) {
      final client = await _db.clientDao
          .watchById(companyId: companyId, id: clientId)
          .first;
      if (client != null) {
        final payload = jsonDecode(client.payload) as Map<String, dynamic>;
        final inner = payload['settings'];
        if (inner is Map<String, dynamic>) clientSettings.addAll(inner);
      }
      // Recorded even when empty: "known to have no overrides" must be
      // distinguishable from "never looked".
      _remember(_clientLayer, '$companyId/$clientId', clientSettings);
    }

    return _merge(company: companySettings, client: clientSettings);
  }

  // ─── First-frame seed mirror ────────────────────────────────────────────
  //
  // The master-detail pane re-keys its subtree per `:id`, so anything it paints
  // needs a synchronous answer on frame 1 or it appears late and shifts the
  // layout. [resolved] is two sequential Drift reads, which is ~3 frames — long
  // enough for the invoice lock banner to push the whole left column down after
  // the user has already started reading it.
  //
  // The LAYERS are mirrored, not the merged result: one warm at company
  // activation then seeds every invoice of every client, because a missing
  // client layer just means "no override". Caching merged (company, client)
  // tuples would leave the seed cold on the first click of each client — which
  // is most clicks.
  //
  // A SEED, never a source of truth. Callers must still run [resolved] and let
  // its answer win; the mirror is refreshed as a side effect of that call, so
  // any staleness is bounded to one mount and cannot recur.

  final Map<String, Map<String, dynamic>> _companyLayer = {};
  final Map<String, Map<String, dynamic>> _clientLayer = {};

  /// Bound on [_clientLayer]; the company layer is bounded by the roster.
  /// Same insertion-order eviction as `BaseEntityRepository._lastSeen`.
  static const int seedCacheLimit = 128;

  /// The cascade as of the last [resolved] call, or null when this company has
  /// never been resolved this session. Read the contract above before using it.
  Map<String, dynamic>? resolvedIfReady({
    required String companyId,
    String? clientId,
  }) {
    final company = _companyLayer[companyId];
    if (company == null) return null;
    return _merge(
      company: company,
      client: clientId == null
          ? const {}
          : _clientLayer['$companyId/$clientId'] ?? const {},
    );
  }

  /// Drop every layer. Called on logout — client-level overrides are user data.
  void clearResolvedCache() {
    _companyLayer.clear();
    _clientLayer.clear();
  }

  /// The one cascade walk, shared by [resolved] and [resolvedIfReady] so they
  /// cannot disagree about precedence. Groups go in the middle in M2.
  Map<String, dynamic> _merge({
    required Map<String, dynamic> company,
    required Map<String, dynamic> client,
  }) => <String, dynamic>{...company, ...client};

  /// Store an unmodifiable copy: a caller mutating a [resolved] result must not
  /// be able to corrupt the mirror, or vice versa.
  void _remember(
    Map<String, Map<String, dynamic>> layer,
    String key,
    Map<String, dynamic> value,
  ) {
    layer
      ..remove(key)
      ..[key] = Map<String, dynamic>.unmodifiable(value);
    while (layer.length > seedCacheLimit) {
      layer.remove(layer.keys.first);
    }
  }

  Map<String, dynamic> _decodeOrEmpty(String raw) {
    if (raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }
}
