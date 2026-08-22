/// Catalog of placeholders the server expands when rendering a custom
/// design or a template (Twig). Drives both the in-editor autocomplete
/// overlay and the Variables side pane in the design editor.
///
/// Two distinct surfaces, distinguished by `Design.isTemplate`:
///
/// 1. **Designs** (`isTemplate = false`) — flat `$tokens` like
///    `$client.name`, `$invoice.balance`. Source:
///    https://invoiceninja.github.io/docs/advanced-topics/custom-fields
///
/// 2. **Templates** (`isTemplate = true`) — Twig (`{{ … }}` / `{% … %}`)
///    operating on a full entity object graph, inside `<ninja></ninja>`
///    blocks. Plus a sandboxed grammar (tags / filters / functions /
///    methods / properties). Source:
///    https://invoiceninja.github.io/docs/advanced-topics/templates
///
/// Both pages were re-fetched on 2026-05-24 and the catalogs are copied
/// verbatim here. When the docs change, re-fetch and update by hand.
library;

// =============================================================================
// $-token catalog (Designs page)
// =============================================================================

class DesignToken {
  const DesignToken(this.token, this.categoryKey);

  /// Literal token including the leading `$`.
  final String token;

  /// Localization key for the group label (e.g. `'invoice'`, `'client'`).
  /// Renders verbatim if no translation exists.
  final String categoryKey;
}

