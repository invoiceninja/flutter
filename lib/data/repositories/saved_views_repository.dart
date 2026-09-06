import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/saved_view.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/utils/combine_latest.dart';

final _log = Logger('SavedViewsRepository');

/// Current snapshot envelope version. Bumped when the snapshot's `data`
/// shape changes (e.g. adding column captures). Older rows decode through
/// the `v == null` legacy lane.
const int kSavedViewSnapshotVersion = 1;

/// Snapshot keys that are a **display preference, not a filter**.
///
/// `GenericListViewModel.currentSnapshot` writes grouping (and its collapsed
/// set) into the same `nav_state` slot as the filters, because that is where
/// per-entity list state lives. They must not take part in Saved View
/// identity though: otherwise grouping a list — or just folding one group —
/// would make the live slot stop matching the view the user applied, silently
/// dropping the sidebar's active-view highlight and turning
/// [SavedViewsRepository.clearAppliedViewFilters] into a no-op.
///
/// Declared here rather than beside the ViewModel so the data layer doesn't
/// have to import UI code.
const Set<String> kDisplayOnlySnapshotKeys = {'groupField', 'collapsedGroups'};

/// Local-only saved views: named snapshots of a list screen's
/// filter+sort+search state plus the user's current column selection. The
/// repository owns serialization and the "apply" path that splices the
/// filter half into `nav_state.filters_json` (which the running list VM's
/// `navStateDao.watchCurrent` listener picks up) and the column half into
/// `user_settings.table_columns_json` (which the VM's existing column
/// listener picks up).
class SavedViewsRepository {
  SavedViewsRepository({
    required this.db,
    required this.userSettings,
    Uuid uuid = const Uuid(),
    DateTime Function()? now,
  }) : _uuid = uuid,
       _now = now ?? DateTime.now;

  final AppDatabase db;

  /// Used by [apply] to write a saved view's column list through to
  /// `user_settings.table_columns_json` — same channel the column picker
  /// uses, so the VM's existing UserSettings listener picks up the change.
  final UserSettingsRepository userSettings;

  final Uuid _uuid;
  final DateTime Function() _now;

  // ── Reads ─────────────────────────────────────────────────────────────

  /// Watch every saved view for [companyId], any entity. The sidebar
  /// consumes this and renders one item per row, grouped by entity at the
  /// UI layer.
  Stream<List<SavedView>> watchAll(String companyId) =>
      db.savedViewsDao.watchAll(companyId).map(_decodeRows);

  /// Watch saved views for a single `(companyId, entityType)`. Drives the
  /// bookmark sheet's existing-views list.
  Stream<List<SavedView>> watchForEntity(
    String companyId,
    EntityType entityType,
  ) => db.savedViewsDao
      .watchForEntity(companyId, entityType.name)
      .map(_decodeRows);

  /// The saved view (if any) whose snapshot deeply matches [currentSnapshot]
  /// for the given `(companyId, entityType)`. Emits `null` when the current
  /// list state doesn't correspond to any saved view.
  ///
  /// Exposed for the deferred "active-view indicator" — that visual lands
  /// as a one-line `StreamBuilder` once the design is ready.
  Stream<SavedView?> matchingView({
    required String companyId,
    required EntityType entityType,
    required Map<String, dynamic> currentSnapshot,
  }) {
    const eq = DeepCollectionEquality();
    return watchForEntity(companyId, entityType).map((views) {
      for (final v in views) {
        if (eq.equals(v.snapshot, currentSnapshot)) return v;
      }
      return null;
    });
  }

  /// The saved view currently reflected by `nav_state.filters_json` for
  /// `(companyId, entityType)`, or `null` when the live list state matches
  /// no saved view. Combine-latests the per-entity saved-views stream with
  /// the live nav_state stream; comparison is on the six-field filter slot
  /// (columnIds stripped) — exactly what [apply] writes and what the list
  /// VM's `currentSnapshot()` persists. Drives the sidebar's active-view
  /// highlight.
  Stream<SavedView?> watchActiveView({
    required String companyId,
    required EntityType entityType,
  }) {
    return combineLatest2(
      watchForEntity(companyId, entityType),
      db.navStateDao.watchCurrent(),
      (views, nav) {
        final slot = _filterSlot(nav?.filtersJson, companyId, entityType);
        if (slot == null) return null;
        return _matchSlot(views, slot);
      },
    );
  }

