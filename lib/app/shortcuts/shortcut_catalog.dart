import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/shortcuts/key_binding.dart';
import 'package:admin/domain/entity_type.dart';

/// Where a shortcut is active. v1 makes only [global] shortcuts customizable;
/// the per-screen leaf shortcuts (list `N`/`E`, pane `F`/`J`/`K`, edit `⌘S`)
/// still live in their scaffolds as fixed `const` maps — they're enumerated
/// here for the help dialog only once migrated. Kept as an enum so the
/// controller's `activatorsFor(scope)` and the settings grouping can widen
/// later without a data-model change.
enum ShortcutScope { global }

/// Grouping in the settings screen + help dialog.
enum ShortcutGroup { general, create }

/// One entry in the shortcut catalog — the single source of truth feeding the
/// real key handling, the hold-modifier hint bar, and the `?` help dialog.
@immutable
class ShortcutDef {
  const ShortcutDef({
    required this.id,
    required this.labelKey,
    required this.group,
    required this.scope,
    this.defaultBinding,
    this.entityType,
  });

  /// Stable persistence key — stored verbatim in `nav_state`. **Never rename**
  /// (a rename orphans a user's saved override).
  final String id;

  /// Localization key for the human label.
  final String labelKey;

  final ShortcutGroup group;
  final ShortcutScope scope;

  /// The out-of-the-box binding, or null for an action that ships **unbound**
  /// (the 15 React "create X" actions — they fire only once the user assigns a
  /// key). A user override (including an explicit "cleared") layers over this in
  /// the controller.
  final KeyBinding? defaultBinding;

  /// Set for `create` actions — the shell resolves this to the entity's
  /// `newRoute` via the registry when the shortcut fires.
  final EntityType? entityType;
}

/// Stable action ids (also the persistence keys). Referenced by the shell when
/// it builds the `actionId → Intent` map for `activatorsFor`.
class ShortcutActionIds {
  static const openCompanyPicker = 'open_company_picker';
  static const openCommandPalette = 'open_command_palette';
  static const toggleSidebar = 'toggle_sidebar';
  static const openSettings = 'open_settings';
  static const openKeyboardShortcuts = 'open_keyboard_shortcuts';
  static const focusSearch = 'focus_search';

  /// Stable snake-cased id for a create action (e.g. `create_recurring_invoice`,
  /// `create_transaction`). Snake-cased so it matches the app's wire/l10n
  /// conventions and never changes — it's a persistence key.
  static String create(EntityType type) => 'create_${_snakeEntityName(type)}';
}

/// camelCase [EntityType.name] → snake_case (`recurringInvoice` →
/// `recurring_invoice`). Matches the `new_*` / `create_*` key conventions.
String _snakeEntityName(EntityType type) => type.name.replaceAllMapped(
  RegExp('[A-Z]'),
  (m) => '_${m[0]!.toLowerCase()}',
);

/// Entity types that get a "create X" shortcut, in a sensible menu order. Every
/// one must have a `newRoute` in the entity registry (verified by the shell at
/// resolve time). `document` is excluded — no standalone create route.
const List<EntityType> kCreateShortcutEntities = <EntityType>[
  EntityType.client,
  EntityType.invoice,
  EntityType.quote,
  EntityType.credit,
  EntityType.payment,
  EntityType.recurringInvoice,
  EntityType.expense,
  EntityType.recurringExpense,
  EntityType.vendor,
  EntityType.purchaseOrder,
  EntityType.product,
  EntityType.project,
  EntityType.task,
  EntityType.transaction,
];

/// Localization key for a create action's entity (`new_client`,
/// `new_recurring_invoice`, `new_transaction`, …).
String _createLabelKey(EntityType type) => 'new_${_snakeEntityName(type)}';

/// The full catalog. The 6 general shortcuts carry the app's current default
/// bindings; the create actions ship unbound (`defaultBinding: null`).
final List<ShortcutDef> kShortcutCatalog = <ShortcutDef>[
  ShortcutDef(
    id: ShortcutActionIds.openCompanyPicker,
    labelKey: 'switch_company',
    group: ShortcutGroup.general,
    scope: ShortcutScope.global,
    defaultBinding: KeyBinding.logical(
      LogicalKeyboardKey.keyK.keyId,
      usesPrimary: true,
    ),
  ),
  ShortcutDef(
    id: ShortcutActionIds.openCommandPalette,
    labelKey: 'search_everything',
    group: ShortcutGroup.general,
    scope: ShortcutScope.global,
    defaultBinding: KeyBinding.logical(
      LogicalKeyboardKey.slash.keyId,
      usesPrimary: true,
    ),
  ),
  ShortcutDef(
    id: ShortcutActionIds.toggleSidebar,
    labelKey: 'toggle_sidebar',
    group: ShortcutGroup.general,
    scope: ShortcutScope.global,
    defaultBinding: KeyBinding.logical(
      LogicalKeyboardKey.keyB.keyId,
      usesPrimary: true,
    ),
  ),
  ShortcutDef(
    id: ShortcutActionIds.openSettings,
    labelKey: 'settings',
    group: ShortcutGroup.general,
    scope: ShortcutScope.global,
    defaultBinding: KeyBinding.logical(
      LogicalKeyboardKey.comma.keyId,
      usesPrimary: true,
    ),
  ),
  const ShortcutDef(
    id: ShortcutActionIds.openKeyboardShortcuts,
    labelKey: 'keyboard_shortcuts',
    group: ShortcutGroup.general,
    scope: ShortcutScope.global,
    defaultBinding: KeyBinding.character('?'),
  ),
  const ShortcutDef(
    id: ShortcutActionIds.focusSearch,
    labelKey: 'focus_search',
    group: ShortcutGroup.general,
    scope: ShortcutScope.global,
    defaultBinding: KeyBinding.character('/'),
  ),
  for (final type in kCreateShortcutEntities)
    ShortcutDef(
      id: ShortcutActionIds.create(type),
      labelKey: _createLabelKey(type),
      group: ShortcutGroup.create,
      scope: ShortcutScope.global,
      entityType: type,
      // defaultBinding: null — ships unbound (React parity).
    ),
];

/// Lookup by action id.
final Map<String, ShortcutDef> kShortcutCatalogById = {
  for (final d in kShortcutCatalog) d.id: d,
};
