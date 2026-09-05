import 'package:flutter/material.dart';

import 'package:admin/domain/sidebar_menu.dart';

/// Icon + label for one of the menu's three non-entity destinations.
///
/// Entity rows get theirs from the registry (`EntityHandlers`); these have no
/// registry entry, so the table lives here — shared by `InSidebar`, which
/// renders them, and the Customize menu sheet, which lists them. Keeping it in
/// one place is the point: a sheet that showed a different icon from the rail
/// would read as a different destination.
class SidebarMenuFixedSpec {
  const SidebarMenuFixedSpec({
    required this.id,
    required this.icon,
    required this.labelKey,
  });

  final String id;
  final IconData icon;
  final String labelKey;
}

const kSidebarMenuDashboardSpec = SidebarMenuFixedSpec(
  id: kSidebarMenuDashboardId,
  icon: Icons.dashboard_outlined,
  labelKey: 'dashboard',
);

const kSidebarMenuReportsSpec = SidebarMenuFixedSpec(
  id: kSidebarMenuReportsId,
  icon: Icons.bar_chart_outlined,
  labelKey: 'reports',
);

const kSidebarMenuActivitySpec = SidebarMenuFixedSpec(
  id: kSidebarMenuActivityId,
  // Deliberately filled where the other rows are outlined: this is the
  // workspace-level Activity branch, not a detail tab. (The detail tabs all
  // use `Icons.history_outlined`, which does exist — an older version of this
  // comment claimed otherwise.)
  icon: Icons.history,
  labelKey: 'activity',
);

/// The three fixed destinations, in the app's default order relative to the
/// entity block: Dashboard leads it, Reports and Activity trail it.
const kSidebarMenuFixedSpecs = <SidebarMenuFixedSpec>[
  kSidebarMenuDashboardSpec,
  kSidebarMenuReportsSpec,
  kSidebarMenuActivitySpec,
];

/// The spec for [id], or null when [id] names an entity rather than one of the
/// fixed rows.
SidebarMenuFixedSpec? sidebarMenuFixedSpec(String id) {
  for (final spec in kSidebarMenuFixedSpecs) {
    if (spec.id == id) return spec;
  }
  return null;
}
