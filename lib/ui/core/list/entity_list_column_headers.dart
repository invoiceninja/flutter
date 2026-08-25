import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/widgets/selection_checkbox.dart';

/// Uppercase eyebrow column labels above the table rows at wide widths.
/// Iterates the VM's current `columns` so header widths and labels stay in
/// lock-step with whatever the user has chosen via the column picker.
///
/// Doubles as the desktop sort control: every header is clickable and the
/// active one shows a ↑/↓ indicator. Generic over the entity type — any
/// [GenericListViewModel] with `ColumnDefinition<T>` columns can use it.
class EntityListColumnHeaders<T> extends StatelessWidget {
  const EntityListColumnHeaders({super.key, required this.vm});

  final GenericListViewModel<T> vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: tokens.ink3,
    );
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      child: Row(
        children: [
          // Leading actions slot — empty label, mirrors row's `…` menu.
          SizedBox(width: colWMoreMenu()),
          const SizedBox(width: kColActionsLeadingGap),
          // Avatar/checkbox slot. On desktop, hovering this slot reveals a
          // select-all checkbox.
          SizedBox(
            width: kColLeadingWidth,
            child: _HeaderSelectAllSlot<T>(vm: vm),
          ),
          const SizedBox(width: kColCellGap),
          for (final col in vm.columns) ...[
            _HeaderCell<T>(column: col, labelStyle: labelStyle, vm: vm),
            const SizedBox(width: kColCellGap),
          ],
          // Pill column: reserved, unlabeled.
          const SizedBox(width: kColWPillSlot),
        ],
      ),
    );
  }
}

class _HeaderCell<T> extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.labelStyle,
    required this.vm,
  });
  final ColumnDefinition<T> column;
  final TextStyle labelStyle;
  final GenericListViewModel<T> vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final isActive = vm.sortField == column.id;
    final activeStyle = labelStyle.copyWith(color: tokens.ink2);
    final text = Text(
      context.tr(column.labelKey).toUpperCase(),
      style: isActive ? activeStyle : labelStyle,
    );
    final arrow = isActive
        ? Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
            child: Icon(
              vm.sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: tokens.ink2,
            ),
          )
        : const SizedBox.shrink();
    final isEnd = column.align == ColumnAlign.end;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: isEnd ? [arrow, text] : [text, arrow],
    );
    final content = InkWell(
      // Display-only columns (tags, notes, a derived status, a "View" link)
      // have no Drift column to order by — a null `onTap` also drops the
      // hover/ripple affordance, so the header doesn't advertise a sort it
      // can't perform. `setSort` rejects them too (via `isValidColumnId`),
      // which covers the persisted-sort and deep-link paths.
      onTap: column.sortable
          ? () => vm.setSort(
              field: column.id,
              // Flip direction only when the active field is tapped again;
              // switching field keeps the current direction.
              ascending: isActive ? !vm.sortAscending : vm.sortAscending,
            )
          : null,
      child: Align(
        alignment: isEnd
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
          // Scale the label down a hair if it would otherwise overflow its
          // fixed column width — e.g. a long uppercased label whose width edges
          // a sub-pixel past `column.width` in the bundled Inter Tight font.
          // `scaleDown` only shrinks when needed (labels that fit are untouched)
          // and, unlike the bare Row, never throws a RenderFlex overflow.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: isEnd
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: row,
          ),
        ),
      ),
    );
    if (column.isFlex) return Expanded(child: content);
    return SizedBox(width: column.width, child: content);
  }
}

/// The wide-mode column header's leading slot. Empty by default; hovers on
/// desktop reveal an empty select-all checkbox. While in multi-select the
/// checkbox is always visible and reflects whether *every* visible row is
/// selected — clicking it then toggles between "select all" and "clear".
class _HeaderSelectAllSlot<T> extends StatefulWidget {
  const _HeaderSelectAllSlot({required this.vm});
  final GenericListViewModel<T> vm;

  @override
  State<_HeaderSelectAllSlot<T>> createState() =>
      _HeaderSelectAllSlotState<T>();
}

class _HeaderSelectAllSlotState<T> extends State<_HeaderSelectAllSlot<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final selecting = vm.isInMultiselect;
    final allSelected =
        selecting && vm.items.isNotEmpty && vm.countSelected == vm.items.length;

    Widget child;
    VoidCallback? onTap;
    if (selecting) {
      child = SelectionCheckbox(checked: allSelected);
      onTap = () {
        if (allSelected) {
          vm.clearSelection();
        } else {
          vm.selectAllVisible();
        }
      };
    } else if (_isHovered && vm.items.isNotEmpty) {
      child = const SelectionCheckbox(checked: false);
      onTap = vm.selectAllVisible;
    } else {
      child = const SizedBox.shrink();
    }

    return MouseRegion(
      onEnter: (_) {
        if (!_isHovered) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (_isHovered) setState(() => _isHovered = false);
      },
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: kColLeadingWidth,
          height: kColLeadingWidth,
          child: Center(child: child),
        ),
      ),
    );
  }
}
