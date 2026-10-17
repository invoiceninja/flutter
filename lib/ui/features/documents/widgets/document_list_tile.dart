import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/cell_slot.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/list/selectable_list_row.dart';
import 'package:admin/ui/core/widgets/document_type_icon.dart';
import 'package:admin/ui/core/widgets/leading_select_slot.dart';
import 'package:admin/ui/features/documents/widgets/document_actions.dart';
import 'package:admin/utils/formatting.dart';

/// One row of the Documents list.
///
/// Wide: the leading `⋮` actions slot, the select slot (whose resting glyph is
/// the file-type icon), then the column cells — the anatomy every list shares.
/// Narrow: icon, name, and a second line of size · date · "Private", like
/// admin-portal's row. The whole row is the one destination; the name is not
/// a link (`docs/row-actions-and-values.md`).
class DocumentListTile extends StatelessWidget {
  const DocumentListTile({
    super.key,
    required this.document,
    required this.columns,
    required this.onTap,
    this.wide = true,
    this.formatter,
    this.onAction,
    this.onSelectTap,
    this.onLongPress,
    this.selected = false,
    this.urlSelected = false,
    this.selecting = false,
    this.hideBottomDivider = false,
  });

  final DocumentRecord document;

  /// Columns to render in wide mode. Ignored when [wide] is false.
  final List<ColumnDefinition<DocumentRecord>> columns;
  final VoidCallback onTap;
  final bool wide;

  /// For the narrow row's date. Null leaves the date out.
  final Formatter? formatter;
  final ValueChanged<DocumentAction>? onAction;
  final VoidCallback? onSelectTap;
  final VoidCallback? onLongPress;
  final bool selected;

  /// True when this row is the one open in the master-detail pane.
  final bool urlSelected;
  final bool selecting;

  /// Suppresses the bottom hairline — computed by the list scaffold.
  final bool hideBottomDivider;

  @override
  Widget build(BuildContext context) {
    return SelectableListRow(
      selected: selected,
      urlSelected: urlSelected,
      hideBottomDivider: hideBottomDivider,
      onTap: () => (selecting ? onSelectTap : onTap)?.call(),
      onLongPress: onLongPress,
      child: Padding(
        padding: listRowPadding(context),
        child: wide ? _wide(context) : _narrow(context),
      ),
    );
  }

  Widget _wide(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: colWMoreMenu(),
          child: (onAction == null || selecting)
              ? const SizedBox.shrink()
              : EntityActionsPopupButton<DocumentAction>(
                  items: DocumentActions.itemsFor(context, document, onAction!),
                ),
        ),
        const SizedBox(width: kColActionsLeadingGap),
        _leading(context),
        const SizedBox(width: kColCellGap),
        for (final col in columns) ...[
          CellSlot<DocumentRecord>(
            column: col,
            entity: document,
            child: col.cellBuilder(document, context),
          ),
          const SizedBox(width: kColCellGap),
        ],
        // Reserved pill slot so the row's right edge matches the header's.
        const SizedBox(width: kColWPillSlot),
      ],
    );
  }

  Widget _narrow(BuildContext context) {
    final tokens = context.inTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _leading(context),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                document.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
              ),
              if (_subtitle(context) case final line?) ...[
                const SizedBox(height: 2),
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: tokens.ink3),
                ),
              ],
            ],
          ),
        ),
        if (onAction != null && !selecting) ...[
          const SizedBox(width: 4),
          EntityActionsPopupButton<DocumentAction>(
            items: DocumentActions.itemsFor(context, document, onAction!),
          ),
        ],
      ],
    );
  }

  /// Size · upload date · "Private" — whichever of them there are.
  String? _subtitle(BuildContext context) {
    final created = document.createdAt;
    final date = formatter == null || created.millisecondsSinceEpoch == 0
        ? null
        : formatter!.date(created.toLocal().toIso8601String().split('T').first);
    final parts = [
      if (document.size > 0) formatSize(document.size),
      ?date,
      if (!document.isPublic) context.tr('private'),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _leading(BuildContext context) {
    return LeadingSelectSlot(
      selecting: selecting,
      selected: selected,
      onSelectTap: onSelectTap,
      // Keeps the slot's 32×32 footprint so the columns stay aligned.
      defaultChild: SizedBox(
        width: 32,
        height: 32,
        child: Icon(
          documentTypeIcon(document.type),
          size: 20,
          color: context.inTheme.ink3,
        ),
      ),
    );
  }
}
