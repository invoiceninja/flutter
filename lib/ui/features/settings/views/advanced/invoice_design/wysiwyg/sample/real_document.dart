import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/domain/billing/billing_doc_totals.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/utils/notes_html.dart';

/// The designer's document filled from one of the company's own invoices.
///
/// The canvas used to show a made-up invoice while the server preview drew a
/// real one, so switching between Design and Preview swapped the whole
/// document and nothing could be compared. With this the page shows the
/// invoice the preview is asked to render.
///
/// The company block comes from [base] — the builder has already put the
/// company's own details there. A value the invoice does not have is empty,
/// not the sample's: that is what will print, and it is what "hide if empty"
/// reacts to.
DesignerSampleData designerDataFromInvoice({
  required Invoice invoice,
  required Client? client,
  required DesignerSampleData base,
  int precision = 2,
  String Function(String countryId)? countryName,
}) {
  String country(String id) => id.isEmpty ? '' : (countryName?.call(id) ?? '');
  String iso(DateTime t) => t.toIso8601String().substring(0, 10);

  final totals = computeTotals(invoice.totalsInput, precision);
  final discount = invoice.isAmountDiscount
      ? invoice.discount
      : (totals.subtotal * invoice.discount / Decimal.fromInt(100))
            .toDecimal(scaleOnInfinitePrecision: 10)
            .round(scale: precision);

  // `HtmlEngine.php`, "Do not change the order of these": a deposit that is
  // asked for is what is due, and its date is the due date; a draft has no
  // balance yet, so its amount is; a paid invoice owes nothing.
  final hasPartial = invoice.partial > Decimal.zero;
  final balanceDue = hasPartial
      ? invoice.partial
      : invoice.isDraft
      ? invoice.amount
      : invoice.statusId == InvoiceStatus.paid
      ? Decimal.zero
      : invoice.balance;
  final dueDate = hasPartial ? invoice.partialDueDate : invoice.dueDate;

  return DesignerSampleData(
    company: base.company,
    // The client's currency, as the server formats with; empty is the
    // company's.
    currencyId: (client?.currencyId ?? '').isEmpty ? null : client!.currencyId,
    isAmountDiscount: invoice.isAmountDiscount,
    invoice: DesignerSampleInvoice(
      number: invoice.number,
      date: invoice.date?.toIso() ?? '',
      dueDate: dueDate?.toIso() ?? '',
      poNumber: invoice.poNumber,
      subtotal: totals.subtotal,
      discount: discount,
      total: invoice.amount,
      paidToDate: invoice.paidToDate,
      // `$balance`: the amount on a draft (`getBalance`).
      balance: invoice.balanceOrAmount,
      balanceDue: balanceDue,
      partial: invoice.partial,
      totalTaxes: invoice.taxAmount,
      customSurcharge1: invoice.customSurcharge1,
      customSurcharge2: invoice.customSurcharge2,
      customSurcharge3: invoice.customSurcharge3,
      customSurcharge4: invoice.customSurcharge4,
      publicUrl: invoice.invitations.firstOrNull?.link ?? '',
      // HTML on the wire; the page draws text.
      publicNotes: plainTextFromHtml(invoice.publicNotes),
      footer: plainTextFromHtml(invoice.footer),
      terms: plainTextFromHtml(invoice.terms),
      label: base.invoice.label,
      customValue1: invoice.customValue1,
      customValue2: invoice.customValue2,
      customValue3: invoice.customValue3,
      customValue4: invoice.customValue4,
      tax: invoice.taxAmount,
      createdAt: iso(invoice.createdAt),
      updatedAt: iso(invoice.updatedAt),
      partialDueDate: invoice.partialDueDate?.toIso() ?? '',
      tags: '',
    ),
    client: _client(invoice, client, country),
    lineItems: [
      for (final item in invoice.lineItems)
        _line(item, invoice: invoice, precision: precision),
    ],
  );
}

