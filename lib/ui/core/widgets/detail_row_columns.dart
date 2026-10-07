import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';

/// A [DetailRowStack] that can run in more than one column.
///
/// For a Details card that is **the only card in its row on a wide window**.
/// One column of label-and-value rows across 1,500 px is a card whose left
/// fifth holds everything and whose other four are blank; split in two it is
/// half the height and the page under it starts sooner.
///
/// The host decides [columns] — from the width it already measured — and this
/// widget holds no `LayoutBuilder`, so it is safe inside an `IntrinsicHeight`
/// row. With fewer than [minRowsToSplit] rows it stays one column: two rows
/// side by side read as a table with a missing header, not as a list.
///
/// Rows fill the first column before the second, so reading order is down
/// then across — the order they have in the single stack.
class DetailRowColumns extends StatelessWidget {
  const DetailRowColumns({
    super.key,
    required this.children,
    this.columns,
    this.minRowsToSplit = 4,
  }) : assert(columns == null || columns >= 1);

  /// Null entries are dropped, as in [DetailRowStack].
  final List<Widget?> children;

  /// Null to take it from the nearest [DetailRowColumnsScope] — one column
  /// where there is none.
  final int? columns;
  final int minRowsToSplit;

  @override
  Widget build(BuildContext context) {
    final rows = children.whereType<Widget>().toList(growable: false);
    final columns = this.columns ?? DetailRowColumnsScope.of(context);
    if (columns == 1 || rows.length < minRowsToSplit) {
      return DetailRowStack(children: rows);
    }
    final perColumn = (rows.length / columns).ceil();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c * perColumn < rows.length; c++) ...[
          if (c > 0) const SizedBox(width: InSpacing.xxl),
          Expanded(
            child: DetailRowStack(
              children: rows.sublist(
                c * perColumn,
                (c + 1) * perColumn > rows.length
                    ? rows.length
                    : (c + 1) * perColumn,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Says how many columns the label-and-value rows of the cards below it run
/// in — for whoever *places* a card to tell the card what only it knows.
///
/// A record's profile puts its lead cards side by side on a wide window. When
/// there is only one, it has the row to itself, and one column of rows across
/// 1,500 px is a card whose left fifth holds everything. So the profile wraps
/// a lone card in `DetailRowColumnsScope(columns: 2)`, and any card that draws
/// its rows through [DetailRowColumns] splits them — without the card
/// measuring anything (a `LayoutBuilder` in a card would make it illegal in
/// the profile's `IntrinsicHeight` row).
///
/// This was done three ways before it was one: held to the header's column
/// with the rest of the row left blank, two columns decided by the host, and
/// nothing at all.
class DetailRowColumnsScope extends InheritedWidget {
  const DetailRowColumnsScope({
    super.key,
    required this.columns,
    required super.child,
  }) : assert(columns >= 1);

  final int columns;

  /// One, where nothing above says otherwise.
  static int of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DetailRowColumnsScope>()
          ?.columns ??
      1;

  @override
  bool updateShouldNotify(DetailRowColumnsScope oldWidget) =>
      oldWidget.columns != columns;
}
