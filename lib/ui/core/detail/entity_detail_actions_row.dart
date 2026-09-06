import 'package:flutter/material.dart';
import 'package:overflow_view/overflow_view.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
// Deliberate import cycle: the dialog needs [EntityActionItem] to read its
// `confirm*` fields, and this file needs `guardedOnTap`. Legal Dart, and
// breaking it would mean extracting the model to its own file plus rewriting
// the import line in ~20 call sites — more churn than the smell is worth.
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';

/// One row item in an [EntityDetailActionsRow].
///
/// Whichever item carries `isPrimary: true` renders as a `FilledButton`
/// (Edit, by convention). An item with `enabled: false` is **hidden** —
/// an action that isn't supported in the current context (e.g. "Refund
/// Payment" while creating a new invoice) simply doesn't appear, rather
/// than rendering greyed-out with a misleading "Coming soon" hint.
///
/// The one exception: a transient/busy disable (e.g. a button greyed only
/// while a bulk op is in flight) passes `disabledTooltipKey: null`, which
/// keeps the item visible-but-inert so it doesn't flicker out and back
/// mid-operation. So an item renders iff
/// `enabled || disabledTooltipKey == null` ([isVisible]).
class EntityActionItem<A> {
  const EntityActionItem({
    required this.kind,
    required this.icon,
    required this.label,
    required this.enabled,
    this.isPrimary = false,
    this.onTap,
    this.children,
    this.disabledTooltipKey = 'coming_soon',
    this.isLifecycle = false,
    this.confirm = false,
    this.isDestructive = false,
    this.confirmMessageKey,
    this.confirmSubject,
  });

  final A kind;
  final IconData icon;
  final String label;
  final bool enabled;
  final bool isPrimary;
  final VoidCallback? onTap;

  /// True for the universal lifecycle actions (Archive / Restore / Delete /
  /// Purge), set only by the standard factories in
  /// `standard_entity_action_items.dart`. [menuChildrenFor] auto-inserts a
  /// single divider before the first visible lifecycle item so the
  /// destructive group reads as separate from the entity-specific actions
  /// above it.
  final bool isLifecycle;

  /// Gate this action behind an "Are you sure?" dialog when the user has
  /// **Confirm actions** on (Settings → Device Settings → Security; on by
  /// default — invoiceninja/flutter#49).
  ///
  /// Set it for a verb that (a) fires a mutation immediately with no further
  /// UI step and (b) is outward-facing, financially significant, or hard to
  /// reverse: Approve, Mark Sent, Cancel, Send Now, Auto Bill, Archive,
  /// Delete, Purge… Do **not** set it for an action that already opens its own
  /// dialog (invoice Mark Paid, client Merge) or navigates to a screen with
  /// its own action button (Send Email, Refund) — a second prompt in front of
  /// those is worse than none. Bulk-toolbar items stay untagged too;
  /// `EntityListScreenScaffold._onBulk` owns that gate.
  ///
  /// The dialog is wired by `guardedOnTap`, not here.
  final bool confirm;

  /// Renders the confirm button in the error colour. Only for verbs that
  /// destroy data (Delete / Purge), not for reversible ones like Archive.
  final bool isDestructive;

  /// Localization key for a message more precise than the default
  /// `are_you_sure` — e.g. `confirm_recurring_email_invoice` ("Are you sure
  /// you want this invoice emailed?") on recurring Send Now. Prefer an
  /// existing Transifex key over inventing app-local copy.
  final String? confirmMessageKey;

  /// The record the action will hit, as a display label ("Acme Corp",
  /// "#0012"). Rendered under the message so a prompt fired from a long list
  /// says *which* row it's about.
  final String? confirmSubject;

  /// Controls how a disabled (`enabled: false`) item is treated.
  ///
  /// Non-null (default `coming_soon`): the item is **hidden** — an action
  /// unsupported in the current context just doesn't appear. Pass `null`
  /// for a transient/busy disable (e.g. greyed only while a bulk op is in
  /// flight): the item stays **visible-but-inert** so it doesn't flicker
  /// out and back mid-operation. See [isVisible].
  final String? disabledTooltipKey;

  /// When non-null, this item is a parent group: it renders as a
  /// `SubmenuButton` whose fly-out lists [children] (e.g. the "Clone"
  /// group over the various clone / clone-to targets). `onTap` is ignored
  /// for parent items — selecting a leaf child invokes its own `onTap`.
  final List<EntityActionItem<A>>? children;

  bool get hasChildren => children != null && children!.isNotEmpty;

