import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/sidebar_menu_controller.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/sidebar_menu.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_menu_entries.dart';

/// Open the main-menu editor: drag to reorder, switch to hide
/// (invoiceninja/flutter#125).
///
/// Wide (≥600) → a centred dialog capped at the settings 720 width. Narrow → a
/// scroll-controlled bottom sheet. Both host the same live editor, and both
/// give the reorderable list a scrollable **of its own** — which is the reason
/// this is a sheet and not an inline card on the settings page. A `shrinkWrap`
/// + `NeverScrollableScrollPhysics` reorderable cannot auto-scroll mid-drag, so
/// on a phone there would be no way to move the last item to the top.
///
/// Mutations apply instantly (no Save gate), matching the dashboard's manage
/// sheet and Device Settings' own rule that every control writes straight to
/// the device-local store. "Reset to defaults" is the escape hatch.
Future<void> openCustomizeMenu(BuildContext context) {
  final wide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: const _CustomizeMenuBody(),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // `showModalBottomSheet` lifts nothing by itself, and padding first makes
    // the 0.92 fraction measure against the reduced box rather than the whole
    // screen. No text field here today, but the next one added would otherwise
    // sit under the keyboard.
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: const FractionallySizedBox(
        heightFactor: 0.92,
        child: _CustomizeMenuBody(),
      ),
    ),
  );
}

class _CustomizeMenuBody extends StatefulWidget {
  const _CustomizeMenuBody();

  @override
  State<_CustomizeMenuBody> createState() => _CustomizeMenuBodyState();
}

