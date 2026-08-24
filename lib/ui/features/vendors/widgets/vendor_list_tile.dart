import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/vendor_columns.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/initials_avatar.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_actions.dart';
import 'package:admin/utils/formatting.dart';

/// One row in the vendors list. Adopts the v2 design system anatomy from
/// `docs/design/v2/screens.jsx:577-596` — square-ish tinted avatar, two
/// lines of identity, right-aligned monospace money columns.
///
/// Mirrors `ClientListTile` structurally; differs only in the data
/// accessors (Vendor has no displayName cascade beyond name → contact
/// fallback, and no money column at all — vendors have no server-side
/// balance).
class VendorListTile extends StatefulWidget {
  const VendorListTile({
    super.key,
    required this.vendor,
    required this.formatter,
    required this.onTap,
    required this.wide,
    this.editable = true,
    this.columns = const <VendorColumn>[],
    this.onAction,
    this.onLongPress,
    this.onSelectTap,
    this.selecting = false,
    this.selected = false,
    this.urlSelected = false,
    this.hideBottomDivider = false,
  });

  final Vendor vendor;

  /// Built from `Services.formatterFor(companyId)` by the parent screen.
  /// Null while the screen's `formatterFor` future is still resolving — in
  /// that transient state money columns render as `—`.
  final Formatter? formatter;

  /// Columns to render in wide mode. The narrow layout ignores this — mobile
  /// shows the rich identity card only.
  final List<VendorColumn> columns;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectTap;
  final bool wide;

  /// False when the row is archived/soft-deleted; greys the wide-table
  /// standalone edit pencil. Sourced from `EntityListTileOptions.editable`.
  final bool editable;
  final ValueChanged<VendorAction>? onAction;
  final bool selecting;
  final bool selected;

  /// True when this row matches the URL's `:id` (active in master-detail
  /// split view). Distinct from [selected] (multi-select) so the tile
  /// can render an unmistakable accent stripe on the left edge for
  /// URL-active rows without conflating with the bulk-select chip.
  final bool urlSelected;

  /// Suppresses the bottom hairline (last row, the selected row, or the row
  /// directly above the selected one). Computed by the list scaffold and
  /// passed straight to [SelectableListRow.hideBottomDivider].
  final bool hideBottomDivider;

  @override
  State<VendorListTile> createState() => _VendorListTileState();
}

class _VendorListTileState extends State<VendorListTile> {
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final tokens = context.inTheme;
    final displayName = _displayName(w.vendor);
    final state = _stateFor(w.vendor);

    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      child: w.wide
          ? _wide(context, tokens, displayName: displayName, state: state)
          : _narrow(context, tokens, displayName: displayName, state: state),
    );

    return Semantics(
      button: true,
      label: _semanticsLabel(
        displayName: displayName,
        state: state,
        selecting: w.selecting,
        selected: w.selected,
      ),
      child: SelectableListRow(
        selected: w.selected,
        urlSelected: w.urlSelected,
        hideBottomDivider: w.hideBottomDivider,
        onTap: w.onTap,
        onLongPress: w.onLongPress,
        child: content,
      ),
    );
  }

  Widget _narrow(
    BuildContext context,
    InTheme tokens, {
    required String displayName,
    required _RowState? state,
  }) {
    final w = widget;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _leading(displayName),
        const SizedBox(width: 12),
        Expanded(child: _identity(context, tokens, displayName)),
        if (state != null) ...[
          const SizedBox(width: 8),
          _Pill(state: state, tokens: tokens),
        ],
        if (w.onAction != null) ...[
          const SizedBox(width: 4),
          EntityActionsPopupButton<VendorAction>(
            items: VendorActions.itemsFor(context, w.vendor, w.onAction!),
          ),
        ],
      ],
    );
  }

  Widget _wide(
    BuildContext context,
    InTheme tokens, {
    required String displayName,
    required _RowState? state,
  }) {
    final w = widget;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: kColWMoreMenu,
          child: w.onAction == null
              ? const SizedBox.shrink()
              : EntityActionsPopupButton<VendorAction>(
                  splitEditAction: true,
                  editEnabled: w.editable,
                  items: VendorActions.itemsFor(context, w.vendor, w.onAction!),
                ),
        ),
        const SizedBox(width: kColActionsLeadingGap),
        _leading(displayName),
        const SizedBox(width: kColCellGap),
        for (final col in w.columns) ...[
          _CellSlot(
            column: col,
            entity: w.vendor,
            child: col.cellBuilder(w.vendor, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        SizedBox(
          width: kColWPillSlot,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: state == null
                ? const SizedBox.shrink()
                : _Pill(state: state, tokens: tokens),
          ),
        ),
      ],
    );
  }

  Widget _leading(String displayName) {
    final w = widget;
    return LeadingSelectSlot(
      selecting: w.selecting,
      selected: w.selected,
      onSelectTap: w.onSelectTap,
      defaultChild: InitialsAvatar(
        seed: w.vendor.id,
        label: initialsFor(displayName) ?? '?',
      ),
    );
  }

  Widget _identity(BuildContext context, InTheme tokens, String displayName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 2),
        _SubtitleLine(vendor: widget.vendor, tokens: tokens),
      ],
    );
  }
}