  /// Whether this item is rendered at all. An unsupported action
  /// (`enabled: false` with a non-null [disabledTooltipKey]) is hidden;
  /// only enabled items and transient-busy ones (`disabledTooltipKey ==
  /// null`) appear. A parent group whose children are all hidden resolves
  /// `enabled: false` (see `standard_entity_action_items`) and is dropped
  /// here too, so no empty submenu is left behind.
  bool get isVisible => enabled || disabledTooltipKey == null;

  /// Maps [items] to the `MenuAnchor` child widgets shared by both menu
  /// surfaces (the detail-header overflow [_MoreMenu] and the list-row
  /// `EntityActionsPopupButton`) so they always agree on styling,
  /// hide-when-unsupported behavior, and submenu nesting. Recurses into
  /// [children] to render nested fly-out submenus.
  static List<Widget> menuChildrenFor<A>(
    BuildContext context,
    List<EntityActionItem<A>> items,
  ) {
    // Auto-divider: emit one separator before the first visible lifecycle
    // item (Archive/Restore/Delete/Purge), but only if a visible
    // non-lifecycle item preceded it in this pass. That single guard also
    // suppresses a stray leading divider when the slice is lifecycle-only
    // (e.g. an overflow "More" menu whose hidden tail is all lifecycle).
    final children = <Widget>[];
    var sawNonLifecycle = false;
    var dividerEmitted = false;
    for (final item in items) {
      if (!item.isVisible) continue;
      if (item.isLifecycle) {
        if (sawNonLifecycle && !dividerEmitted) {
          children.add(Divider(height: 9, color: context.inTheme.border));
          dividerEmitted = true;
        }
      } else {
        sawNonLifecycle = true;
      }
      if (item.hasChildren) {
        children.add(
          SubmenuButton(
            leadingIcon: Icon(item.icon, size: 18),
            menuChildren: menuChildrenFor<A>(context, item.children!),
            child: Text(item.label),
          ),
        );
      } else if (item.enabled) {
        children.add(
          MenuItemButton(
            leadingIcon: Icon(item.icon, size: 18),
            onPressed: guardedOnTap<A>(context, item),
            child: Text(item.label),
          ),
        );
      } else {
        // Only reachable for a transient-busy disable
        // (disabledTooltipKey == null); no tooltip by design.
        children.add(
          MenuItemButton(
            leadingIcon: Icon(item.icon, size: 18),
            onPressed: null,
            child: Text(item.label),
          ),
        );
      }
    }
    return children;
  }
}

/// Lets the edit-screen header tell its [EntityOverflowActionBar] whether to
/// render the wide spread bar or the compact `⋮`, based on the **full header
/// width**. The bar's own slot can't be trusted for this: in the wide layout it
/// sits in the post-title `Expanded`, which under-reports the width once the
/// title takes its share (between 600 and ~892 px the slot is < 600 even though
/// the screen is plainly wide). Absent in detail / multi-select contexts, where
/// the bar owns the full slot and falls back to its own [LayoutBuilder].
class ActionBarLayoutScope extends InheritedWidget {
  const ActionBarLayoutScope({
    super.key,
    required this.wide,
    required super.child,
  });

  final bool wide;

  static bool? maybeWideOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ActionBarLayoutScope>()?.wide;

  @override
  bool updateShouldNotify(ActionBarLayoutScope oldWidget) =>
      oldWidget.wide != wide;
}

/// The overflow-aware button cluster shared by the edit-screen action bar (the
/// Save button forwarded as [leading] + the edit-screen actions) and the
/// list-screen multi-select AppBar. The caller owns outer sizing / alignment —
/// this widget just lays the cluster out at its natural width.
///
/// **Width-aware when it has a pinned [leading]** (Save / Edit): wide → visible
/// buttons spread left-to-right, the tail collapsing into a labeled "More"
/// menu; narrow → the compact form, just [leading] + a single `⋮` holding every
/// action — identical to the entity detail header's narrow cluster. The decision
/// comes from an enclosing [ActionBarLayoutScope] when present (the edit header
/// supplies it from its full width), otherwise from a local [LayoutBuilder]
/// (detail-wide, where the bar owns the whole title slot).
///
/// With **no [leading]** (the multi-select bulk bar) it stays the spread bar at
/// every width — a locked design (see `EntityListSelectionAppBar`).
///
/// (Entity *detail* headers use [EntityDetailActionsRow], which reuses this bar
/// when wide — Edit forwarded as [leading] — and renders its own compact `⋮`
/// cluster when narrow; see there.)
class EntityOverflowActionBar<A> extends StatelessWidget {
  const EntityOverflowActionBar({super.key, required this.items, this.leading});

