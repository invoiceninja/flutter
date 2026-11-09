import 'package:flutter/material.dart';

import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/release_notes.dart';
import 'package:admin/domain/welcome.dart';

/// The first-run Welcome's content (docs/first-run-welcome.md): one curated
/// list per [WelcomeKind], three rows at most, translated — unlike the
/// release notes, which mirror the English GitHub release. Nothing here goes
/// into `kReleaseNotes`.
///
/// The store filter is the release notes' own ([ReleaseNoteSurface]): the
/// App Store builds never name Android, Play or F-Droid, a widgets row needs
/// a platform with widgets, a keyboard row a keyboard. And never a link out.

/// What a row does when tapped.
sealed class WelcomeAction {
  const WelcomeAction();
}

/// A screen in the app, gated like the sidebar: the module, the permission,
/// and — for company settings — admin.
final class WelcomeRoute extends WelcomeAction {
  const WelcomeRoute(
    this.path, {
    this.module,
    this.permission,
    this.adminOnly = false,
  });

  final String path;
  final EntityType? module;
  final String? permission;
  final bool adminOnly;
}

/// The command palette — search everything.
final class WelcomePalette extends WelcomeAction {
  const WelcomePalette();
}

/// The phone-app promo's QR / store buttons.
final class WelcomeMobileApp extends WelcomeAction {
  const WelcomeMobileApp();
}

/// Contact us — "Still can't find it? Tell us".
final class WelcomeContactUs extends WelcomeAction {
  const WelcomeContactUs();
}

@immutable
class WelcomeItem {
  const WelcomeItem({
    required this.id,
    required this.icon,
    this.titleKey = '',
    this.titleTemplateKey,
    this.titleArgs = const {},
    this.bodyKey,
    this.touchBodyKey,
    this.action,
    this.hiddenOn = const {},
    this.showsPaletteKeys = false,
    this.hideOnTouch = false,
  });

  final String id;
  final IconData icon;

  /// A plain title. Empty when [titleTemplateKey] is set.
  final String titleKey;

  /// A title with `:placeholders`, each filled with the translation of the
  /// key [titleArgs] names for it — so a sentence can name a screen exactly
  /// as the app labels it ("use :summary and :period" → the reports'
  /// gallery names). `welcome_content_test` checks every placeholder has an
  /// argument.
  final String? titleTemplateKey;
  final Map<String, String> titleArgs;
  final String? bodyKey;

  /// The body on a touch device, where there is no shortcut to name.
  final String? touchBodyKey;
  final WelcomeAction? action;
  final Set<ReleaseNoteSurface> hiddenOn;

  /// Draws the command palette's live shortcut as key caps beside the text.
  final bool showsPaletteKeys;

  /// About a physical keyboard: left out where the pointer is a finger —
  /// a phone browser included, which [ReleaseNoteSurface.nativePhone] misses.
  final bool hideOnTouch;
}

/// The most rows one list shows. Best-in-class welcomes show three things
/// and one button.
const int kWelcomeMaxRows = 3;

/// Get started — how this app works, for someone who already invoices.
const List<WelcomeItem> kWelcomeGetStarted = [
  WelcomeItem(
    id: 'find',
    icon: Icons.search,
    titleKey: 'welcome_find_title',
    bodyKey: 'welcome_find_body',
    touchBodyKey: 'welcome_find_body_touch',
    action: WelcomePalette(),
    showsPaletteKeys: true,
  ),
  WelcomeItem(
    id: 'offline',
    icon: Icons.cloud_off_outlined,
    titleKey: 'welcome_offline_title',
    bodyKey: 'welcome_offline_body',
  ),
  WelcomeItem(
    id: 'devices',
    icon: Icons.devices_outlined,
    titleKey: 'welcome_devices_title',
    bodyKey: 'welcome_devices_body',
    action: WelcomeMobileApp(),
    // Already on a phone.
    hiddenOn: {ReleaseNoteSurface.nativePhone},
  ),
  WelcomeItem(
    id: 'yours',
    icon: Icons.palette_outlined,
    titleKey: 'welcome_yours_title',
    bodyKey: 'welcome_yours_body',
    action: WelcomeRoute('/settings/device_settings'),
  ),
];

