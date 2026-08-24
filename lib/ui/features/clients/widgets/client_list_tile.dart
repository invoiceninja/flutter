import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';
import 'package:admin/ui/core/widgets/initials_avatar.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/clients/widgets/client_actions.dart';
import 'package:admin/utils/formatting.dart';

// Legacy column widths consumed by the screen's `_ColumnHeaders` strip
// while the columns refactor is in flight. Safe to remove once the header
// migrates to the `ClientColumn`-driven layout.
const double kColWOutstanding = 140;
const double kColWLifetime = 120;

/// One row in the clients list. Adopts the v2 design system anatomy from
/// `docs/design/v2/screens.jsx:577-596` — square-ish tinted avatar, two
/// lines of identity, right-aligned monospace money columns.
///
/// The wide/narrow decision lives on the caller (typically a screen-level
/// `LayoutBuilder`) so the screen can decide whether to render a column
/// header strip above the rows. Pass [wide] in.
class ClientListTile extends StatefulWidget {
  const ClientListTile({
    super.key,
    required this.client,
    required this.formatter,
    required this.onTap,
    required this.wide,
    this.editable = true,
    this.columns = const <ClientColumn>[],
    this.onAction,
    this.onLongPress,
    this.onSelectTap,
    this.selecting = false,
    this.selected = false,
    this.urlSelected = false,
    this.hideBottomDivider = false,
  });

  final Client client;

  /// Built from `Services.formatterFor(companyId)` by the parent screen.
  /// Resolves per-client currency overrides via `client.currencyId`. Null
  /// while the screen's `formatterFor` future is still resolving — in that
  /// transient state the money columns render as `—`.
  final Formatter? formatter;

  /// Columns to render in wide mode. Empty list falls back to the legacy
  /// outstanding/lifetime layout (mainly for tests that haven't been
  /// updated). The narrow layout ignores this entirely — mobile keeps the
  /// rich identity card.
  final List<ClientColumn> columns;

  final VoidCallback onTap;

  /// Fires on long-press. Wired by the screen to enter selection mode and
  /// toggle this row.
  final VoidCallback? onLongPress;

  /// Fires when the user clicks the leading-slot selection checkbox. On
  /// desktop, hovering the leading slot (where the avatar sits) reveals an
  /// empty checkbox in its place; a click on it enters multi-select with
  /// this row toggled. In selection mode the checkbox is always visible
  /// and tapping it likewise toggles.
  final VoidCallback? onSelectTap;

  /// True for the wide table-style row; false for the narrow stacked tile.
  final bool wide;

  /// False when the row is archived/soft-deleted; greys the wide-table
  /// standalone edit pencil. Sourced from `EntityListTileOptions.editable`.
  final bool editable;

  /// Action menu callback. When null, the more-horiz menu is hidden — which
  /// is exactly what selection mode wants (bulk actions live in the AppBar).
  final ValueChanged<ClientAction>? onAction;

  /// True while the list is in multi-select mode. The leading avatar swaps
  /// for a checkbox; the per-row action menu hides.
  final bool selecting;

  /// True when this tile is part of the active selection. Renders the
  /// `accentSoft` bg + 3px leading accent border. Also drives the
  /// checkbox's checked state when [selecting] is true.
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
  State<ClientListTile> createState() => _ClientListTileState();
}

class _ClientListTileState extends State<ClientListTile> {
  @override
  Widget build(BuildContext context) {
    final w = widget;
    final tokens = context.inTheme;
    final displayName = _displayName(w.client);
    final state = _stateFor(w.client);
    final outstandingPositive = w.client.balance > Decimal.zero;
    final formattedOutstanding =
        w.formatter?.money(
          w.client.balance,
          clientCurrencyId: w.client.currencyId,
        ) ??
        '';
    final formattedPaid =
        w.formatter?.money(
          w.client.paidToDate,
          clientCurrencyId: w.client.currencyId,
        ) ??
        '';

    final content = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
      child: w.wide
          ? _wide(context, tokens, displayName: displayName, state: state)
          : _narrow(
              context,
              tokens,
              displayName: displayName,
              state: state,
              formattedOutstanding: formattedOutstanding,
              formattedPaid: formattedPaid,
              outstandingPositive: outstandingPositive,
            ),
    );

