import 'package:flutter/widgets.dart';

/// Publishes whether the settings **two-pane** layout is on screen, i.e.
/// whether `SettingsListSidebar` is sitting next to the routed page.
///
/// [SettingsShell] is the only thing that can answer this — it owns the
/// `LayoutBuilder` whose width decides the split, and `Breakpoints
/// .settingsTwoPane`'s own doc warns that the sites splitting that width
/// "MUST stay in agreement", so consumers read the decision rather than
/// re-deriving it.
///
/// Consumed by the AppBar chrome: with the section list beside you a back
/// arrow is redundant (and on two-pane actively wrong — `/settings` redirects
/// straight back out to Company Details at that width), so it only appears
/// when this is false. **Absent means false**: no settings two-pane is
/// wrapping us, so no section list is on screen — which is exactly the case
/// for the one Settings destination that lives in its own branch
/// (`/settings/expense_categories`).
class SettingsTwoPaneScope extends InheritedWidget {
  const SettingsTwoPaneScope({
    super.key,
    required this.isTwoPane,
    required super.child,
  });

  final bool isTwoPane;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SettingsTwoPaneScope>()
          ?.isTwoPane ??
      false;

  @override
  bool updateShouldNotify(SettingsTwoPaneScope oldWidget) =>
      isTwoPane != oldWidget.isTwoPane;
}

/// Where a Settings destination that happens to be an **entity list** should
/// send its back arrow, or `null` when it should keep today's hamburger.
///
/// Credit Cards & Banks, Payment Links and Expense Categories are reached from
/// the Settings menu but render through `EntityListScreenScaffold`, so they
/// never see [SettingsScreenScaffold]'s chrome. Without this they were the
/// only Settings entries still showing a hamburger (issue #40).
///
/// [routePath] is the entity's **registry** route (`EntityRegistry`), not the
/// live URL: the list stays mounted while a master-detail pane floats over it,
/// so a live URL would read `/settings/expense_categories/cat_1` and point the
/// arrow at the list the user is already looking at. The registry value is also
/// static, which keeps this off the router's rebuild path.
///
/// [menuVisible] is whether `/settings` actually renders the settings menu at
/// the current width — `settingsIndexRedirect(...) == null`. Above that width
/// `/settings` redirects to Company Details, so an arrow claiming to go "back
/// to Settings" would drop the user somewhere they never were. Note this is a
/// different question from [SettingsTwoPaneScope]: Expense Categories lives in
/// its own branch and never sees that scope, so it has to ask the router's own
/// predicate instead.
///
/// Returns the route's URL-parent — `/settings/company_gateways` →
/// `/settings`. Pure so the rule is testable without a widget tree.
String? settingsBackTargetFor({
  required String routePath,
  required bool menuVisible,
}) {
  if (!menuVisible) return null;
  if (!routePath.startsWith('/settings/')) return null;
  final parent = routePath.substring(0, routePath.lastIndexOf('/'));
  return parent.isEmpty ? '/settings' : parent;
}