/// Every `$`-prefixed token documented on the Designs page, grouped by
/// section. The order matches the doc page; do not sort alphabetically —
/// the section grouping is the more useful axis.
const List<DesignToken> kDesignTokens = [
  // General / System
  DesignToken(r'$tax', 'general'),
  DesignToken(r'$app_url', 'general'),
  DesignToken(r'$from', 'general'),
  DesignToken(r'$to', 'general'),
  DesignToken(r'$total_tax_labels', 'general'),
  DesignToken(r'$total_tax_values', 'general'),
  DesignToken(r'$line_tax_labels', 'general'),
  DesignToken(r'$line_tax_values', 'general'),

  // Dates
  DesignToken(r'$date', 'date'),
  DesignToken(r'$invoice.date', 'date'),
  DesignToken(r'$due_date', 'date'),
  DesignToken(r'$invoice.due_date', 'date'),
  DesignToken(r'$payment_due', 'date'),
  DesignToken(r'$entity.datetime', 'date'),
  DesignToken(r'$invoice.datetime', 'date'),
  DesignToken(r'$quote.datetime', 'date'),
  DesignToken(r'$credit.datetime', 'date'),

  // Entity / Document (generic)
  DesignToken(r'$entity', 'entity'),
  DesignToken(r'$number', 'entity'),
  DesignToken(r'$entity_number', 'entity'),
  DesignToken(r'$entity_issued_to', 'entity'),
  DesignToken(r'$your_entity', 'entity'),
  DesignToken(r'$entity.terms', 'entity'),
  DesignToken(r'$terms', 'entity'),
  DesignToken(r'$entity.public_notes', 'entity'),
  DesignToken(r'$entity_footer', 'entity'),

  // Invoice
  DesignToken(r'$invoice.number', 'invoice'),
  DesignToken(r'$invoice.po_number', 'invoice'),
  DesignToken(r'$invoice.discount', 'invoice'),
  DesignToken(r'$invoice.subtotal', 'invoice'),
  DesignToken(r'$invoice.balance_due', 'invoice'),
  DesignToken(r'$invoice.total', 'invoice'),
  DesignToken(r'$invoice.amount', 'invoice'),
  DesignToken(r'$invoice.taxes', 'invoice'),
  DesignToken(r'$invoice.custom1', 'invoice'),
  DesignToken(r'$invoice.custom2', 'invoice'),
  DesignToken(r'$invoice.custom3', 'invoice'),
  DesignToken(r'$invoice.custom4', 'invoice'),
  DesignToken(r'$invoice.public_notes', 'invoice'),
  DesignToken(r'$invoice_total_raw', 'invoice'),
  DesignToken(r'$invoice_no', 'invoice'),
  DesignToken(r'$invoice.invoice_no', 'invoice'),
  DesignToken(r'$invoice.balance', 'invoice'),
  DesignToken(r'$invoice.tags', 'invoice'),

  // Quote
  DesignToken(r'$quote.balance_due', 'quote'),
  DesignToken(r'$quote.total', 'quote'),
  DesignToken(r'$quote.amount', 'quote'),
  DesignToken(r'$quote.date', 'quote'),
  DesignToken(r'$quote.number', 'quote'),
  DesignToken(r'$quote.po_number', 'quote'),
  DesignToken(r'$quote.quote_number', 'quote'),
  DesignToken(r'$quote_no', 'quote'),
  DesignToken(r'$quote.quote_no', 'quote'),
  DesignToken(r'$quote.valid_until', 'quote'),
  DesignToken(r'$quote.tags', 'quote'),

  // Credit
  DesignToken(r'$credit.total', 'credit'),
  DesignToken(r'$credit.number', 'credit'),
  DesignToken(r'$credit.po_number', 'credit'),
  DesignToken(r'$credit.date', 'credit'),
  DesignToken(r'$credit.balance', 'credit'),
  DesignToken(r'$credit_amount', 'credit'),
  DesignToken(r'$credit_balance', 'credit'),
  DesignToken(r'$credit_number', 'credit'),
  DesignToken(r'$credit_no', 'credit'),
  DesignToken(r'$credit.credit_no', 'credit'),
  DesignToken(r'$credit.tags', 'credit'),

  // Vendor / Purchase Order — only the tag tokens for now; the rest of
  // these namespaces aren't on the docs page this catalog mirrors.
  DesignToken(r'$vendor.tags', 'vendor'),
  DesignToken(r'$purchase_order.tags', 'purchase_order'),

  // Financial / Totals
  DesignToken(r'$discount', 'totals'),
  DesignToken(r'$subtotal', 'totals'),
  DesignToken(r'$balance_due', 'totals'),
  DesignToken(r'$balance_due_raw', 'totals'),
  DesignToken(r'$outstanding', 'totals'),
  DesignToken(r'$partial_due', 'totals'),
  DesignToken(r'$total', 'totals'),
  DesignToken(r'$amount', 'totals'),
  DesignToken(r'$amount_raw', 'totals'),
  DesignToken(r'$amount_due', 'totals'),
  DesignToken(r'$balance', 'totals'),
  DesignToken(r'$taxes', 'totals'),
  DesignToken(r'$paid_to_date', 'totals'),
  DesignToken(r'$custom_surcharge1', 'totals'),
  DesignToken(r'$custom_surcharge2', 'totals'),
  DesignToken(r'$custom_surcharge3', 'totals'),
  DesignToken(r'$custom_surcharge4', 'totals'),

  // Links / URLs
  DesignToken(r'$view_link', 'links'),
  DesignToken(r'$view_url', 'links'),

  // Project
  DesignToken(r'$project.name', 'project'),
  DesignToken(r'$project.number', 'project'),

  // Client
  DesignToken(r'$client1', 'client'),
  DesignToken(r'$client2', 'client'),
  DesignToken(r'$client3', 'client'),
  DesignToken(r'$client4', 'client'),
  DesignToken(r'$client_name', 'client'),
  DesignToken(r'$client.name', 'client'),
  DesignToken(r'$client.number', 'client'),
  DesignToken(r'$client.address1', 'client'),
  DesignToken(r'$client.address2', 'client'),
  DesignToken(r'$client_address', 'client'),
  DesignToken(r'$client.address', 'client'),
  DesignToken(r'$client.id_number', 'client'),
  DesignToken(r'$client.vat_number', 'client'),
  DesignToken(r'$client.website', 'client'),
  DesignToken(r'$client.phone', 'client'),
  DesignToken(r'$client.country', 'client'),
  DesignToken(r'$client.email', 'client'),
  DesignToken(r'$client.currency', 'client'),
  DesignToken(r'$client.lang_2', 'client'),
  DesignToken(r'$client.balance', 'client'),
  DesignToken(r'$client_balance', 'client'),
  DesignToken(r'$address1', 'client'),
  DesignToken(r'$address2', 'client'),
  DesignToken(r'$id_number', 'client'),
  DesignToken(r'$vat_number', 'client'),
  DesignToken(r'$website', 'client'),
  DesignToken(r'$phone', 'client'),
  DesignToken(r'$country', 'client'),
  DesignToken(r'$email', 'client'),
  DesignToken(r'$city_state_postal', 'client'),
  DesignToken(r'$client.city_state_postal', 'client'),
  DesignToken(r'$postal_city_state', 'client'),
  DesignToken(r'$client.postal_city_state', 'client'),
  DesignToken(r'$client.tags', 'client'),

  // Client Shipping Address
  DesignToken(r'$client.shipping_address', 'shipping_address'),
  DesignToken(r'$client.shipping_address1', 'shipping_address'),
  DesignToken(r'$client.shipping_address2', 'shipping_address'),
  DesignToken(r'$client.shipping_city', 'shipping_address'),
  DesignToken(r'$client.shipping_state', 'shipping_address'),
  DesignToken(r'$client.shipping_postal_code', 'shipping_address'),
  DesignToken(r'$client.shipping_country', 'shipping_address'),

  // Contact
  DesignToken(r'$contact.full_name', 'contact'),
  DesignToken(r'$contact.email', 'contact'),
  DesignToken(r'$contact.phone', 'contact'),
  DesignToken(r'$contact.name', 'contact'),
  DesignToken(r'$contact.first_name', 'contact'),
  DesignToken(r'$contact.last_name', 'contact'),
  DesignToken(r'$contact.custom1', 'contact'),
  DesignToken(r'$contact.custom2', 'contact'),
  DesignToken(r'$contact.custom3', 'contact'),
  DesignToken(r'$contact.custom4', 'contact'),
  DesignToken(r'$contact.signature', 'contact'),

  // Company
  DesignToken(r'$company1', 'company'),
  DesignToken(r'$company2', 'company'),
  DesignToken(r'$company3', 'company'),
  DesignToken(r'$company4', 'company'),
  DesignToken(r'$company.name', 'company'),
  DesignToken(r'$company.address1', 'company'),
  DesignToken(r'$company.address2', 'company'),
  DesignToken(r'$company.city', 'company'),
  DesignToken(r'$company.state', 'company'),
  DesignToken(r'$company.postal_code', 'company'),
  DesignToken(r'$company.country', 'company'),
  DesignToken(r'$company.phone', 'company'),
  DesignToken(r'$company.email', 'company'),
  DesignToken(r'$company.vat_number', 'company'),
  DesignToken(r'$company.id_number', 'company'),
  DesignToken(r'$company.website', 'company'),
  DesignToken(r'$company.address', 'company'),
  DesignToken(r'$company.city_state_postal', 'company'),
  DesignToken(r'$company.postal_city_state', 'company'),
  DesignToken(r'$company.logo', 'company'),
  DesignToken(r'$company.tags', 'company'),

  // Logo
  DesignToken(r'$logo', 'logo'),
  DesignToken(r'$company_logo', 'logo'),

  // Product / Line Item
  DesignToken(r'$product.item', 'product'),
  DesignToken(r'$product.date', 'product'),
  DesignToken(r'$product.discount', 'product'),
  DesignToken(r'$product.product_key', 'product'),
  DesignToken(r'$product.description', 'product'),
  DesignToken(r'$product.unit_cost', 'product'),
  DesignToken(r'$product.quantity', 'product'),
  DesignToken(r'$product.tax', 'product'),
  DesignToken(r'$product.tax_name1', 'product'),
  DesignToken(r'$product.tax_name2', 'product'),
  DesignToken(r'$product.tax_name3', 'product'),
  DesignToken(r'$product.line_total', 'product'),
  DesignToken(r'$product.product1', 'product'),
  DesignToken(r'$product.product2', 'product'),
  DesignToken(r'$product.product3', 'product'),
  DesignToken(r'$product.product4', 'product'),
  DesignToken(r'$product.tags', 'product'),

  // Task
  DesignToken(r'$task.date', 'task'),
  DesignToken(r'$task.discount', 'task'),
  DesignToken(r'$task.service', 'task'),
  DesignToken(r'$task.description', 'task'),
  DesignToken(r'$task.rate', 'task'),
  DesignToken(r'$task.hours', 'task'),
  DesignToken(r'$task.tax', 'task'),
  DesignToken(r'$task.tax_name1', 'task'),
  DesignToken(r'$task.tax_name2', 'task'),
  DesignToken(r'$task.tax_name3', 'task'),
  DesignToken(r'$task.line_total', 'task'),
  DesignToken(r'$task.tags', 'task'),

  // QR Code
  DesignToken(r'$spc_qr_code', 'qr_code'),

  // Font / Style
  DesignToken(r'$secondary_font_url', 'font'),
  DesignToken(r'$secondary_font_name', 'font'),
  DesignToken(r'$font_size', 'font'),
  DesignToken(r'$font_name', 'font'),
  DesignToken(r'$font_url', 'font'),

  // Labels
  DesignToken(r'$thanks', 'labels'),
  DesignToken(r'$details', 'labels'),
  DesignToken(r'$item', 'labels'),
  DesignToken(r'$description', 'labels'),
];

