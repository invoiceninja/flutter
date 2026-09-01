import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/shortcut_tooltip.dart';
import 'package:admin/ui/features/shell/widgets/company_avatar.dart';
import 'package:admin/ui/features/shell/widgets/show_company_picker.dart';

/// Company names longer than this get a hover tooltip revealing the full
/// name (the label itself truncates with an ellipsis).
const int kCompanyNameTooltipThreshold = 22;

/// Header button at the top of the sidebar showing the active company and
/// opening the [CompanyPicker] on tap.
///
/// **Always tappable, including with a single company.** It used to go inert at
/// `companies.length <= 1`, which turned a wrong roster into a dead end: when a
/// company is missing from the session (issue #16 — a null `token` in the
/// login/refresh envelope used to drop the whole entry), the user was left with
/// an unresponsive button and no way to see what the app thought it knew. The
/// picker is also the sidebar's only Sign-out entry, and the ⌘K path
/// (`scaffold_with_nav.dart`) never had the gate — so this is the consistent
/// behavior, not a new affordance.
///
/// Issue #104 did **not** revert that. On a single-company mobile drawer this
/// widget isn't rendered at all, but the control it opens is still there — it
/// moves to `SidebarCompanyFooterAction` in the footer row, which is reachable
/// at `companies.length` of 1 *and* 0. Relocated, never gated: `CompanyPicker`
/// owns the app's only "New company" entry, so making it unreachable at one
/// company would lock an owner out of ever having two.
class CompanySwitcherButton extends StatefulWidget {
  const CompanySwitcherButton({
    required this.session,
    this.onBeforeOpen,
    this.compact = false,
    this.touch = false,
    super.key,
  });

  final AuthSession session;

  /// Fires after the user taps the button and before the picker is shown.
  /// Used by `AppDrawer` to pop the drawer first so the picker doesn't sit
  /// on top of an open drawer. Null in the desktop sidebar.
  final VoidCallback? onBeforeOpen;

  /// Icon-only variant used when the wide-layout sidebar is collapsed: only
  /// the avatar renders, no name text or chevron. Tap still opens the picker
  /// anchored on the same key.
  final bool compact;

  /// Floors the button at [InSizes.touchTarget] tall. Never bites outside
  /// [compact] mode — the expanded button is already 46: `Container` folds the
  /// 1-px border into the 8-px padding, so it is 28 avatar + 2x9. Height only: the collapsed rail leaves just 64 − 28 = 36 px of
  /// usable width. Set from `Env.isTouchPrimary` by `InSidebar`; see issue #11.
  final bool touch;

  @override
  State<CompanySwitcherButton> createState() => _CompanySwitcherButtonState();
}

class _CompanySwitcherButtonState extends State<CompanySwitcherButton> {
  /// Anchors the picker popup to this button's render box. Held in State so it
  /// stays stable across rebuilds: `InSidebar` reconstructs this button on
  /// every session re-emit / collapse-pref change, and a fresh `GlobalKey` per
  /// build would fail `Material.canUpdate` (keys differ by identity), tearing
  /// down and remounting the whole subtree — including the logo `Image`, which
  /// then has no prior frame for `gaplessPlayback` to bridge. That remount was
  /// the intermittent sidebar-logo flash.
  final GlobalKey _anchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final session = widget.session;
    final current = session.currentCompany;
    final name = current?.displayName ?? '—';
    final seed = current?.id ?? '';
    final avatar = CompanyAvatar(
      name: name,
      seed: seed,
      size: 28,
      logoUrl: current?.logoUrl,
    );
    final nameText = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: tokens.ink,
      ),
    );
    final Widget button = Material(
      key: _anchorKey,
      color: tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: InkWell(
        onTap: () {
          widget.onBeforeOpen?.call();
          showCompanyPicker(context, anchorKey: _anchorKey);
        },
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(InRadii.r2),
            border: Border.all(color: tokens.border),
          ),
          padding: EdgeInsets.all(widget.compact ? 4 : 8),
          constraints: widget.touch
              ? const BoxConstraints(minHeight: InSizes.touchTarget)
              : null,
          child: widget.compact
              ? Align(alignment: Alignment.centerLeft, child: avatar)
              : Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: name.length > kCompanyNameTooltipThreshold
                          ? Tooltip(message: name, child: nameText)
                          : nameText,
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.unfold_more, size: 14, color: tokens.ink3),
                  ],
                ),
        ),
      ),
    );

    return ShortcutTooltip(
      label: context.tr('switch_company'),
      keys: [platformModifierLabel(), 'K'],
      child: button,
    );
  }
}