  /// The saved view whose filter snapshot deeply equals [slot], or `null`.
  /// `apply` strips `columnIds` before splicing into nav_state, so strip it
  /// here too — otherwise a column-customized view could never match its own
  /// applied slot. Single source of truth for the active-view equality, shared
  /// by [watchActiveView] and [clearAppliedViewFilters].
  ///
  /// [kDisplayOnlySnapshotKeys] comes off **both** sides
  /// for the same reason: grouping and its collapsed set ride in the same
  /// nav_state slot but are a display preference, not a filter. Leaving them
  /// in would mean grouping a list — or just folding one group — silently
  /// dropped the active-view highlight and disabled [clearAppliedViewFilters].
  SavedView? _matchSlot(List<SavedView> views, Map<String, dynamic> slot) {
    const eq = DeepCollectionEquality();
    final liveSlot = Map<String, dynamic>.from(slot)
      ..removeWhere((k, _) => kDisplayOnlySnapshotKeys.contains(k));
    for (final v in views) {
      final viewSlot = Map<String, dynamic>.from(v.snapshot)
        ..remove('columnIds')
        ..removeWhere((k, _) => kDisplayOnlySnapshotKeys.contains(k));
      if (eq.equals(viewSlot, liveSlot)) return v;
    }
    return null;
  }

  /// When the live nav_state slot for `(companyId, entityType)` matches a
  /// saved view, remove just that slot so the list reverts to its default
  /// and the sidebar highlight returns to the entity row. No-op when there
  /// is no slot, or the slot is a manual (non-saved-view) filter set —
  /// manual filtering is deliberately preserved.
  ///
  /// The slot's absence is transient: a live list VM resets to defaults
  /// (via its `nav_state` listener) and its debounced `_persist` re-writes
  /// the slot as the *default* snapshot. The invariant that drives the
  /// sidebar highlight is "slot ≠ any saved-view snapshot", not "slot
  /// absent" — both states resolve to the entity row being highlighted.
  Future<void> clearAppliedViewFilters({
    required String companyId,
    required EntityType entityType,
  }) async {
    final nav = await db.navStateDao.current();
    final slot = _filterSlot(nav?.filtersJson, companyId, entityType);
    if (slot == null) return; // nothing applied
    final views = await watchForEntity(companyId, entityType).first;
    if (_matchSlot(views, slot) == null) return; // manual filters → keep
    final decoded = jsonDecode(nav!.filtersJson!);
    if (decoded is! Map) return;
    final doc = Map<String, dynamic>.from(decoded);
    final companyBlob = doc[companyId];
    if (companyBlob is! Map) return;
    // Remove the slot OUTRIGHT. Writing a partial `{groupField, ...}` slot here
    // looked like the obvious counterpart to `apply`'s carry-across, but it
    // breaks a load-bearing invariant: the list VM's nav-state listener
    // substitutes `_defaultSnapshot()` for an ABSENT slot, which is byte-equal
    // to `currentSnapshot()` at defaults, so both dedupe guards hold and the
    // listener no-ops. A partial slot never equals `currentSnapshot()` (which
    // always emits the six filter keys), so every later emission of the shared
    // `nav_state` row — a route write, another entity's persist — would fail
    // both guards and re-run `_applyDecoded` + `_resetAndReload`, refetching
    // page 1 and clearing the multiselect, until the 500 ms debounced persist
    // rewrote the slot. Grouping is a display preference and resets here; the
    // bug this repo actually had was `apply` destroying it, and that stays
    // fixed.
    final companyMap = Map<String, dynamic>.from(companyBlob)
      ..remove(entityType.name);
    if (companyMap.isEmpty) {
      doc.remove(companyId);
    } else {
      doc[companyId] = companyMap;
    }
    await db.navStateDao.saveFilters(
      filtersJson: jsonEncode(doc),
      now: _now().millisecondsSinceEpoch,
    );
  }

