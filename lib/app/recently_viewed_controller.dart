import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/recent_record.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/entity_type.dart';

final _log = Logger('RecentlyViewedController');

/// Owns the "recently-viewed entities" list backing the command palette's
/// "Recent" group.
///
/// **Per-company.** Recents are kept keyed by `companyId`
/// (`_byCompany`) and persisted as a `{ "<companyId>": [records…] }` JSON
/// object in the single-row `nav_state.recent_entities_json` (partial
/// write, same pattern as [SidebarController]). Switching company swaps to
/// that company's own list (the previous company's recents are preserved,
/// not cleared); logging back into a company restores its list — across
/// app restarts too.
///
/// Cross-tenant isolation is *structural*: [items] / [record] always read
/// and write `_byCompany[_currentCompanyId]`, so one company can never see
/// another's recents (no clear-on-switch/logout machinery needed). Writes
/// are debounced — opening a detail screen is a hot path.
class RecentlyViewedController extends ChangeNotifier {
  RecentlyViewedController({
    required AppDatabase db,
    required ValueListenable<AuthSession?> session,
    this.maxEntries = 12,
    DateTime Function()? now,
    Duration persistDebounce = const Duration(milliseconds: 400),
  }) : _db = db,
       _session = session,
       _now = now ?? DateTime.now,
       _persistDebounce = persistDebounce {
    _currentCompanyId = _session.value?.currentCompanyId;
    _session.addListener(_onSession);
  }

  final AppDatabase _db;
  final ValueListenable<AuthSession?> _session;
  final DateTime Function() _now;
  final Duration _persistDebounce;

  /// Cap on retained entries **per company** so the blob (and the palette
  /// list) stay small.
  final int maxEntries;

  /// Recents keyed by `companyId`. Newest-first within each list.
  final Map<String, List<RecentRecord>> _byCompany =
      <String, List<RecentRecord>>{};
  String? _currentCompanyId;
  Timer? _persistTimer;

  /// Newest first, scoped to the active company. Empty when logged out
  /// (no current company) or before the session resolves.
  List<RecentRecord> get items {
    final c = _currentCompanyId;
    if (c == null) return const <RecentRecord>[];
    return List.unmodifiable(_byCompany[c] ?? const <RecentRecord>[]);
  }

  /// Load the persisted per-company map on launch. Best-effort: a
  /// malformed blob yields no recents rather than throwing into boot. A
  /// legacy *array* blob (the pre-per-company single-company shape) can't
  /// be attributed to a company here — the session hasn't resolved yet at
  /// boot — so it's dropped (a one-time, low-value loss on upgrade).
  Future<void> restore() async {
    try {
      final raw = (await _db.navStateDao.current())?.recentEntitiesJson;
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return; // legacy List shape → dropped
      _byCompany.clear();
      decoded.forEach((companyId, list) {
        if (companyId is! String || list is! List) return;
        final records = list
            .map(RecentRecord.tryFromJson)
            .whereType<RecentRecord>()
            .take(maxEntries)
            .toList();
        if (records.isNotEmpty) _byCompany[companyId] = records;
      });
      notifyListeners();
    } catch (e, st) {
      _log.warning('Failed to restore recently-viewed', e, st);
    }
  }

  /// Record (or refresh) a visited entity for the **active company**.
  /// De-dupes by (type, id): an already-present entity moves to the front
  /// with a fresh timestamp + the latest label (names change). No-ops on
  /// an empty id or when there's no active company (logged out).
  void record({
    required EntityType type,
    required String id,
    required String label,
  }) {
    final company = _currentCompanyId;
    if (id.isEmpty || company == null) return;
    final entry = RecentRecord(
      type: type,
      id: id,
      label: label,
      viewedAt: _now(),
    );
    final list = _byCompany.putIfAbsent(company, () => <RecentRecord>[]);
    list
      ..removeWhere(entry.sameEntity)
      ..insert(0, entry);
    if (list.length > maxEntries) {
      list.removeRange(maxEntries, list.length);
    }
    notifyListeners();
    _schedulePersist();
  }

  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, _persist);
  }

  Future<void> _persist() async {
    try {
      final payload = <String, dynamic>{
        for (final entry in _byCompany.entries)
          if (entry.value.isNotEmpty)
            entry.key: entry.value.map((r) => r.toJson()).toList(),
      };
      await _db.navStateDao.saveRecentEntities(
        recentEntitiesJson: payload.isEmpty ? null : jsonEncode(payload),
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      // A failed write doesn't roll back the in-memory map — the user
      // still sees their recents until next launch.
      _log.warning('Failed to persist recently-viewed', e, st);
    }
  }

  /// Active company changed (switch / login / logout). Just swap which
  /// company's list [items] reflects — no clearing, no scrub: storage is
  /// keyed by company, so the previous company's recents stay intact and
  /// resurface when the user returns to it.
  void _onSession() {
    final companyId = _session.value?.currentCompanyId;
    if (companyId == _currentCompanyId) return;
    _currentCompanyId = companyId;
    notifyListeners();
  }

  /// Drop every company's recents from memory. Called from the logout fan-out
  /// in `Services.build`, beside `sidebarMenu.resetInMemory()`.
  ///
  /// Storage being keyed by company makes cross-*company* isolation structural,
  /// which is why [_onSession] deliberately doesn't clear — but the cross-*user*
  /// case shares the company id, so nothing separated one user's recents from
  /// the next person to sign in on the same device. `_byCompany` is an
  /// app-lifetime map on a `Services` singleton and was only ever cleared inside
  /// [restore], which runs once at boot: user B's command palette showed user A's
  /// client names and invoice numbers, and B's first [record] call wrote the
  /// whole map straight back into the freshly wiped `nav_state`.
  ///
  /// The pending debounce is cancelled first, or that queued [_persist] would
  /// re-write the map this is clearing.
  void reset() {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (_byCompany.isEmpty) return;
    _byCompany.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    _session.removeListener(_onSession);
    super.dispose();
  }
}
