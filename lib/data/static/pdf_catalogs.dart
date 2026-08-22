/// Static catalogs for the Invoice Design settings page. None of this data is
/// shipped by `/api/v1/statics` — fonts, page sizes, page layouts, and the
/// available PDF variables per section are hardcoded in the legacy admin-portal
/// and the React web client too. Keep them in sync with those sources.
///
/// Each section's `defaultSelected` tracks the server's first-load default,
/// `CompanySettings::getEntityVariableDefaults()` in the invoiceninja backend —
/// the per-tab `Reset` button restores exactly this list. Update these when
/// that method changes.
library;

/// `settings.page_layout` wire values.
const kPageLayouts = <String>['portrait', 'landscape'];

/// `settings.page_size` wire values.
const kPageSizes = <String>[
  'A5',
  'A4',
  'A3',
  'B5',
  'B4',
  'JIS-B5',
  'JIS-B4',
  'letter',
  'legal',
  'ledger',
];

/// `settings.font_size` wire values. Server treats this as an int (point size).
const kFontSizes = <int>[
  6,
  8,
  10,
  12,
  14,
  16,
  18,
  20,
  22,
  24,
  26,
  28,
  30,
  32,
  34,
  36,
  38,
  40,
  42,
];

/// `settings.page_numbering_alignment` wire values.
class PageNumberingAlignment {
  static const left = 'L';
  static const center = 'C';
  static const right = 'R';
}

const kPageNumberingAlignments = <String>[
  PageNumberingAlignment.left,
  PageNumberingAlignment.center,
  PageNumberingAlignment.right,
];

/// `settings.company_logo_size` unit suffix. The wire value is a string like
/// `"100%"` or `"80px"`; the unit is the last 1–2 chars.
class LogoSizeUnit {
  static const percent = '%';
  static const pixels = 'px';
}

const kLogoSizeUnits = <String>[LogoSizeUnit.percent, LogoSizeUnit.pixels];

/// Section keys used in [CompanySettings.pdfVariables]. The map key on the
/// wire is one of these literals; renaming any will break round-trips.
class PdfVariableSection {
  static const clientDetails = 'client_details';
  static const companyDetails = 'company_details';
  static const companyAddress = 'company_address';
  static const invoiceDetails = 'invoice_details';
  static const quoteDetails = 'quote_details';
  static const creditDetails = 'credit_details';
  static const vendorDetails = 'vendor_details';
  static const purchaseOrderDetails = 'purchase_order_details';
  static const productColumns = 'product_columns';
  static const productQuoteColumns = 'product_quote_columns';
  static const taskColumns = 'task_columns';
  static const totalColumns = 'total_columns';
}

/// Variables available for a PDF section, plus the subset selected by default
/// when the saved settings don't override the section.
class PdfVariableCatalog {
  const PdfVariableCatalog({
    required this.sectionKey,
    required this.titleKey,
    required this.available,
    required this.defaultSelected,
  });

  /// Wire key under [CompanySettings.pdfVariables] (e.g. `'client_details'`).
  final String sectionKey;

  /// Localization key for the page / tab title (e.g. `'client_details'`).
  final String titleKey;

  /// All variables the user can add. Each entry is the full token including
  /// the leading `$` and namespace, e.g. `'$client.name'`.
  final List<String> available;

  /// Variables included on first paint when the saved `pdf_variables` map
  /// doesn't carry this section.
  final List<String> defaultSelected;
}

/// Static field-name constants — port of admin-portal's `ClientFields`,
/// `CompanyFields`, etc. classes (`lib/data/models/*_model.dart`). String
/// values are exactly what the server expects after the `$<namespace>.`
/// prefix.
class _ClientFields {
  static const name = 'name';
  static const number = 'number';
  static const idNumber = 'id_number';
  static const vatNumber = 'vat_number';
  static const website = 'website';
  static const phone = 'phone';
  static const address1 = 'address1';
  static const address2 = 'address2';
  static const cityStatePostal = 'city_state_postal';
  static const postalCityState = 'postal_city_state';
  static const postalCity = 'postal_city';
  static const country = 'country';
  static const locationName = 'location_name';
  static const balance = 'balance';
  static const custom1 = 'custom1';
  static const custom2 = 'custom2';
  static const custom3 = 'custom3';
  static const custom4 = 'custom4';
  static const tags = 'tags';
}