  final List<EntityActionItem<A>> items;

  /// Optional widget rendered as the first child of the cluster (the edit
  /// screen's Save button). It must be a plain button — NO `Tooltip` /
  /// `AnimatedSize` / `OverlayPortal` — because `OverflowView` lays its
  /// children out inside a layout callback (see the Save-button comment in
  /// `entity_edit_scaffold.dart`). It is laid out before [items] so the
  /// `OverflowView` — which collapses from the *end* — never hides it; every
  /// hidden child is therefore still a trailing [items] entry, keeping the
  /// `remaining`→`hidden` slice below correct.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    // Drop unsupported actions up front so the visible cluster and the
    // `remaining`→`hidden` overflow slice both index the same list — the
    // hidden-count math below depends on that.
    final shown = [
      for (final item in items)
        if (item.isVisible) item,
    ];

    // Wide: visible buttons left-to-right, the tail collapsing into a labeled
    // "More" menu. `OverflowView` never RenderFlex-overflows in a tight slot
    // (it collapses gracefully) — the property the edit-screen header relies on.
    Widget spreadBar() => OverflowView.flexible(
      spacing: 8,
      children: [
        if (leading != null) leading!,
        for (final item in shown) _ActionButton<A>(item: item),
      ],
      builder: (context, remaining) {
        // `remaining` counts hidden children from the end of the full
        // children list (which includes [leading] at index 0). When the
        // bar is so tight even `leading` would collapse, `remaining` can
        // reach `shown.length + 1`; clamp so the slice never goes negative.
        final hiddenCount = remaining > shown.length ? shown.length : remaining;
        final hidden = shown.sublist(shown.length - hiddenCount);
        return _MoreMenu<A>(items: hidden);
      },
    );

    // Narrow: the pinned [leading] (Save / Edit) + a single compact `⋮` holding
    // every action — mirrors `EntityDetailActionsRow`'s narrow cluster. A plain
    // Row, NOT measured inside `OverflowView`'s layout callback, so the `⋮`
    // IconButton's Tooltip is safe here (the OverlayPortal hazard only bites
    // OverflowView children).
    Widget compactBar() => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading!,
        if (shown.isNotEmpty) SizedBox(width: InSpacing.md(context)),
        if (shown.isNotEmpty) _OverflowMenuButton<A>(items: shown),
      ],
    );

    // No pinned leading (the multi-select bulk bar) → always the spread bar.
    if (leading == null) return spreadBar();

    // Prefer the edit header's full-width decision; fall back to local
    // constraints in the detail-wide context (where the bar owns the whole
    // title slot, so the slot width is accurate).
    final scopeWide = ActionBarLayoutScope.maybeWideOf(context);
    if (scopeWide != null) return scopeWide ? spreadBar() : compactBar();
    return LayoutBuilder(
      builder: (context, constraints) =>
          Breakpoints.isWide(constraints) ? spreadBar() : compactBar(),
    );
  }
}

/// The detail-header action cluster shared by every entity detail screen.
/// Per-entity wrappers (e.g. `VendorDetailActionsRow`) only contribute the
/// action enum and the [EntityActionItem] list.
///
/// Layout is **width-gated** on the allocated width (`Breakpoints.isWide`,
/// measured via the [LayoutBuilder] so it reflects the title slot / pane the
/// row was handed, not the device size):
///
///  * **Wide** (full-screen detail, or a slide-over pane expanded to full
///    width) → reuses [EntityOverflowActionBar] with the primary **Edit**
///    pinned as `leading`: as many of the remaining actions as fit spread
///    inline, the rest collapse into a labeled "More" menu — identical to the
///    edit-screen bar.
///  * **Narrow** (mobile, or the half-width master-detail / slide-over pane) →
///    the compact form: the primary **Edit** as a dedicated button followed by
///    a single `⋮` menu holding every *other* action.
///
/// Degenerate cases (both widths): a soft-deleted record (no `isPrimary` item)
/// drops the Edit button — wide spreads its lifecycle actions inline + "More",
/// narrow shows just the `⋮`; a record whose only action is Edit shows just the
/// Edit button (the overflow trigger is suppressed when it would be empty).
class EntityDetailActionsRow<A> extends StatelessWidget {
  const EntityDetailActionsRow({super.key, required this.items});

  final List<EntityActionItem<A>> items;

