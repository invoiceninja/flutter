import 'package:admin/data/models/domain/company_settings.dart';

/// The five entity types that share line items, taxes, totals, contacts,
/// designs, PDF rendering, and email — invoice / quote / credit /
/// purchase_order / recurring_invoice. Used by widgets in
/// `lib/ui/features/billing_shared/` to branch on entity-specific copy
/// without importing the entity domain models (which keeps the shared
/// layer independent of any single entity).
enum BillingDocType {
  invoice,
  quote,
  credit,
  purchaseOrder,
  recurringInvoice;

  /// Wire name used in API paths (`/api/v1/invoices`, `/api/v1/quotes`,
  /// `/api/v1/credits`, `/api/v1/purchase_orders`, `/api/v1/recurring_invoices`).
  String get wireName => switch (this) {
    BillingDocType.invoice => 'invoice',
    BillingDocType.quote => 'quote',
    BillingDocType.credit => 'credit',
    BillingDocType.purchaseOrder => 'purchase_order',
    BillingDocType.recurringInvoice => 'recurring_invoice',
  };

  /// Pluralized API path segment.
  String get apiPath => switch (this) {
    BillingDocType.invoice => '/api/v1/invoices',
    BillingDocType.quote => '/api/v1/quotes',
    BillingDocType.credit => '/api/v1/credits',
    BillingDocType.purchaseOrder => '/api/v1/purchase_orders',
    BillingDocType.recurringInvoice => '/api/v1/recurring_invoices',
  };

  /// i18n key for the singular form ("Invoice", "Quote", …). Resolved via
  /// `context.tr(type.singularLabelKey)`.
  String get singularLabelKey => switch (this) {
    BillingDocType.invoice => 'invoice',
    BillingDocType.quote => 'quote',
    BillingDocType.credit => 'credit',
    BillingDocType.purchaseOrder => 'purchase_order',
    BillingDocType.recurringInvoice => 'recurring_invoice',
  };

  /// i18n key for the plural form ("Invoices", "Quotes", …).
  String get pluralLabelKey => switch (this) {
    BillingDocType.invoice => 'invoices',
    BillingDocType.quote => 'quotes',
    BillingDocType.credit => 'credits',
    BillingDocType.purchaseOrder => 'purchase_orders',
    BillingDocType.recurringInvoice => 'recurring_invoices',
  };

  /// Delivery-note PDF variant is invoice-only (admin-portal endpoint:
  /// `POST /api/v1/invoices/{id}/delivery_note`). Other billing docs hide
  /// the toggle.
  bool get supportsDeliveryNote => this == BillingDocType.invoice;

  /// Whether a *future* (scheduled) send is supported. The server's
  /// `task_scheduler` only accepts invoice / quote / credit / purchase_order
  /// as schedulable entities — `recurring_invoice` is not valid, so a
  /// "schedule" there silently degrades to an immediate send. The email
  /// composer hides the Schedule action when this is false.
  bool get supportsScheduledSend => this != BillingDocType.recurringInvoice;

  /// In-stock quantity is shown at the product-selection point (line-item
  /// picker + inline typeahead) only on invoices — the doc that consumes
  /// stock. React parity (its product selector passes `displayStockQuantity`
  /// only on `/invoices`). Other billing docs leave the count hidden.
  bool get showsProductStock => this == BillingDocType.invoice;

  // ── The edit layout's capability spec ───────────────────────────────
  //
  // What `BillingDocEditLayout` needs to know to be each document. Every
  // difference the five copied layouts had is named here — the accidental
  // ones too, kept as they were (the mobile partial field's placement, the
  // recurring invoice's desktop number label): unifying those is a product
  // decision, not a refactor. `billing_doc_type_test.dart` pins every value.

  /// Who the document is addressed to. Decides the picker, the contacts,
  /// the totals' currency, the PDF gate and the line-item editor.
  BillingDocParty get party => this == BillingDocType.purchaseOrder
      ? BillingDocParty.vendor
      : BillingDocParty.client;

  /// The document-date and due-date labels; null on the recurring invoice,
  /// whose dates come from its schedule.
  String? get dateLabelKey => switch (this) {
    BillingDocType.invoice => 'invoice_date',
    BillingDocType.quote => 'quote_date',
    BillingDocType.credit => 'credit_date',
    BillingDocType.purchaseOrder => 'purchase_order_date',
    BillingDocType.recurringInvoice => null,
  };