// =============================================================================
// Twig catalog (Templates page) — entity graph + sandbox
// =============================================================================

/// One node in the Twig entity graph: scalar field names plus named
/// children that resolve back into other schemas in the graph.
class EntitySchema {
  const EntitySchema({
    this.fields = const [],
    this.objects = const {},
    this.arrays = const {},
  });

  /// Scalar field names (no leading dot).
  final List<String> fields;

  /// Field name → schema key for nested objects (single instance).
  final Map<String, String> objects;

  /// Field name → schema key for nested arrays (element type).
  final Map<String, String> arrays;
}

class TwigCatalog {
  const TwigCatalog({
    required this.entityGraph,
    required this.tags,
    required this.filters,
    required this.functions,
    required this.methods,
    required this.properties,
  });

  /// Root identifier → schema. Singular and plural aliases both resolve
  /// to the same element schema so `{% set inv = invoices|first %}{{ inv.<TAB> }}`
  /// works the same as `{{ invoices[0].<TAB> }}`.
  final Map<String, EntitySchema> entityGraph;

  /// Sandboxed Twig tag names. Includes the closing tags (`endif` /
  /// `endfor` / `endset` / `endfilter`) so they autocomplete too.
  final List<String> tags;

  /// Whitelisted Twig filters (used after `|`).
  final List<String> filters;