class _ContactFields {
  static const fullName = 'full_name';
  static const email = 'email';
  static const phone = 'phone';
  static const custom1 = 'custom1';
  static const custom2 = 'custom2';
  static const custom3 = 'custom3';
  static const custom4 = 'custom4';
}

class _CompanyFields {
  static const name = 'name';
  static const idNumber = 'id_number';
  static const vatNumber = 'vat_number';
  static const website = 'website';
  static const email = 'email';
  static const phone = 'phone';
  static const address1 = 'address1';
  static const address2 = 'address2';
  static const cityStatePostal = 'city_state_postal';
  static const postalCityState = 'postal_city_state';
  static const postalCity = 'postal_city';
  static const country = 'country';
  static const custom1 = 'custom1';
  static const custom2 = 'custom2';
  static const custom3 = 'custom3';
  static const custom4 = 'custom4';
  static const tags = 'tags';
}

class _InvoiceFields {
  static const number = 'number';
  static const poNumber = 'po_number';
  static const date = 'date';
  static const dueDate = 'due_date';
  static const amount = 'amount';
  static const balance = 'balance';
  static const balanceDue = 'balance_due';
  static const total = 'total';
  static const project = 'project';
  static const vendor = 'vendor';
  static const customValue1 = 'custom1';
  static const customValue2 = 'custom2';
  static const customValue3 = 'custom3';
  static const customValue4 = 'custom4';
  static const tags = 'tags';
}

class _QuoteFields {
  static const number = 'number';
  static const poNumber = 'po_number';
  static const date = 'date';
  static const validUntil = 'valid_until';
  static const total = 'total';
  static const project = 'project';
  static const customValue1 = 'custom1';
  static const customValue2 = 'custom2';
  static const customValue3 = 'custom3';
  static const customValue4 = 'custom4';
  static const tags = 'tags';
}

class _CreditFields {
  static const number = 'number';
  static const poNumber = 'po_number';
  static const validUntil = 'valid_until';
  static const date = 'date';
  static const total = 'total';
  static const balance = 'balance';
  static const customValue1 = 'custom1';
  static const customValue2 = 'custom2';
  static const customValue3 = 'custom3';
  static const customValue4 = 'custom4';
  static const tags = 'tags';
}

class _VendorFields {
  static const name = 'name';
  static const number = 'number';
  static const vatNumber = 'vat_number';
  static const address1 = 'address1';
  static const address2 = 'address2';
  static const cityStatePostal = 'city_state_postal';
  static const postalCityState = 'postal_city_state';
  static const postalCity = 'postal_city';
  static const country = 'country';
  static const phone = 'phone';
  static const customValue1 = 'custom1';
  static const customValue2 = 'custom2';
  static const customValue3 = 'custom3';
  static const customValue4 = 'custom4';
  static const tags = 'tags';
}

class _PurchaseOrderFields {
  static const number = 'number';
  static const poNumber = 'po_number';
  static const date = 'date';
  static const dueDate = 'due_date';
  static const total = 'total';
  static const balanceDue = 'balance_due';
  static const customValue1 = 'custom1';
  static const customValue2 = 'custom2';
  static const customValue3 = 'custom3';
  static const customValue4 = 'custom4';
  static const tags = 'tags';
}

class _ProductFields {
  static const item = 'item';
  static const description = 'description';
  static const quantity = 'quantity';
  static const unitCost = 'unit_cost';
  static const tax = 'tax';
  static const taxAmount = 'tax_amount';
  static const discount = 'discount';
  static const lineTotal = 'line_total';
  static const grossLineTotal = 'gross_line_total';
  static const netCost = 'net_cost';
  static const custom1 = 'product1';
  static const custom2 = 'product2';
  static const custom3 = 'product3';
  static const custom4 = 'product4';
  static const tags = 'tags';
}

