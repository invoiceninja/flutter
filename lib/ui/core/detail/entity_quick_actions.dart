import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';

/// One candidate for a record's quick-action strip: an existing
/// [EntityActionItem] plus what a tile needs that a menu row does not.
///
/// The strip is a second *render* of actions the record already has, never a
/// second definition — gating, the confirmation prompt and the unsynced guard
/// all stay on [item].
@immutable
class EntityQuickAction<A> {
  const EntityQuickAction({
    required this.item,
    required this.shortLabel,
    this.applies = true,
    this.busy,
  });

  final EntityActionItem<A> item;

  /// A one- or two-word label that fits a ~70 px tile in every locale: the
  /// entity noun ("Invoice"), not the menu's verb phrase ("New Invoice" is
  /// "Nieuwe factuur", and "Klantenportaal" alone is 77 px). The full
  /// `item.label` is what a tooltip and a screen reader get.
  final String shortLabel;

  /// Whether this action is worth a tile *for this record right now* — Enter
  /// Payment only while something is owed, Call only when there is a number.
  /// Distinct from `item.enabled`, which says whether it can run at all: an
  /// action that does not apply here stays available from the `⋮` menu.
  final bool applies;

  /// True while the action is in flight (a timer starting). The tile stays in
  /// place, inert, rather than vanishing and shifting its neighbours.
  final ValueListenable<bool>? busy;
}

/// The first [max] entries of [priority] that both apply and are visible.
///
/// Order is the host's ranking of what a user most often does from this
/// record; a higher-ranked action that does not apply simply yields its slot
/// to the next one.
List<EntityQuickAction<A>> pickQuickActions<A>(
  Iterable<EntityQuickAction<A>> priority, {
  required int max,
}) => [
  for (final q in priority)
    if (q.applies && q.item.isVisible) q,
].take(max).toList(growable: false);

/// Finds the item for [kind] anywhere in [items], including inside a group's
/// fly-out — New Invoice lives under the "Create New" parent.
EntityActionItem<A>? findActionItem<A>(
  List<EntityActionItem<A>> items,
  A kind,
) {
  for (final item in items) {
    if (item.kind == kind && !item.hasChildren) return item;
    final children = item.children;
    if (children != null) {
      final nested = findActionItem<A>(children, kind);
      if (nested != null) return nested;
    }
  }
  return null;
}

/// How many tiles fit: four in the pane or on a phone, six once the strip has
/// room for them at a width a label can still be read in.
const double kQuickActionsWideWidth = 560;
const int kQuickActionsNarrowMax = 4;
const int kQuickActionsWideMax = 6;

/// A row of equal-width tiles for the few things a user most often does from
/// a record — bill it, take a payment, get hold of someone.
///
/// Builds nothing, and takes no space, when no action applies. Otherwise it
/// **owns its trailing gap**, because whether it is empty can change after the
/// host has laid it out (see `EntityRecordColumn.quickActions`).
///
/// Tiles sit on `surface` with the card border and shadow, not on
/// `surfaceAlt`: the alternate surface is 1.04-1.22:1 against the page in
/// every palette, which does not read as something to press. They are also
/// deliberately neutral rather than accent-tinted — the accent is the user's
/// own choice, and a red or green one would read as overdue or paid.
///
/// Every tile holds exactly one line of label, at a size that scales down to
/// fit rather than wrapping.
class EntityQuickActions<A> extends StatelessWidget {
  const EntityQuickActions({super.key, required this.priority});

  final List<EntityQuickAction<A>> priority;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final picked = pickQuickActions<A>(
          priority,
          max: constraints.maxWidth >= kQuickActionsWideWidth
              ? kQuickActionsWideMax
              : kQuickActionsNarrowMax,
        );
        if (picked.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: EdgeInsets.only(bottom: InSpacing.lg(context)),
          // `IntrinsicHeight` + stretch: a label that scales down to fit is
          // also a pixel or two shorter, which left that tile's bottom edge
          // above its neighbours'. Legal here — the tiles hold no
          // `LayoutBuilder`; being *under* one, as this is, is not the problem.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < picked.length; i++) ...[
                  if (i > 0) const SizedBox(width: InSpacing.sm),
                  Expanded(child: _QuickActionTile<A>(action: picked[i])),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionTile<A> extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final EntityQuickAction<A> action;

  @override
  Widget build(BuildContext context) {
    final busy = action.busy;
    if (busy == null) return _build(context, busy: false);
    return ValueListenableBuilder<bool>(
      valueListenable: busy,
      builder: (context, isBusy, _) => _build(context, busy: isBusy),
    );
  }

  Widget _build(BuildContext context, {required bool busy}) {
    final tokens = context.inTheme;
    final item = action.item;
    final handler = (busy || !item.enabled)
        ? null
        : guardedOnTap<A>(context, item);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(InRadii.r2),
      side: BorderSide(color: tokens.border),
    );
    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        enabled: handler != null,
        label: item.label,
        onTap: handler,
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(InRadii.r2),
            boxShadow: tokens.shadow1,
          ),
          // The colour is painted by this `Material`, not by a box above it,
          // so the ink it hosts is visible.
          child: Material(
            color: tokens.surface,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: handler,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: kQuickTileHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: InSpacing.sm,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (busy)
                        const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          item.icon,
                          size: 20,
                          color: handler == null ? tokens.ink4 : tokens.ink2,
                        ),
                      const SizedBox(height: InSpacing.xs),
                      // Scales down rather than wrapping or ellipsizing: a
                      // second line would make this tile taller than its
                      // neighbours, and a clipped label is a guess.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          action.shortLabel,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: handler == null ? tokens.ink3 : tokens.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tile's floor. Above the 44 px touch target on its own, so there is no
/// separate touch branch — and a floor, not a height, so a large text scale
/// grows the row instead of clipping the label.
const double kQuickTileHeight = 56;