  /// Whitelisted Twig functions.
  final List<String> functions;

  /// Whitelisted Twig methods (called with `()`).
  final List<String> methods;

  /// Whitelisted Twig properties.
  final List<String> properties;
}

/// Twig boolean / null literals — autocomplete inside `{{ }}` / `{% %}`.
const List<String> kTwigLiterals = ['true', 'false', 'null'];

/// Single-word Twig operator keywords from the docs' examples
/// (`is defined`, `is not empty`, `and`, `or`, `not`, `in`). Multi-word
/// phrases aren't autocompletable cleanly, but the individual words
/// surface usefully inside `{% %}` tag context.
const List<String> kTwigOperatorKeywords = [
  'and',
  'or',
  'not',
  'in',
  'is',
  'defined',
  'empty',
];

/// Element IDs documented across both docs pages as required hooks for
/// server-rendered content (e.g. `<div id="client-details"></div>`).
/// Designs page: client-details / company-details / company-address /
/// entity-details / delivery-note-table / product-table / task-table /
/// table-totals / footer. Templates page adds vendor-details and
/// shipping-address. Surfaced in both modes — picking the wrong one is
/// a graceful no-op at the server, and gating by mode would surprise
/// users.
const List<String> kDocumentedElementIds = [
  'client-details',
  'company-details',
  'company-address',
  'entity-details',
  'delivery-note-table',
  'product-table',
  'task-table',
  'table-totals',
  'footer',
  'vendor-details',
  'shipping-address',
];

// `final` (not `const`) because `_entityGraph` registers
// `_purchaseOrderSchema`, which itself is a `final` derived from
// `_invoiceSchema` (PO shares invoice shape + a reduced vendor object;
// const inheritance isn't possible in Dart, so the derived schema is
// built once at first access). All other lists stay const.
final TwigCatalog kTwigCatalog = TwigCatalog(
  entityGraph: _entityGraph,
  tags: const [
    'if',
    'endif',
    'else',
    'elseif',
    'for',
    'endfor',
    'set',
    'endset',
    'filter',
    'endfilter',
  ],
  filters: const [
    'escape',
    'e',
    'upper',
    'lower',
    'capitalize',
    'filter',
    'length',
    'merge',
    'format_currency',
    'format_number',
    'format_percent_number',
    'map',
    'join',
    'first',
    'date',
    'sum',
    'nl2br',
    'reduce',
  ],
  functions: const ['range', 'cycle', 'constant', 'date'],
  methods: const ['img', 't'],
  properties: const ['type_id'],
);

// -- entity schemas -----------------------------------------------------------

