import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/location_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/real_document.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';

Invoice _invoice([Map<String, dynamic> overrides = const {}]) =>
    Invoice.fromApi(
      InvoiceApi.fromJson({
        'id': 'inv1',
        'client_id': 'c1',
        'number': '0042',
        'po_number': 'PO-7',
        'status_id': '2',
        'amount': '330.00',
        'balance': '130.00',
        'paid_to_date': '200.00',
        'total_taxes': '30.00',
        'date': '2026-03-04',
        'due_date': '2026-04-03',
        'updated_at': 1700000000,
        'created_at': 1690000000,
        'public_notes': '<p>Thank <b>you</b>.</p>',
        'terms': '<p>Net 30</p>',
        'footer': '',
        'line_items': [
          {
            'product_key': 'Design',
            'notes': 'Brand refresh',
            'cost': 100,
            'quantity': 2,
            'tax_name1': 'VAT',
            'tax_rate1': 10,
          },
          {
            'product_key': 'Hosting',
            'notes': 'One year',
            'cost': 100,
            'quantity': 1,
          },
        ],
        'invitations': [
          {'id': 'i1', 'key': 'k', 'link': 'https://portal.example.com/i/k'},
        ],
        ...overrides,
      }),
    );

Client _client({List<LocationApi> locations = const []}) => Client.fromApi(
  ClientApi(
    id: 'c1',
    name: 'Blue Door Bakery',
    displayName: 'Blue Door Bakery',
    number: 'C-9',
    address1: '1 Mill Lane',
    city: 'Leeds',
    state: 'West Yorkshire',
    postalCode: 'LS1 4AB',
    countryId: '826',
    phone: '0113 496 0000',
    vatNumber: 'GB123',
    shippingAddress1: '2 Dock Road',
    shippingCity: 'Hull',
    shippingPostalCode: 'HU1 1AA',
    shippingCountryId: '826',
    contacts: const [
      ContactApi(id: 'k2', firstName: 'Sam', lastName: 'Other'),
      ContactApi(
        id: 'k1',
        firstName: 'Ada',
        lastName: 'Lovelace',
        email: 'ada@bluedoor.example',
        phone: '07700 900000',
        isPrimary: true,
      ),
    ],
    locations: locations,
    updatedAt: 1,
  ),
);

