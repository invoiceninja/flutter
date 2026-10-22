import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme_controller.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';

/// Opens the quick theme switcher in the right form factor for the layout.
///
/// On wide layouts it pops up as a positioned overlay anchored to [anchorKey]'s
/// render box and opening *upward* (the affordance lives in the sidebar
/// footer, near the bottom of the screen). On narrow layouts — including the
/// mobile drawer, where `MediaQuery` reflects the full screen — it comes up as
/// a bottom sheet on the root navigator so it sits above the drawer.
///
/// Mirrors `show_company_picker.dart`: the two sidebar popups share chrome,
/// the 120 ms fade, and the anchored / bottom-sheet split so they read as one
/// system.
Future<void> showThemeMenu(BuildContext context, {GlobalKey? anchorKey}) {
  final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
  if (!isWide) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: ThemeMenu(fillWidth: true),
        ),
      ),
    );
  }

  Offset? topLeft;
  Size? anchorSize;
  if (anchorKey?.currentContext != null) {
    final box = anchorKey!.currentContext!.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      topLeft = box.localToGlobal(Offset.zero);
      anchorSize = box.size;
    }
  }

  return Navigator.of(context).push(
    _ThemeMenuRoute(
      topLeft: topLeft,
      anchorSize: anchorSize,
      // Snapshot the localized "Dismiss" string — PopupRoute's barrierLabel
      // getter has no BuildContext.
      barrierLabelText: context.tr('dismiss'),
    ),
  );
}

class _ThemeMenuRoute extends PopupRoute<void> {
  _ThemeMenuRoute({
    this.topLeft,
    this.anchorSize,
    required this.barrierLabelText,
  });

  final Offset? topLeft;
  final Size? anchorSize;
  final String barrierLabelText;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => barrierLabelText;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _PositionedThemeMenu(topLeft: topLeft, anchorSize: anchorSize);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    );
  }
}

class _PositionedThemeMenu extends StatelessWidget {
  const _PositionedThemeMenu({required this.topLeft, this.anchorSize});

  final Offset? topLeft;
  final Size? anchorSize;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    const menuWidth = 260.0;
    const margin = 8.0;
    double left;
    double bottom;
    double maxHeight;
    if (topLeft != null) {
      // Start-align with the icon and open upward: the menu's bottom edge sits
      // just above the anchor's top. In a right-to-left locale the menu's
      // right edge follows the icon's, so it grows leftwards, off the rail
      // (which sits at the right there). Clamp maxHeight at 0 so a very short
      // window can't hand ConstrainedBox a negative constraint.
      left = Directionality.of(context) == TextDirection.rtl
          ? topLeft!.dx + (anchorSize?.width ?? 0) - menuWidth
          : topLeft!.dx;
      bottom = screen.height - topLeft!.dy + margin;
      maxHeight = (topLeft!.dy - margin).clamp(0.0, double.infinity);
    } else {
      left = (screen.width - menuWidth) / 2;
      bottom = margin + 60;
      maxHeight = screen.height - 2 * margin;
    }
    left = left.clamp(margin, screen.width - menuWidth - margin);
    return Stack(
      children: [
        // rtl: physical — `left` is global-coordinate maths, already mirrored.
        Positioned(
          left: left,
          bottom: bottom,
          width: menuWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: const ThemeMenu(),
          ),
        ),
      ],
    );
  }
}

/// Overlay content: the three theme modes as selectable rows plus a shortcut
/// into the full appearance settings. Watches [ThemeController] so the active
/// check tracks live as the mode changes.
///
/// Public so widget tests can pump it directly (as `CompanyPicker` is) without
/// driving the `PopupRoute`; the route + positioning around it stay private.
class ThemeMenu extends StatelessWidget {
  const ThemeMenu({this.fillWidth = false, super.key});

  /// The bottom sheet wants full width; the desktop popup wants a fixed 260 px.
  final bool fillWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = context.read<Services>().theme;
    final width = fillWidth ? double.infinity : 260.0;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(InRadii.r3),
          boxShadow: fillWidth ? null : tokens.shadow2,
          border: Border.all(color: tokens.border),
        ),
        padding: const EdgeInsets.all(8),
        child: ListenableBuilder(
          listenable: theme,
          builder: (context, _) {
            final mode = theme.themeMode;
            // What ThemeMode.system resolves to right now, shown as a note on
            // the System row so "System" isn't an opaque choice.
            final systemIsDark =
                MediaQuery.platformBrightnessOf(context) == Brightness.dark;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                    child: Text(
                      context.tr('appearance'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink3,
                      ),
                    ),
                  ),
                  _ModeRow(
                    icon: Icons.light_mode_outlined,
                    label: context.tr('light'),
                    isActive: mode == ThemeMode.light,
                    onTap: () => _select(context, theme, ThemeMode.light),
                  ),
                  _ModeRow(
                    icon: Icons.dark_mode_outlined,
                    label: context.tr('dark'),
                    isActive: mode == ThemeMode.dark,
                    onTap: () => _select(context, theme, ThemeMode.dark),
                  ),
                  _ModeRow(
                    icon: Icons.brightness_auto_outlined,
                    label: context.tr('system'),
                    note: context.tr(systemIsDark ? 'dark' : 'light'),
                    isActive: mode == ThemeMode.system,
                    onTap: () => _select(context, theme, ThemeMode.system),
                  ),
                  const SizedBox(height: 6),
                  Divider(height: 1, color: tokens.border),
                  const SizedBox(height: 6),
                  const _DeviceSettingsRow(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _select(BuildContext context, ThemeController theme, ThemeMode mode) {
    unawaited(theme.setThemeMode(mode));
    Navigator.of(context).maybePop();
  }
}

/// A selectable theme-mode row, styled like the company picker's `_CompanyRow`:
/// accent-soft background + a trailing check when active. [note] renders as a
/// muted suffix (the System row's resolved brightness).
class _ModeRow extends StatelessWidget {
  const _ModeRow({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.note,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Material(
      color: isActive ? tokens.accentSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? tokens.accent : tokens.ink3,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                    children: [
                      if (note != null)
                        TextSpan(
                          text: '  ·  $note',
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: tokens.ink3,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isActive) Icon(Icons.check, size: 16, color: tokens.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shortcut into the full appearance controls (palette, custom colors,
/// security). Closes the menu first, then navigates — capturing the router
/// before the pop so we don't touch a disposed context across the gap.
class _DeviceSettingsRow extends StatelessWidget {
  const _DeviceSettingsRow();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: InkWell(
        onTap: () {
          final router = GoRouter.maybeOf(context);
          Navigator.of(context).maybePop();
          router?.go('/settings/device_settings');
        },
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.devices_outlined, size: 16, color: tokens.ink3),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('device_settings'),
                  style: TextStyle(fontSize: 13, color: tokens.ink2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: tokens.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
