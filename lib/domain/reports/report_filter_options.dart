/// Static option catalogs for report filter controls that have a known,
/// fixed value set (Status). Mirrors React's per-entity filter hooks
/// (`react/src/pages/.../common/hooks/use*Filters`), which feed
/// `StatusSelector` — the wire values must match the server's report
/// `status` filter exactly. `labelKey` is a localization key.
///
/// Keyed by the report `identifier` (the registry's stable wire name), not
/// `EntityType`, because purchase-order / recurring-invoice statuses differ
/// from their closest entity icon.
library;

typedef ReportFilterOption = ({String id, String labelKey});

/// Status options for the `status` filter, by report identifier. Returns
/// `null` for reports without a known status set — callers fall back to a
/// free-text field.
List<ReportFilterOption>? reportStatusOptions(String reportIdentifier) {
  switch (reportIdentifier) {
    case 'invoice':
    case 'invoice_item':
      return const [
        (id: 'draft', labelKey: 'draft'),
        (id: 'paid', labelKey: 'paid'),
        (id: 'unpaid', labelKey: 'unpaid'),
        (id: 'overdue', labelKey: 'past_due'),
        (id: 'cancelled', labelKey: 'cancelled'),
      ];
    case 'quote':
    case 'quote_item':
      return const [
        (id: 'draft', labelKey: 'draft'),
        (id: 'sent', labelKey: 'sent'),
        (id: 'approved', labelKey: 'approved'),
        (id: 'expired', labelKey: 'expired'),
        (id: 'upcoming', labelKey: 'upcoming'),
        (id: 'converted', labelKey: 'converted'),
        // No `cancelled` here, despite `Quote::STATUS_CANCELLED` existing and
        // the LIST filter supporting it: reports go through
        // `BaseExport::addQuoteStatusFilter`, a different method from
        // `QuoteFilters::client_status`, and it has no `cancelled` arm. An
        // unmatched value there leaves the nested `where` closure empty, which
        // Laravel drops — so the option would return EVERY quote under a
        // "Cancelled" heading. See BACKEND.md. (`addInvoiceStatusFilter` does
        // have the arm, which is why the invoice list above can offer it.)
      ];
    case 'credit':
      return const [
        (id: 'draft', labelKey: 'draft'),
        (id: 'sent', labelKey: 'sent'),
        (id: 'partial', labelKey: 'partial'),
        (id: 'applied', labelKey: 'applied'),
      ];
    case 'payment':
      return const [
        (id: 'pending', labelKey: 'pending'),
        (id: 'cancelled', labelKey: 'cancelled'),
        (id: 'failed', labelKey: 'failed'),
        (id: 'completed', labelKey: 'completed'),
        (id: 'partially_refunded', labelKey: 'partially_refunded'),
        (id: 'refunded', labelKey: 'refunded'),
        (id: 'partially_unapplied', labelKey: 'partially_unapplied'),
      ];
    case 'expense':
      return const [
        (id: 'logged', labelKey: 'logged'),
        (id: 'pending', labelKey: 'pending'),
        (id: 'invoiced', labelKey: 'invoiced'),
        (id: 'paid', labelKey: 'paid'),
        (id: 'unpaid', labelKey: 'unpaid'),
        (id: 'uncategorized', labelKey: 'uncategorized'),
      ];
    case 'purchase_order':
    case 'purchase_order_item':
      return const [
        (id: 'draft', labelKey: 'draft'),
        (id: 'sent', labelKey: 'sent'),
        (id: 'accepted', labelKey: 'accepted'),
        (id: 'cancelled', labelKey: 'cancelled'),
      ];
    case 'recurring_invoice':
    case 'recurring_invoice_item':
      return const [
        (id: 'draft', labelKey: 'draft'),
        (id: 'active', labelKey: 'active'),
        (id: 'paused', labelKey: 'paused'),
        (id: 'completed', labelKey: 'completed'),
      ];
    // `task` is the reports-screen identifier; `tasks` is the scheduler's
    // email_report name for the same report (server `EmailReport` exporter).
    case 'task':
    case 'tasks':
      return const [
        (id: 'invoiced', labelKey: 'invoiced'),
        (id: 'uninvoiced', labelKey: 'uninvoiced'),
      ];
    default:
      return null;
  }
}
