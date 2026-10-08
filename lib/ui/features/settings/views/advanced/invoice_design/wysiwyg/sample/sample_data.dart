import 'package:decimal/decimal.dart';

/// Sample invoice data for the WYSIWYG canvas. Ports React's
/// `useSampleInvoiceData.ts` so the rendered preview shows the same
/// Acme-Corp / INV-0001 fixture before the user picks a real entity. The
/// shape mirrors the React `InvoiceData` interface — keys map 1:1 to the
/// `$client.*`, `$company.*`, `$invoice.*`, `$entity.*`, and flat tokens
/// understood by [replaceVariables].
class DesignerSampleData {
  const DesignerSampleData({
    required this.invoice,
    required this.client,
    required this.company,
    required this.lineItems,
    this.currencyId,
    this.isAmountDiscount = true,
  });

  final DesignerSampleInvoice invoice;
  final DesignerSampleClient client;
  final DesignerSampleCompany company;
  final List<DesignerSampleLineItem> lineItems;

  /// The currency this document's amounts are in — its client's. Null is the
  /// company's own, which is right for the sample and wrong for a real
  /// invoice of a client billed in another currency.
  final String? currencyId;

  /// Whether a line's discount is an amount. When it is a percentage the
  /// server prints `10%`, not ten of the currency.
  final bool isAmountDiscount;

  /// This fixture with the company's own name, address, contact details and
  /// logo in place of the made-up ones — whichever of them the company has
  /// set. The client and the invoice stay sample data.
  ///
  /// A designer that opens on "Your Company LLC" beside a grey box makes the
  /// user imagine their own letterhead; the app already knows it.
  DesignerSampleData withCompany({
    String? name,
    String? logo,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? postalCode,
    String? phone,
    String? email,
    String? website,
    String? vatNumber,
    String? idNumber,
  }) {
    String pick(String? own, String sample) =>
        (own == null || own.trim().isEmpty) ? sample : own.trim();
    final base = company;
    // Only when the company has an address of its own does the sample's
    // second line and city go: half of each would be nobody's address.
    final hasAddress = [
      address1,
      city,
      postalCode,
    ].any((v) => v != null && v.trim().isNotEmpty);
    final cityState = [
      if ((city ?? '').trim().isNotEmpty) city!.trim(),
      if ((state ?? '').trim().isNotEmpty) state!.trim(),
    ].join(', ');
    final postal = (postalCode ?? '').trim();
    return DesignerSampleData(
      invoice: invoice,
      client: client,
      lineItems: lineItems,
      currencyId: currencyId,
      isAmountDiscount: isAmountDiscount,
      company: DesignerSampleCompany(
        name: pick(name, base.name),
        logo: pick(logo, base.logo),
        address: hasAddress ? (address1 ?? '').trim() : base.address,
        address1: hasAddress ? (address1 ?? '').trim() : base.address1,
        address2: hasAddress ? (address2 ?? '').trim() : base.address2,
        cityStatePostal: hasAddress
            ? [cityState, postal].where((v) => v.isNotEmpty).join(' ')
            : base.cityStatePostal,
        postalCityState: hasAddress
            ? [postal, cityState].where((v) => v.isNotEmpty).join(' ')
            : base.postalCityState,
        country: base.country,
        idNumber: pick(idNumber, base.idNumber),
        phone: pick(phone, base.phone),
        email: pick(email, base.email),
        customValue1: base.customValue1,
        customValue2: base.customValue2,
        customValue3: base.customValue3,
        customValue4: base.customValue4,
        website: pick(website, base.website),
        vatNumber: pick(vatNumber, base.vatNumber),
        tags: base.tags,
      ),
    );
  }

