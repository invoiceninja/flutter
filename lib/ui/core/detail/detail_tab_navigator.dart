import 'package:flutter/widgets.dart';

/// Lets `EntityDetailScaffold`'s `[` / `]` shortcuts step the detail strip
/// without the scaffold knowing a strip exists.
///
/// The scaffold owns the key bindings (they share its `Shortcuts` map with
/// `E`, so one focus node serves all three) but the `TabController` lives two
/// layers down in `EntityDetailTabs`. The strip binds itself here on mount and
/// unbinds on dispose; a screen with no tabs simply never binds, and the keys
/// do nothing.
///
/// Deliberately a leaf — `flutter/widgets` only — so `entity_detail_tabs.dart`
/// can read it without importing the scaffold.
class DetailTabNavigator {
  void Function(int delta)? _step;

  /// Whether a strip is currently bound. The scaffold reads this so a key
  /// press on a tabless screen falls through instead of being swallowed.
  bool get hasTabs => _step != null;

  void bind(void Function(int delta) step) => _step = step;

  /// Only clears the binding it was handed: when a strip is replaced, the new
  /// one binds before the old one's `dispose` runs.
  void unbind(void Function(int delta) step) {
    if (_step == step) _step = null;
  }

  /// Moves [delta] tabs along the strip, clamped at both ends.
  void step(int delta) => _step?.call(delta);
}

/// Publishes the scaffold's [DetailTabNavigator] to the strip below it.
class DetailTabNavigatorScope extends InheritedWidget {
  const DetailTabNavigatorScope({
    super.key,
    required this.navigator,
    required super.child,
  });

  final DetailTabNavigator navigator;

  /// `getInheritedWidgetOfExactType`, not `dependOn…`: the navigator object
  /// never changes for the scaffold's lifetime, so there is nothing to rebuild
  /// for, and this stays legal from `initState`.
  static DetailTabNavigator? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<DetailTabNavigatorScope>()
      ?.navigator;

  @override
  bool updateShouldNotify(DetailTabNavigatorScope oldWidget) =>
      !identical(oldWidget.navigator, navigator);
}