  @override
  Widget build(BuildContext context) {
    final visible = [
      for (final item in items)
        if (item.isVisible) item,
    ];
    final primaryIndex = visible.indexWhere((item) => item.isPrimary);
    final primary = primaryIndex == -1 ? null : visible[primaryIndex];
    // Everything that isn't the surfaced primary. (When there's no primary,
    // `primaryIndex` is -1 and every item is kept.)
    final rest = [
      for (var i = 0; i < visible.length; i++)
        if (i != primaryIndex) visible[i],
    ];

    // The AppBar's title slot (and the embedded pane's Expanded) pass loose
    // constraints (minWidth: 0), so the row hugs its content by default.
    // SizedBox(width: infinity) forces it to fill the slot; Align then pushes
    // the cluster to the right edge, matching the body's right padding via the
    // scaffold's titleSpacing: InSpacing.lg(context). The LayoutBuilder's
    // constraints reflect that same allocated width — wide ⇒ the spread overflow
    // bar, narrow ⇒ the compact `⋮` (mobile + master-detail/slide-over pane).
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = Breakpoints.isWide(constraints);
        return SizedBox(
          width: double.infinity,
          child: Align(
            alignment: Alignment.centerRight,
            child: wide
                // Pin Edit as `leading` (a plain enabled FilledButton — never
                // collapses, like Save on the edit bar); the rest spread inline
                // and overflow into "More".
                ? EntityOverflowActionBar<A>(
                    leading: primary == null
                        ? null
                        : _ActionButton<A>(item: primary),
                    items: rest,
                  )
                // Compact: Edit + a single `⋮` holding every other action.
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (primary != null) _ActionButton<A>(item: primary),
                      if (primary != null && rest.isNotEmpty)
                        SizedBox(width: InSpacing.md(context)),
                      if (rest.isNotEmpty) _OverflowMenuButton<A>(items: rest),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _ActionButton<A> extends StatelessWidget {
  const _ActionButton({required this.item});
  final EntityActionItem<A> item;

  @override
  Widget build(BuildContext context) {
    // Group parent (e.g. "Clone"): there's no single action to fire, so
    // render a MenuAnchor that opens the same fly-out the overflow "More"
    // menu would. Without this a visible (non-overflowed) group would be a
    // dead button — `onTap` is null on a group item.
    if (item.hasChildren) {
      return MenuAnchor(
        consumeOutsideTap: true,
        menuChildren: EntityActionItem.menuChildrenFor<A>(
          context,
          item.children!,
        ),
        builder: (context, controller, _) => OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          icon: Icon(item.icon, size: 18),
          label: Text(item.label),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      );
    }
    final Widget button = item.isPrimary
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            icon: Icon(item.icon, size: 18),
            label: Text(item.label),
            onPressed: item.enabled ? guardedOnTap<A>(context, item) : null,
          )
        : OutlinedButton.icon(
            // CLAUDE.md: OutlinedButton inside a Row must override the
            // theme's Size.fromHeight(40) default, otherwise the infinite
            // minWidth crashes the surrounding Row layout.
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            icon: Icon(item.icon, size: 18),
            label: Text(item.label),
            onPressed: item.enabled ? guardedOnTap<A>(context, item) : null,
          );
    if (item.enabled || item.disabledTooltipKey == null) return button;
    return Tooltip(
      message: context.tr(item.disabledTooltipKey!),
      child: button,
    );
  }
}

class _MoreMenu<A> extends StatelessWidget {
  const _MoreMenu({required this.items});
  final List<EntityActionItem<A>> items;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      consumeOutsideTap: true,
      menuChildren: EntityActionItem.menuChildrenFor<A>(context, items),
      // Trigger styled as an OutlinedButton so it sits flush with the
      // other action buttons (same height, border, padding). The `⋮` beside a
      // label is deliberate and app-wide — CLAUDE.md § Design system (v2).
      builder: (context, controller, _) => OutlinedButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
        icon: const Icon(Icons.more_vert, size: 18),
        label: Text(context.tr('more')),
      ),
    );
  }
}

/// The detail-header `⋮` overflow: an `IconButton` opening a [MenuAnchor] with
/// every non-primary action. Used by [EntityDetailActionsRow] (the detail
/// header is a plain `Row`, so unlike [_MoreMenu] — a child of `OverflowView`
/// in [EntityOverflowActionBar] — this is free to use an `IconButton`/`Tooltip`).
class _OverflowMenuButton<A> extends StatelessWidget {
  const _OverflowMenuButton({required this.items});
  final List<EntityActionItem<A>> items;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      consumeOutsideTap: true,
      menuChildren: EntityActionItem.menuChildrenFor<A>(context, items),
      builder: (context, controller, _) => IconButton(
        tooltip: context.tr('more'),
        icon: const Icon(Icons.more_vert),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