  /// Default fixture matching React's `SAMPLE_INVOICE_DATA`. Dates are ISO
  /// strings (formatted on render by the company [Formatter]); money values
  /// are `Decimal` (formatted on render).
  static final DesignerSampleData fallback = DesignerSampleData(
    invoice: DesignerSampleInvoice(
      number: 'INV-0001',
      date: '2025-12-09',
      dueDate: '2025-12-23',
      poNumber: 'PO-2025-001',
      subtotal: Decimal.parse('1500.00'),
      discount: Decimal.zero,
      total: Decimal.parse('1650.00'),
      paidToDate: Decimal.zero,
      balance: Decimal.parse('1650.00'),
      totalTaxes: Decimal.parse('150.00'),
      customSurcharge1: Decimal.parse('25.00'),
      customSurcharge2: Decimal.zero,
      customSurcharge3: Decimal.zero,
      customSurcharge4: Decimal.zero,
      publicUrl: 'https://example.com/invoice/view/INV-0001',
      publicNotes:
          'Thank you for your business! Payment is due within 14 days.',
      footer:
          'If you have any questions, please contact us at hello@yourcompany.com',
      terms:
          'Payment is due within 14 days of invoice date. Late payments may be '
          'subject to a 1.5% monthly service charge.',
      // `$entity_label` on the server is the translated document type in
      // title case ("Invoice", "Quote") — probed, not upper case.
      label: 'Invoice',
      customValue1: 'Custom Invoice Field 1',
      customValue2: 'Custom Invoice Field 2',
      customValue3: 'Custom Invoice Field 3',
      customValue4: 'Custom Invoice Field 4',
      tax: Decimal.parse('150.00'),
      createdAt: '2025-12-01',
      updatedAt: '2025-12-09',
      partialDueDate: '2025-12-15',
      tags: 'Priority, Net30',
    ),
    client: DesignerSampleClient(
      name: 'Acme Corporation',
      number: 'CLIENT-0001',
      address: '123 Business Street',
      address1: '123 Business Street',
      address2: 'Suite 200',
      cityStatePostal: 'New York, NY 10001',
      postalCityState: '10001 New York, NY',
      country: 'United States',
      idNumber: 'ID-456789',
      phone: '(555) 123-4567',
      email: 'billing@acme.com',
      customValue1: 'Custom Client Field 1',
      customValue2: 'Custom Client Field 2',
      customValue3: 'Custom Client Field 3',
      customValue4: 'Custom Client Field 4',
      vatNumber: 'VAT789012',
      contactName: 'Jane Smith',
      contactFullName: 'Jane Smith',
      contactEmail: 'jane@acme.com',
      contactPhone: '(555) 123-4567',
      contactCustomValue1: 'Custom Contact Field 1',
      contactCustomValue2: 'Custom Contact Field 2',
      contactCustomValue3: 'Custom Contact Field 3',
      contactCustomValue4: 'Custom Contact Field 4',
      shippingAddress1: '400 Warehouse Way',
      shippingAddress2: 'Loading Dock B',
      shippingCity: 'Jersey City',
      shippingState: 'NJ',
      shippingPostalCode: '07305',
      shippingCountry: 'United States',
      shippingCityStatePostal: 'Jersey City, NJ 07305',
      shippingPostalCityState: '07305 Jersey City, NJ',
      shippingPostalCity: '07305 Jersey City',
      locationName: 'Main Location',
      locationCustomValue1: 'Custom Location Field 1',
      locationCustomValue2: 'Custom Location Field 2',
      locationCustomValue3: 'Custom Location Field 3',
      locationCustomValue4: 'Custom Location Field 4',
      tags: 'VIP, Wholesale',
    ),
    company: DesignerSampleCompany(
      name: 'Your Company LLC',
      logo: '/logo180.png',
      address: '456 Commerce Avenue',
      address1: '456 Commerce Avenue',
      address2: 'Floor 12',
      cityStatePostal: 'San Francisco, CA 94102',
      postalCityState: '94102 San Francisco, CA',
      country: 'United States',
      idNumber: 'CO-ID-987654',
      phone: '(555) 987-6543',
      email: 'hello@yourcompany.com',
      customValue1: 'Custom Company Field 1',
      customValue2: 'Custom Company Field 2',
      customValue3: 'Custom Company Field 3',
      customValue4: 'Custom Company Field 4',
      website: 'www.yourcompany.com',
      vatNumber: 'VAT123456',
      tags: 'Design, Consulting',
    ),
    lineItems: [
      DesignerSampleLineItem(
        productKey: 'WEB-DESIGN',
        notes: 'Website Design & Development',
        quantity: Decimal.one,
        cost: Decimal.parse('1000.00'),
        netCost: Decimal.parse('1000.00'),
        grossLineTotal: Decimal.parse('1100.00'),
        lineTotal: Decimal.parse('1000.00'),
        discount: Decimal.zero,
        taxRate1: '10%',
        customValue1: 'Custom Item Field 1',
        customValue2: 'Custom Item Field 2',
      ),
      DesignerSampleLineItem(
        productKey: 'CONSULTING',
        notes: 'Technical Consulting Services',
        quantity: Decimal.parse('5'),
        cost: Decimal.parse('100.00'),
        netCost: Decimal.parse('100.00'),
        grossLineTotal: Decimal.parse('550.00'),
        lineTotal: Decimal.parse('500.00'),
        discount: Decimal.zero,
        taxRate1: '10%',
        customValue1: 'Custom Item Field 1',
        customValue2: 'Custom Item Field 2',
      ),
    ],
  );
}

class DesignerSampleInvoice {
  const DesignerSampleInvoice({
    required this.number,
    required this.date,
    required this.dueDate,
    required this.poNumber,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paidToDate,
    required this.balance,
    required this.totalTaxes,
    required this.customSurcharge1,
    required this.customSurcharge2,
    required this.customSurcharge3,
    required this.customSurcharge4,
    required this.publicUrl,
    required this.publicNotes,
    required this.footer,
    required this.terms,
    required this.label,
    required this.customValue1,
    required this.customValue2,
    required this.customValue3,
    required this.customValue4,
    required this.tax,
    required this.createdAt,
    required this.updatedAt,
    required this.partialDueDate,
    required this.tags,
    this.partial,
    this.balanceDue,
  });