/// Underscore-prefixed schema keys are internal — they back a typed
/// relation (e.g. `_po_vendor` for the reduced vendor on PO) but
/// shouldn't surface as autocompletable Twig roots. The autocomplete
/// builder filters them out when listing bare identifiers.
final Map<String, EntitySchema> _entityGraph = {
  // Both singular (set by `{% set inv = invoices|first %}`) and plural
  // (array) point at the same per-element schema. Quotes / credits share
  // invoice shape verbatim; POs share invoice shape but add a reduced
  // vendor object.
  'invoice': _invoiceSchema,
  'invoices': _invoiceSchema,
  'quote': _invoiceSchema,
  'quotes': _invoiceSchema,
  'credit': _invoiceSchema,
  'credits': _invoiceSchema,
  'purchase_order': _purchaseOrderSchema,
  'purchase_orders': _purchaseOrderSchema,

  'task': _taskSchema,
  'tasks': _taskSchema,

  'payment': _paymentSchema,
  'payments': _paymentSchema,

  'expense': _expenseSchema,
  'expenses': _expenseSchema,

  'project': _projectSchema,
  'projects': _projectSchema,

  'line_item': _lineItemSchema,
  'line_items': _lineItemSchema,

  'time_log': _timeLogSchema,

  'paymentable': _paymentableSchema,
  'paymentables': _paymentableSchema,

  'total_tax_map': _taxMapSchema,
  'line_tax_map': _taxMapSchema,

  'client': _clientSchema,
  'vendor': _vendorSchema,
  'user': _userSchema,
  'company': _companySchema,
  'location': _locationSchema,

  // Internal — not exposed as a Twig root (see `isPublicTwigRoot`).
  '_po_vendor': _poVendorSchema,
};

/// Returns true when the schema key should appear as a bare-identifier
/// completion option (so internal helper schemas like `_po_vendor`
/// don't pollute the menu).
bool isPublicTwigRoot(String schemaKey) => !schemaKey.startsWith('_');

/// Reduced vendor shape exposed on `purchase_orders[].vendor` per the
/// templates docs (only `name` / `vat_number` / `currency`).
const EntitySchema _poVendorSchema = EntitySchema(
  fields: ['name', 'vat_number', 'currency'],
);

/// Purchase orders share the invoice scalar/array shape but additionally
/// expose a reduced `vendor` object — per the templates docs, vendor is
/// not on invoices / quotes / credits but is on POs (with three fields
/// only). Built as a `final` because Dart can't const-derive from
/// `_invoiceSchema`'s members.
final EntitySchema _purchaseOrderSchema = EntitySchema(
  fields: _invoiceSchema.fields,
  objects: {..._invoiceSchema.objects, 'vendor': '_po_vendor'},
  arrays: _invoiceSchema.arrays,
);

const EntitySchema _invoiceSchema = EntitySchema(
  fields: [
    'amount',
    'balance',
    'status_id',
    'status',
    'amount_raw',
    'balance_raw',
    'number',
    'discount',
    'po_number',
    'date',
    'last_sent_date',
    'next_send_date',
    'due_date',
    'terms',
    'public_notes',
    'private_notes',
    'uses_inclusive_taxes',
    'tax_name1',
    'tax_rate1',
    'tax_name2',
    'tax_rate2',
    'tax_name3',
    'tax_rate3',
    'total_taxes',
    'total_taxes_raw',
    'is_amount_discount',
    'footer',
    'partial',
    'partial_due_date',
    'custom_value1',
    'custom_value2',
    'custom_value3',
    'custom_value4',
    'custom_surcharge1',
    'custom_surcharge2',
    'custom_surcharge3',
    'custom_surcharge4',
    'exchange_rate',
    'custom_surcharge_tax1',
    'custom_surcharge_tax2',
    'custom_surcharge_tax3',
    'custom_surcharge_tax4',
    'reminder1_sent',
    'reminder2_sent',
    'reminder3_sent',
    'reminder_last_sent',
    'paid_to_date',
    'auto_bill_enabled',
    'actual_delivery_date',
    'invoice_period',
    'valid_until',
    'is_deleted',
    'has_tasks',
    'has_expenses',
    'currency_id',
  ],
  objects: {'project': 'project', 'client': 'client'},
  arrays: {
    'line_items': 'line_items',
    'payments': 'payments',
    'total_tax_map': 'total_tax_map',
    'line_tax_map': 'line_tax_map',
  },
);

