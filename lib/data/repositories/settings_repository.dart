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
    final groupSettings = <String, dynamic>{};
    if (clientId != null) {
      final client = await _db.clientDao
          .watchById(companyId: companyId, id: clientId)
          .first;
      var groupId = '';
      if (client != null) {
        final payload = jsonDecode(client.payload) as Map<String, dynamic>;
        final inner = payload['settings'];
        if (inner is Map<String, dynamic>) clientSettings.addAll(inner);
        groupId = client.groupSettingsId ?? '';
      }
      // Recorded even when empty: "known to have no overrides" must be
      // distinguishable from "never looked".
      _remember(
        _clientLayer,
        '$companyId/$clientId',
        clientSettings,
        companion: _clientGroup,
        companionValue: groupId,
      );

      if (groupId.isNotEmpty) {
        final group = await _db.groupSettingDao
            .watchById(companyId: companyId, id: groupId)
            .first;
        if (group != null) {
          final payload = jsonDecode(group.payload) as Map<String, dynamic>;
          final inner = payload['settings'];
          if (inner is Map<String, dynamic>) groupSettings.addAll(inner);
        }
        _remember(_groupLayer, '$companyId/$groupId', groupSettings);
      }
    }

    return _merge(
      company: companySettings,
      group: groupSettings,
      client: clientSettings,
    );
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
  final Map<String, Map<String, dynamic>> _groupLayer = {};
  final Map<String, Map<String, dynamic>> _clientLayer = {};

  /// `'{companyId}/{clientId}' -> groupSettingsId` (empty when ungrouped), so
  /// the synchronous [resolvedIfReady] can tell "this client has no group"
  /// from "this client's group layer isn't cached yet".
  ///
  /// Its key set is IDENTICAL to [_clientLayer]'s by construction — [_remember]
  /// writes and evicts both in one call, and nothing else touches it. That is
  /// load-bearing, not tidiness: a plain map write here grew without bound
  /// while [_clientLayer] evicted past [seedCacheLimit], so after 129 distinct
  /// clients the 129th resolve dropped client #1's OVERRIDES while this map
  /// still named its group — sending [resolvedIfReady] down the group branch to
  /// return `{company + group}` and claim readiness, with the client tier
  /// silently missing. A client that overrides its group's
  /// `lock_invoices: when_sent` back to `off` then seeded as locked. A seed may
  /// be cold, and it may be stale for one mount; it must never DROP a tier.
  final Map<String, String> _clientGroup = {};

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
    if (clientId == null) {
      return _merge(company: company, group: const {}, client: const {});
    }
    final key = '$companyId/$clientId';
    final groupId = _clientGroup[key];
    // A client this mirror has never resolved falls through to the company
    // layer, exactly as it did before groups existed. That is what makes ONE
    // company-level warm seed every client in the list — the property the
    // whole mirror is built on, since the first click on each client is most
    // clicks. The group tier is missing for that one frame; `resolved()`
    // follows and wins, and the seed drives rendering only (both invoice-lock
    // GATES call the async `resolveInvoiceLockReason`).
    //
    // Once the client HAS been resolved we know its group, and then a missing
    // group layer is a real gap rather than a cold cache — answer null there
    // instead of silently dropping a tier we know applies.
    if (groupId != null && groupId.isNotEmpty) {
      final group = _groupLayer['$companyId/$groupId'];
      if (group == null) return null;
      return _merge(
        company: company,
        group: group,
        client: _clientLayer[key] ?? const {},
      );
    }
    return _merge(
      company: company,
      group: const {},
      client: _clientLayer[key] ?? const {},
    );
  }

  /// Drop every layer. Called on logout — client-level overrides are user data.
  void clearResolvedCache() {
    _companyLayer.clear();
    _groupLayer.clear();
    _clientLayer.clear();
    _clientGroup.clear();
  }

  /// The one cascade walk, shared by [resolved] and [resolvedIfReady] so they
  /// cannot disagree about precedence: company, then group, then client.
  ///
  /// The group tier used to be missing here (`{...company, ...client}`) long
  /// after Groups shipped — `client_settings_cascade.dart` walks all three and
  /// its header records skipping the group as a FIXED bug. This resolver backs
  /// the gates that *act* on settings: `resolveInvoiceLockReason` /
  /// `peekInvoiceLockReason` (`lock_invoices`, `e_invoice_type`), the
  /// add-to-invoice dialog, and tap-to-call's `timezone_id`. So a group-level
  /// `lock_invoices = when_sent` never locked in the app: no banner, Edit and
  /// Delete still enabled on a sent invoice, and the write then either 4xx'd
  /// from the outbox or diverged from what the portal and PDF show.
  Map<String, dynamic> _merge({
    required Map<String, dynamic> company,
    required Map<String, dynamic> group,
    required Map<String, dynamic> client,
  }) => <String, dynamic>{...company, ...group, ...client};

  /// Store an unmodifiable copy: a caller mutating a [resolved] result must not
  /// be able to corrupt the mirror, or vice versa.
  ///
  /// [companion] is a parallel map keyed the same way ([_clientGroup]) that is
  /// written AND evicted here, in the same call, so its key set cannot drift
  /// from the layer's. Keeping the two in step by convention at the call site
  /// is what failed before; see [_clientGroup].
  void _remember(
    Map<String, Map<String, dynamic>> layer,
    String key,
    Map<String, dynamic> value, {
    Map<String, String>? companion,
    String? companionValue,
  }) {
    layer
      ..remove(key)
      ..[key] = Map<String, dynamic>.unmodifiable(value);
    companion
      ?..remove(key)
      ..[key] = companionValue ?? '';
    while (layer.length > seedCacheLimit) {
      final evicted = layer.keys.first;
      layer.remove(evicted);
      companion?.remove(evicted);
    }
  }

  Map<String, dynamic> _decodeOrEmpty(String raw) {
    if (raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    return decoded is Map<String, dynamic> ? decoded : const {};
  }
}
