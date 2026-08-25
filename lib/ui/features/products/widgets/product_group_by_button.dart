import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/products/view_models/product_list_view_model.dart';

/// Wide-screen "Group by" control for the products list, injected through
/// `EntityListScreenScaffold.extraAppBarActions` (the slot the Tasks
/// list/kanban toggle uses). Phones get the same choice inside the sort
/// bottom sheet instead — their AppBar already carries select + sort, and a
/// third unlabelled glyph would bury the feature.
///
/// A `PopupMenuButton`, not a `SegmentedButton`: the labels are the company's
/// own custom-field names, so they're variable-length and can't be budgeted
/// for (`tags_screen.dart` outgrew exactly that toggle).
class ProductGroupByButton extends StatelessWidget {
  const ProductGroupByButton({required this.vm, super.key});

  /// Stands in for "no grouping" so the menu never carries a `null` **value**.
  ///
  /// `PopupMenuButton<T>` cannot tell a null-valued selection from a dismissal
  /// — `_PopupMenuButtonState._showButtonMenu` awaits `showMenu<T?>` and does
  /// `if (newValue == null) { onCanceled?.call(); return; }` *before* reaching
  /// `onSelected` (`material/popup_menu.dart`). Typed `String?` with a
  /// `value: null` row, this menu's No-grouping entry therefore never called
  /// `vm.setGroupField(null)`, and since the wide AppBar branch carries no sort
  /// sheet, a grouped desktop list had no way back to ungrouped at all.
  ///
  /// Empty string is safe as the sentinel: a grouping id is either
  /// [kProductGroupTags] or a `ProductFieldIds.custom*` key, never blank.
  static const String _kNoGrouping = '';

  final ProductListViewModel vm;

  String _labelFor(BuildContext context, String id) =>
      id == kProductGroupTags ? context.tr('tags') : vm.groupFieldLabel(id);

  @override
  Widget build(BuildContext context) {
    final ids = vm.availableGroupFieldIds;
    // Nothing groupable (no populated custom field, no tagged row) — don't
    // render a control whose every option would be a no-op. Safe to hide only
    // because `availableGroupFieldIds` always retains the active dimension, so
    // this can't hide the off switch out from under a grouped list.
    if (ids.isEmpty) return const SizedBox.shrink();

    final tokens = context.inTheme;
    // The *effective* grouping, so a choice whose slot the company has
    // un-configured reads as off rather than captioning a dead label.
    final active = vm.effectiveGroupField;
    final activeLabel = active == null ? null : _labelFor(context, active);
    // Tinted + named while grouping is on, so a regrouped list never reads as
    // one that mysteriously re-sorted itself.
    final on = activeLabel != null && activeLabel.isNotEmpty;

    return PopupMenuButton<String>(
      tooltip: context.tr('group_by'),
      initialValue: active ?? _kNoGrouping,
      onSelected: (id) => vm.setGroupField(id == _kNoGrouping ? null : id),
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: _kNoGrouping,
          child: Text(context.tr('no_grouping')),
        ),
        for (final id in ids)
          PopupMenuItem<String>(value: id, child: Text(_labelFor(context, id))),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.md(context),
          vertical: InSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: on ? tokens.accent : tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.segment,
              size: 16,
              color: on ? tokens.accent : tokens.ink2,
            ),
            const SizedBox(width: InSpacing.sm),
            Text(
              on ? activeLabel : context.tr('group_by'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: on ? tokens.accent : tokens.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
