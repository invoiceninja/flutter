import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/domain/vendor_contact.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/vendor_columns.dart';
import 'package:admin/domain/contact_label.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/initials_avatar.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/core/widgets/party_call_button.dart';
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
    this.onViewRecord,
    this.selecting = false,
    this.selected = false,
    this.urlSelected = false,
    this.hideBottomDivider = false,
  });

  final Vendor vendor;

  /// Built from `Services.formatterFor(companyId)` by the parent screen.
  /// Null while the screen's `formatterFor` future is still resolving. The
  /// narrow row has no money at all (see the class doc), so this only reaches
  /// the wide table's column cells, which format through `FormatterScope`.
  final Formatter? formatter;

  /// Columns to render in wide mode. The narrow layout ignores this — mobile
  /// shows the rich identity card only.
  final List<VendorColumn> columns;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSelectTap;

  /// Navigates to this vendor's record, unconditionally — unlike [onTap],
  /// which toggles selection in multi-select mode and *closes* the pane when
  /// the row is already URL-selected. Feeds the "View vendor" footer of the
  /// narrow row's call-button picker. See `ClientListTile.onViewRecord`.
  final VoidCallback? onViewRecord;
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
    final displayName = _displayName(context, w.vendor);
    final state = _stateFor(w.vendor);

    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      child: w.wide
          ? _wide(context, tokens, displayName: displayName, state: state)
          : _narrow(
              context,
              tokens,
              displayName: displayName,
              state: state,
              callButton: _callButton(displayName),
            ),
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

  /// The narrow row's dial affordance (invoiceninja/flutter#111) — the
  /// `ClientListTile._callButton` twin; see there for why the candidate walk
  /// runs before the preference check and why it hides in multi-select.
  ///
  /// No `clientId:`: a vendor has no settings cascade of its own, so the
  /// picker correctly omits the local-time line rather than quoting the
  /// *company's* zone under `Call <vendor>`.
  Widget? _callButton(String displayName) {
    final w = widget;
    if (w.selecting) return null;
    final candidates = vendorPhoneCandidates(w.vendor);
    if (candidates.isEmpty) return null;
    return PhoneCallButton(
      variant: PhoneCallButtonVariant.listRow,
      candidates: candidates,
      partyName: displayName,
      onViewParty: w.onViewRecord,
      viewPartyLabelKey: 'view_vendor',
      logTarget: (
        type: EntityType.vendor,
        id: w.vendor.id,
        subject: displayName,
      ),
    );
  }

  Widget _narrow(
    BuildContext context,
    InTheme tokens, {
    required String displayName,
    required _RowState? state,
    required Widget? callButton,
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
        // Trailing action cluster — see `ClientListTile._narrow` for why both
        // controls hang off the row's right edge, why the gap below widens to 8
        // only when the call button is present, and why it is `InSpacing.sm`
        // rather than the wide table's `kColActionsClusterGap`.
        if (callButton != null) callButton,
        if (w.onAction != null) ...[
          SizedBox(width: callButton != null ? InSpacing.sm : 4),
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
          width: colWMoreMenu(),
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
        _SubtitleLine(
          vendor: widget.vendor,
          tokens: tokens,
          partyName: displayName,
        ),
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
  const _SubtitleLine({
    required this.vendor,
    required this.tokens,
    required this.partyName,
  });
  final Vendor vendor;
  final InTheme tokens;

  /// The title rendered directly above this line. The client twin gets its
  /// duplicate from the server; here [_displayName] runs the same
  /// name -> contact-name -> contact-email cascade itself, so a nameless vendor
  /// printed its contact's name twice with no help at all
  /// (invoiceninja/flutter#118).
  final String partyName;

  @override
  Widget build(BuildContext context) {
    final contact = _firstContact(vendor);
    final contactLabel = contact == null
        ? ''
        : contactSubtitleLabel(
            contactName: '${contact.firstName} ${contact.lastName}',
            contactEmail: contact.email,
            partyName: partyName,
          );
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
      // Blank rather than a dash, matching `ClientListTile`'s subtitle
      // (invoiceninja/flutter#112). Still a rendered `Text`: an empty one keeps
      // its full line box at the current text scale, so the name above holds
      // its vertical position instead of zigzagging down a scrolled list.
      text = '';
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

String _displayName(BuildContext context, Vendor v) {
  if (v.name.isNotEmpty) return v.name;
  final c = _firstContact(v);
  if (c != null) {
    final composed = ('${c.firstName} ${c.lastName}').trim();
    if (composed.isNotEmpty) return composed;
    if (c.email.isNotEmpty) return c.email;
  }
  return context.tr('no_name_fallback');
}

VendorContact? _firstContact(Vendor v) {
  if (v.contacts.isEmpty) return null;
  for (final c in v.contacts) {
    if (c.isPrimary) return c;
  }
  return v.contacts.first;
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
