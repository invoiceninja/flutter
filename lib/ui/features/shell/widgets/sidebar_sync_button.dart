import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/resync_controller.dart';
import 'package:admin/l10n/localization.dart';

/// One-tap Sync, paired with the company switcher at the top of the sidebar
/// (issue #14 — syncing used to be four taps deep in Settings).
///
/// Pure and directly pumpable: it takes the progress listenable and the
/// callback rather than reaching for `context.read<Services>()`, matching
/// `SidebarNavItem` / `NavHistoryButtons`.
///
/// Three states, keyed off whether the in-flight pass belongs to *this*
/// company (a pass deliberately outlives a company switch):
///
/// | state                   | glyph          | tap  |
/// |-------------------------|----------------|------|
/// | idle                    | sync icon      | runs |
/// | running (this company)  | spinner        | inert|
/// | running (other company) | dimmed icon    | inert|
class SidebarSyncButton extends StatelessWidget {
  const SidebarSyncButton({
    required this.progress,
    required this.companyId,
    required this.onSync,
    this.compact = false,
    this.touch = false,
    super.key,
  });

  final ValueListenable<ResyncProgress> progress;

  /// Active company — compared against the in-flight pass's company so the
  /// spinner can't show up on the wrong workspace.
  final String companyId;

  final VoidCallback onSync;

  /// Icon-only rail variant. Drops the width floor: the collapsed rail leaves
  /// 64 − 28 padding = 36 px, which a 44 floor would overflow.
  final bool compact;

  /// Floors the button at [InSizes.touchTarget]. Set from `Env.isTouchPrimary`
  /// by `InSidebar` and threaded down like [compact]; see issue #11.
  final bool touch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return ValueListenableBuilder<ResyncProgress>(
      valueListenable: progress,
      builder: (context, p, _) {
        final mine = p.isRunningFor(companyId);
        final blocked = p.isRunning && !mine;
        final String tip;
        if (mine) {
          tip = p.total > 0
              ? context.tr('syncing_progress', {
                  'count': '${p.completed}',
                  'total': '${p.total}',
                })
              : context.tr('syncing');
        } else {
          tip = context.tr(blocked ? 'sync_in_progress' : 'sync_now');
        }
        // Indeterminate on purpose even once `total` is known: a 16-px
        // determinate arc conveys almost nothing, and swapping a spinning ring
        // for a near-frozen arc mid-pass reads as a hang. The count lives in
        // the tooltip instead. RepaintBoundary keeps a ~30 s animation off the
        // rail's own boundary — without it the whole 232-px column repaints
        // every frame for the length of the pass.
        final Widget glyph = mine
            ? const RepaintBoundary(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : Icon(
                Icons.sync,
                size: 18,
                color: blocked
                    ? tokens.ink3.withValues(alpha: 0.35)
                    : tokens.ink3,
              );
        return Tooltip(
          // Plain Tooltip, not ShortcutTooltip: there's no shortcut to
          // advertise, and `richMessage` isn't matched by `find.byTooltip`.
          message: tip,
          waitDuration: const Duration(milliseconds: 600),
          child: Material(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(InRadii.r2),
            child: InkWell(
              onTap: p.isRunning ? null : onSync,
              borderRadius: BorderRadius.circular(InRadii.r2),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(InRadii.r2),
                  border: Border.all(color: tokens.border),
                ),
                // Minimums only — never `SizedBox(height:)`. The expanded
                // header stretches this box to the company switcher's height,
                // which grows with text scale; a fixed height would fight that
                // and clip the switcher's descenders.
                constraints: BoxConstraints(
                  minWidth: compact ? 0 : (touch ? InSizes.touchTarget : 36),
                  minHeight: touch ? InSizes.touchTarget : 36,
                ),
                child: Center(child: glyph),
              ),
            ),
          ),
        );
      },
    );
  }
}