const EntitySchema _lineItemSchema = EntitySchema(
  fields: [
    'quantity',
    'cost',
    'product_key',
    'notes',
    'discount',
    'is_amount_discount',
    'tax_name1',
    'tax_rate1',
    'tax_name2',
    'tax_rate2',
    'tax_name3',
    'tax_rate3',
    'sort_id',
    'line_total',
    'gross_line_total',
    'custom_value1',
    'custom_value2',
    'custom_value3',
    'custom_value4',
    'type_id',
    'product_cost',
    'tax_amount',
    'date',
    'tax_id',
    'task_id',
    'expense_id',
    '_id',
    'cost_raw',
    'discount_raw',
    'line_total_raw',
    'gross_line_total_raw',
    'tax_amount_raw',
    'product_cost_raw',
    'net_cost',
    'net_cost_raw',
  ],
  objects: {'task': 'task'},
);

const EntitySchema _taskSchema = EntitySchema(
  fields: [
    'number',
    'description',
    'duration',
    'rate',
    'rate_raw',
    'created_at',
    'updated_at',
    'date',
    'status',
    'custom_value1',
    'custom_value2',
    'custom_value3',
    'custom_value4',
  ],
  objects: {
    'project': 'project',
    'user': 'user',
    'client': 'client',
    'assigned_user': 'user',
  },
  arrays: {'time_log': 'time_log'},
);

const EntitySchema _timeLogSchema = EntitySchema(
  fields: [
    'start_date_raw',
    'start_date',
    'end_date_raw',
    'end_date',
    'description',
    'billable',
    'duration_raw',
    'duration',
  ],
);

const EntitySchema _paymentSchema = EntitySchema(
  fields: [
    'status', 'badge', 'amount', 'applied', 'balance', 'refunded',
    'amount_raw', 'applied_raw', 'refunded_raw', 'balance_raw',
    'date', 'method', 'currency', 'exchange_rate',
    'transaction_reference', 'is_manual', 'number',
    'custom_value1', 'custom_value2', 'custom_value3', 'custom_value4',
    'created_at', 'updated_at',
    // Array of plain strings per docs (e.g. "24. March 2024 Invoice
    // #0029 $104.95 Refunded") — surface as a scalar so dotted-walk
    // doesn't suggest bogus paymentable fields.
    'refund_activity',
  ],
  objects: {'client': 'client'},
  arrays: {'paymentables': 'paymentables'},
);

const EntitySchema _paymentableSchema = EntitySchema(
  fields: [
    'amount_raw',
    'refunded_raw',
    'net_raw',
    'amount',
    'refunded',
    'net',
    'is_credit',
    'date',
    'created_at',
    'updated_at',
    'timestamp',
  ],
  // Polymorphic relations — credits share the invoice schema shape.
  objects: {'invoice': 'invoice', 'credit': 'invoice'},
);

const EntitySchema _clientSchema = EntitySchema(
  fields: [
    'name',
    'number',
    'id_number',
    'invoice_term_days',
    'quote_term_days',
    'balance',
    'payment_balance',
    'credit_balance',
    'vat_number',
    'currency',
    'locale',
    'address1',
    'address2',
    'city',
    'state',
    'postal_code',
    'country_id',
    'group',
    'phone',
    'address',
    'shipping_address',
    'custom_value1',
    'custom_value2',
    'custom_value3',
    'custom_value4',
  ],
  objects: {'location': 'location'},
);

const EntitySchema _locationSchema = EntitySchema(
  fields: [
    'location_name',
    'address',
    'address1',
    'address2',
    'city',
    'state',
    'postal_code',
    'country',
  ],
);

const EntitySchema _projectSchema = EntitySchema(
  fields: [
    'id',
    'name',
    'number',
    'created_at',
    'updated_at',
    'task_rate',
    'task_rate_raw',
    'due_date',
    'private_notes',
    'public_notes',
    'budgeted_hours',
    'custom_value1',
    'custom_value2',
    'custom_value3',
    'custom_value4',
    'color',
    'current_hours',
  ],
  objects: {'user': 'user', 'client': 'client', 'assigned_user': 'user'},
  arrays: {'tasks': 'tasks', 'expenses': 'expenses', 'invoices': 'invoices'},
);

