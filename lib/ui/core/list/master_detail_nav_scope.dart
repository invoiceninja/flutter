import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Lightweight shared state between `MasterDetailLayout` and the list
/// scaffold mounted inside it. The list scaffold writes the visible
/// item ids + the URL-derived `selectedId` here on every rebuild; the
/// pane's keyboard shortcuts (`J` / `K` / `↓` / `↑`) read it to compute
/// the next / previous row to navigate to, and the detail pane reads
/// [itemById] for a synchronous first-frame seed.
///
/// Why a controller instead of a callback: the layout doesn't have
/// access to the list's VM (the list is an opaque widget), and the
/// scaffold doesn't know about the layout's keyboard handlers. A
/// shared object pushed into the InheritedWidget tree lets each side
/// touch only what it needs.
///
/// Deliberately a leaf: `flutter/widgets` + `go_router` only, so
/// `entity_detail_tabs.dart` can read the tab memory without pulling
/// `Services` / provider / the whole 1000-line layout into its graph.
/// (`entity_detail_scaffold.dart` reads this too but gains nothing from the
/// split — it already imports `master_detail_layout.dart` for
/// `MasterDetailPaneScope`.) `master_detail_layout.dart` re-exports both
/// classes, so existing imports are unchanged.
class MasterDetailNavController {
  String? _selectedId;
  List<String> _itemIds = const <String>[];
  List<Object?> _items = const <Object?>[];

  /// Animated close hook bound by the layout's State in `initState`.
  /// Called by list tiles via [MasterDetailNavScope.requestClose] so
  /// row-click-deselect plays the same slide-out as the X button —
  /// the URL only changes after the reverse animation finishes.
  Future<void> Function()? closePane;

  /// The tab the user last selected on this entity's detail pane, so clicking
  /// through rows doesn't snap back to the first tab every time. Session-only
  /// and per entity branch (this controller lives with the `MasterDetailLayout`
  /// State) — deliberately not persisted to `nav_state`.
  ///
  /// The count rides along because an index only means the same tab while the
  /// strip has the same shape. Most conditional tabs are module- or
  /// permission-gated (constant for the session), but the invoice pane gates
  /// one on `invoiceSupportsPaymentSchedule` — **per record**. Restoring an
  /// index across a count change would clamp 5 → 4 and silently land the user
  /// on a tab they weren't reading, so a mismatch declines to restore instead.
  ({int index, int count})? lastTab;

  /// [items] is index-aligned with [itemIds] — both are built by the list
  /// scaffold from one pass over its VM with the same visibility predicate.
  /// It defaults to empty so a caller that only cares about J/K navigation
  /// (and any test double) keeps compiling.
  void update({
    required String? selectedId,
    required List<String> itemIds,
    List<Object?> items = const <Object?>[],
  }) {
    _selectedId = selectedId;
    _itemIds = itemIds;
    _items = items;
  }

  /// The visible domain object for [id] from the list's most recent
  /// snapshot, or null when the list has never rendered that row (deep
  /// link, command palette, cold start — those keep the pane's spinner).
  ///
  /// Typed `Object?` because `GenericListViewModel<T>` has no `Object`
  /// bound; the caller does an `is T` test rather than a cast that could
  /// throw. Linear scan on purpose — it runs once per row click, which is
  /// cheaper than allocating a map on every list rebuild.
  Object? itemById(String id) {
    final i = _itemIds.indexOf(id);
    return (i < 0 || i >= _items.length) ? null : _items[i];
  }

  String? nextId() {
    if (_itemIds.isEmpty) return null;
    if (_selectedId == null) return _itemIds.first;
    final i = _itemIds.indexOf(_selectedId!);
    if (i < 0 || i >= _itemIds.length - 1) return null;
    return _itemIds[i + 1];
  }

  String? prevId() {
    if (_itemIds.isEmpty) return null;
    if (_selectedId == null) return _itemIds.last;
    final i = _itemIds.indexOf(_selectedId!);
    if (i <= 0) return null;
    return _itemIds[i - 1];
  }
}

/// InheritedWidget that publishes the layout's
/// [MasterDetailNavController] to descendants without triggering
/// rebuilds — descendants read the controller object once and call
/// methods on it; the controller's internal state isn't observable
/// (the keyboard handlers don't need to react to changes, they just
/// need the latest value at key-press time).
class MasterDetailNavScope extends InheritedWidget {
  const MasterDetailNavScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final MasterDetailNavController controller;

  /// Registers no dependency, so this is legal from `initState` — which is
  /// where the detail pane reads its seed.
  static MasterDetailNavController? maybeOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MasterDetailNavScope>();
    return scope?.controller;
  }

  /// Close the pane from a descendant (e.g. a list tile's
  /// click-to-deselect). Runs the layout's animated close when hosted
  /// inside a master-detail pane; falls back to plain
  /// `GoRouter.go(basePath)` otherwise (narrow viewports, tests).
  static void requestClose(BuildContext context, {required String basePath}) {
    final close = maybeOf(context)?.closePane;
    if (close != null) {
      close();
    } else {
      GoRouter.of(context).go(basePath);
    }
  }

  // Marker only — descendants treat the controller as a stable ref.
  @override
  bool updateShouldNotify(MasterDetailNavScope oldWidget) =>
      controller != oldWidget.controller;
}
