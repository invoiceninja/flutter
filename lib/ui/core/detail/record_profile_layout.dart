import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';

/// How many lead cards share one row before another row starts. Three equal
/// cards is what fits the narrowest wide layout (1000 px) without a Details
/// row's label and value fighting for a hundred pixels each.
const int kRecordProfileCardsPerRow = 3;

/// A record's profile cards, placed the way the record layout places them
/// (`docs/detail-screen-layout.md` § The record layout):
///
///  * at [Breakpoints.entityFormMultiColumn] and up the [lead] cards sit side
///    by side as equal cards that **end on one line** — and a lone one takes
///    the row, with its rows in two columns ([DetailRowColumnsScope]);
///  * below it they stack, in the same order;
///  * the [tail] cards — notes, anything that wants the whole width — run
///    beneath, full width, either way.
///
/// **Pass only cards that will draw something.** The gap between cards is paid
/// per entry, not per painted card, so an entry that builds nothing leaves a
/// doubled gap between its neighbours — and in the wide row an empty
/// `Expanded` holds a share of the width for nothing. A host therefore decides
/// which cards exist from the same rows it hands them to draw.
///
/// **A lead card must not contain a `LayoutBuilder`** (`ClampedText` has one,
/// which is why notes are a tail card): the row is levelled with
/// `IntrinsicHeight`, and a `LayoutBuilder` has no intrinsic height.
///
/// The record column above this has already centred and capped the narrow
/// stack, so there is no second cap here.
class RecordProfileLayout extends StatelessWidget {
  const RecordProfileLayout({
    super.key,
    required this.lead,
    this.tail = const [],
  });

  final List<Widget> lead;
  final List<Widget> tail;

  @override
  Widget build(BuildContext context) {
    if (lead.isEmpty && tail.isEmpty) return const SizedBox.shrink();
    final gap = SizedBox(height: InSpacing.md(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
        final rows = <Widget>[
          if (!wide)
            ...lead
          else if (lead.length == 1)
            // Nothing to share the row with: it takes the width, and is told
            // it may run its rows in two columns so it does not become one
            // column of values against a window of blank card.
            DetailRowColumnsScope(columns: 2, child: lead.single)
          else
            for (final cards in _balanced(lead)) _row(context, cards),
          ...tail,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) ...[if (i > 0) gap, rows[i]],
          ],
        );
      },
    );
  }

  /// [cards] in as few rows as [kRecordProfileCardsPerRow] allows, **evened
  /// out**: four cards are two rows of two, not three and a stray one
  /// stretched across the whole window.
  static List<List<Widget>> _balanced(List<Widget> cards) {
    final rowCount = (cards.length / kRecordProfileCardsPerRow).ceil();
    final perRow = (cards.length / rowCount).ceil();
    return [
      for (var i = 0; i < cards.length; i += perRow)
        cards.sublist(i, i + perRow > cards.length ? cards.length : i + perRow),
    ];
  }

  /// One level row.
  Widget _row(BuildContext context, List<Widget> cards) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) SizedBox(width: InSpacing.md(context)),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}