/// What's changed — for someone coming from the previous app. Led by the
/// "All your data is already here" callout the dialog draws above it.
const List<WelcomeItem> kWelcomeWhatsChanged = [
  WelcomeItem(
    id: 'offline',
    icon: Icons.cloud_off_outlined,
    titleKey: 'welcome_offline_title',
    bodyKey: 'welcome_hl_offline_body',
  ),
  WelcomeItem(
    id: 'reports',
    icon: Icons.bar_chart_outlined,
    titleKey: 'welcome_hl_reports_title',
    bodyKey: 'welcome_hl_reports_body',
    action: WelcomeRoute('/reports', permission: 'view_reports'),
  ),
  WelcomeItem(
    id: 'designer',
    icon: Icons.dashboard_customize_outlined,
    titleKey: 'welcome_hl_designer_title',
    bodyKey: 'welcome_hl_designer_body',
    action: WelcomeRoute('/settings/invoice_design', adminOnly: true),
  ),
  // Fallbacks, for a user the three above are gated away from.
  WelcomeItem(
    id: 'tasks',
    icon: Icons.view_kanban_outlined,
    titleKey: 'welcome_hl_tasks_title',
    bodyKey: 'welcome_hl_tasks_body',
    action: WelcomeRoute('/tasks', module: EntityType.task),
  ),
  WelcomeItem(
    id: 'widgets',
    icon: Icons.widgets_outlined,
    titleKey: 'welcome_hl_widgets_title',
    bodyKey: 'welcome_hl_widgets_body',
    hiddenOn: {ReleaseNoteSurface.withoutHomeWidgets},
  ),
  WelcomeItem(
    id: 'keyboard',
    icon: Icons.keyboard_outlined,
    titleKey: 'welcome_hl_keyboard_title',
    bodyKey: 'welcome_hl_keyboard_body',
    action: WelcomeRoute('/settings/keyboard_shortcuts'),
    hiddenOn: {ReleaseNoteSurface.nativePhone},
    hideOnTouch: true,
  ),
];

/// "Can't find something?" — where the previous app's things went. Search
/// first, because it is the real answer; "Tell us" last.
const List<WelcomeItem> kWelcomeCantFind = [
  WelcomeItem(
    id: 'search',
    icon: Icons.search,
    titleKey: 'welcome_cf_search',
    touchBodyKey: 'welcome_cf_search_touch',
    action: WelcomePalette(),
    showsPaletteKeys: true,
  ),
  WelcomeItem(
    id: 'dashboard',
    icon: Icons.space_dashboard_outlined,
    titleKey: 'welcome_cf_dashboard',
  ),
  WelcomeItem(
    id: 'tax',
    icon: Icons.receipt_long_outlined,
    titleTemplateKey: 'welcome_cf_tax_reports',
    titleArgs: {'summary': 'tax_summary_report', 'period': 'tax_period_report'},
    action: WelcomeRoute('/reports', permission: 'view_reports'),
  ),
  WelcomeItem(
    id: 'tell_us',
    icon: Icons.chat_bubble_outline,
    titleKey: 'welcome_cf_tell_us',
    action: WelcomeContactUs(),
  ),
];

/// [items] as [surfaces] and this user may see them: an item hidden on one
/// of the surfaces, or whose action this user can't reach, is left out;
/// then at most [limit].
List<WelcomeItem> visibleWelcomeItems(
  List<WelcomeItem> items, {
  required Set<ReleaseNoteSurface> surfaces,
  required bool Function(WelcomeAction action) reachable,
  bool touch = false,
  int? limit = kWelcomeMaxRows,
}) {
  final out = <WelcomeItem>[];
  for (final item in items) {
    if (item.hiddenOn.any(surfaces.contains)) continue;
    if (touch && item.hideOnTouch) continue;
    final action = item.action;
    if (action != null && !reachable(action)) continue;
    out.add(item);
    if (limit != null && out.length >= limit) break;
  }
  return out;
}