  /// Copy the display-only keys ([kDisplayOnlySnapshotKeys]) from the live
  /// nav-state slot [from] onto the slot [to] that is about to replace it.
  /// No-op for a slot that carries none (a list that was never grouped).
  static void _carryDisplayOnly({
    required Object? from,
    required Map<String, dynamic> to,
  }) {
    if (from is! Map) return;
    for (final key in kDisplayOnlySnapshotKeys) {
      final value = from[key];
      if (value != null) to[key] = value;
    }
  }

  /// Decode `doc[companyId][entityType.name]` out of a `filters_json` blob.
  /// Returns `null` on missing/corrupt input — same guard shape as [apply].
  Map<String, dynamic>? _filterSlot(
    String? filtersJson,
    String companyId,
    EntityType entityType,
  ) {
    if (filtersJson == null || filtersJson.isEmpty) return null;
    try {
      final decoded = jsonDecode(filtersJson);
      if (decoded is! Map) return null;
      final company = decoded[companyId];
      if (company is! Map) return null;
      final slot = company[entityType.name];
      if (slot is! Map) return null;
      return Map<String, dynamic>.from(slot);
    } catch (_) {
      return null;
    }
  }

  // ── Writes ────────────────────────────────────────────────────────────

  Future<SavedView> create({
    required String companyId,
    required EntityType entityType,
    required String name,
    required Map<String, dynamic> snapshot,
    String? iconKey,
  }) async {
    final nowMs = _now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final payload = _encode(snapshot);
    await db.savedViewsDao.insertView(
      SavedViewsCompanion(
        id: Value(id),
        companyId: Value(companyId),
        entityType: Value(entityType.name),
        name: Value(name),
        payloadJson: Value(payload),
        icon: Value(iconKey),
        createdAt: Value(nowMs),
        updatedAt: Value(nowMs),
      ),
    );
    return SavedView(
      id: id,
      companyId: companyId,
      entityType: entityType,
      name: name,
      snapshot: snapshot,
      iconKey: iconKey,
      createdAt: nowMs,
      updatedAt: nowMs,
    );
  }

  Future<void> rename({required String viewId, required String newName}) async {
    await db.savedViewsDao.updateById(
      id: viewId,
      name: newName,
      now: _now().millisecondsSinceEpoch,
    );
  }

  Future<void> updateSnapshot({
    required String viewId,
    required Map<String, dynamic> snapshot,
  }) async {
    await db.savedViewsDao.updateById(
      id: viewId,
      payloadJson: _encode(snapshot),
      now: _now().millisecondsSinceEpoch,
    );
  }

  /// Set (or clear, with `iconKey == null`) the curated icon for [viewId].
  /// No-op when the row is missing.
  Future<void> setIcon({
    required String viewId,
    required String? iconKey,
  }) async {
    await db.savedViewsDao.updateById(
      id: viewId,
      icon: Value(iconKey),
      now: _now().millisecondsSinceEpoch,
    );
  }

  Future<void> delete(String viewId) async {
    await db.savedViewsDao.deleteById(viewId);
  }

