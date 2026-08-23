import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/nav_history_controller.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/shortcut_tooltip.dart';

/// Browser-style back/forward buttons at the top of the sidebar — the visible
/// affordance for [NavHistoryController], the same history the Cmd/Alt+←/→
/// shortcuts walk. Without it the history is keyboard-only and effectively
/// undiscoverable: tapping a client/vendor link on an invoice strands the
/// user on the linked record with no apparent way back.
///
/// This is *history* back (return to the exact previous location), not the
/// structural "up" the master-detail pane arrows perform (detail → its own
/// list, `entityCloseTargetPath`) — the two must not be conflated. On Android
/// the system back gesture walks this same history (`SystemBackGate`), so these
/// arrows and the gesture agree; the pane arrow is the "up" of the pair.
class NavHistoryButtons extends StatelessWidget {
  const NavHistoryButtons({
    this.compact = false,
    this.popDrawerFirst = false,
    this.touch = false,
    super.key,
  });

  /// Collapsed-rail variant: the pair centers itself in the 64-px rail
  /// instead of left-aligning under the company switcher.
  final bool compact;

  /// Grows the pair to [InSizes.touchTarget]. Set from `Env.isTouchPrimary` by
  /// `InSidebar`; see issue #11. Height always, width only when there's room —
  /// see [_HistoryButton].
  final bool touch;

  /// True when hosted inside `AppDrawer`: dismisses the drawer before
  /// navigating (same order as `AppDrawer.onSelectBranch` — the route change
  /// would otherwise happen invisibly underneath the open drawer).
  final bool popDrawerFirst;

  @override
  Widget build(BuildContext context) {
    final history = context.watch<NavHistoryController>();
    // KeyCap chip glyph: '⌘' on Apple; 'Alt+' elsewhere loses its '+' —
    // the chip row already reads as a combination.
    final mod = platformHistoryModifierLabel().replaceAll('+', '');
    return Row(
      mainAxisAlignment: compact
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        _HistoryButton(
          icon: Icons.arrow_back,
          labelKey: 'go_back',
          keys: [mod, '←'],
          enabled: history.canGoBack,
          touch: touch,
          compact: compact,
          onPressed: () => _navigate(context, history.back),
        ),
        _HistoryButton(
          icon: Icons.arrow_forward,
          labelKey: 'go_forward',
          keys: [mod, '→'],
          enabled: history.canGoForward,
          touch: touch,
          compact: compact,
          onPressed: () => _navigate(context, history.forward),
        ),
      ],
    );
  }

  void _navigate(BuildContext context, VoidCallback go) {
    // `go` closes over the controller resolved in build, so it stays valid
    // after the drawer's context is popped away.
    if (popDrawerFirst) Navigator.pop(context);
    go();
  }
}

/// One arrow of the pair. Mirrors the sidebar footer's `_CollapseToggleButton`
/// sizing overrides — the app-wide `IconButton.minimumSize = fromHeight(44)`
/// theme default would balloon the button inside the tight header row.
class _HistoryButton extends StatelessWidget {
  const _HistoryButton({
    required this.icon,
    required this.labelKey,
    required this.keys,
    required this.enabled,
    required this.onPressed,
    this.touch = false,
    this.compact = false,
  });

  final IconData icon;
  final String labelKey;
  final List<String> keys;
  final bool enabled;
  final VoidCallback onPressed;
  final bool touch;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final button = IconButton(
      style: IconButton.styleFrom(
        // Touch grows the height always, the width only off the collapsed
        // rail: the pair is centred in 64 px with no horizontal padding, so
        // 2×32 already fills it exactly and 2×44 would overflow.
        minimumSize: touch
            ? Size(compact ? 32 : InSizes.touchTarget, InSizes.touchTarget)
            : const Size(32, 32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(
        icon,
        size: 18,
        // Explicit icon color bypasses the theme's disabled tint, so dim
        // manually — staying in the rail's ink family either way.
        color: enabled ? tokens.ink3 : tokens.ink3.withValues(alpha: 0.35),
      ),
      onPressed: enabled ? onPressed : null,
    );
    // Only advertise the shortcut while the action can actually fire —
    // same rule as the company switcher's ⌘K tooltip.
    if (!enabled) return button;
    return ShortcutTooltip(
      label: context.tr(labelKey),
      keys: keys,
      waitDuration: const Duration(milliseconds: 600),
      child: button,
    );
  }
}

/// Routes the dedicated back/forward thumb buttons found on many mice
/// ([kBackMouseButton] / [kForwardMouseButton]) into the same history —
/// exactly what a browser does with them. Wraps the authenticated shell's
/// content in `ScaffoldWithNav`; dialogs and sheets live on the root
/// navigator's overlay outside this subtree, so clicks there are unaffected.
class NavHistoryMouseListener extends StatelessWidget {
  const NavHistoryMouseListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind != PointerDeviceKind.mouse) return;
        final history = context.read<NavHistoryController>();
        if (event.buttons & kBackMouseButton != 0) {
          history.back();
        } else if (event.buttons & kForwardMouseButton != 0) {
          history.forward();
        }
      },
      child: child,
    );
  }
}