class _CustomizeMenuBodyState extends State<_CustomizeMenuBody> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Every destination the menu can hold, in the app's own order — **not** the
  /// module-filtered list the sidebar renders.
  ///
  /// This is the load-bearing half of `setEntries`' contract. `resolveMenuEntries`
  /// returns exactly the ids it is given, so writing back a list resolved from
  /// the sidebar's narrower view would silently erase the stored position of
  /// every entity whose module the company currently has switched off — and
  /// they would come back at the bottom of the menu when it was re-enabled.
  List<String> _allIds(EntityRegistry registry) => <String>[
    kSidebarMenuDashboardId,
    for (final h in registry.sidebarTop) h.type.name,
    kSidebarMenuReportsId,
    kSidebarMenuActivityId,
  ];

  /// Store [next], or clear the preference outright when it *is* the default.
  ///
  /// Hiding a row and showing it again would otherwise leave the full default
  /// list stored: "Reset to defaults" would appear with nothing to do, and the
  /// install would be frozen out of any later change to the default order.
  /// `DashboardViewModel.panelsAreDefault` gates its own reset the same way.
  void _apply(
    SidebarMenuController controller,
    List<SidebarMenuEntryPref> next,
    List<String> allIds,
  ) {
    if (_isDefault(next, allIds)) {
      controller.resetEntries();
    } else {
      controller.setEntries(next);
    }
  }

  /// True when [next] is the app's own order with nothing hidden.
  static bool _isDefault(List<SidebarMenuEntryPref> next, List<String> allIds) {
    if (next.length != allIds.length) return false;
    for (var i = 0; i < next.length; i++) {
      if (next[i].id != allIds[i] || !next[i].visible) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Services sits above MaterialApp (main.dart), so this reads fine from a
    // root-navigator dialog.
    final services = context.read<Services>();
    final registry = services.entityRegistry;
    final enabledModules =
        services.auth.session.value?.currentCompany?.enabledModules ?? 0;
    final tokens = context.inTheme;

    final byId = <String, ({IconData icon, String labelKey, bool available})>{};
    for (final spec in kSidebarMenuFixedSpecs) {
      byId[spec.id] = (
        icon: spec.icon,
        labelKey: spec.labelKey,
        // Reports is permission-gated rather than module-gated, and that gate
        // is not surfaced here: it is rare, the user cannot change it, and the
        // row simply never renders in the sidebar. Only the module case — which
        // an admin *can* change, and which is common — is flagged.
        available: true,
      );
    }
    for (final h in registry.sidebarTop) {
      byId[h.type.name] = (
        icon: h.effectiveOutlinedIcon,
        labelKey: h.effectiveLabelKey,
        available: isEntityModuleEnabledForCompany(h.type, enabledModules),
      );
    }
    final allIds = _allIds(registry);

    return ListenableBuilder(
      listenable: services.sidebarMenu,
      builder: (context, _) {
        final entries = services.sidebarMenu.entriesFor(allIds);
        // `showModalBottomSheet` defaults to `useSafeArea: false`, and the
        // sheet is bottom-anchored, so nothing else pays the system inset.
        // Measured on a 390x844 phone: without this the action row's own
        // padding leaves it stopping 26 px short of the screen edge — enough to
        // clear a 24-px Android gesture bar by two pixels, and not enough for a
        // 34-px iPhone home indicator, which lands on the Done button. The
        // sheet's bottom edge is flush to the screen either way.
        //
        // A no-op in the dialog branch, where `showDialog`'s own default
        // `useSafeArea: true` has already paid the inset and removed it for
        // descendants; both sibling sheets wrap unconditionally for that reason
        // (`entity_column_picker_sheet.dart`, `manage_dashboard_cards_sheet.dart`).
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  context.tr('customize_menu'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.tr('close'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Divider(height: 1, color: tokens.border),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: _scroll,
                  padding: EdgeInsets.symmetric(
                    horizontal: InSpacing.lg(context),
                    vertical: InSpacing.md(context),
                  ),
                  buildDefaultDragHandles: false,
                  itemCount: entries.length,
                  onReorderItem: (oldIndex, newIndex) {
                    // No `if (newIndex > oldIndex) newIndex--` fix-up:
                    // `onReorderItem` is handed the post-removal destination
                    // already (reorderable_list.dart), unlike the deprecated
                    // `onReorder`.
                    final next = List<SidebarMenuEntryPref>.from(entries);
                    final moved = next.removeAt(oldIndex);
                    next.insert(newIndex, moved);
                    _apply(services.sidebarMenu, next, allIds);
                  },
                  itemBuilder: (context, i) {
                    final entry = entries[i];
                    final meta = byId[entry.id];
                    return _MenuRow(
                      key: ValueKey(entry.id),
                      index: i,
                      icon: meta?.icon ?? Icons.circle_outlined,
                      title: context.tr(meta?.labelKey ?? entry.id),
                      visible: entry.visible,
                      available: meta?.available ?? true,
                      onToggle: () {
                        final next = List<SidebarMenuEntryPref>.from(entries);
                        next[i] = entry.copyWith(visible: !entry.visible);
                        _apply(services.sidebarMenu, next, allIds);
                      },
                    );
                  },
                ),
              ),
              Divider(height: 1, color: tokens.border),
              Padding(
                padding: EdgeInsets.all(InSpacing.lg(context)),
                child: Row(
                  children: [
                    if (services.sidebarMenu.hasCustomEntries)
                      TextButton(
                        onPressed: services.sidebarMenu.resetEntries,
                        child: Text(context.tr('reset_to_defaults')),
                      ),
                    const Spacer(),
                    PrimaryDialogAction(
                      label: context.tr('done'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One reorderable menu row: drag handle, the destination's own icon + label,
/// and a show/hide switch.
///
/// A row whose module the company has switched off is listed all the same, and
/// stays draggable — only its switch goes inert. Dropping it from the list
/// instead would take its stored position with it (see `_allIds`), and a user
/// who re-enables the module would find it at the bottom of their menu.
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.index,
    required this.icon,
    required this.title,
    required this.visible,
    required this.available,
    required this.onToggle,
    super.key,
  });

  /// The drag handle's hit area — the finger target on touch, the glyph's own
  /// box on a pointer platform where a 44-px slot would just be slack.
  static double get _handleSize =>
      Env.isTouchPrimary ? InSizes.touchTarget : 20;

  final int index;
  final IconData icon;
  final String title;
  final bool visible;
  final bool available;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Two muted states, never conflated: a module-disabled row is inert and
    // says why; a user-hidden row is a live control whose switch already
    // carries the message, so it only loses a little emphasis.
    final titleColor = !available
        ? tokens.ink3
        : (visible ? tokens.ink : tokens.ink2);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ReorderableDragStartListener(
        index: index,
        child: Tooltip(
          message: context.tr('drag_to_reorder'),
          // `Container(color:)` and not a `SizedBox`, which would change
          // nothing: `ReorderableDragStartListener` is a `Listener` on the
          // default `HitTestBehavior.deferToChild`, and `SizedBox` / `Padding`
          // / `Center` all defer too — so the drag target would stay the 20-px
          // glyph. `ColoredBox` is the one that passes `opaque` down, which is
          // what actually grows the target to the finger this feature is for.
          child: Container(
            color: Colors.transparent,
            width: _handleSize,
            height: _handleSize,
            alignment: Alignment.center,
            child: Icon(Icons.drag_indicator, color: tokens.ink3, size: 20),
          ),
        ),
      ),
      title: Row(
        children: [
          Icon(icon, size: 20, color: titleColor),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: titleColor),
            ),
          ),
        ],
      ),
      subtitle: available
          ? null
          : Text(
              context.tr('module_disabled'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
            ),
      trailing: Tooltip(
        message: context.tr(visible ? 'hide' : 'show'),
        child: Switch.adaptive(
          value: visible,
          onChanged: available ? (_) => onToggle() : null,
        ),
      ),
    );
  }
}
