import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

/// The count chip on a sidebar row. Lives in its own file (rather than staying
/// private to `sidebar_nav_item.dart`) so the Sidebar counters card in Device
/// Settings can render a live preview of the exact badge the rail will show —
/// same widget, same stream, same colour.
class SidebarBadge extends StatelessWidget {
  const SidebarBadge({
    required this.count,
    this.active = false,
    this.tone = SidebarBadgeTone.neutral,
    super.key,
  });

  final int count;

  /// Whether the row this badge sits on is the selected one. Only affects the
  /// [SidebarBadgeTone.neutral] palette — see [colorsFor].
  final bool active;

  final SidebarBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final colors = colorsFor(tokens, tone, active: active);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(InRadii.r1),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        count > 999 ? '999+' : '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: colors.fg,
        ),
      ),
    );
  }

  /// Badge palette for [tone]. The three non-neutral tones deliberately ignore
  /// [active]: an overdue count has to stay red on the selected row, or the one
  /// row you're looking at is the one that stops warning you.
  ///
  /// These are the same tokens the status pills use (`InvoiceStatusPill`, the
  /// products list' stock cell), so a red badge reads as the same "overdue" the
  /// rest of the app means.
  static ({Color fg, Color bg}) colorsFor(
    InTheme tokens,
    SidebarBadgeTone tone, {
    required bool active,
  }) => switch (tone) {
    SidebarBadgeTone.danger => (fg: tokens.overdue, bg: tokens.overdueSoft),
    SidebarBadgeTone.warning => (fg: tokens.warning, bg: tokens.warningSoft),
    SidebarBadgeTone.muted => (fg: tokens.draft, bg: tokens.draftSoft),
    SidebarBadgeTone.neutral =>
      active
          ? (fg: tokens.accent, bg: tokens.surface)
          : (fg: tokens.ink3, bg: tokens.surfaceAlt),
  };

  /// Dot colour for the collapsed rail, where a number doesn't fit. The dot is
  /// the only signal there, so it carries the tone.
  static Color dotColorFor(InTheme tokens, SidebarBadgeTone tone) =>
      switch (tone) {
        SidebarBadgeTone.danger => tokens.overdue,
        SidebarBadgeTone.warning => tokens.warning,
        SidebarBadgeTone.muted => tokens.draft,
        SidebarBadgeTone.neutral => tokens.accent,
      };
}