  String? get dueDateLabelKey => switch (this) {
    BillingDocType.quote => 'valid_until',
    BillingDocType.recurringInvoice => null,
    _ => 'due_date',
  };

  /// The number field's label on the narrow layout.
  String get numberLabelKey => switch (this) {
    BillingDocType.invoice => 'invoice_number',
    BillingDocType.quote => 'quote_number',
    BillingDocType.credit => 'credit_number',
    BillingDocType.purchaseOrder => 'po_number',
    BillingDocType.recurringInvoice => 'recurring_invoice_number',
  };

  /// The number field's label on the desktop card. The recurring invoice's
  /// says "Invoice Number" there and "Recurring Number" on the narrow layout —
  /// kept as it shipped.
  String get desktopNumberLabelKey => this == BillingDocType.recurringInvoice
      ? 'invoice_number'
      : numberLabelKey;

  /// Whether the document has a PO-number field beside its own number. A
  /// purchase order's own number IS its PO number (labelled so), exactly as
  /// React and v1 present it.
  bool get hasPoNumberField => this != BillingDocType.purchaseOrder;

  /// Where the narrow Details tab puts the partial-payment field, or none.
  BillingDocPartialPlacement get mobilePartialPlacement => switch (this) {
    BillingDocType.invoice => BillingDocPartialPlacement.afterDatesRow,
    BillingDocType.quote => BillingDocPartialPlacement.afterDiscount,
    BillingDocType.credit => BillingDocPartialPlacement.afterDates,
    BillingDocType.purchaseOrder ||
    BillingDocType.recurringInvoice => BillingDocPartialPlacement.none,
  };

  bool get hasPartial =>
      mobilePartialPlacement != BillingDocPartialPlacement.none;

  /// Whether a line item's row menu offers "create a task from this"
  /// (invoiceninja/flutter#88).
  bool get supportsCreateTaskFromLineItem =>
      this == BillingDocType.invoice || this == BillingDocType.quote;

  /// Whether inactive narrow tabs are kept out of arrow-key traversal — see
  /// `BillingDocEditTabStrip.excludeInactiveFocus` for why only here.
  bool get excludesInactiveTabFocus => this == BillingDocType.recurringInvoice;

  /// The company setting a "Save as default" on the terms / footer writes;
  /// null on the recurring invoice, which inherits the invoice's.
  String? get termsDefaultKey =>
      this == BillingDocType.recurringInvoice ? null : '${wireName}_terms';

  String? get footerDefaultKey =>
      this == BillingDocType.recurringInvoice ? null : '${wireName}_footer';

  /// [settings] with [value] as this document's default terms / footer.
  CompanySettings withDefaultTerms(CompanySettings settings, String? value) =>
      switch (this) {
        BillingDocType.invoice => settings.copyWith(invoiceTerms: value),
        BillingDocType.quote => settings.copyWith(quoteTerms: value),
        BillingDocType.credit => settings.copyWith(creditTerms: value),
        BillingDocType.purchaseOrder => settings.copyWith(
          purchaseOrderTerms: value,
        ),
        BillingDocType.recurringInvoice => settings,
      };

  CompanySettings withDefaultFooter(CompanySettings settings, String? value) =>
      switch (this) {
        BillingDocType.invoice => settings.copyWith(invoiceFooter: value),
        BillingDocType.quote => settings.copyWith(quoteFooter: value),
        BillingDocType.credit => settings.copyWith(creditFooter: value),
        BillingDocType.purchaseOrder => settings.copyWith(
          purchaseOrderFooter: value,
        ),
        BillingDocType.recurringInvoice => settings,
      };

  /// Hero tags of the line-item picker FAB on the desktop page and over the
  /// narrow Items tab's wide table.
  String get pickerFabHeroTag => '${wireName}_picker_fab';
  String get mobilePickerFabHeroTag => '${wireName}_picker_fab_mobile';
}

/// Who a billing document is addressed to.
enum BillingDocParty { client, vendor }

/// Where the narrow Details tab puts the partial-payment (deposit) field. The
/// three placements are an accident of five copied layouts, kept as shipped.
enum BillingDocPartialPlacement {
  /// No partial payment (purchase order, recurring invoice).
  none,

  /// After Discount, its due date only once a partial is set (quote).
  afterDiscount,

  /// After the dates, its due date only once a partial is set (credit).
  afterDates,

  /// After the dates, beside its due date, both always shown (invoice).
  afterDatesRow,
}
