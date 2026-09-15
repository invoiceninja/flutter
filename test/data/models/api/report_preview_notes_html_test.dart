import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/report_preview_api_model.dart';
import 'package:admin/data/models/domain/report_preview.dart';

/// A report can carry a notes / terms / footer column, and only two of the
/// server's decorators `strip_tags` before sending it — `QuoteDecorator`,
/// `PurchaseOrderDecorator`, `RecurringInvoiceDecorator` and `VendorDecorator`
/// define no notes methods at all, so those arrive with their markup.
///
/// Flattening at the parse rather than at the widget covers the table cell, the
/// narrow card list, the column filter, the sort and the group key in one go.

ReportPreview _preview(
  Object? cell, {
  String column = 'invoice.public_notes',
}) => decodeReportPreview({
  'columns': [
    {'identifier': column, 'display_value': 'Public notes'},
  ],
  '0': [cell],
});

ReportCell _cell(Object? raw, {String column = 'invoice.public_notes'}) =>
    _preview(raw, column: column).rows.single.cells.single;

void main() {
  test('markup never reaches the cell, the filter or the sort key', () {
    final cell = _cell('<p>Hi Bob</p><p>Thanks for the <b>quote</b>.</p>');

    expect(cell, isA<ReportStringCell>());
    expect((cell as ReportStringCell).value, 'Hi Bob Thanks for the quote.');
    expect(cell.filterText, isNot(contains('<')));
    expect(cell.sortKey, isNot(contains('<')));
  });

  test('a pre-formatted display value is flattened too', () {
    // `displayValue` wins over `value` everywhere — in the cell text, in
    // `filterText`, and in the group key.
    final cell = _cell({
      'value': '<p>raw</p>',
      'display_value': '<p>shown</p>',
    });

    expect((cell as ReportStringCell).displayValue, 'shown');
    expect(cell.filterText, 'shown');
  });

  test('an ordinary cell is untouched', () {
    // The common case: no markup, so nothing to do — including prose whose
    // `<` is not a tag.
    expect((_cell('Acme Ltd') as ReportStringCell).value, 'Acme Ltd');
    expect((_cell('width < 5') as ReportStringCell).value, 'width < 5');
    expect((_cell(null) as ReportStringCell).value, isNull);
  });

  test('entities are resolved, so a name reads as a name', () {
    expect(
      (_cell('<p>Caf&eacute; &amp; co</p>') as ReportStringCell).value,
      'Café & co',
    );
  });
}
