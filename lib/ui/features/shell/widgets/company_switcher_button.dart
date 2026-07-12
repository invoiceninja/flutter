import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/widgets/shortcut_tooltip.dart';
import 'package:admin/ui/features/shell/widgets/company_avatar.dart';
import 'package:admin/ui/features/shell/widgets/show_company_picker.dart';

/// Header button at the top of the sidebar showing the active company and
/// (when more than one workspace is available) opening the [CompanyPicker]
/// on tap.
///
/// Single-company case: chevron is hidden and the button is inert.
class CompanySwitcherButton extends StatefulWidget {
  const CompanySwitcherButton({
    required this.session,
    this.onBeforeOpen,
    this.compact = false,
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
    final multi = session.companies.length > 1;
    final name = current?.displayName ?? '—';
    final seed = current?.id ?? '';
    final avatar = CompanyAvatar(
      name: name,
      seed: seed,
      size: 28,
      logoUrl: current?.logoUrl,
    );
    final Widget button = Material(
      key: _anchorKey,
      color: tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: InkWell(
        onTap: multi
            ? () {
                widget.onBeforeOpen?.call();
                showCompanyPicker(context, anchorKey: _anchorKey);
              }
            : null,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(InRadii.r2),
            border: Border.all(color: tokens.border),
          ),
          padding: EdgeInsets.all(widget.compact ? 4 : 8),
          child: widget.compact
              ? Align(alignment: Alignment.centerLeft, child: avatar)
              : Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    if (multi) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.unfold_more, size: 14, color: tokens.ink3),
                    ],
                  ],
                ),
        ),
      ),
    );

    // Only advertise ⌘K when the button is interactive (more than one
    // workspace) — matching when the picker actually opens.
    if (!multi) return button;
    return ShortcutTooltip(
      label: context.tr('switch_company'),
      keys: [platformModifierLabel(), 'K'],
      child: button,
    );
  }
}