  /// The deposit asked for (`$partial`); zero when there is none.
  final Decimal? partial;

  /// What `$balance_due` prints, which is not always [balance]: the deposit
  /// while one is asked for, the full amount on a draft, nothing once paid
  /// (`HtmlEngine.php`). Null is [balance].
  final Decimal? balanceDue;

  /// Whether a deposit is being asked for — the server then also relabels
  /// the balance-due row "Partial Due" and prints the deposit's due date.
  bool get hasPartial => (partial ?? Decimal.zero) > Decimal.zero;

  final String number;
  final String date;
  final String dueDate;
  final String poNumber;
  final Decimal subtotal;
  final Decimal discount;
  final Decimal total;
  final Decimal paidToDate;
  final Decimal balance;
  final Decimal totalTaxes;
  final Decimal customSurcharge1;
  final Decimal customSurcharge2;
  final Decimal customSurcharge3;
  final Decimal customSurcharge4;
  final String publicUrl;
  final String publicNotes;
  final String footer;
  final String terms;
  final String label;
  final String customValue1;
  final String customValue2;
  final String customValue3;
  final String customValue4;
  final Decimal tax;
  final String createdAt;
  final String updatedAt;
  final String partialDueDate;
  final String tags;
}

class DesignerSampleClient {
  const DesignerSampleClient({
    required this.name,
    required this.number,
    required this.address,
    required this.address1,
    required this.address2,
    required this.cityStatePostal,
    required this.postalCityState,
    required this.country,
    required this.idNumber,
    required this.phone,
    required this.email,
    required this.customValue1,
    required this.customValue2,
    required this.customValue3,
    required this.customValue4,
    required this.vatNumber,
    required this.contactName,
    required this.contactFullName,
    required this.contactEmail,
    required this.contactPhone,
    required this.contactCustomValue1,
    required this.contactCustomValue2,
    required this.contactCustomValue3,
    required this.contactCustomValue4,
    required this.shippingAddress1,
    required this.shippingAddress2,
    required this.shippingCity,
    required this.shippingState,
    required this.shippingPostalCode,
    required this.shippingCountry,
    required this.shippingCityStatePostal,
    required this.shippingPostalCityState,
    required this.shippingPostalCity,
    required this.locationName,
    required this.locationCustomValue1,
    required this.locationCustomValue2,
    required this.locationCustomValue3,
    required this.locationCustomValue4,
    required this.tags,
  });

  final String name;
  final String number;
  final String address;
  final String address1;
  final String address2;
  final String cityStatePostal;
  final String postalCityState;
  final String country;
  final String idNumber;
  final String phone;
  final String email;
  final String customValue1;
  final String customValue2;
  final String customValue3;
  final String customValue4;
  final String vatNumber;
  final String contactName;
  final String contactFullName;
  final String contactEmail;
  final String contactPhone;
  final String contactCustomValue1;
  final String contactCustomValue2;
  final String contactCustomValue3;
  final String contactCustomValue4;
  final String shippingAddress1;
  final String shippingAddress2;
  final String shippingCity;
  final String shippingState;
  final String shippingPostalCode;
  final String shippingCountry;
  final String shippingCityStatePostal;
  final String shippingPostalCityState;
  final String shippingPostalCity;
  final String locationName;
  final String locationCustomValue1;
  final String locationCustomValue2;
  final String locationCustomValue3;
  final String locationCustomValue4;
  final String tags;
}

class DesignerSampleCompany {
  const DesignerSampleCompany({
    required this.name,
    required this.logo,
    required this.address,
    required this.address1,
    required this.address2,
    required this.cityStatePostal,
    required this.postalCityState,
    required this.country,
    required this.idNumber,
    required this.phone,
    required this.email,
    required this.customValue1,
    required this.customValue2,
    required this.customValue3,
    required this.customValue4,
    required this.website,
    required this.vatNumber,
    required this.tags,
  });

  final String name;
  final String logo;
  final String address;
  final String address1;
  final String address2;
  final String cityStatePostal;
  final String postalCityState;
  final String country;
  final String idNumber;
  final String phone;
  final String email;
  final String customValue1;
  final String customValue2;
  final String customValue3;
  final String customValue4;
  final String website;
  final String vatNumber;
  final String tags;
}

class DesignerSampleLineItem {
  const DesignerSampleLineItem({
    required this.productKey,
    required this.notes,
    required this.quantity,
    required this.cost,
    required this.netCost,
    required this.grossLineTotal,
    required this.lineTotal,
    required this.discount,
    required this.taxRate1,
    required this.customValue1,
    required this.customValue2,
  });

  final String productKey;
  final String notes;
  final Decimal quantity;
  final Decimal cost;
  final Decimal netCost;
  final Decimal grossLineTotal;
  final Decimal lineTotal;
  final Decimal discount;
  final String taxRate1;
  final String customValue1;
  final String customValue2;
}
