import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_badge.dart';
import 'package:admin/ui/core/widgets/shortcut_tooltip.dart';

/// One row in the sidebar nav list. Three visual states:
///
///   * **active** — accent background + ink, bold weight.
///   * **inactive enabled** — transparent background, muted ink.
///   * **disabled** — same as inactive but with `ink4` and a tap that pops a
///     "Coming soon" SnackBar instead of switching branches. The disabled
///     state is what the design's many placeholder items use today.
///
/// Optional [trailingHover] reveals a secondary action button on mouse
/// hover (wide-mode only — compact rail and disabled rows ignore it). The
/// hover slot is intended for `IconButton`-shaped widgets whose internal
/// gesture detector consumes taps so the row's `onTap` doesn't also fire.
class SidebarNavItem extends StatefulWidget {
  const SidebarNavItem({
    required this.label,
    required this.icon,
    required this.active,
    this.onTap,
    this.count,
    this.countTone = SidebarBadgeTone.neutral,
    this.countLabel,
    this.disabled = false,
    this.compact = false,
    this.tile = false,
    this.touch = false,
    this.trailingHover,
    this.trailing,
    this.leaderKey,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  final int? count;

  /// Colour weight of the [count] badge — set from the row's selected
  /// `SidebarBadgeMode`. Neutral is the plain "how many are there" count.
  final SidebarBadgeTone countTone;

  /// Localized name of what [count] is counting ("Overdue", "Low stock"). Shown
  /// in a tooltip on the badge, and folded into the row tooltip in [compact]
  /// mode where the number isn't rendered at all. Null for a plain total, which
  /// needs no explanation.
  final String? countLabel;

  final bool disabled;

  /// Icon-only variant for the collapsed wide-layout sidebar. The label
  /// surfaces in a hover tooltip; the optional `count` becomes a small accent
  /// dot at the icon's top-right (numbers don't fit in 64 px).
  final bool compact;

  /// Grid variant for the "pills" menu layout (invoiceninja/flutter#125): a
  /// bordered card with the icon above a centred two-line label, matching the
  /// dashboard's quick-action tiles so the two read as one system.
  ///
  /// Ignored when [compact] — the 64-px rail is already denser than any grid.
  /// A tile has no room for a hover slot, so [trailingHover] is dropped; the
  /// one slot beside the icon carries [trailing] if there is one and the
  /// [count] badge otherwise (the two never coexist — see [trailing]).
  ///
  /// An enabled tile also gains a full-label tooltip, deliberately on
  /// `TooltipTriggerMode.manual` so it can't swallow the long press that opens
  /// the row's counter menu — see the comment at the return site.
  final bool tile;

  /// Floors the row at [InSizes.touchTarget] so a finger has something to aim
  /// at. Set from `Env.isTouchPrimary` by `InSidebar` — pointer platforms keep
  /// the denser 32-px row. Typography and icon size are identical either way;
  /// only the hit area grows. See issue #11.
  final bool touch;

  /// Secondary action revealed at the row's right edge when the mouse
  /// hovers over this row. Ignored in [compact] mode (no horizontal room)
  /// and on [disabled] rows (no real action to invoke).
  final Widget? trailingHover;

  /// Always-visible secondary action at the row's right edge (no hover
  /// gate), used by saved-view rows so their context menu is discoverable
  /// and keyboard-reachable. Ignored in [compact] mode (no room). Replaces
  /// both [trailingHover] and the [count] badge. Invariant: a row never sets
  /// both [trailing] and [count] — saved-view rows set [trailing] only, badge
  /// rows set [count] only. ([trailingHover] and [count] *do* coexist.)
  final Widget? trailing;

  /// The second key of this row's `G`-then-letter leader jump (e.g. `'C'`
  /// for Clients). When non-null and the row is enabled, hovering shows a
  /// "label · G then X" shortcut tooltip. Null for rows with no leader jump.
  final String? leaderKey;

  @override
  State<SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<SidebarNavItem> {
  bool _hovered = false;

  /// A tile is excluded as well as the rail: there is no room for a hover
  /// affordance in an 80-px cell, and without this the `MouseRegion` below
  /// would mount and `setState` on every pointer crossing for nothing.
  bool get _showsTrailingHover =>
      widget.trailingHover != null &&
      !widget.compact &&
      !widget.tile &&
      !widget.disabled;

  /// The badge, plus a tooltip naming what it counts when that isn't obvious.
  /// A bare red `3` is only useful if you can find out it means "overdue".
  Widget _badgeWithTooltip() {
    final badge = SidebarBadge(
      count: widget.count!,
      active: widget.active,
      tone: widget.countTone,
    );
    final label = widget.countLabel;
    if (label == null) return badge;
    return Tooltip(
      message: '${widget.count} $label',
      waitDuration: const Duration(milliseconds: 400),
      // On a tile, `manual` for the same reason the tile's own tooltip uses it
      // — and this one is easy to miss, because it sits *inside* the tile and
      // covers only the badge glyph. A default-trigger tooltip registers its
      // `LongPressGestureRecognizer` deeper in the tree than the
      // `_BadgeModeMenuTarget` wrapped around the whole tile, so a long press
      // landing on the number opens this instead of the counter menu. It hits
      // exactly the tiles that HAVE a menu: a non-null `countLabel` means a
      // non-total badge mode, which means the entity offers more than one.
      // Rows are untouched — there the badge is beside the label, not the
      // whole target, and hover already explains it.
      triggerMode: widget.tile ? TooltipTriggerMode.manual : null,
      child: badge,
    );
  }

  /// Row tooltip text in compact mode. The collapsed rail shows a coloured dot
  /// with no number, so the count and what it counts ride along here — this is
  /// the only place that information exists when the sidebar is collapsed.
  String get _compactTooltip {
    final label = widget.countLabel;
    final count = widget.count;
    if (label == null || count == null || count == 0) return widget.label;
    return '${widget.label} — $count $label';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final fg = widget.disabled
        ? tokens.ink4
        : widget.active
        ? tokens.accentInk
        : tokens.ink2;
    final iconFg = widget.disabled
        ? tokens.ink4
        : widget.active
        ? tokens.accent
        : tokens.ink3;
    final bg = widget.active ? tokens.accentSoft : Colors.transparent;
    final effectiveOnTap = widget.disabled
        ? () => Notify.info(
            context,
            context.tr('feature_coming_soon', {'feature': widget.label}),
          )
        : widget.onTap;
    final iconWidget = Icon(widget.icon, size: 18, color: iconFg);
    final isTile = !widget.compact && widget.tile;
    final body = widget.compact
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Align(
              alignment: Alignment.centerLeft,
              child: widget.count != null && widget.count! > 0
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        iconWidget,
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            key: const Key('clients-badge-dot'),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: SidebarBadge.dotColorFor(
                                tokens,
                                widget.countTone,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: tokens.surface,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : iconWidget,
            ),
          )
        : isTile
        ? Padding(
            // Same "no fixed height" rule as the row below — the label is free
            // to grow with the text scaler, and equal heights across a grid run
            // come from `SidebarNavGrid`'s IntrinsicHeight, never from here.
            padding: const EdgeInsets.symmetric(
              horizontal: InSpacing.xs,
              vertical: InSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    iconWidget,
                    // One slot, because a row never sets both `trailing` and
                    // `count` (see the field docs). `trailing` is not
                    // decoration here — on the Reports tile it is the Pro lock,
                    // the only signal the destination is gated before you tap
                    // it — so it wins, and the badge keeps its *number* rather
                    // than degrading to the rail's dot, which exists only
                    // because 64 px has no room for digits.
                    if (widget.trailing != null) ...[
                      const SizedBox(width: 4),
                      widget.trailing!,
                    ] else if (widget.count != null && widget.count! > 0) ...[
                      const SizedBox(width: 4),
                      _badgeWithTooltip(),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: widget.active
                        ? FontWeight.w600
                        : FontWeight.w500,
                    height: 1.2,
                    color: fg,
                  ),
                ),
              ],
            ),
          )
        : Padding(
            // No fixed row height. The 18px icon sets the row's minimum and
            // the label is free to grow with the text scaler. A hard
            // `SizedBox(height: 18)` here used to clamp the label's line box
            // and slice the descenders once the user's text size pushed it
            // past 18px — the app offers Large/Extra-Large and the OS
            // accessibility scaler passes through unclamped; at the default
            // (Normal) size the icon already pins the row to 18px, so this is
            // a no-op there. Regression: sidebar_nav_item_test.dart.
            // (`touch` adds a *minimum* below, which is safe for the same
            // reason a fixed height wasn't: it can only add space, never take
            // the label's line box away.)
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              children: [
                iconWidget,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.active
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: fg,
                    ),
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 4),
                  widget.trailing!,
                ] else ...[
                  // The hover `+` and the badge coexist. They used to be
                  // mutually exclusive, which was harmless for a plain total
                  // but not once the number can be a red "3 overdue" — hovering
                  // a row must not hide the thing it's warning you about. The
                  // label ellipsizes to make room, as it already did.
                  if (_showsTrailingHover && _hovered) ...[
                    const SizedBox(width: 4),
                    widget.trailingHover!,
                  ],
                  if (widget.count != null && widget.count! > 0) ...[
                    const SizedBox(width: 6),
                    _badgeWithTooltip(),
                  ],
                ],
              ],
            ),
          );
    // The tile's outline. Border-only and *inside* the Material below, never an
    // `Ink` and never an opaque fill: the Material owns the colour so the
    // InkWell's ripple paints above it and still shows through this Container.
    // Painting the fill here instead would hide the ripple entirely — the
    // idiom `test/lint/no_ink_widget_test.dart` exists to enforce.
    final Widget shapedBody = isTile
        ? Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.active ? tokens.accent : tokens.border,
              ),
              borderRadius: BorderRadius.circular(InRadii.r2),
            ),
            child: body,
          )
        : body;
    // The interactive surface: fill + ripple + hit area. Named for what it is
    // rather than `tile`, which now means the grid variant a few lines up.
    final surface = Material(
      color: bg,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: InkWell(
        onTap: effectiveOnTap,
        borderRadius: BorderRadius.circular(InRadii.r2),
        // Inside the InkWell so the ripple and the hit area both fill the
        // target, and the Material above sizes to it so an active row's accent
        // background does too. `minHeight`, never `SizedBox(height:)` — see the
        // padding comment above; the Row centres its icon inside the extra
        // space, which reads as the `vertical: 13` the app's other
        // thumb-friendly rows use.
        child: widget.touch
            ? ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: InSizes.touchTarget,
                ),
                child: shapedBody,
              )
            : shapedBody,
      ),
    );
    Widget result = surface;
    if (_showsTrailingHover) {
      result = MouseRegion(
        onEnter: (_) {
          if (!_hovered) setState(() => _hovered = true);
        },
        onExit: (_) {
          if (_hovered) setState(() => _hovered = false);
        },
        child: result,
      );
    }
    if (widget.disabled) {
      return Tooltip(
        message: context.tr('coming_soon'),
        waitDuration: const Duration(milliseconds: 600),
        child: result,
      );
    }
    if (widget.leaderKey != null) {
      // Advertise the `G`-then-letter leader jump. Covers compact mode too
      // (which otherwise shows only the bare label tooltip) since the label
      // rides along in the shortcut tooltip.
      return ShortcutTooltip(
        // Compact rows fold the count into the label — the collapsed rail's
        // dot has no number, and this tooltip is the only text it gets. A
        // tile does the same: it ellipsizes a long single word and has no
        // width to grow into, so the full label has to ride the tooltip.
        label: widget.compact || isTile ? _compactTooltip : widget.label,
        keys: ['G', widget.leaderKey!],
        sequence: true,
        waitDuration: const Duration(milliseconds: 600),
        // This branch is reached BEFORE the `isTile` one below, so without
        // this the four entities that have a leader key — client, invoice,
        // product, task — silently lost the manual trigger that branch
        // exists to set, and with it the badge-mode long-press menu wrapped
        // around them. See the comment there for the full mechanism; the
        // short version is that a default-trigger tooltip registers its own
        // recognizer deeper in the tree and wins the arena. Those four are
        // exactly the entities with >1 badge mode, so every grid tile that
        // HAS a counter menu was the one that couldn't open it.
        triggerMode: isTile ? TooltipTriggerMode.manual : null,
        child: result,
      );
    }
    if (isTile) {
      // A tile ellipsizes a long single word ("Transactions" once the text
      // scale passes Normal, and far sooner in German), and unlike the row it
      // has no width to grow into — so the full label rides along here.
      //
      // `manual`, and that is load-bearing rather than tidy. The default
      // (`longPress`) makes `RawTooltip._handlePointerDown` register its own
      // `LongPressGestureRecognizer` from a `Listener` *below* this widget, so
      // it enters the gesture arena ahead of `_BadgeModeMenuTarget`'s
      // `onLongPressStart` wrapped around the outside, wins on the same 500 ms
      // deadline, and rejects it. On touch — which is the whole audience for
      // the grid — that would leave every tile answering a long press with its
      // own label instead of the "what should this count?" menu, and there is
      // no right-click there to fall back on. Hover is unaffected: trigger mode
      // "does not affect mouse devices" (`raw_tooltip.dart:352`), which is
      // reached through a `MouseRegion` rather than the arena.
      return Tooltip(
        message: _compactTooltip,
        triggerMode: TooltipTriggerMode.manual,
        waitDuration: const Duration(milliseconds: 600),
        child: result,
      );
    }
    if (widget.compact) {
      // Enabled items also need a tooltip in compact mode — the label is the
      // only thing telling the user what this icon is.
      return Tooltip(
        message: _compactTooltip,
        waitDuration: const Duration(milliseconds: 600),
        child: result,
      );
    }
    return result;
  }
}
