import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/list/cell_slot.dart';
import 'package:admin/ui/core/widgets/cell_copy_hover.dart';

/// Behavioural coverage for the wide-table cell now shared by every entity
/// list.
///
/// It replaced seventeen private `_CellSlot` copies that no test referenced —
/// which is how two of them drifted into a different brace style without
/// anyone noticing, and why a wrong entity passed to `valueBuilder` would have
/// been invisible. One test here now stands behind all seventeen tiles.
///
/// The width branch is the load-bearing part: it is what keeps a row's cells
/// lined up with `EntityListColumnHeaders`, whose `_HeaderCell<T>` resolves the
/// same `isFlex ? Expanded : SizedBox(width:)` decision on the header side.
class _Row {
  const _Row(this.name);
  final String name;
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    ColumnDefinition<_Row> column, {
    _Row entity = const _Row('Acme'),
  }) => tester.pumpWidget(
    MaterialApp(
      // CopyIconButton reads `context.inTheme`; it only mounts when the
      // column has a copy value, which is why one test needed this.
      theme: buildInTheme(InTheme.light),
      home: Scaffold(
        // A Row so `Expanded` is legal — the real host is the tile's Row.
        body: Row(
          children: [
            CellSlot<_Row>(
              column: column,
              entity: entity,
              child: const Text('CELL'),
            ),
          ],
        ),
      ),
    ),
  );

  ColumnDefinition<_Row> col({
    double? width,
    ColumnAlign align = ColumnAlign.start,
    String? Function(_Row)? valueBuilder,
  }) => ColumnDefinition<_Row>(
    id: 'name',
    labelKey: 'name',
    width: width,
    align: align,
    valueBuilder: valueBuilder,
    cellBuilder: (r, _) => Text(r.name),
  );

  testWidgets('a flex column expands; a sized one takes the declared width', (
    tester,
  ) async {
    // `width: null` is what makes a column flex — the identity column. Getting
    // this backwards silently knocks every following cell out of alignment
    // with its header.
    await pump(tester, col());
    expect(find.byType(Expanded), findsOneWidget);
    expect(
      tester.widgetList<SizedBox>(find.byType(SizedBox)).map((s) => s.width),
      isNot(contains(140.0)),
    );

    await pump(tester, col(width: 140));
    expect(find.byType(Expanded), findsNothing);
    expect(
      tester.widgetList<SizedBox>(find.byType(SizedBox)).map((s) => s.width),
      contains(140.0),
    );
  });

  testWidgets('align: end anchors the cell to the trailing edge', (
    tester,
  ) async {
    // The Align that wraps THIS cell's child — `find.byType(Align).first`
    // picks up an unrelated one from the Scaffold and passes even when the
    // branch is deleted.
    AlignmentGeometry alignOf() => tester
        .widget<Align>(
          find
              .ancestor(of: find.text('CELL'), matching: find.byType(Align))
              .first,
        )
        .alignment;

    await pump(tester, col(width: 100));
    expect(alignOf(), AlignmentDirectional.centerStart);

    await pump(tester, col(width: 100, align: ColumnAlign.end));
    expect(alignOf(), AlignmentDirectional.centerEnd);
  });

  testWidgets('the copy value comes from valueBuilder, fed THIS row', (
    tester,
  ) async {
    // The conversion renamed a per-file parameter (`quote:`, `category:`, …)
    // to `entity:` across seventeen call sites. Passing the wrong object here
    // would put another row's text on the clipboard and nothing would throw.
    await pump(
      tester,
      col(width: 100, valueBuilder: (r) => 'copy:${r.name}'),
      entity: const _Row('Globex'),
    );
    expect(
      tester.widget<CellCopyHover>(find.byType(CellCopyHover)).value,
      'copy:Globex',
    );
  });

  testWidgets('a column with no valueBuilder offers nothing to copy', (
    tester,
  ) async {
    // `CellCopyHover` suppresses the affordance on a null value — that is how
    // a dashed cell avoids offering to copy an em dash.
    await pump(tester, col(width: 100));
    expect(
      tester.widget<CellCopyHover>(find.byType(CellCopyHover)).value,
      isNull,
    );
  });

  testWidgets('the column align is forwarded to the copy affordance', (
    tester,
  ) async {
    await pump(tester, col(width: 100, align: ColumnAlign.end));
    expect(
      tester.widget<CellCopyHover>(find.byType(CellCopyHover)).align,
      ColumnAlign.end,
    );
  });
}
