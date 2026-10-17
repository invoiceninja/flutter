import 'package:admin/domain/entity_type.dart';

/// The record types a document can hang off, by the wire name the
/// `document_records.parent_type` column stores.
///
/// One table, both directions, so "store a parent" and "read one back" can't
/// disagree. The wire names are the server's snake-case entity names
/// (`invoice`, `recurring_expense`, `group`, …) — what a `documentable_type`
/// would carry once the server sends it (BACKEND.md § Documents list).
const Map<EntityType, String> kDocumentParentWireNames = {
  EntityType.client: 'client',
  EntityType.product: 'product',
  EntityType.invoice: 'invoice',
  EntityType.recurringInvoice: 'recurring_invoice',
  EntityType.quote: 'quote',
  EntityType.credit: 'credit',
  EntityType.payment: 'payment',
  EntityType.task: 'task',
  EntityType.project: 'project',
  EntityType.expense: 'expense',
  EntityType.recurringExpense: 'recurring_expense',
  EntityType.vendor: 'vendor',
  EntityType.purchaseOrder: 'purchase_order',
  EntityType.group: 'group',
  EntityType.company: 'company',
};

/// The [EntityType] behind a stored or received parent name, or null when it
/// is not one a document can belong to.
///
/// Accepts the snake-case wire name and, because that is what Laravel's
/// morph columns hold, a model class name (`App\Models\RecurringInvoice`,
/// `App\Models\GroupSetting`).
EntityType? documentParentTypeFromWire(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final entry in kDocumentParentWireNames.entries) {
    if (entry.value == raw) return entry.key;
  }
  final base = raw.split(r'\').last;
  return _classNames[base];
}

/// The stored name for [type], or null when a document cannot belong to it.
String? documentParentWireName(EntityType type) =>
    kDocumentParentWireNames[type];

const Map<String, EntityType> _classNames = {
  'Client': EntityType.client,
  'Product': EntityType.product,
  'Invoice': EntityType.invoice,
  'RecurringInvoice': EntityType.recurringInvoice,
  'Quote': EntityType.quote,
  'Credit': EntityType.credit,
  'Payment': EntityType.payment,
  'Task': EntityType.task,
  'Project': EntityType.project,
  'Expense': EntityType.expense,
  'RecurringExpense': EntityType.recurringExpense,
  'Vendor': EntityType.vendor,
  'PurchaseOrder': EntityType.purchaseOrder,
  'GroupSetting': EntityType.group,
  'Company': EntityType.company,
};
