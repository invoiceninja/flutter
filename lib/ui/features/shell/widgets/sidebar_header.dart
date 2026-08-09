import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/resync_controller.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/features/shell/widgets/company_switcher_button.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_sync_button.dart';

/// Top of the sidebar: the company switcher paired with the one-tap Sync
/// button (issue #14 — "Download data" used to be four taps deep in Settings).
///
/// The two are *siblings*, never nested: [CompanySwitcherButton]'s `InkWell`
/// covers its whole box and would swallow a tap landing on a child.
///
/// Pure and directly pumpable — `onSync` arrives as a callback rather than
/// this widget reaching for `Services`, matching `SidebarNavItem` /
/// `NavHistoryButtons` / `SidebarSyncButton`.
class SidebarHeader extends StatelessWidget {
  const SidebarHeader({
    required this.session,
    required this.resync,
    required this.onSync,
    this.onBeforeCompanyPicker,
    this.compact = false,
    this.touch = false,
    super.key,
  });

  final AuthSession session;
  final ValueListenable<ResyncProgress> resync;
  final VoidCallback onSync;
  final VoidCallback? onBeforeCompanyPicker;
  final bool compact;
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final switcher = CompanySwitcherButton(
      session: session,
      onBeforeOpen: onBeforeCompanyPicker,
      compact: compact,
      touch: touch,
    );
    final sync = SidebarSyncButton(
      progress: resync,
      companyId: session.currentCompanyId,
      compact: compact,
      touch: touch,
      onSync: onSync,
    );
    if (compact) {
      // The 64-px rail leaves 64 − 28 padding = 36 px, which the avatar-only
      // switcher already fills exactly — so Sync stacks under it, not beside.
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switcher,
          SizedBox(height: InSpacing.sm),
          sync,
        ],
      );
    }
    // IntrinsicHeight is what makes `stretch` usable here: a bare Row inherits
    // `maxHeight: infinity` from the sidebar's Column, and `stretch` would
    // resolve to an infinite tight height. With it, the Sync box is exactly as
    // tall as the switcher — including at large text scale, where the company
    // name's line box pushes the switcher past 44. Cheap at this size because
    // the name is `maxLines: 1` + ellipsis, so its intrinsic height is one line
    // box at any width.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: switcher),
          SizedBox(width: InSpacing.sm),
          sync,
        ],
      ),
    );
  }
}
