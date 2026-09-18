import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/login_response_api_model.dart';

/// invoiceninja/flutter#170 — the `/refresh` envelope carries a DELTA for the
/// fourteen browsable entity tables, and v2 used to drop every one of them.
///
/// The server's `refreshResponse()` parses the full `first_load` include set
/// unconditionally, so these arrays arrive on every refresh whether we read
/// them or not. These tests pin (a) that they now land on the envelope, and
/// (b) that they parse through `tolerantList` — which matters more here than
/// anywhere else, because these fields share an envelope with the session and
/// the reference bundles. One strictly-parsed malformed invoice would throw out
/// of `LoginResponseApi.fromJson` and take the whole refresh down with it.
void main() {
  Map<String, dynamic> company(String id) => {
    'company': <String, dynamic>{'id': 'co_$id', 'name': 'Company $id'},
    'token': <String, dynamic>{'token': 'tok_$id', 'name': 't'},
    'account': <String, dynamic>{'id': 'acc_$id'},
  };

  LoginResponseApi parseWithCompany(Map<String, dynamic> companyPatch) {
    final json = company('a');
    (json['company'] as Map<String, dynamic>).addAll(companyPatch);
    return LoginResponseApi.fromJson({
      'data': [json],
    });
  }

  test('every browsable entity array lands on the envelope', () {
    final parsed = parseWithCompany({
      'clients': [
        {'id': 'cl_1', 'updated_at': 11},
      ],
      'products': [
        {'id': 'pr_1', 'updated_at': 12},
      ],
      'invoices': [
        {'id': 'in_1', 'updated_at': 13},
      ],
      'recurring_invoices': [
        {'id': 'ri_1', 'updated_at': 14},
      ],
      'quotes': [
        {'id': 'qu_1', 'updated_at': 15},
      ],
      'credits': [
        {'id': 'cr_1', 'updated_at': 16},
      ],
      'payments': [
        {'id': 'pa_1', 'updated_at': 17},
      ],
      'tasks': [
        {'id': 'ta_1', 'updated_at': 18},
      ],
      'projects': [
        {'id': 'pj_1', 'updated_at': 19},
      ],
      'expenses': [
        {'id': 'ex_1', 'updated_at': 20},
      ],
      'recurring_expenses': [
        {'id': 're_1', 'updated_at': 21},
      ],
      'vendors': [
        {'id': 've_1', 'updated_at': 22},
      ],
      'purchase_orders': [
        {'id': 'po_1', 'updated_at': 23},
      ],
      'bank_transactions': [
        {'id': 'bt_1', 'updated_at': 24},
      ],
    });

    final co = parsed.data.single.company;
    expect(co.clients.single.id, 'cl_1');
    expect(co.products.single.id, 'pr_1');
    expect(co.invoices.single.id, 'in_1');
    expect(co.recurringInvoices.single.id, 'ri_1');
    expect(co.quotes.single.id, 'qu_1');
    expect(co.credits.single.id, 'cr_1');
    expect(co.payments.single.id, 'pa_1');
    expect(co.tasks.single.id, 'ta_1');
    expect(co.projects.single.id, 'pj_1');
    expect(co.expenses.single.id, 'ex_1');
    expect(co.recurringExpenses.single.id, 're_1');
    expect(co.vendors.single.id, 've_1');
    expect(co.purchaseOrders.single.id, 'po_1');
    expect(co.bankTransactions.single.id, 'bt_1');

    // `updated_at` is what the staleness guard and the keyset cursor both read.
    expect(co.invoices.single.updatedAt, 13);
  });

  test('a malformed entity row is skipped; the rest of the array survives', () {
    final parsed = parseWithCompany({
      'invoices': [
        {'id': 'in_ok', 'updated_at': 5},
        {
          'id': {'not': 'a string'},
        },
        {'id': 'in_ok2', 'updated_at': 6},
      ],
    });

    expect(parsed.data.single.company.invoices.map((i) => i.id), [
      'in_ok',
      'in_ok2',
    ]);
  });

  test('a malformed entity row does not take down the session or the '
      'reference bundles', () {
    final parsed = parseWithCompany({
      'tax_rates': [
        {'id': 'tr_ok', 'name': 'VAT'},
      ],
      'invoices': [
        {
          'id': {'not': 'a string'},
        },
      ],
    });

    // The whole point: the company, its token and its bundles are unharmed.
    expect(parsed.data, hasLength(1));
    expect(parsed.data.single.company.id, 'co_a');
    expect(parsed.data.single.token.token, 'tok_a');
    expect(parsed.data.single.company.taxRates.single.id, 'tr_ok');
    expect(parsed.data.single.company.invoices, isEmpty);
  });

  test('an absent or non-array entity key parses as an empty list', () {
    // An older self-hosted server that does not ship the arrays, and a server
    // that ships an object where a list was expected, both degrade to "no
    // delta" rather than throwing.
    expect(parseWithCompany({}).data.single.company.invoices, isEmpty);
    expect(
      parseWithCompany({
        'invoices': <String, dynamic>{},
      }).data.single.company.invoices,
      isEmpty,
    );
  });
}