class _TaskFields {
  static const service = 'service';
  static const description = 'description';
  static const hours = 'hours';
  static const rate = 'rate';
  static const tax = 'tax';
  static const taxAmount = 'tax_amount';
  static const discount = 'discount';
  static const lineTotal = 'line_total';
  static const grossLineTotal = 'gross_line_total';
  static const custom1 = 'task1';
  static const custom2 = 'task2';
  static const custom3 = 'task3';
  static const custom4 = 'task4';
  static const tags = 'tags';
}

class _TotalFields {
  static const subtotal = 'subtotal';
  static const netSubtotal = 'net_subtotal';
  static const discount = 'discount';
  static const lineTaxes = 'line_taxes';
  static const totalTaxes = 'total_taxes';
  static const customSurcharge1 = 'custom_surcharge1';
  static const customSurcharge2 = 'custom_surcharge2';
  static const customSurcharge3 = 'custom_surcharge3';
  static const customSurcharge4 = 'custom_surcharge4';
  static const paidToDate = 'paid_to_date';
  static const total = 'total';
  static const outstanding = 'outstanding';
}

List<String> _prefix(String namespace, List<String> fields) =>
    fields.map((f) => '\$$namespace.$f').toList(growable: false);

/// All PDF-variable sections keyed by [PdfVariableSection]. Used by:
/// - `PdfVariableListBody` to render the per-tab reorderable list
/// - `kPdfVariableSectionOrder` to enumerate the tabs in display order
final Map<String, PdfVariableCatalog> kPdfVariableSections = {
  PdfVariableSection.clientDetails: PdfVariableCatalog(
    sectionKey: PdfVariableSection.clientDetails,
    titleKey: 'client_details',
    available: [
      ..._prefix('client', [
        _ClientFields.name,
        _ClientFields.number,
        _ClientFields.idNumber,
        _ClientFields.vatNumber,
        _ClientFields.website,
        _ClientFields.phone,
        _ClientFields.address1,
        _ClientFields.address2,
        _ClientFields.cityStatePostal,
        _ClientFields.postalCityState,
        _ClientFields.postalCity,
        _ClientFields.country,
        _ClientFields.locationName,
        _ClientFields.custom1,
        _ClientFields.custom2,
        _ClientFields.custom3,
        _ClientFields.custom4,
        _ClientFields.tags,
      ]),
      ..._prefix('contact', [
        _ContactFields.fullName,
        _ContactFields.email,
        _ContactFields.phone,
        _ContactFields.custom1,
        _ContactFields.custom2,
        _ContactFields.custom3,
        _ContactFields.custom4,
      ]),
    ],
    defaultSelected: [
      ..._prefix('client', [
        _ClientFields.locationName,
        _ClientFields.name,
        _ClientFields.number,
        _ClientFields.vatNumber,
        _ClientFields.address1,
        _ClientFields.address2,
        _ClientFields.cityStatePostal,
        _ClientFields.country,
        _ClientFields.phone,
      ]),
      ..._prefix('contact', [_ContactFields.email]),
    ],
  ),

  PdfVariableSection.companyDetails: PdfVariableCatalog(
    sectionKey: PdfVariableSection.companyDetails,
    titleKey: 'company_details',
    available: _prefix('company', [
      _CompanyFields.name,
      _CompanyFields.idNumber,
      _CompanyFields.vatNumber,
      _CompanyFields.website,
      _CompanyFields.email,
      _CompanyFields.phone,
      _CompanyFields.address1,
      _CompanyFields.address2,
      _CompanyFields.cityStatePostal,
      _CompanyFields.postalCityState,
      _CompanyFields.postalCity,
      _CompanyFields.country,
      _CompanyFields.custom1,
      _CompanyFields.custom2,
      _CompanyFields.custom3,
      _CompanyFields.custom4,
      _CompanyFields.tags,
    ]),
    defaultSelected: _prefix('company', [
      _CompanyFields.name,
      _CompanyFields.idNumber,
      _CompanyFields.vatNumber,
      _CompanyFields.website,
      _CompanyFields.email,
      _CompanyFields.phone,
    ]),
  ),

  PdfVariableSection.companyAddress: PdfVariableCatalog(
    sectionKey: PdfVariableSection.companyAddress,
    titleKey: 'company_address',
    available: _prefix('company', [
      _CompanyFields.name,
      _CompanyFields.idNumber,
      _CompanyFields.vatNumber,
      _CompanyFields.website,
      _CompanyFields.email,
      _CompanyFields.phone,
      _CompanyFields.address1,
      _CompanyFields.address2,
      _CompanyFields.cityStatePostal,
      _CompanyFields.postalCityState,
      _CompanyFields.postalCity,
      _CompanyFields.country,
      _CompanyFields.custom1,
      _CompanyFields.custom2,
      _CompanyFields.custom3,
      _CompanyFields.custom4,
      _CompanyFields.tags,
    ]),
    defaultSelected: _prefix('company', [
      _CompanyFields.address1,
      _CompanyFields.address2,
      _CompanyFields.cityStatePostal,
      _CompanyFields.country,
    ]),
  ),

  PdfVariableSection.invoiceDetails: PdfVariableCatalog(
    sectionKey: PdfVariableSection.invoiceDetails,
    titleKey: 'invoice_details',
    available: [
      ..._prefix('invoice', [
        _InvoiceFields.number,
        _InvoiceFields.poNumber,
        _InvoiceFields.date,
        _InvoiceFields.dueDate,
        _InvoiceFields.amount,
        _InvoiceFields.balance,
        _InvoiceFields.balanceDue,
        _InvoiceFields.total,
        _InvoiceFields.project,
        _InvoiceFields.vendor,
        _InvoiceFields.customValue1,
        _InvoiceFields.customValue2,
        _InvoiceFields.customValue3,
        _InvoiceFields.customValue4,
        _InvoiceFields.tags,
      ]),
      ..._prefix('client', [_ClientFields.balance]),
    ],
    defaultSelected: _prefix('invoice', [
      _InvoiceFields.number,
      _InvoiceFields.poNumber,
      _InvoiceFields.date,
      _InvoiceFields.dueDate,
      _InvoiceFields.total,
      _InvoiceFields.balanceDue,
      _InvoiceFields.project,
    ]),
  ),

  PdfVariableSection.quoteDetails: PdfVariableCatalog(
    sectionKey: PdfVariableSection.quoteDetails,
    titleKey: 'quote_details',
    available: [
      ..._prefix('quote', [
        _QuoteFields.number,
        _QuoteFields.poNumber,
        _QuoteFields.date,
        _QuoteFields.validUntil,
        _QuoteFields.total,
        _QuoteFields.project,
        _QuoteFields.customValue1,
        _QuoteFields.customValue2,
        _QuoteFields.customValue3,
        _QuoteFields.customValue4,
        _QuoteFields.tags,
      ]),
      ..._prefix('client', [_ClientFields.balance]),
    ],
    defaultSelected: _prefix('quote', [
      _QuoteFields.number,
      _QuoteFields.poNumber,
      _QuoteFields.date,
      _QuoteFields.validUntil,
      _QuoteFields.total,
      _QuoteFields.project,
    ]),
  ),

  PdfVariableSection.creditDetails: PdfVariableCatalog(
    sectionKey: PdfVariableSection.creditDetails,
    titleKey: 'credit_details',
    available: [
      ..._prefix('credit', [
        _CreditFields.number,
        _CreditFields.poNumber,
        _CreditFields.date,
        _CreditFields.validUntil,
        _CreditFields.total,
        _CreditFields.balance,
        _CreditFields.customValue1,
        _CreditFields.customValue2,
        _CreditFields.customValue3,
        _CreditFields.customValue4,
        _CreditFields.tags,
      ]),
      ..._prefix('client', [_ClientFields.balance]),
    ],
    defaultSelected: _prefix('credit', [
      _CreditFields.number,
      _CreditFields.poNumber,
      _CreditFields.validUntil,
      _CreditFields.date,
      _CreditFields.balance,
      _CreditFields.total,
    ]),
  ),

  PdfVariableSection.vendorDetails: PdfVariableCatalog(
    sectionKey: PdfVariableSection.vendorDetails,
    titleKey: 'vendor_details',
    available: [
      ..._prefix('vendor', [
        _VendorFields.name,
        _VendorFields.number,
        _VendorFields.vatNumber,
        _VendorFields.address1,
        _VendorFields.address2,
        _VendorFields.cityStatePostal,
        _VendorFields.postalCityState,
        _VendorFields.postalCity,
        _VendorFields.country,
        _VendorFields.phone,
        _VendorFields.customValue1,
        _VendorFields.customValue2,
        _VendorFields.customValue3,
        _VendorFields.customValue4,
        _VendorFields.tags,
      ]),
      ..._prefix('contact', [_ContactFields.email]),
    ],
    defaultSelected: [
      ..._prefix('vendor', [
        _VendorFields.name,
        _VendorFields.number,
        _VendorFields.vatNumber,
        _VendorFields.address1,
        _VendorFields.address2,
        _VendorFields.cityStatePostal,
        _VendorFields.country,
        _VendorFields.phone,
      ]),
      ..._prefix('contact', [_ContactFields.email]),
    ],
  ),

  PdfVariableSection.purchaseOrderDetails: PdfVariableCatalog(
    sectionKey: PdfVariableSection.purchaseOrderDetails,
    titleKey: 'purchase_order_details',
    available: _prefix('purchase_order', [
      _PurchaseOrderFields.number,
      _PurchaseOrderFields.poNumber,
      _PurchaseOrderFields.date,
      _PurchaseOrderFields.dueDate,
      _PurchaseOrderFields.total,
      _PurchaseOrderFields.balanceDue,
      _PurchaseOrderFields.customValue1,
      _PurchaseOrderFields.customValue2,
      _PurchaseOrderFields.customValue3,
      _PurchaseOrderFields.customValue4,
      _PurchaseOrderFields.tags,
    ]),
    defaultSelected: _prefix('purchase_order', [
      _PurchaseOrderFields.number,
      _PurchaseOrderFields.poNumber,
      _PurchaseOrderFields.date,
      _PurchaseOrderFields.dueDate,
      _PurchaseOrderFields.total,
      _PurchaseOrderFields.balanceDue,
    ]),
  ),

  PdfVariableSection.productColumns: PdfVariableCatalog(
    sectionKey: PdfVariableSection.productColumns,
    titleKey: 'product_columns',
    available: _prefix('product', [
      _ProductFields.item,
      _ProductFields.description,
      _ProductFields.quantity,
      _ProductFields.unitCost,
      _ProductFields.tax,
      _ProductFields.taxAmount,
      _ProductFields.discount,
      _ProductFields.lineTotal,
      _ProductFields.custom1,
      _ProductFields.custom2,
      _ProductFields.custom3,
      _ProductFields.custom4,
      _ProductFields.grossLineTotal,
      _ProductFields.netCost,
      _ProductFields.tags,
    ]),
    defaultSelected: _prefix('product', [
      _ProductFields.item,
      _ProductFields.description,
      _ProductFields.unitCost,
      _ProductFields.quantity,
      _ProductFields.discount,
      _ProductFields.tax,
      _ProductFields.lineTotal,
    ]),
  ),

  PdfVariableSection.productQuoteColumns: PdfVariableCatalog(
    sectionKey: PdfVariableSection.productQuoteColumns,
    titleKey: 'quote_product_columns',
    available: _prefix('product', [
      _ProductFields.item,
      _ProductFields.description,
      _ProductFields.quantity,
      _ProductFields.unitCost,
      _ProductFields.tax,
      _ProductFields.taxAmount,
      _ProductFields.discount,
      _ProductFields.lineTotal,
      _ProductFields.custom1,
      _ProductFields.custom2,
      _ProductFields.custom3,
      _ProductFields.custom4,
      _ProductFields.grossLineTotal,
      _ProductFields.tags,
    ]),
    defaultSelected: _prefix('product', [
      _ProductFields.item,
      _ProductFields.description,
      _ProductFields.unitCost,
      _ProductFields.quantity,
      _ProductFields.discount,
      _ProductFields.tax,
      _ProductFields.lineTotal,
    ]),
  ),

  PdfVariableSection.taskColumns: PdfVariableCatalog(
    sectionKey: PdfVariableSection.taskColumns,
    titleKey: 'task_columns',
    available: _prefix('task', [
      _TaskFields.service,
      _TaskFields.description,
      _TaskFields.hours,
      _TaskFields.rate,
      _TaskFields.tax,
      _TaskFields.taxAmount,
      _TaskFields.discount,
      _TaskFields.lineTotal,
      _TaskFields.custom1,
      _TaskFields.custom2,
      _TaskFields.custom3,
      _TaskFields.custom4,
      _TaskFields.grossLineTotal,
      _TaskFields.tags,
    ]),
    defaultSelected: _prefix('task', [
      _TaskFields.service,
      _TaskFields.description,
      _TaskFields.rate,
      _TaskFields.hours,
      _TaskFields.discount,
      _TaskFields.tax,
      _TaskFields.lineTotal,
    ]),
  ),

  PdfVariableSection.totalColumns: PdfVariableCatalog(
    sectionKey: PdfVariableSection.totalColumns,
    titleKey: 'total_fields',
    available: <String>[
      '\$${_TotalFields.subtotal}',
      '\$${_TotalFields.netSubtotal}',
      '\$${_TotalFields.discount}',
      '\$${_TotalFields.lineTaxes}',
      '\$${_TotalFields.totalTaxes}',
      '\$${_TotalFields.customSurcharge1}',
      '\$${_TotalFields.customSurcharge2}',
      '\$${_TotalFields.customSurcharge3}',
      '\$${_TotalFields.customSurcharge4}',
      '\$${_TotalFields.paidToDate}',
      '\$${_TotalFields.total}',
      '\$${_TotalFields.outstanding}',
    ],
    defaultSelected: <String>[
      '\$${_TotalFields.netSubtotal}',
      '\$${_TotalFields.subtotal}',
      '\$${_TotalFields.discount}',
      '\$${_TotalFields.customSurcharge1}',
      '\$${_TotalFields.customSurcharge2}',
      '\$${_TotalFields.customSurcharge3}',
      '\$${_TotalFields.customSurcharge4}',
      '\$${_TotalFields.totalTaxes}',
      '\$${_TotalFields.lineTaxes}',
      '\$${_TotalFields.total}',
      '\$${_TotalFields.paidToDate}',
      '\$${_TotalFields.outstanding}',
    ],
  ),
};

/// Display order of PDF-variable tabs. The shell filters by enabled-module
/// flags and `sync_invoice_quote_columns`.
const kPdfVariableSectionOrder = <String>[
  PdfVariableSection.clientDetails,
  PdfVariableSection.companyDetails,
  PdfVariableSection.companyAddress,
  PdfVariableSection.invoiceDetails,
  PdfVariableSection.quoteDetails,
  PdfVariableSection.creditDetails,
  PdfVariableSection.vendorDetails,
  PdfVariableSection.purchaseOrderDetails,
  PdfVariableSection.productColumns,
  PdfVariableSection.productQuoteColumns,
  PdfVariableSection.taskColumns,
  PdfVariableSection.totalColumns,
];
