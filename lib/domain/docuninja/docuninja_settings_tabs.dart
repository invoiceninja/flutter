/// DocuNinja's settings tabs as sub-routes, as React's are
/// (`/docuninja/settings/<tab>`, `routes.tsx` and `useSettingsTabs.tsx`).
/// A leaf: the router, the deep-link parser, the restart restore and the
/// screen all read it. docs/docuninja.md § Settings.
library;

/// The settings page; it redirects to [kDocuNinjaSettingsDefaultTab].
const String kDocuNinjaSettingsRoute = '/docuninja/settings';

/// React's tab order (`useSettingsTabs`), by URL slug.
const List<String> kDocuNinjaSettingsTabs = [
  'email_settings',
  'email_templates',
  'notifications',
  'widget_defaults',
  'reminder_schedules',
];

/// React's index route (`<Navigate to="email_templates" />`).
const String kDocuNinjaSettingsDefaultTab = 'email_templates';

/// The location of [tab]'s page.
String docuNinjaSettingsTabPath(String tab) => '$kDocuNinjaSettingsRoute/$tab';

/// The tab [path] names (`/docuninja/settings/<tab>`), or null when it is
/// not a settings tab's page.
String? docuNinjaSettingsTabOf(String path) {
  const prefix = '$kDocuNinjaSettingsRoute/';
  if (!path.startsWith(prefix)) return null;
  final tab = path.substring(prefix.length);
  return kDocuNinjaSettingsTabs.contains(tab) ? tab : null;
}
