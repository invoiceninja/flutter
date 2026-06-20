import 'package:flutter/widgets.dart';

/// Builds the real (narrow) list tile for a result [item] at [index].
/// [item] is the VM's `dynamic` row; the scaffold casts it back to the
/// concrete entity type.
typedef ResultTileBuilder =
    Widget Function(BuildContext context, Object? item, int index);

/// Opens the record identified by [id].
typedef OpenRecordCallback = void Function(String id);

/// Bridges the list scaffold (which owns the per-entity tile builder and the
/// navigate-to-record action) to the narrow `FilterEntrySheet` — a pushed
/// route that can't reach the scaffold through the element tree.
///
/// The scaffold wraps its search field in this scope;
/// `TokenSearchField._openSheet` reads it (the field is under the scope) and
/// passes the closures into the sheet, which uses them to render live matching
/// results as real list tiles and to open a tapped record.
///
/// [maybeOf] is read from an event handler (sheet open), so it uses
/// `getInheritedWidgetOfExactType` — a dependency-free lookup, not
/// `dependOnInheritedWidgetOfExactType`.
class EntityListResultScope extends InheritedWidget {
  const EntityListResultScope({
    required this.resultTile,
    required this.onOpenRecord,
    required super.child,
    super.key,
  });

  final ResultTileBuilder resultTile;
  final OpenRecordCallback onOpenRecord;

  static EntityListResultScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EntityListResultScope>();

  @override
  bool updateShouldNotify(EntityListResultScope oldWidget) =>
      !identical(resultTile, oldWidget.resultTile) ||
      !identical(onOpenRecord, oldWidget.onOpenRecord);
}
