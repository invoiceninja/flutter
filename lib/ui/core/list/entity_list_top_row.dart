import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_column_picker_sheet.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/saved_views_button.dart';
import 'package:admin/ui/core/widgets/shortcut_tooltip.dart';

/// One [InSizes.headerRow]-tall slot for something that sits BESIDE the
/// search field in a header row — a button, or the whole selection row.
///
/// The row is top-aligned and the search field in it can be several lines
/// tall, so each sibling gets a fixed first-line slot to be centred in:
/// otherwise the "New" button slid down the header every time a chip wrapped.
///
/// The slot is a floor with a ceiling that only moves with the text scale. At
/// the default scale that is exactly [InSizes.headerRow] — which matters on a
/// touch platform, where a button's layout box is padded to 48 px and would
/// otherwise make every header 3 px taller than the sidebar row it lines up
/// with. (The old fixed-height `AppBar` clamped that padding the same way.)
/// At a larger text scale the ceiling lifts, so a label is never sliced.
class HeaderRowSlot extends StatelessWidget {
  const HeaderRowSlot({required this.child, this.expand = false, super.key});

  final Widget child;

  /// True when [child] is a row of its own that should fill the slot's width
  /// (the selection chrome); false for a single button, which keeps its own.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    const floor = InSizes.headerRow;
    final ceiling = math.max(
      floor,
      MediaQuery.textScalerOf(context).scale(floor),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: floor, maxHeight: ceiling),
      child: Center(widthFactor: expand ? null : 1, child: child),
    );
  }
}

/// Wide-mode page header: primary "new" action, token search field, columns
/// picker — all in one row. Rendered by [EntityListAppBar].
///
/// Top-aligned: the search field wraps its chips and may be several lines
/// tall, and everything beside it stays on the first line ([HeaderRowSlot]).
///
/// Generic over the [GenericListViewModel] so every entity list screen
/// shares the same chrome — only the per-entity [searchField] differs.
class EntityListTopRow<T> extends StatelessWidget {
  const EntityListTopRow({
    required this.vm,
    required this.newRoute,
    required this.newLabelKey,
    required this.searchField,
    this.extraActions = const [],
    this.canCreate = true,
    super.key,
  });

  final GenericListViewModel<T> vm;

  /// Route the "New X" button navigates to (e.g. `/clients/new`).
  final String newRoute;

  /// Localization key for the primary button label (e.g. `new_client`).
  final String newLabelKey;

  /// When false, the "New X" button is rendered but disabled. Used by
  /// plan-gated screens so a free-plan user can't start a new entity.
  final bool canCreate;

  /// Feature-built token search field. Each entity supplies its own
  /// `FilterKey` set, so the widget is built by the caller.
  final Widget searchField;

  /// Optional entity-specific actions rendered at the *trailing edge* of
  /// the row, after the Saved Views button — e.g. the Tasks list/kanban
  /// toggle. Anchored right so the affordance keeps its position when the
  /// user navigates between sections that drop the Columns / Saved Views
  /// buttons (e.g. switching to the kanban view). Each entry is rendered
  /// with a 12 px gap before it; pass an empty list to opt out.
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Primary action leads the row. The `minimumSize` override fixes a
    // Flutter flex-first-pass sizing bug — without a finite minimum,
    // `_RenderInputPadding` collapses to invalid constraints when an
    // `Expanded` sibling sits next to it.
    final newButton = FilledButton.icon(
      onPressed: canCreate ? () => context.go(newRoute) : null,
      icon: const Icon(Icons.add, size: 18),
      label: Text(context.tr(newLabelKey)),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Only advertise the `N` shortcut when creating is enabled (the
        // shortcut itself is canCreate-gated).
        HeaderRowSlot(
          child: canCreate
              ? ShortcutTooltip(
                  label: context.tr(newLabelKey),
                  keys: const ['N'],
                  child: newButton,
                )
              : newButton,
        ),
        const SizedBox(width: 16),
        // The token field carries every filter dimension. It fills the row
        // between the New button and the Columns button; `Expanded` still
        // keeps the Columns button glued to the row's trailing edge
        // (24 px from the screen, flush with the table card below).
        Expanded(child: searchField),
        const SizedBox(width: 12),
        HeaderRowSlot(
          child: OutlinedButton.icon(
            onPressed: () => _openColumnsPicker(context),
            icon: const Icon(Icons.view_column_outlined, size: 14),
            label: Text(
              context.tr('columns'),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.ink2,
              side: BorderSide(color: tokens.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(InRadii.r1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 36),
            ),
          ),
        ),
        const SizedBox(width: 12),
        HeaderRowSlot(child: SavedViewsButton<T>(vm: vm)),
        for (final w in extraActions) ...[
          const SizedBox(width: 12),
          HeaderRowSlot(child: w),
        ],
      ],
    );
  }

  void _openColumnsPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EntityColumnPickerSheet<T>(
        initial: vm.columnIds,
        // The decorated registry: custom-field slots under the company's own
        // labels, unconfigured slots omitted.
        allColumns: vm.availableColumns,
        onApply: vm.setColumns,
        onReset: vm.resetColumns,
      ),
    );
  }
}

/// Slim toolbar for an embedded related-entity list (a detail-screen tab):
/// just the token search field + a compact "+ New" button — no Columns /
/// Saved Views (matches the React client-detail layout). At every width the
/// search field fills and the "+ New" button trails on the same row; the
/// entity-specific label is moved to the button's tooltip to save space.
class EmbeddedListTopRow extends StatelessWidget {
  const EmbeddedListTopRow({
    required this.searchField,
    required this.newRoute,
    required this.newLabelKey,
    required this.wide,
    this.canCreate = true,
    this.showNew = true,
    this.onNewPressed,
    super.key,
  });

  /// False leaves the New button out altogether — the parent record is
  /// read-only, so there is nothing to explain by greying it.
  final bool showNew;

  final Widget searchField;
  final String newRoute;
  final String newLabelKey;
  final bool wide;
  final bool canCreate;

  /// Parent-prefilled create handler. Falls back to `context.go(newRoute)`.
  final void Function(BuildContext context)? onNewPressed;

  @override
  Widget build(BuildContext context) {
    final onNew = !canCreate
        ? null
        : () => (onNewPressed ?? (ctx) => ctx.go(newRoute))(context);
    final newButton = Tooltip(
      message: context.tr(newLabelKey),
      child: FilledButton.icon(
        onPressed: onNew,
        icon: const Icon(Icons.add, size: 18),
        label: Text(context.tr('new')),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
    // Top-aligned for the same reason as [EntityListTopRow]: the field can
    // wrap, and "New" stays level with its first line.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: searchField),
        if (showNew) ...[
          const SizedBox(width: 12),
          HeaderRowSlot(child: newButton),
        ],
      ],
    );
  }
}
