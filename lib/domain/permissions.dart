/// Permission grid constants for the User Management Permissions tab.
///
/// The server stores permissions as a comma-separated string on
/// `company_user.permissions` (e.g. `view_client,edit_invoice,create_all`).
/// The 14 entity rows × 3 verb columns combine into `<verb>_<entity>` tokens;
/// the "All" row uses `<verb>_all`; three special-case toggles live above
/// the grid.
///
/// When `is_admin = true`, the permissions string is empty and every grid
/// cell is implicitly granted. The edit ViewModel preserves a draft buffer
/// so flipping admin off restores the previous selection in-session.
library;

/// Entities that appear as rows in the permission grid. Order matches React's
/// `pages/settings/users/edit/components/Permissions.tsx`.
const List<String> kPermissionEntities = <String>[
  'client',
  'product',
  'invoice',
  'payment',
  'recurring_invoice',
  'quote',
  'credit',
  'project',
  'task',
  'vendor',
  'expense',
  'bank_transaction',
  'purchase_order',
  'recurring_expense',
];

/// Verb columns. Mirrors React. Order is preserved on the wire.
const List<String> kPermissionVerbs = <String>['create', 'view', 'edit'];

/// Special toggles rendered *above* the grid (per React layout).
const List<String> kPermissionSpecial = <String>[
  'view_dashboard',
  'view_reports',
  'disable_emails',
];

/// Localization key for each special toggle's title. `view_reports` has no
/// string of its own in any locale bundle — React labels that row `reports` —
/// so without this map `context.tr` falls through to the raw slug.
const Map<String, String> kPermissionSpecialLabels = <String, String>{
  'view_dashboard': 'view_dashboard',
  'view_reports': 'reports',
  'disable_emails': 'disable_emails',
};

/// Localization key for each special toggle's subtitle, mirroring React's
/// `leftSideHelp`. `view_dashboard` has none there.
const Map<String, String> kPermissionSpecialHelp = <String, String>{
  'view_reports': 'view_report_permission',
  'disable_emails': 'disable_emails_help',
};

/// Tokens whose presence *removes* an ability rather than granting one.
/// Admins are never subject to them, so such a row reads OFF instead of
/// inheriting the blanket admin grant.
const Set<String> kPermissionNegative = <String>{'disable_emails'};

/// Cell token for an entity-verb pair (`create_client`, `view_invoice`, …).
String permissionToken({required String verb, required String entity}) =>
    '${verb}_$entity';

/// "All" row token (`create_all` / `view_all` / `edit_all`).
String permissionAllToken(String verb) => '${verb}_all';

/// Next permission list after toggling the "All" checkbox for [verb].
///
/// Turning it on drops the now-redundant per-entity tokens for that verb and
/// adds `<verb>_all`; turning it off just removes `<verb>_all`. Tokens for
/// other verbs and any unmodeled tokens are preserved untouched.
List<String> permissionsAfterToggleAll({
  required List<String> current,
  required String verb,
  required bool checked,
}) {
  final next = List<String>.of(current)..remove(permissionAllToken(verb));
  if (checked) {
    for (final entity in kPermissionEntities) {
      next.remove(permissionToken(verb: verb, entity: entity));
    }
    next.add(permissionAllToken(verb));
  }
  return next;
}

/// Next permission list after toggling a single `(verb, entity)` cell, plus
/// whether the change auto-promoted the column to `<verb>_all`.
///
///  * Checking the last unchecked cell in a column collapses the 14 explicit
///    tokens to `<verb>_all` (auto-promote; `promoted == true`).
///  * Unchecking a cell while `<verb>_all` is set expands the column to the
///    other 13 explicit tokens — "all except this one" in one click (React
///    parity).
///
/// Tokens for other verbs and any unmodeled tokens are preserved.
({List<String> permissions, bool promoted}) permissionsAfterToggleCell({
  required List<String> current,
  required String verb,
  required String entity,
  required bool checked,
}) {
  final next = List<String>.of(current);
  final token = permissionToken(verb: verb, entity: entity);
  final allToken = permissionAllToken(verb);
  var promoted = false;
  if (checked) {
    if (!next.contains(token)) next.add(token);
    final everyEntityChecked = kPermissionEntities.every(
      (e) => next.contains(permissionToken(verb: verb, entity: e)),
    );
    if (everyEntityChecked) {
      for (final e in kPermissionEntities) {
        next.remove(permissionToken(verb: verb, entity: e));
      }
      next.add(allToken);
      promoted = true;
    }
  } else if (next.contains(allToken)) {
    next.remove(allToken);
    for (final e in kPermissionEntities) {
      if (e != entity) next.add(permissionToken(verb: verb, entity: e));
    }
  } else {
    next.remove(token);
  }
  return (permissions: next, promoted: promoted);
}
