import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/core/list/deep_link_filter_intent.dart';

/// `due_date` column id — invoice & quote list VMs accept it via
/// `isValidColumnId`.
const String kInvoiceDueDateColumnId = 'due_date';

/// The invoice-list filters a link may name (`/invoices?filter=<name>`) — the
/// home-screen widgets open "past due" and "unpaid" with them. Allow-listed:
/// a link is outside input, and only these become list filters.
const Set<String> kInvoiceLinkFilters = {'past_due', 'unpaid'};

/// The list a link's `filter` opens: exactly what the dashboard's own
/// Outstanding and past-due figures open, so a widget and the dashboard
/// never disagree about what "unpaid" means. Null for anything else.
ListFilterIntent? invoiceLinkFilterIntent(
  String? name, {
  required Date today,
}) => switch (name) {
  'past_due' => buildInvoiceKpiIntent(
    overdue: true,
    isAllTimeRange: true,
    start: today,
    end: today,
  ),
  'unpaid' => buildInvoiceKpiIntent(
    overdue: false,
    isAllTimeRange: true,
    start: today,
    end: today,
  ),
  _ => null,
};

/// Builds the deep-link [ListFilterIntent] for the Outstanding / Overdue KPI
/// cards. Extracted as a pure function so the period-window rule is unit
/// testable.
///
/// **Overdue** is an as-of-today metric (`due_date < today`), independent of
/// the dashboard's period window — exactly like the Past Due panel
/// (`DashboardApi.fetchPastDueInvoices` / `_pastDueInvoicesIntent`), which
/// sends `overdue=true` with no `date_range`. Carrying the period as a
/// `date_range` on the invoice *issue* date filtered the destination list
/// down to nothing (overdue invoices are old; their issue date rarely falls
/// inside "this month"), so the deep-link showed an empty list while a manual
/// `overdue:true` filter did not. Overdue therefore never carries a window.
///
/// **Outstanding** (`client_status=unpaid`) is period-scoped: it carries the
/// dashboard window as a closed `date,<start>,<end>` range unless the range is
/// the open-ended "all time" preset.
ListFilterIntent buildInvoiceKpiIntent({
  required bool overdue,
  required bool isAllTimeRange,
  required Date start,
  required Date end,
}) {
  if (overdue) {
    return ListFilterIntent(
      extraFilters: const {
        'overdue': {'true'},
      },
      sortField: kInvoiceDueDateColumnId,
      sortAscending: true,
    );
  }
  return ListFilterIntent(
    extraFilters: {
      // `status_id`, NOT `client_status`. The invoices list registers no
      // `client_status` key and `InvoiceRepository.watchPage` has no local
      // mirror for one (quotes / credits / payments / expenses all do), so it
      // narrowed the network fetch while the Drift watch the list actually
      // renders from ignored it: the user landed on an unfiltered list — paid,
      // draft and cancelled invoices included — with no chip explaining
      // anything and a lit "clear filters" icon, and the phantom filter then
      // persisted to `nav_state` and silently windowed every later page fetch.
      //
      // Sent + partial IS "unpaid" — the same definition `InvoiceDao`'s own
      // `unpaid` badge mode uses — and `status_id` renders as a real, removable
      // chip that the DAO mirrors locally.
      'status_id': {InvoiceStatus.sent.wireId, InvoiceStatus.partial.wireId},
      if (!isAllTimeRange)
        'date_range': {'date,${start.toIso()},${end.toIso()}'},
    },
  );
}
