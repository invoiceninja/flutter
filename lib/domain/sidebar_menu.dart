/// The user's main-menu preference — how the sidebar's nav block is laid out,
/// what order its destinations appear in, and which of them are shown
/// (invoiceninja/flutter#125).
///
/// The block this describes is Dashboard + the entity rows + Reports +
/// Activity. Saved views, Settings and Outbox are deliberately outside it —
/// see the class doc on `InSidebar` for why.
///
/// Persisted device-locally by `SidebarMenuController` into
/// `nav_state.sidebar_menu_json`. This file holds only the parts that need no
/// database, no registry and no widget tree, so they can be unit-tested
/// directly; like [SidebarBadgeMode] it stays free of a UI import.
library;

/// How the nav block renders.
///
/// [list] is the full-width row per destination the app has always shown.
/// [grid] is the denser icon-above-label tile grid asked for in #125, matching
/// the dashboard's quick-action pills. The collapsed 64-px rail ignores this
/// entirely — it is already denser than any grid.
enum SidebarMenuLayout { list, grid }

/// Parse a stored [SidebarMenuLayout] name. Anything unrecognized — a value
/// written by a newer build, or a corrupt blob — falls back to [list], which
/// is what every install renders today.
SidebarMenuLayout sidebarMenuLayoutFromName(Object? raw) {
  for (final value in SidebarMenuLayout.values) {
    if (value.name == raw) return value;
  }
  return SidebarMenuLayout.list;
}

/// Menu id of the Dashboard row.
const kSidebarMenuDashboardId = 'dashboard';

/// Menu id of the Reports row.
const kSidebarMenuReportsId = 'reports';

/// Menu id of the company Activity row.
const kSidebarMenuActivityId = 'activity';

/// The three non-entity destinations in the reorderable block. Entity rows use
/// `EntityType.name` as their id instead.
///
/// These must never collide with an `EntityType` name — the two id spaces share
/// one list, so a collision would silently give one row the other's stored
/// position. Pinned by `test/domain/sidebar_menu_test.dart`.
const kSidebarMenuFixedIds = <String>[
  kSidebarMenuDashboardId,
  kSidebarMenuReportsId,
  kSidebarMenuActivityId,
];

/// One destination's preference: where it sits (its index in the list) and
/// whether it is shown at all.
///
/// Persisted as `"<id>|<1|0>"`, array order = render order — the same encoding
/// as [DashboardPanelPref], for the same reason: it survives a JSON round trip
/// with no nested objects, and a corrupt entry is droppable in isolation.
class SidebarMenuEntryPref {
  const SidebarMenuEntryPref({required this.id, this.visible = true});

  /// `EntityType.name`, or one of [kSidebarMenuFixedIds].
  final String id;
  final bool visible;

  SidebarMenuEntryPref copyWith({bool? visible}) =>
      SidebarMenuEntryPref(id: id, visible: visible ?? this.visible);

  String toJson() => '$id|${visible ? 1 : 0}';

  /// Parse a `"<id>|<1|0>"` entry. Strict: returns null unless there are
  /// exactly two parts and the visible token is exactly `0` or `1`, so a
  /// truncated `"client|"` is dropped and re-defaulted by [resolveMenuEntries]
  /// rather than silently reading as hidden — which would make an entity
  /// vanish from the menu with no way to tell why.
  static SidebarMenuEntryPref? tryParse(Object? raw) {
    if (raw is! String) return null;
    final parts = raw.split('|');
    if (parts.length != 2) return null;
    final id = parts[0];
    if (id.isEmpty) return null;
    final v = parts[1];
    if (v != '0' && v != '1') return null;
    return SidebarMenuEntryPref(id: id, visible: v == '1');
  }

  @override
  bool operator ==(Object other) =>
      other is SidebarMenuEntryPref &&
      other.id == id &&
      other.visible == visible;

  @override
  int get hashCode => Object.hash(id, visible);

  @override
  String toString() => 'SidebarMenuEntryPref($id, visible: $visible)';
}

/// The menu to render: [defaultOrder] permuted by the user's [stored]
/// preference, every entry carrying its stored `visible` flag.
///
/// Three rules, each of which fails silently if dropped:
///
///  * a stored id absent from [defaultOrder] is **dropped** — a module the
///    company turned off, or an entity removed between releases. It is dropped
///    from the *render*, never from storage, so turning the module back on
///    restores the row exactly where the user put it;
///  * a [defaultOrder] id absent from [stored] is **inserted at its default
///    index**, clamped. Without this an entity added in a later release would
///    be missing from the menu of every user who had ever customised it — and
///    they would have no way to discover it was missing. Same splice
///    `EntityColumnPickerSheet._applied` uses for a column id it can't render;
///  * the result is always the complete [defaultOrder] id set, so callers can
///    index it against their own list without a containment check.
///
/// A duplicate id in a corrupt blob keeps its first occurrence.
///
/// **The caller decides what [defaultOrder] means, and it matters.** The
/// sidebar passes only the destinations it can render (module-enabled
/// entities); the customize sheet passes every one. Writing back a list
/// resolved from the sidebar's narrower view would therefore erase the stored
/// position of every entity whose module happens to be off — which is why
/// `SidebarMenuController.setEntries` has exactly one caller.
List<SidebarMenuEntryPref> resolveMenuEntries({
  required List<String> defaultOrder,
  required List<SidebarMenuEntryPref> stored,
}) {
  if (stored.isEmpty) {
    return List.unmodifiable([
      for (final id in defaultOrder) SidebarMenuEntryPref(id: id),
    ]);
  }
  final known = defaultOrder.toSet();
  final seen = <String>{};
  final out = <SidebarMenuEntryPref>[];
  for (final entry in stored) {
    if (!known.contains(entry.id)) continue;
    if (!seen.add(entry.id)) continue;
    out.add(entry);
  }
  // Ascending, so several newly-added ids keep their relative default order.
  for (var i = 0; i < defaultOrder.length; i++) {
    final id = defaultOrder[i];
    if (!seen.add(id)) continue;
    out.insert(i.clamp(0, out.length), SidebarMenuEntryPref(id: id));
  }
  return List.unmodifiable(out);
}
