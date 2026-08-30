import 'package:flutter/material.dart';

import 'package:admin/app/mdi_icons.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';

/// Standard [EntityActionItem] factories — the universal Edit / Archive /
/// Restore / Delete / Purge actions every entity exposes. Each entity's
/// `<Entity>Actions.itemsFor()` composes from these + its entity-specific
/// extras, so the icon, label key, and `isPrimary` / `enabled` defaults
/// stay consistent across entities.
///
/// `archive` and `restore` return null when the entity isn't in the right
/// state — the caller spreads the conditional with `?...` rather than
/// repeating an `if (canArchive)` per entity.
///
/// Archive / Delete / Purge are tagged `confirm: true` here, so every entity
/// inherits the "Are you sure?" gate (see `EntityActionItem.confirm`) without
/// restating it. Pass `subject:` — the record's display label — so the prompt
/// can say which row it's about.

/// Primary "Edit" action. Renders as the `FilledButton` in the row.
EntityActionItem<A> editActionItem<A>({
  required BuildContext context,
  required A kind,
  required VoidCallback onTap,
  bool isPrimary = true,
}) => EntityActionItem(
  kind: kind,
  icon: MdiIcons.circleEditOutline,
  label: context.tr('edit'),
  enabled: true,
  isPrimary: isPrimary,
  onTap: onTap,
);

/// Archive action. Returns null when the entity is already archived or
/// soft-deleted — caller must check the right preconditions.
EntityActionItem<A>? archiveActionItem<A>({
  required BuildContext context,
  required A kind,
  required bool canArchive,
  required VoidCallback onTap,
  String? subject,
}) {
  if (!canArchive) return null;
  return EntityActionItem(
    kind: kind,
    icon: Icons.archive_outlined,
    label: context.tr('archive'),
    enabled: true,
    isLifecycle: true,
    // Reversible (the toast offers Undo), so not `isDestructive` — but still
    // confirmed: archiving by accident is the exact complaint in #49.
    confirm: true,
    confirmSubject: subject,
    onTap: onTap,
  );
}

/// Restore action. Returns null when the entity is in a fresh / live state.
EntityActionItem<A>? restoreActionItem<A>({
  required BuildContext context,
  required A kind,
  required bool canRestore,
  required VoidCallback onTap,
}) {
  if (!canRestore) return null;
  return EntityActionItem(
    kind: kind,
    icon: Icons.unarchive_outlined,
    label: context.tr('restore'),
    enabled: true,
    isLifecycle: true,
    onTap: onTap,
  );
}

/// Delete action. Returns null when the entity is already soft-deleted
/// (Restore is the correct action in that state, not another Delete).
EntityActionItem<A>? deleteActionItem<A>({
  required BuildContext context,
  required A kind,
  required bool canDelete,
  required VoidCallback onTap,
  String? subject,
}) {
  if (!canDelete) return null;
  return EntityActionItem(
    kind: kind,
    icon: Icons.delete_outline,
    label: context.tr('delete'),
    enabled: true,
    isLifecycle: true,
    confirm: true,
    isDestructive: true,
    confirmSubject: subject,
    onTap: onTap,
  );
}

/// Purge action. Permanently destroys the entity and every related
/// record. Returns null when the user lacks permission ([canPurge] is
/// false), hiding the menu item entirely — matches React's
/// `isAdmin || isOwner` gate.
EntityActionItem<A>? purgeActionItem<A>({
  required BuildContext context,
  required A kind,
  required bool canPurge,
  required VoidCallback onTap,
  String? subject,
  bool confirm = true,
}) {
  if (!canPurge) return null;
  return EntityActionItem(
    kind: kind,
    icon: Icons.delete_forever_outlined,
    label: context.tr('purge'),
    enabled: true,
    isLifecycle: true,
    // `confirm: false` for the one caller (Client) whose dispatch already
    // opens a stronger bespoke warning — two prompts is worse than one.
    confirm: confirm,
    isDestructive: true,
    confirmSubject: subject,
    onTap: onTap,
  );
}

/// "Clone" group parent. Collapses an entity's several clone variants
/// (Clone, Clone to Invoice/Quote/Credit/PO/Recurring) into one
/// fly-out submenu so they stop burying the rest of the actions menu.
/// The parent is never dispatched — selecting a [children] leaf invokes
/// that child's own `onTap`.
EntityActionItem<A> cloneGroupActionItem<A>({
  required BuildContext context,
  required A kind,
  required List<EntityActionItem<A>> children,
}) => EntityActionItem(
  kind: kind,
  icon: Icons.copy_outlined,
  label: context.tr('clone'),
  enabled: children.any((c) => c.enabled),
  children: children,
);

/// "New" group parent. Collapses an entity's "create related record"
/// variants (New Invoice / Quote / Payment / Task / Expense) into one
/// fly-out submenu so they stop burying the rest of the actions menu.
/// The parent is never dispatched — selecting a [children] leaf invokes
/// that child's own `onTap`.
EntityActionItem<A> newGroupActionItem<A>({
  required BuildContext context,
  required A kind,
  required List<EntityActionItem<A>> children,
}) => EntityActionItem(
  kind: kind,
  icon: Icons.add_circle_outline,
  label: context.tr('create_new'),
  enabled: children.any((c) => c.enabled),
  children: children,
);

/// "PDF" group parent. Collapses View / Download / Print PDF (and, for
/// invoices, Delivery Note) into one fly-out submenu so they stop burying
/// the rest of the actions menu. The parent is never dispatched —
/// selecting a [children] leaf invokes that child's own `onTap`.
EntityActionItem<A> pdfGroupActionItem<A>({
  required BuildContext context,
  required A kind,
  required List<EntityActionItem<A>> children,
}) => EntityActionItem(
  kind: kind,
  icon: Icons.picture_as_pdf_outlined,
  label: context.tr('pdf'),
  enabled: children.any((c) => c.enabled),
  children: children,
);

/// "Copy Link" — puts a shareable `invoiceninja://` deep link to this record
/// on the clipboard, so a colleague can open it straight on the record
/// instead of being told an id to search for (invoiceninja/flutter#96).
///
/// Returns null — i.e. the item doesn't exist — for a record that has no
/// shareable identity: a create form (empty id) or an offline create still
/// carrying a `tmp_` id, which resolves to nothing on anyone else's device.
///
/// Not `isLifecycle`, so `menuChildrenFor`'s auto-divider leaves it at the
/// bottom of the normal-actions group rather than beside Archive/Delete; and
/// deliberately not `confirm`, which CLAUDE.md reserves for mutations.
EntityActionItem<A>? copyLinkActionItem<A>({
  required BuildContext context,
  required A kind,
  required String entityId,
  required VoidCallback onTap,
}) {
  if (entityId.isEmpty || entityId.startsWith('tmp_')) return null;
  return EntityActionItem(
    kind: kind,
    // `Icons.link`, not `Icons.copy_outlined` — that one is Clone's.
    icon: Icons.link,
    label: context.tr('copy_link'),
    enabled: true,
    onTap: onTap,
  );
}
