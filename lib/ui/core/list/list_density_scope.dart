import 'package:flutter/widgets.dart';

import 'package:admin/app/list_density_controller.dart';

/// Publishes the device's list density (Normal / Compact) to the widget tree.
///
/// Mounted once, in `main.dart`'s `MaterialApp.builder` — above the router's
/// Navigator, so every route, dialog, sheet and master-detail pane is under
/// it. An `InheritedNotifier`, so flipping the setting rebuilds only the
/// widgets that read it (rows, list chrome), never `MaterialApp`.
///
/// With no scope above — every widget test that doesn't mount one — every
/// reader gets Normal, which is exactly what lists rendered before Compact
/// existed. `test/lint/list_row_density_wiring_test.dart` pins that `main.dart`
/// actually mounts it, since nothing else would notice a missing scope.
/// See `docs/list-density.md`.
class ListDensityScope extends InheritedNotifier<ListDensityController> {
  const ListDensityScope({
    super.key,
    required ListDensityController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Whether lists should render compact. Subscribes: call from `build`.
  static bool isCompactOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ListDensityScope>()
          ?.notifier
          ?.isCompact ??
      false;

  /// [isCompactOf] without subscribing — for code outside `build`, such as a
  /// scroll estimate computed in a callback.
  static bool isCompactRead(BuildContext context) =>
      context
          .getInheritedWidgetOfExactType<ListDensityScope>()
          ?.notifier
          ?.isCompact ??
      false;
}
