import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// The side inset of a DocuNinja table page — its search row and the table
/// card — as the app's wide lists have it.
const double kDnTableInset = 24;

/// One column of a DocuNinja table: its header's translation key and its
/// share of the row.
typedef DnTableColumn = ({String labelKey, int flex});

/// React's table (`DataTable.tsx`) on a wide pane, as the documents list
/// draws it: the column header and [rows] in one bordered card, sized to its
/// rows. [rows] are slivers (the rows, or [DnNoRecordsLine] for an empty
/// table); each row hosts its own ink (`Material(type: transparency)`), since
/// the card's fill paints over the Scaffold's.
///
/// [leadingWidth] is the rows' checkbox slot and [trailingWidth] their `⋮`,
/// so the header's columns line up with the cells.
Widget dnTableCard(
  BuildContext context, {
  required List<DnTableColumn> columns,
  required List<Widget> rows,
  double leadingWidth = 0,
  double trailingWidth = 0,
}) {
  final tokens = context.inTheme;
  return DecoratedSliver(
    decoration: BoxDecoration(
      color: tokens.surface,
      borderRadius: BorderRadius.circular(InRadii.r3),
      boxShadow: tokens.shadow1,
    ),
    sliver: DecoratedSliver(
      // The border over the rows: the header strip and a selected
      // row fill to the edge and would otherwise cover it.
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: DnTableHeader(
              columns: columns,
              leadingWidth: leadingWidth,
              trailingWidth: trailingWidth,
            ),
          ),
          ...rows,
        ],
      ),
    ),
  );
}

/// The app's wide-list header strip (`EntityListColumnHeaders`): uppercase
/// labels on the alternate surface, then a divider.
class DnTableHeader extends StatelessWidget {
  const DnTableHeader({
    super.key,
    required this.columns,
    this.leadingWidth = 0,
    this.trailingWidth = 0,
  });

  final List<DnTableColumn> columns;
  final double leadingWidth;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: tokens.ink3,
    );
    // A fill and a divider, not a bottom border: a radius needs a uniform
    // border. Inside the card's border, so a hair under its radius.
    final strip = Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(InRadii.r3 - 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (leadingWidth > 0) SizedBox(width: leadingWidth),
          for (final c in columns)
            Expanded(
              flex: c.flex,
              child: Text(
                context.tr(c.labelKey).toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          if (trailingWidth > 0) SizedBox(width: trailingWidth),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [strip, const Divider(height: 1)],
    );
  }
}

/// React's empty table: one muted line where the rows would be
/// (`DataTable.tsx`, `no_records_found`), not a page-high empty state.
class DnNoRecordsLine extends StatelessWidget {
  const DnNoRecordsLine({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
    child: Text(
      context.tr('no_records_found'),
      textAlign: TextAlign.center,
      style: TextStyle(color: context.inTheme.ink3, fontSize: 14),
    ),
  );
}

/// The AppBar's Save on a DocuNinja edit page, as `SettingsPageScaffold`
/// draws its own: an accent text button, a spinner while it saves.
class DnAppBarSaveButton extends StatelessWidget {
  const DnAppBarSaveButton({
    super.key,
    required this.saving,
    required this.onPressed,
  });

  final bool saving;

  /// Null turns the button off.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: saving ? null : onPressed,
    style: TextButton.styleFrom(foregroundColor: context.inTheme.accent),
    child: saving
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(context.tr('save')),
  );
}
