import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/list_density_controller.dart';
import 'package:admin/l10n/localization.dart';

/// The toggle's side: 36 px with a pointer, the 44 px touch target on touch.
/// `EntityListTopRow` budgets the toolbar with it.
double listDensityToggleSize() => Env.isTouchPrimary ? InSizes.touchTarget : 36;

/// One-click Normal ↔ Compact switch for the list density, beside the wide
/// list toolbar's Columns button — where a user who can't see enough rows is
/// already looking. Device Settings → List density is the same preference;
/// both write the one [ListDensityController].
///
/// A Material 3 toggle: the icon shows the current density and turns accent
/// while Compact is on, the tooltip (also its semantic label) names it, and the
/// list reflowing behind it is the rest of the feedback. Bordered and `r1`
/// like the Columns button it sits beside; 36 px with a pointer, the 44 px
/// touch target on touch. See `docs/list-density.md`.
class ListDensityToggle extends StatelessWidget {
  const ListDensityToggle({super.key, required this.controller});

  final ListDensityController controller;

  @override
  Widget build(BuildContext context) {
    // Listens itself rather than trusting its host to rebuild it: a host that
    // passes the controller straight in would otherwise show a stale state.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _button(context),
    );
  }

  Widget _button(BuildContext context) {
    final tokens = context.inTheme;
    final compact = controller.isCompact;
    final size = listDensityToggleSize();
    return IconButton(
      isSelected: compact,
      onPressed: controller.toggle,
      tooltip:
          '${context.tr('list_density')}: '
          '${context.tr(compact ? 'compact' : 'normal')}',
      icon: const Icon(Icons.density_medium_outlined, size: 16),
      selectedIcon: const Icon(Icons.density_small_outlined, size: 16),
      style: IconButton.styleFrom(
        side: BorderSide(color: tokens.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InRadii.r1),
        ),
        fixedSize: Size.square(size),
        minimumSize: Size.square(size),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
