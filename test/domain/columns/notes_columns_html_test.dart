import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/api/recurring_invoice_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/domain/columns/credit_columns.dart';
import 'package:admin/domain/columns/invoice_columns.dart';
import 'package:admin/domain/columns/purchase_order_columns.dart';
import 'package:admin/domain/columns/quote_columns.dart';
import 'package:admin/domain/columns/recurring_invoice_columns.dart';
import 'package:admin/domain/columns/vendor_columns.dart';

/// Notes columns on the seven entities whose notes are HTML on the wire must
/// flatten the markup — `colNotes(html: true)` or `cellNotes` at an inline
/// definition. The flag is opt-in and the failure mode is a cell printing
/// `<p>` tags, which nobody sees until they add that column to a list.
///
/// Expense, project, payment and recurring-expense notes are plain text
/// everywhere (React edits them in a `<textarea>`) and are deliberately absent.

const _html = '<p>Hi Bob</p><p>Thanks for the <b>quote</b>.</p>';

/// One notes column, with the entity to render it against.
class _Case {
  _Case(this.label, this.cell, this.value);

  final String label;
  final Widget Function(BuildContext context) cell;
  final String? value;
}

_Case _caseFor<T>(
  String label,
  List<ColumnDefinition<T>> registry,
  String id,
  T entity,
) {
  final column = registry.firstWhere((c) => c.id == id);
  return _Case(
    label,
    (context) => column.cellBuilder(entity, context),
    column.valueBuilder?.call(entity),
  );
}

List<_Case> _cases() {
  final client = Client.fromApi(
    ClientApi.fromJson({
      'id': 'c1',
      'name': 'Acme',
      'balance': '0',
      'public_notes': _html,
      'private_notes': _html,
    }),
  );
  final vendor = Vendor.fromApi(
    VendorApi.fromJson({
      'id': 'v1',
      'name': 'Supplier',
      'public_notes': _html,
      'private_notes': _html,
    }),
  );
  Map<String, dynamic> doc(String id) => {
    'id': id,
    'public_notes': _html,
    'private_notes': _html,
  };
  final invoice = Invoice.fromApi(InvoiceApi.fromJson(doc('i1')));
  final quote = Quote.fromApi(QuoteApi.fromJson(doc('q1')));
  final credit = Credit.fromApi(CreditApi.fromJson(doc('cr1')));
  final po = PurchaseOrder.fromApi(PurchaseOrderApi.fromJson(doc('po1')));
  final recurring = RecurringInvoice.fromApi(
    RecurringInvoiceApi.fromJson(doc('r1')),
  );

  return [
    _caseFor('client.public_notes', kAllClientColumns, 'public_notes', client),
    _caseFor(
      'client.private_notes',
      kAllClientColumns,
      'private_notes',
      client,
    ),
    _caseFor('vendor.public_notes', kAllVendorColumns, 'public_notes', vendor),
    _caseFor(
      'vendor.private_notes',
      kAllVendorColumns,
      'private_notes',
      vendor,
    ),
    _caseFor(
      'invoice.public_notes',
      kAllInvoiceColumns,
      'public_notes',
      invoice,
    ),
    _caseFor(
      'invoice.private_notes',
      kAllInvoiceColumns,
      'private_notes',
      invoice,
    ),
    _caseFor('quote.public_notes', kAllQuoteColumns, 'public_notes', quote),
    _caseFor('quote.private_notes', kAllQuoteColumns, 'private_notes', quote),
    _caseFor('credit.public_notes', kAllCreditColumns, 'public_notes', credit),
    _caseFor(
      'credit.private_notes',
      kAllCreditColumns,
      'private_notes',
      credit,
    ),
    _caseFor('po.public_notes', kAllPurchaseOrderColumns, 'public_notes', po),
    _caseFor('po.private_notes', kAllPurchaseOrderColumns, 'private_notes', po),
    _caseFor(
      'recurring.public_notes',
      kAllRecurringInvoiceColumns,
      'public_notes',
      recurring,
    ),
    _caseFor(
      'recurring.private_notes',
      kAllRecurringInvoiceColumns,
      'private_notes',
      recurring,
    ),
  ];
}

void main() {
  testWidgets('every HTML-bearing notes column flattens its markup', (
    tester,
  ) async {
    final cases = _cases();
    expect(cases, hasLength(14));

    for (final c in cases) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          home: Scaffold(body: Builder(builder: c.cell)),
        ),
      );
      final rendered = tester.widget<CellText>(find.byType(CellText)).value;
      expect(rendered, isNot(contains('<')), reason: c.label);
      expect(rendered, 'Hi Bob Thanks for the quote.', reason: c.label);

      // The copy value keeps the paragraphs a one-line cell can't show.
      expect(c.value, isNot(contains('<')), reason: c.label);
      expect(c.value, 'Hi Bob\n\nThanks for the quote.', reason: c.label);
    }
  });
}