    return Semantics(
      button: true,
      label: _semanticsLabel(
        displayName: displayName,
        outstanding: formattedOutstanding,
        outstandingPositive: outstandingPositive,
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
    required String formattedOutstanding,
    required String formattedPaid,
    required bool outstandingPositive,
  }) {
    final w = widget;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _leading(displayName),
        const SizedBox(width: 12),
        Expanded(child: _identity(context, tokens, displayName)),
        const SizedBox(width: 12),
        // Cap the money column so a pathological amount (huge balance in a
        // wide currency) ellipsizes instead of overflowing the row. The cap is
        // generous — realistic balances render in full, so the identity
        // (Expanded above) keeps its normal width; only extreme values clip.
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _money(
                formattedOutstanding,
                isZero: !outstandingPositive,
                bold: outstandingPositive,
                color: outstandingPositive ? tokens.overdue : tokens.ink3,
              ),
              const SizedBox(height: 2),
              _money(
                formattedPaid,
                isZero: w.client.paidToDate == Decimal.zero,
                color: tokens.ink3,
                fontSize: 11,
              ),
            ],
          ),
        ),
        if (state != null) ...[
          const SizedBox(width: 8),
          _Pill(state: state, tokens: tokens),
        ],
        if (w.onAction != null) ...[
          const SizedBox(width: 4),
          EntityActionsPopupButton<ClientAction>(
            items: ClientActions.itemsFor(context, w.client, w.onAction!),
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
        // Leading `…` actions slot. Empty when `onAction` is null
        // (selection mode); otherwise the in-row PopupMenuButton.
        SizedBox(
          width: kColWMoreMenu,
          child: w.onAction == null
              ? const SizedBox.shrink()
              : EntityActionsPopupButton<ClientAction>(
                  splitEditAction: true,
                  editEnabled: w.editable,
                  items: ClientActions.itemsFor(context, w.client, w.onAction!),
                ),
        ),
        const SizedBox(width: kColActionsLeadingGap),
        _leading(displayName),
        const SizedBox(width: kColCellGap),
        for (final col in w.columns) ...[
          _CellSlot(
            column: col,
            entity: w.client,
            child: col.cellBuilder(w.client, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        // Pill slot — reserved width so the row's right edge stays fixed
        // even when the pill is absent.
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
        seed: w.client.id,
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
        _SubtitleLine(client: widget.client, tokens: tokens),
      ],
    );
  }

  Widget _money(
    String text, {
    required bool isZero,
    Color? color,
    bool bold = false,
    double fontSize = 13,
  }) {
    return Text(
      isZero ? '—' : text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      // Tabular figures align decimal columns row-to-row.
      style: moneyTextStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w500 : FontWeight.w400,
        color: color,
        height: 1.2,
      ),
    );
  }
}

// ─── Column slot ───────────────────────────────────────────────────────

/// Renders one column's cell at its declared width or as a flex-expanded
/// slot for the identity column.
class _CellSlot extends StatelessWidget {
  const _CellSlot({
    required this.column,
    required this.entity,
    required this.child,
  });
  final ClientColumn column;
  final Client entity;
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

// ─── Subtitle line ─────────────────────────────────────────────────────

class _SubtitleLine extends StatelessWidget {
  const _SubtitleLine({required this.client, required this.tokens});
  final Client client;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final contact = _primaryContact(client);
    final contactLabel = _contactLabel(contact);
    final city = client.city.trim();

    final pieces = <String>[
      if (contactLabel.isNotEmpty) contactLabel,
      if (city.isNotEmpty) city,
    ];

    String text;
    Color color;
    if (pieces.isNotEmpty) {
      text = pieces.join(' · ');
      color = tokens.ink3;
    } else if (client.number.isNotEmpty) {
      text = client.number;
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

// ─── State pill ────────────────────────────────────────────────────────

enum _RowState { deleted, archived, unsynced }

_RowState? _stateFor(Client c) {
  if (c.isDeleted) return _RowState.deleted;
  if (c.archivedAt != null) return _RowState.archived;
  if (c.isDirty) return _RowState.unsynced;
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

// ─── Helpers ───────────────────────────────────────────────────────────

String _displayName(Client c) {
  if (c.displayName.isNotEmpty) return c.displayName;
  if (c.name.isNotEmpty) return c.name;
  return '(no name)';
}

Contact? _primaryContact(Client c) {
  if (c.contacts.isEmpty) return null;
  for (final ct in c.contacts) {
    if (ct.isPrimary) return ct;
  }
  return c.contacts.first;
}

String _contactLabel(Contact? c) {
  if (c == null) return '';
  final name = ('${c.firstName} ${c.lastName}').trim();
  if (name.isNotEmpty) return name;
  return c.email.trim();
}

String _semanticsLabel({
  required String displayName,
  required String outstanding,
  required bool outstandingPositive,
  required _RowState? state,
  required bool selecting,
  required bool selected,
}) {
  final parts = <String>[];
  // In selection mode lead with the toggle state — the row's tap toggles
  // selection rather than navigates, and a screen reader should announce
  // that intent first.
  if (selecting) {
    parts.add(selected ? 'selected' : 'not selected');
  }
  parts.add(displayName);
  if (outstandingPositive) {
    parts.add('outstanding $outstanding');
  } else {
    parts.add('no outstanding balance');
  }
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