class _CellSlot extends StatelessWidget {
  const _CellSlot({
    required this.column,
    required this.entity,
    required this.child,
  });
  final VendorColumn column;
  final Vendor entity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final aligned = Align(
      alignment: column.align == ColumnAlign.end
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: child,
    );
    final cell = CellCopyHover(
      value: column.valueBuilder?.call(entity),
      align: column.align,
      child: aligned,
    );
    if (column.isFlex) {
      return Expanded(child: cell);
    }
    return SizedBox(width: column.width, child: cell);
  }
}

class _SubtitleLine extends StatelessWidget {
  const _SubtitleLine({required this.vendor, required this.tokens});
  final Vendor vendor;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final contact = _firstContact(vendor);
    final contactLabel = _contactLabel(contact);
    final city = vendor.city.trim();

    final pieces = <String>[
      if (contactLabel.isNotEmpty) contactLabel,
      if (city.isNotEmpty) city,
    ];

    String text;
    Color color;
    if (pieces.isNotEmpty) {
      text = pieces.join(' · ');
      color = tokens.ink3;
    } else if (vendor.number.isNotEmpty) {
      text = vendor.number;
      color = tokens.ink3;
    } else {
      text = '—';
      color = tokens.ink4;
    }

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 12, color: color, height: 1.25),
    );
  }
}

enum _RowState { deleted, archived, unsynced }

_RowState? _stateFor(Vendor v) {
  if (v.isDeleted) return _RowState.deleted;
  if (v.archivedAt != null) return _RowState.archived;
  if (v.isDirty) return _RowState.unsynced;
  return null;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.state, required this.tokens});
  final _RowState state;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, tooltip) = switch (state) {
      _RowState.deleted => (
        context.tr('deleted'),
        tokens.overdueSoft,
        tokens.overdue,
        context.tr('deleted_soft_delete_tooltip'),
      ),
      _RowState.archived => (
        context.tr('archived'),
        tokens.draftSoft,
        tokens.draft,
        context.tr('archived'),
      ),
      _RowState.unsynced => (
        context.tr('unsynced'),
        tokens.sentSoft,
        tokens.sent,
        context.tr('unsynced_pending_outbox_tooltip'),
      ),
    };
    return StatusPill(label: label, fgColor: fg, bgColor: bg, tooltip: tooltip);
  }
}

String _displayName(Vendor v) {
  if (v.name.isNotEmpty) return v.name;
  final c = _firstContact(v);
  if (c != null) {
    final composed = ('${c.firstName} ${c.lastName}').trim();
    if (composed.isNotEmpty) return composed;
    if (c.email.isNotEmpty) return c.email;
  }
  return '(no name)';
}

VendorContact? _firstContact(Vendor v) {
  if (v.contacts.isEmpty) return null;
  for (final c in v.contacts) {
    if (c.isPrimary) return c;
  }
  return v.contacts.first;
}

String _contactLabel(VendorContact? c) {
  if (c == null) return '';
  final name = ('${c.firstName} ${c.lastName}').trim();
  if (name.isNotEmpty) return name;
  return c.email.trim();
}

String _semanticsLabel({
  required String displayName,
  required _RowState? state,
  required bool selecting,
  required bool selected,
}) {
  final parts = <String>[];
  if (selecting) {
    parts.add(selected ? 'selected' : 'not selected');
  }
  parts.add(displayName);
  switch (state) {
    case _RowState.deleted:
      parts.add('deleted');
    case _RowState.archived:
      parts.add('archived');
    case _RowState.unsynced:
      parts.add('unsynced');
    case null:
      break;
  }
  return parts.join(', ');
}