const EntitySchema _expenseSchema = EntitySchema(
  fields: [
    'number',
    'category',
    'amount',
    'amount_raw',
    'date',
    'private_notes',
    'public_notes',
    'exchange_rate',
    'tax_name1',
    'tax_rate1',
    'tax_name2',
    'tax_rate2',
    'tax_name3',
    'tax_rate3',
    'tax_amount1',
    'tax_amount2',
    'tax_amount3',
    'payment_date',
    'transaction_reference',
    'custom_value1',
    'custom_value2',
    'custom_value3',
    'custom_value4',
    'calculate_tax_by_amount',
    'uses_inclusive_taxes',
  ],
  objects: {'client': 'client', 'vendor': 'vendor', 'project': 'project'},
  arrays: {'invoice': 'invoices'},
);

const EntitySchema _vendorSchema = EntitySchema(
  fields: [
    'name',
    'phone',
    'website',
    'number',
    'id_number',
    'vat_number',
    'currency',
    'custom_value1',
    'custom_value2',
    'custom_value3',
    'custom_value4',
    'address',
    'shipping_address',
    'locale',
  ],
);

const EntitySchema _userSchema = EntitySchema(
  fields: ['name', 'email', 'signature'],
);

const EntitySchema _companySchema = EntitySchema(
  fields: [
    'name',
    'classification',
    'address1',
    'address2',
    'city',
    'state',
    'postal_code',
    'country',
    'country_2',
    'city_state_postal',
    'postal_city_state',
    'postal_city',
    'phone',
    'email',
    'vat_number',
    'id_number',
    'website',
    'payment_terms',
    'valid_until',
    'custom1',
    'custom2',
    'custom3',
    'custom4',
  ],
);

const EntitySchema _taxMapSchema = EntitySchema(fields: ['name', 'total']);

// =============================================================================
// Side-pane groupings
// =============================================================================

/// Maps a side-pane group's `titleKey` to the entity tokens that must
/// appear in `Design.entities` for the group's variables to apply.
/// Both singular and plural forms are accepted because design-mode
/// entities are stored singular (`'invoice'`) while template-mode
/// entities (when the multi-select gap is closed) will use the Twig
/// doc convention (`'tasks'`, `'payments'`, …). Groups absent from
/// this map (`'client'`, `'contact'`, `'company'`, `'user'`) are
/// universal and never gated.
const Map<String, List<String>> kGroupRequiredEntities = {
  'invoice': ['invoice', 'invoices'],
  'quote': ['quote', 'quotes'],
  'credit': ['credit', 'credits'],
  'purchase_order': ['purchase_order', 'purchase_orders'],
  'task': ['task', 'tasks'],
  'payment': ['payment', 'payments'],
  'project': ['project', 'projects'],
  'expense': ['expense', 'expenses'],
};

/// True when a side-pane group is applicable to the current design's
/// `entities`. Empty entities = unrestricted (brand-new draft hasn't
/// picked a binding yet — graying everything would be hostile).
/// Universal groups (not in [kGroupRequiredEntities]) are always
/// enabled.
bool isGroupEnabledForEntities(String titleKey, List<String> entities) {
  if (entities.isEmpty) return true;
  final required = kGroupRequiredEntities[titleKey];
  if (required == null) return true;
  return required.any(entities.contains);
}

/// Variables card shape consumed by the design editor's Variables tab.
class DesignVariableGroup {
  const DesignVariableGroup({required this.titleKey, required this.variables});

  /// Localization key for the section heading.
  final String titleKey;

  /// Variable strings (already including `$` or `{{ … }}` wrappers).
  final List<String> variables;
}

/// Side pane in **design** mode. Curated subset of `$tokens` — ported
/// from React (`src/pages/settings/invoice-design/customize/common/variables.ts`).
/// The in-editor autocomplete still exposes the full [kDesignTokens] list.
const List<DesignVariableGroup> kDesignVariableGroups = [
  DesignVariableGroup(
    titleKey: 'invoice',
    variables: [
      r'$amount',
      r'$assigned_to_user',
      r'$balance',
      r'$created_by_user',
      r'$date',
      r'$discount',
      r'$due_date',
      r'$exchange_rate',
      r'$footer',
      r'$invoice',
      r'$invoice.tags',
      r'$invoices',
      r'$number',
      r'$payment_button',
      r'$payment_url',
      r'$payments',
      r'$po_number',
      r'$public_notes',
      r'$terms',
      r'$view_button',
      r'$view_url',
    ],
  ),
  DesignVariableGroup(
    titleKey: 'client',
    variables: [
      r'$client.address1',
      r'$client.address2',
      r'$client.city',
      r'$client.country',
      r'$client.credit_balance',
      r'$client.id_number',
      r'$client.name',
      r'$client.phone',
      r'$client.postal_code',
      r'$client.public_notes',
      r'$client.shipping_address1',
      r'$client.shipping_address2',
      r'$client.shipping_city',
      r'$client.shipping_country',
      r'$client.shipping_postal_code',
      r'$client.shipping_state',
      r'$client.state',
      r'$client.tags',
      r'$client.vat_number',
    ],
  ),
  DesignVariableGroup(
    titleKey: 'contact',
    variables: [
      r'$contact.email',
      r'$contact.first_name',
      r'$contact.last_name',
      r'$contact.phone',
    ],
  ),
  DesignVariableGroup(
    titleKey: 'company',
    variables: [
      r'$company.address1',
      r'$company.address2',
      r'$company.country',
      r'$company.email',
      r'$company.id_number',
      r'$company.name',
      r'$company.phone',
      r'$company.state',
      r'$company.tags',
      r'$company.vat_number',
      r'$company.website',
    ],
  ),
];