void main() {
  final base = DesignerSampleData.fallback;
  DesignerSampleData build({
    Invoice? invoice,
    Client? client,
    bool noClient = false,
  }) => designerDataFromInvoice(
    invoice: invoice ?? _invoice(),
    client: noClient ? null : (client ?? _client()),
    base: base,
    countryName: (id) => id == '826' ? 'United Kingdom' : '',
  );

  test('the invoice is the real one; the company block is left alone', () {
    final data = build();
    expect(data.invoice.number, '0042');
    expect(data.invoice.date, '2026-03-04');
    expect(data.invoice.dueDate, '2026-04-03');
    expect(data.invoice.poNumber, 'PO-7');
    expect(data.invoice.total, Decimal.parse('330.00'));
    expect(data.invoice.balance, Decimal.parse('130.00'));
    expect(data.invoice.paidToDate, Decimal.parse('200.00'));
    expect(data.invoice.totalTaxes, Decimal.parse('30.00'));
    expect(data.invoice.publicUrl, 'https://portal.example.com/i/k');
    // The builder has already put the company's own letterhead in `base`.
    expect(identical(data.company, base.company), isTrue);
  });

  test('the lines add up to the subtotal the totals block shows', () {
    final data = build();
    expect(
      [for (final l in data.lineItems) l.lineTotal],
      [Decimal.fromInt(200), Decimal.fromInt(100)],
    );
    expect(
      data.lineItems.fold(Decimal.zero, (sum, l) => sum + l.lineTotal),
      data.invoice.subtotal,
    );
    // Tax is added to the line that carries the rate, and only that one.
    expect(data.lineItems.first.grossLineTotal, Decimal.fromInt(220));
    expect(data.lineItems.first.taxRate1, '10%');
    expect(data.lineItems.last.grossLineTotal, Decimal.fromInt(100));
    expect(data.lineItems.last.taxRate1, '');
  });

  test('a percentage discount is shown as the amount it comes to', () {
    final percent = build(
      invoice: _invoice({'discount': 10, 'is_amount_discount': false}),
    );
    expect(percent.invoice.discount, Decimal.fromInt(30));
    final amount = build(
      invoice: _invoice({'discount': 25, 'is_amount_discount': true}),
    );
    expect(amount.invoice.discount, Decimal.fromInt(25));
  });

  group('what is due, as the server works it out', () {
    String due(DesignerSampleData d) =>
        replaceVariables(r'$balance_due', data: d);
    String balance(DesignerSampleData d) =>
        replaceVariables(r'$balance', data: d);

    test('a draft owes its amount — its balance is still zero', () {
      final draft = build(
        invoice: _invoice({
          'status_id': '1',
          'balance': '0',
          'paid_to_date': '0',
        }),
      );
      expect(draft.invoice.balance, Decimal.fromInt(330));
      expect(due(draft), contains('330'));
      expect(balance(draft), contains('330'));
    });

    test('a sent one owes its balance', () {
      final sent = build();
      expect(due(sent), contains('130'));
      expect(balance(sent), contains('130'));
    });

    test('a paid one owes nothing', () {
      final paid = build(
        invoice: _invoice({
          'status_id': '4',
          'balance': '0',
          'paid_to_date': '330',
        }),
      );
      expect(paid.invoice.balanceDue, Decimal.zero);
    });

    test('a deposit that is asked for is what is due, on its own date', () {
      final part = build(
        invoice: _invoice({'partial': '50', 'partial_due_date': '2026-03-10'}),
      );
      expect(part.invoice.partial, Decimal.fromInt(50));
      expect(part.invoice.hasPartial, isTrue);
      expect(due(part), contains('50'));
      expect(due(part), isNot(contains('130')));
      expect(replaceVariables(r'$partial', data: part), contains('50'));
      // `$due_date` is the deposit's; the balance is still the balance.
      expect(part.invoice.dueDate, '2026-03-10');
      expect(balance(part), contains('130'));
    });

    test('no deposit: none is due, and the due date is the invoice\'s', () {
      final none = build();
      expect(none.invoice.hasPartial, isFalse);
      expect(none.invoice.dueDate, '2026-04-03');
    });
  });

  group('amounts are the client\'s, and a rate is a rate', () {
    test('the document carries the client\'s currency', () {
      final client = Client.fromApi(
        const ClientApi(
          id: 'c1',
          name: 'Euro Ltd',
          settings: {'currency_id': '3'},
        ),
      );
      expect(build(client: client).currencyId, '3');
      // None of its own: the company's.
      expect(build().currencyId, anyOf(isNull, isNotEmpty));
      expect(
        designerDataFromInvoice(
          invoice: _invoice(),
          client: null,
          base: DesignerSampleData.fallback,
        ).currencyId,
        isNull,
      );
    });

    test('a percentage line discount prints as a percentage', () {
      final lines = [
        {'product_key': 'Design', 'cost': 100, 'quantity': 1, 'discount': 10},
      ];
      final percent = build(
        invoice: _invoice({'line_items': lines, 'is_amount_discount': false}),
      );
      expect(percent.isAmountDiscount, isFalse);
      expect(
        resolveItemVariable(
          'item.discount',
          percent.lineItems.single,
          data: percent,
        ),
        '10%',
      );
      final amount = build(
        invoice: _invoice({'line_items': lines, 'is_amount_discount': true}),
      );
      expect(
        resolveItemVariable(
          'item.discount',
          amount.lineItems.single,
          data: amount,
        ),
        isNot(contains('%')),
      );
    });
  });

  test('notes are HTML on the wire and text on the page', () {
    final data = build();
    expect(data.invoice.publicNotes, 'Thank you.');
    expect(data.invoice.terms, 'Net 30');
    expect(data.invoice.footer, '');
  });

  test('the client, its primary contact, and names for country ids', () {
    final c = build().client;
    expect(c.name, 'Blue Door Bakery');
    expect(c.address1, '1 Mill Lane');
    expect(c.cityStatePostal, 'Leeds, West Yorkshire LS1 4AB');
    expect(c.postalCityState, 'LS1 4AB Leeds, West Yorkshire');
    expect(c.country, 'United Kingdom');
    // The primary contact, not whichever happens to be first.
    expect(c.contactFullName, 'Ada Lovelace');
    expect(c.email, 'ada@bluedoor.example');
    expect(c.contactPhone, '07700 900000');
    expect(c.shippingAddress1, '2 Dock Road');
    // No state: no stray comma.
    expect(c.shippingCityStatePostal, 'Hull HU1 1AA');
    expect(c.shippingPostalCity, 'HU1 1AA Hull');
  });

  test('an invoice for a location ships to the location', () {
    final data = build(
      invoice: _invoice({'location_id': 'loc1'}),
      client: _client(
        locations: const [
          LocationApi(
            id: 'loc1',
            name: 'North depot',
            address1: '9 Quay Street',
            city: 'Newcastle',
            postalCode: 'NE1 3DX',
            countryId: '826',
          ),
        ],
      ),
    );
    expect(data.client.locationName, 'North depot');
    expect(data.client.shippingAddress1, '9 Quay Street');
    expect(data.client.shippingCityStatePostal, 'Newcastle NE1 3DX');
  });

  test('what the invoice does not have is empty, not the sample\'s', () {
    // "Hide if empty" reacts to this, and it is what will print.
    final data = build(invoice: _invoice({'po_number': ''}), noClient: true);
    expect(data.invoice.poNumber, '');
    expect(data.client.name, '');
    expect(data.client.shippingAddress1, '');
    expect(data.invoice.customValue1, '');
  });

  test('the page\'s tokens resolve to the real values', () {
    final data = build();
    expect(replaceVariables(r'$invoice.number', data: data), '0042');
    expect(replaceVariables(r'$client.name', data: data), 'Blue Door Bakery');
    expect(replaceVariables(r'$contact.full_name', data: data), 'Ada Lovelace');
    expect(replaceVariables(r'$company.name', data: data), base.company.name);
  });
}