  /// Apply [viewId]: splice its snapshot into `nav_state.filters_json` at
  /// `companyId → entityType.name` (drives the VM's filter listener), and
  /// — when the snapshot carries a `columnIds` list — write that through to
  /// [UserSettings] so the VM's column listener picks up the new layout.
  /// No-op when the row is missing.
  ///
  /// Legacy snapshots (saved before columnIds was a captured field) have
  /// no `columnIds` key; in that case the column layout is left untouched.
  Future<void> apply(String viewId) async {
    final row = await db.savedViewsDao.byId(viewId);
    if (row == null) return;
    final entityType = _entityTypeOrNull(row.entityType);
    if (entityType == null) return;
    final snapshot = _decodePayload(row.payloadJson);
    if (snapshot == null) return;

    // Filters → nav_state.filters_json. Strip `columnIds` before splicing
    // so the nav_state slot stays at the six-field shape the VM's
    // currentSnapshot()/equality check uses.
    final filterSlot = Map<String, dynamic>.from(snapshot)..remove('columnIds');
    final nav = await db.navStateDao.current();
    final existing = nav?.filtersJson;
    Map<String, dynamic> doc;
    if (existing == null || existing.isEmpty) {
      doc = <String, dynamic>{};
    } else {
      try {
        final decoded = jsonDecode(existing);
        doc = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      } catch (_) {
        doc = <String, dynamic>{};
      }
    }
    final companyBlob = doc[row.companyId];
    final companyMap = companyBlob is Map<String, dynamic>
        ? Map<String, dynamic>.from(companyBlob)
        : <String, dynamic>{};
    // Carry the LIVE slot's display-only keys (grouping + its collapsed set)
    // across. `savedViewSnapshot` strips them at capture time precisely because
    // they "must not take part in Saved View identity" — but splicing the
    // stripped map in as the WHOLE slot then deleted them, so applying a view
    // silently un-grouped the list and lost which groups were folded, with no
    // way to get either back but re-picking the dimension by hand. The sibling
    // deep-link path (`_applyIntentState`) already leaves grouping alone, for
    // the reason its comment gives: "an intent that silently ungrouped the list
    // would be a surprise".
    _carryDisplayOnly(from: companyMap[entityType.name], to: filterSlot);
    companyMap[entityType.name] = filterSlot;
    doc[row.companyId] = companyMap;

    await db.navStateDao.saveFilters(
      filtersJson: jsonEncode(doc),
      now: _now().millisecondsSinceEpoch,
    );

    // Columns → user_settings.table_columns_json. Wrap separately so a
    // settings-not-hydrated failure (UserSettingsRepository.setColumns
    // silently no-ops in that case) never blocks the filter apply above.
    final columnIdsRaw = snapshot['columnIds'];
    if (columnIdsRaw is List) {
      final columnIds = columnIdsRaw.whereType<String>().toList();
      if (columnIds.isNotEmpty) {
        try {
          await userSettings.setColumns(
            companyId: row.companyId,
            entityType: entityType,
            columns: columnIds,
          );
        } catch (e, st) {
          _log.warning(
            'Failed to apply columns from saved view $viewId',
            e,
            st,
          );
        }
      }
    }
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /// Wrap [data] in the schema-versioned envelope. Reading code accepts
  /// both `{"v": 1, "data": {...}}` (current) and a bare `{...}` (forward-
  /// compat lane for legacy rows that never went through this encoder).
  String _encode(Map<String, dynamic> data) =>
      jsonEncode({'v': kSavedViewSnapshotVersion, 'data': data});

  /// Decode payload JSON. Returns `null` (skip) on corrupt rows so a single
  /// bad write doesn't poison the whole watch stream.
  Map<String, dynamic>? _decodePayload(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      // Versioned envelope.
      if (decoded.containsKey('v')) {
        final inner = decoded['data'];
        if (inner is Map) return Map<String, dynamic>.from(inner);
        return null;
      }
      // Legacy / forward-compat: bare snapshot map.
      return Map<String, dynamic>.from(decoded);
    } catch (e, st) {
      _log.warning('Failed to decode saved-view payload', e, st);
      return null;
    }
  }

  EntityType? _entityTypeOrNull(String name) {
    for (final t in EntityType.values) {
      if (t.name == name) return t;
    }
    return null;
  }

  List<SavedView> _decodeRows(List<SavedViewRow> rows) {
    final out = <SavedView>[];
    for (final row in rows) {
      final entityType = _entityTypeOrNull(row.entityType);
      if (entityType == null) {
        // Drop rows referencing entities the build no longer knows about
        // (renamed enum case, removed module). Logged but never thrown —
        // a single bad row would otherwise blank out the sidebar.
        _log.fine(
          'Skipping saved view ${row.id}: unknown entity '
          '${row.entityType}',
        );
        continue;
      }
      final snapshot = _decodePayload(row.payloadJson);
      if (snapshot == null) continue;
      out.add(
        SavedView(
          id: row.id,
          companyId: row.companyId,
          entityType: entityType,
          name: row.name,
          snapshot: snapshot,
          iconKey: row.icon,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
      );
    }
    return out;
  }
}