/// Side pane in **template** mode. Curated subset of Twig variables —
/// mirrors React's `docu_*` groups so authors get a focused starter
/// set; the in-editor autocomplete still exposes the full graph.
const List<DesignVariableGroup> kTwigVariableGroups = [
  DesignVariableGroup(
    titleKey: 'invoice',
    variables: [
      '{{ invoice.number }}',
      '{{ invoice.date }}',
      '{{ invoice.due_date }}',
      '{{ invoice.amount }}',
      '{{ invoice.balance }}',
      '{{ invoice.po_number }}',
      '{{ invoice.public_notes }}',
      '{{ invoice.terms }}',
    ],
  ),
  DesignVariableGroup(
    titleKey: 'client',
    variables: [
      '{{ client.name }}',
      '{{ client.number }}',
      '{{ client.address1 }}',
      '{{ client.address2 }}',
      '{{ client.city }}',
      '{{ client.state }}',
      '{{ client.postal_code }}',
      '{{ client.phone }}',
      '{{ client.balance }}',
      '{{ client.vat_number }}',
    ],
  ),
  DesignVariableGroup(
    titleKey: 'contact',
    variables: [
      '{{ contact.first_name }}',
      '{{ contact.last_name }}',
      '{{ contact.email }}',
      '{{ contact.phone }}',
    ],
  ),
  DesignVariableGroup(
    titleKey: 'company',
    variables: [
      '{{ company.name }}',
      '{{ company.address1 }}',
      '{{ company.address2 }}',
      '{{ company.city }}',
      '{{ company.state }}',
      '{{ company.postal_code }}',
      '{{ company.country }}',
      '{{ company.email }}',
      '{{ company.website }}',
    ],
  ),
  DesignVariableGroup(
    titleKey: 'user',
    variables: ['{{ user.name }}', '{{ user.email }}', '{{ user.signature }}'],
  ),
  DesignVariableGroup(
    titleKey: 'project',
    variables: [
      '{{ project.name }}',
      '{{ project.number }}',
      '{{ project.due_date }}',
      '{{ project.budgeted_hours }}',
      '{{ project.current_hours }}',
      '{{ project.task_rate }}',
      '{{ project.public_notes }}',
    ],
  ),
  DesignVariableGroup(
    titleKey: 'task',
    variables: [
      '{{ task.number }}',
      '{{ task.description }}',
      '{{ task.duration }}',
      '{{ task.rate }}',
      '{{ task.date }}',
      '{{ task.status }}',
    ],
  ),
  DesignVariableGroup(
    titleKey: 'payment',
    variables: [
      '{{ payment.number }}',
      '{{ payment.amount }}',
      '{{ payment.date }}',
      '{{ payment.method }}',
      '{{ payment.transaction_reference }}',
      '{{ payment.currency }}',
    ],
  ),
  DesignVariableGroup(
    titleKey: 'expense',
    variables: [
      '{{ expense.number }}',
      '{{ expense.amount }}',
      '{{ expense.date }}',
      '{{ expense.category }}',
      '{{ expense.transaction_reference }}',
      '{{ expense.payment_date }}',
    ],
  ),
  // Universal group (no entity-gating). One chip: the statement-template
  // marker HTML comment the docs say a statement template must include.
  // Not surfaced via typed autocomplete — too long, too special — but
  // discoverable here.
  DesignVariableGroup(
    titleKey: 'snippets',
    variables: ['<!-- Statement - TemplateID #TS4 ##statement##-->'],
  ),
];
