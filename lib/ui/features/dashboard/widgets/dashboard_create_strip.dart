import 'package:flutter/material.dart';
import 'package:overflow_view/overflow_view.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/quick_create.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_create_fab.dart';

/// The widest the strip may grow. It is what caps the number of buttons: about
/// six fit, and the rest stay under More however wide the window is. Fourteen
/// buttons across an ultrawide bar would be a toolbar nobody can scan.
const double kDashboardCreateStripMaxWidth = 720;

/// The wide dashboard's create buttons: "+ Invoice", "+ Quote", "+ Payment" …
/// for everything the user may start, in the order the phone's `+` sheet uses.
///
/// It lives in the dashboard's fixed top bar, not in the page. A row of create
/// buttons in the scrolling body is what the phone layout once had and lost
/// (invoiceninja/flutter#164): it scrolled away with the page, so the one thing
/// a user comes to the dashboard to do most was off screen as soon as they
/// read anything.
///
/// **How many show is measured, not guessed.** `OverflowView` lays out as many
/// buttons as fit and hands the rest to the More menu, so German's longer
/// nouns or a narrower window move the cut without a breakpoint table to keep
/// in step. That is also why no button here carries a `Tooltip`: `OverflowView`
/// lays its children out inside a layout callback, where an `OverlayPortal`
/// cannot mount (see `EntityOverflowActionBar`).
///
/// Renders nothing — and takes no space — when [options] is empty, so a user
/// who may create nothing gets no strip rather than an empty one.
class DashboardCreateStrip extends StatelessWidget {
  const DashboardCreateStrip({
    super.key,
    required this.options,
    required this.onCreate,
  });

  /// What the user may create, already gated by `quickCreateEntities` and in
  /// its order. The first is drawn as the primary.
  final List<QuickCreateOption> options;

  final ValueChanged<EntityType> onCreate;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: kDashboardCreateStripMaxWidth,
      ),
      child: OverflowView.flexible(
        spacing: InSpacing.sm,
        children: [
          for (var i = 0; i < options.length; i++)
            _CreateButton(
              option: options[i],
              primary: i == 0,
              onTap: () => onCreate(options[i].type),
            ),
        ],
        builder: (context, remaining) {
          // `remaining` counts hidden children from the end. Clamped: in a slot
          // too tight for even the first button it can reach the whole list.
          final hidden = remaining > options.length
              ? options.length
              : remaining;
          return _MoreCreates(
            options: options.sublist(options.length - hidden),
            onCreate: onCreate,
          );
        },
      ),
    );
  }
}

/// One height for every button in the strip. The theme floors a filled button
/// at 44 and an outlined one at 40, which left the primary 4 px taller than
/// its neighbours; on touch all of them take the touch target.
double _stripButtonHeight() => Env.isTouchPrimary ? InSizes.touchTarget : 40;

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.option,
    required this.primary,
    required this.onTap,
  });

  final QuickCreateOption option;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = Size(64, _stripButtonHeight());
    const icon = Icon(Icons.add, size: 16);
    final label = Text(
      context.tr(quickCreateNounKey(option.type)),
      maxLines: 1,
      softWrap: false,
    );
    final Widget button = primary
        ? FilledButton.icon(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              minimumSize: size,
              maximumSize: Size(double.infinity, size.height),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: icon,
            label: label,
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              maximumSize: Size(double.infinity, size.height),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: icon,
            label: label,
          );
    // The visible label is the bare noun beside a `+`; a screen reader gets the
    // full phrase the phone's sheet and the list screens use ("New Invoice",
    // "Enter Payment"). `onTap` is re-declared because `excludeSemantics`
    // drops the button's own.
    return Semantics(
      button: true,
      label: context.tr(quickCreateLabelKey(option.type)),
      onTap: onTap,
      excludeSemantics: true,
      child: button,
    );
  }
}

/// The creates that did not fit, under a labelled More button drawn like its
/// neighbours.
class _MoreCreates extends StatelessWidget {
  const _MoreCreates({
    required this.options,
    required this.onCreate,
    this.compact = false,
  });

  final List<QuickCreateOption> options;
  final ValueChanged<EntityType> onCreate;

  /// A square filled `+` instead of a labelled "More" — the whole strip in one
  /// button, for a slot too tight for anything else.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = _stripButtonHeight();
    return BackDismissibleMenuAnchor(
      consumeOutsideTap: true,
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            leadingIcon: Icon(option.icon, size: 18),
            onPressed: () => onCreate(option.type),
            child: Text(context.tr(quickCreateLabelKey(option.type))),
          ),
      ],
      builder: (context, controller, _) {
        void toggle() =>
            controller.isOpen ? controller.close() : controller.open();
        if (compact) {
          return IconButton.filled(
            tooltip: context.tr('create'),
            onPressed: toggle,
            icon: const Icon(Icons.add, size: 20),
            constraints: BoxConstraints.tightFor(width: height, height: height),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(InRadii.r2),
              ),
            ),
          );
        }
        return OutlinedButton.icon(
          onPressed: toggle,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(64, height),
            maximumSize: Size(double.infinity, height),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.more_vert, size: 18),
          label: Text(context.tr('more')),
        );
      },
    );
  }
}

/// Width (and height) of [DashboardCreateMenuButton].
double dashboardCreateMenuButtonExtent() => _stripButtonHeight();

/// Every create behind one `+` button — what the strip becomes in a slot too
/// tight for a labelled button. The wide layout has no `+` FAB, so however
/// little room the bar has, creating something must stay one tap and a pick
/// away.
class DashboardCreateMenuButton extends StatelessWidget {
  const DashboardCreateMenuButton({
    super.key,
    required this.options,
    required this.onCreate,
  });

  final List<QuickCreateOption> options;
  final ValueChanged<EntityType> onCreate;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) return const SizedBox.shrink();
    return _MoreCreates(options: options, onCreate: onCreate, compact: true);
  }
}