DesignerSampleClient _client(
  Invoice invoice,
  Client? client,
  String Function(String) country,
) {
  if (client == null) return _emptyClient;
  final contact =
      client.contacts.where((c) => c.isPrimary).firstOrNull ??
      client.contacts.firstOrNull;
  final contactName = contact == null
      ? ''
      : '${contact.firstName} ${contact.lastName}'.trim();
  final location = client.locations
      .where((l) => l.id == invoice.locationId)
      .firstOrNull;
  // The shipping address is the invoice's location when it names one, else
  // the client's own.
  final ship = location == null
      ? (
          address1: client.shippingAddress1,
          address2: client.shippingAddress2,
          city: client.shippingCity,
          state: client.shippingState,
          postalCode: client.shippingPostalCode,
          countryId: client.shippingCountryId,
        )
      : (
          address1: location.address1,
          address2: location.address2,
          city: location.city,
          state: location.state,
          postalCode: location.postalCode,
          countryId: location.countryId,
        );
  return DesignerSampleClient(
    name: client.displayName.isNotEmpty ? client.displayName : client.name,
    number: client.number,
    address: client.address1,
    address1: client.address1,
    address2: client.address2,
    cityStatePostal: _cityStatePostal(
      client.city,
      client.state,
      client.postalCode,
    ),
    postalCityState: _postalCityState(
      client.postalCode,
      client.city,
      client.state,
    ),
    country: country(client.countryId),
    idNumber: client.idNumber,
    phone: client.phone,
    email: contact?.email ?? '',
    customValue1: client.customValue1,
    customValue2: client.customValue2,
    customValue3: client.customValue3,
    customValue4: client.customValue4,
    vatNumber: client.vatNumber,
    contactName: contactName,
    contactFullName: contactName,
    contactEmail: contact?.email ?? '',
    contactPhone: contact?.phone ?? '',
    contactCustomValue1: contact?.customValue1 ?? '',
    contactCustomValue2: contact?.customValue2 ?? '',
    contactCustomValue3: contact?.customValue3 ?? '',
    contactCustomValue4: contact?.customValue4 ?? '',
    shippingAddress1: ship.address1,
    shippingAddress2: ship.address2,
    shippingCity: ship.city,
    shippingState: ship.state,
    shippingPostalCode: ship.postalCode,
    shippingCountry: country(ship.countryId),
    shippingCityStatePostal: _cityStatePostal(
      ship.city,
      ship.state,
      ship.postalCode,
    ),
    shippingPostalCityState: _postalCityState(
      ship.postalCode,
      ship.city,
      ship.state,
    ),
    shippingPostalCity: _join([ship.postalCode, ship.city], ' '),
    locationName: location?.name ?? '',
    locationCustomValue1: location?.customValue1 ?? '',
    locationCustomValue2: location?.customValue2 ?? '',
    locationCustomValue3: location?.customValue3 ?? '',
    locationCustomValue4: location?.customValue4 ?? '',
    tags: '',
  );
}

DesignerSampleLineItem _line(
  LineItem item, {
  required Invoice invoice,
  required int precision,
}) {
  final lineTotal = computeLineTotal(
    item,
    isAmountDiscount: invoice.isAmountDiscount,
    precision: precision,
  );
  final rate = item.taxRate1 + item.taxRate2 + item.taxRate3;
  // With exclusive taxes the gross adds the line's own rates; inclusive
  // prices already hold them.
  final hundred = Decimal.fromInt(100);
  final gross = invoice.usesInclusiveTaxes || rate == Decimal.zero
      ? lineTotal
      : (lineTotal * (hundred + rate) / hundred)
            .toDecimal(scaleOnInfinitePrecision: 10)
            .round(scale: precision);
  return DesignerSampleLineItem(
    productKey: item.productKey,
    notes: item.notes,
    quantity: item.quantity,
    cost: item.cost,
    netCost: item.cost,
    grossLineTotal: gross,
    lineTotal: lineTotal,
    discount: item.discount,
    taxRate1: item.taxRate1 == Decimal.zero ? '' : '${item.taxRate1}%',
    customValue1: item.customValue1,
    customValue2: item.customValue2,
  );
}

String _join(List<String> parts, String separator) => [
  for (final p in parts)
    if (p.trim().isNotEmpty) p.trim(),
].join(separator);

String _cityStatePostal(String city, String state, String postal) => _join([
  _join([city, state], ', '),
  postal,
], ' ');

String _postalCityState(String postal, String city, String state) => _join([
  postal,
  _join([city, state], ', '),
], ' ');

const DesignerSampleClient _emptyClient = DesignerSampleClient(
  name: '',
  number: '',
  address: '',
  address1: '',
  address2: '',
  cityStatePostal: '',
  postalCityState: '',
  country: '',
  idNumber: '',
  phone: '',
  email: '',
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  vatNumber: '',
  contactName: '',
  contactFullName: '',
  contactEmail: '',
  contactPhone: '',
  contactCustomValue1: '',
  contactCustomValue2: '',
  contactCustomValue3: '',
  contactCustomValue4: '',
  shippingAddress1: '',
  shippingAddress2: '',
  shippingCity: '',
  shippingState: '',
  shippingPostalCode: '',
  shippingCountry: '',
  shippingCityStatePostal: '',
  shippingPostalCityState: '',
  shippingPostalCity: '',
  locationName: '',
  locationCustomValue1: '',
  locationCustomValue2: '',
  locationCustomValue3: '',
  locationCustomValue4: '',
  tags: '',
);
