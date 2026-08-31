/// The status-tab strip that sits above every entity list (issue #98).
///
/// A tab is one bucket of an entity's [SidebarBadgeMode] catalog, surfaced as a
/// one-tap filter instead of the three-to-four taps the token search field
/// costs. The catalog is deliberately reused rather than re-declared: the tab's
/// **count** and the tab's **rows** are then computed by literally the same
/// Drift expression (`BaseEntityDao.badgeModePredicate`), so a tab reading
/// "Draft 6" above five rows is structurally impossible.
///
/// This file adds only the two things the catalog can't answer:
///
///  * **Order.** `kInvoiceBadgeModes` is ordered `total, overdue, unpaid,
///    draft` — its convention is "the most actionable status right after
///    total", which as tabs would read All / Overdue / Unpaid / Draft, i.e. the
///    funnel backwards. Tabs run in lifecycle order instead.
///  * **[ListStatusTabSpec.serverFilters]** — the optional translation into
///    real API query params, applied only to the *fetch*.
///
/// Modes themselves (label, tone, the inventory gate) are joined in at call
/// time from the entity's own `EntityHandlers.badgeModes`, so this file can
/// never disagree with the sidebar about what a mode is called or coloured.
///
/// A leaf on purpose: it imports only `entity_type.dart` and
/// `sidebar_badge_modes.dart`, neither of which imports anything, so nothing
/// here can drag `lib/ui/**` into `lib/data/**`.
library;

import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

/// The `extraFilters` slot the strip writes: a single [SidebarBadgeMode.id].
///
/// **Local-first.** It never reaches the wire — `_serverExtraFilters()` strips
/// it and splices in [ListStatusTabSpec.serverFilters] instead — and the list
/// is narrowed by the DAO re-applying `badgeModePredicate` inside `watchPage`.
///
/// **Never rename**, and never rename a mode id it can hold: the value lands in
/// `nav_state.filters_json` and in saved views.
const String kBadgeModeFilterKey = 'badge_mode';

/// One non-`All` tab: which badge mode it shows, and how (if at all) that
/// narrows the network fetch.
class ListStatusTabSpec {
  const ListStatusTabSpec(
    this.modeId, {
    this.serverFilters = const {},
    this.widened = false,
  });

  /// A [SidebarBadgeMode.id] from this entity's own catalog. Enforced by
  /// `test/domain/list_status_tabs_test.dart`, which also fails the build when
  /// a newly added mode has no tab — the same silent-failure guard
  /// `sidebar_badge_count_test` gives predicates.
  final String modeId;

  /// Flat API query params that narrow the FETCH to a **superset** of this
  /// tab's rows, or empty for "fetch unnarrowed and filter locally".
  ///
  /// **The superset direction is the whole contract.** Over-fetching is free —
  /// the local predicate discards the extra rows. Under-fetching is silent and
  /// wrong on screen: the fetch skips rows the local predicate would have
  /// shown, so the tab reads "Expired 12" over eight rows and the missing four
  /// never arrive. Where the obvious value would be a subset, WIDEN it (quotes
  /// send `expired,draft`) rather than dropping to local-only; leave it empty
  /// only when no superset short of "everything" exists.
  ///
  /// Every entry below was read off `app/Filters/*.php` in the server repo
  /// against the matching `badgeModePredicate`. Don't add one from the param
  /// name alone.
  final Map<String, Set<String>> serverFilters;

  /// True when [serverFilters] returns **strictly more** rows than
  /// `badgeModePredicate` — i.e. the local predicate still narrows *after* the
  /// fetch lands.
  ///
  /// This is not bookkeeping: it decides whether the tab arms the auto-chain.
  /// A widened fetch can fill page 1 with rows the local predicate then throws
  /// away (Quotes → Expired pulling 50 drafts to find 3 expired quotes), which
  /// emits a short list with no scroll extent — so the scroll-driven load-more
  /// never fires and the tab reads "Expired 3" over a false "No records found".
  /// [statusTabNarrowsLocally] is what stops that.
  ///
  /// An exact mapping (the server clause and the badge predicate select the
  /// same rows) leaves this false: paging is then wholly the server's job.
  final bool widened;
}

/// Per-entity tabs, in the order they render after `All`.
///
/// An entity absent from this map gets no strip. So do the settings-hosted
/// lists (gateways, payment links, expense categories), which declare only
/// [kDefaultBadgeModes].
const Map<EntityType, List<ListStatusTabSpec>> kListStatusTabs = {
  // -- Server-narrowed ------------------------------------------------------

  // `InvoiceFilters::status_id` is a plain `whereIn`, so draft/unpaid are
  // exact. `overdue` is a superset: the server ORs `due_date` and
  // `partial_due_date` where `invoiceOverdueFilter` COALESCEs them.
  EntityType.invoice: [
    ListStatusTabSpec(
      'draft',
      serverFilters: {
        'status_id': {'1'},
      },
    ),
    ListStatusTabSpec(
      'unpaid',
      serverFilters: {
        'status_id': {'2', '3'},
      },
    ),
    ListStatusTabSpec(
      'overdue',
      serverFilters: {
        'overdue': {'true'},
      },
      // Only by the partial-due-date-in-the-future row, so the fetch is in
      // practice exactly right — but it IS a superset, and pretending
      // otherwise is how the auto-chain gets switched off by accident.
      widened: true,
    ),
  ],

  // `quoteClientStatusFilter` was written to mirror `QuoteFilters::
  // client_status` clause-for-clause, incl. `sent`'s not-yet-expired guard —
  // so those three are exact. `expired` is NOT: the server requires
  // `status_id = 2`, while the app also counts a past-due *draft* as expired.
  // The `,draft` widens it back to a superset.
  EntityType.quote: [
    ListStatusTabSpec(
      'draft',
      serverFilters: {
        'client_status': {'draft'},
      },
    ),
    ListStatusTabSpec(
      'sent',
      serverFilters: {
        'client_status': {'sent'},
      },
    ),
    ListStatusTabSpec(
      'approved',
      serverFilters: {
        'client_status': {'approved'},
      },
    ),
    ListStatusTabSpec(
      'expired',
      serverFilters: {
        'client_status': {'expired', 'draft'},
      },
      // The `,draft` is what makes this a superset, and it is a big one: an
      // account with 200 drafts and 3 expired quotes fills page 1 with drafts.
      // Without the auto-chain that renders "Expired 3" over "No records
      // found".
      widened: true,
    ),
  ],

  // draft/sent are plain `whereIn`, so both are exact. `unapplied` is
  // deliberately left LOCAL-ONLY: the only superset available is "every
  // non-draft status", which is nearly the whole table — it would buy no real
  // narrowing while flipping `isNarrowedFetch` (costing the delta cursor) and
  // switching off the auto-chain the local predicate needs. Don't "restore" it.
  EntityType.credit: [
    ListStatusTabSpec(
      'draft',
      serverFilters: {
        'client_status': {'draft'},
      },
    ),
    ListStatusTabSpec(
      'sent',
      serverFilters: {
        'client_status': {'sent'},
      },
    ),
    ListStatusTabSpec('unapplied'),
  ],

  // pending/failed are plain `whereIn`, so both are exact. `unapplied` is
  // LOCAL-ONLY for the same reason as credits: the nearest superset is
  // `completed,partially_refunded`, which is most payments — no useful
  // narrowing, and it would cost both the delta cursor and the auto-chain.
  // (Also do NOT reach for the server's `partially_unapplied`: it adds
  // `refunded = 0`, excluding the partially-refunded payments the badge
  // predicate includes, which makes it a SUBSET and would hide rows.)
  EntityType.payment: [
    ListStatusTabSpec(
      'pending',
      serverFilters: {
        'client_status': {'pending'},
      },
    ),
    ListStatusTabSpec(
      'failed',
      serverFilters: {
        'client_status': {'failed'},
      },
    ),
    ListStatusTabSpec('unapplied'),
  ],

  // `pending` is exact. `logged` is widened to `uninvoiced`
  // (`invoice_id IS NULL` ⊇ `invoice_id = '' ∧ ¬should_be_invoiced`) because
  // the server's own `logged` also requires `payment_date IS NULL AND
  // amount >= 0`. `unpaid` has no superset: the server keys off `payment_date`
  // / `transaction_reference`, the app off the denormalized `is_paid`.
  EntityType.expense: [
    ListStatusTabSpec(
      'logged',
      serverFilters: {
        'client_status': {'uninvoiced'},
      },
      // `uninvoiced` also carries the `pending` bucket, so a pending-heavy
      // account can fill page 1 without a single logged expense.
      widened: true,
    ),
    ListStatusTabSpec(
      'pending',
      serverFilters: {
        'client_status': {'pending'},
      },
    ),
    ListStatusTabSpec('unpaid'),
  ],

  // Plain `whereIn` on `RecurringInvoiceFilters::client_status`. NOTE this is
  // `client_status`, not the `status_id` the list's own chip writes —
  // `status_id` is implemented ONLY on `InvoiceFilters`, so that chip is
  // silently ignored server-side today (see BACKEND.md).
  EntityType.recurringInvoice: [
    ListStatusTabSpec(
      'draft',
      serverFilters: {
        'client_status': {'draft'},
      },
    ),
    ListStatusTabSpec(
      'active',
      serverFilters: {
        'client_status': {'active'},
      },
    ),
    ListStatusTabSpec(
      'paused',
      serverFilters: {
        'client_status': {'paused'},
      },
    ),
  ],

  // `TaskFilters::client_status` — `is_running = true` / `invoice_id IS NULL`,
  // exactly the two badge predicates.
  EntityType.task: [
    ListStatusTabSpec(
      'running',
      serverFilters: {
        'client_status': {'is_running'},
      },
    ),
    ListStatusTabSpec(
      'uninvoiced',
      serverFilters: {
        'client_status': {'uninvoiced'},
      },
    ),
  ],

  // draft/accepted are plain `whereIn`. `sent` is left local: the server's
  // clause is `(status_id = 2 AND due_date IS NULL) OR due_date >= today` — an
  // unnested `orWhere` — so a sent PO past its due date matches NEITHER
  // disjunct. Not a superset, and no widening short of no filter fixes it.
  EntityType.purchaseOrder: [
    ListStatusTabSpec(
      'draft',
      serverFilters: {
        'client_status': {'draft'},
      },
    ),
    ListStatusTabSpec('sent'),
    ListStatusTabSpec(
      'accepted',
      serverFilters: {
        'client_status': {'accepted'},
      },
    ),
  ],

  // Plain `whereIn` on `BankTransactionFilters::client_status`. Same
  // `status_id`-is-invoice-only caveat as recurring invoices above.
  EntityType.transaction: [
    ListStatusTabSpec(
      'unmatched',
      serverFilters: {
        'client_status': {'unmatched'},
      },
    ),
    ListStatusTabSpec(
      'matched',
      serverFilters: {
        'client_status': {'matched'},
      },
    ),
  ],

  // -- Local-only: no server dimension models these buckets -----------------
  EntityType.client: [
    ListStatusTabSpec('outstanding'),
    ListStatusTabSpec('overdue'),
  ],
  EntityType.product: [
    ListStatusTabSpec('low_stock'),
    ListStatusTabSpec('out_of_stock'),
  ],
  EntityType.project: [
    ListStatusTabSpec('overdue'),
    ListStatusTabSpec('over_budget'),
  ],
  EntityType.vendor: [
    ListStatusTabSpec('unpaid_expenses'),
    ListStatusTabSpec('open_purchase_orders'),
  ],
  // Deliberately empty despite `RecurringExpenseFilters::client_status`
  // existing: its vocabulary is `logged/pending/invoiced/paid/unpaid` and its
  // `pending` means "should be invoiced", nothing to do with the recurring
  // status this entity's badge modes describe. Sending it would be wrong, not
  // merely unhelpful.
  EntityType.recurringExpense: [
    ListStatusTabSpec('draft'),
    ListStatusTabSpec('pending'),
    ListStatusTabSpec('active'),
    ListStatusTabSpec('paused'),
  ],
};

/// A tab with its [SidebarBadgeMode] joined in. `mode == null` is the `All`
/// tab, which always leads the strip.
class ResolvedStatusTab {
  const ResolvedStatusTab(this.mode, this.serverFilters);

  final SidebarBadgeMode? mode;
  final Map<String, Set<String>> serverFilters;

  bool get isAll => mode == null;

  /// Localization key for the tab label. `all` is in `en.json`.
  String get labelKey => mode?.labelKey ?? 'all';

  /// What `Services.watchEntityCount` should count for this tab.
  String get countModeId => mode?.id ?? kBadgeModeTotal;

  /// What the DAO should filter by — null for `All`, which filters nothing.
  String? get listModeId => mode?.id;

  SidebarBadgeTone get tone => mode?.tone ?? SidebarBadgeTone.neutral;
}

const ResolvedStatusTab _allTab = ResolvedStatusTab(
  null,
  <String, Set<String>>{},
);

/// The strip for [type]: `All` first, then every spec'd tab whose mode this
/// company can actually use.
///
/// [modes] is the entity's `EntityHandlers.badgeModes` — passed in rather than
/// looked up so this file needs no map of its own to drift out of sync, and so
/// the registry (which imports the whole UI graph) stays out of `lib/domain`.
///
/// Returns `const []` when only `All` would survive: a one-tab strip is chrome
/// with no function. That's what silently keeps the strip off a Products list
/// with inventory tracking disabled, and off every settings-hosted list.
List<ResolvedStatusTab> listStatusTabsFor(
  EntityType type, {
  required List<SidebarBadgeMode> modes,
  required bool trackInventory,
}) {
  final specs = kListStatusTabs[type];
  if (specs == null) return const [];
  final available = <String, SidebarBadgeMode>{
    for (final m in availableBadgeModes(modes, trackInventory: trackInventory))
      m.id: m,
  };
  final out = <ResolvedStatusTab>[_allTab];
  for (final spec in specs) {
    final mode = available[spec.modeId];
    if (mode != null) out.add(ResolvedStatusTab(mode, spec.serverFilters));
  }
  return out.length > 1 ? out : const [];
}

/// The API params a `badge_mode` value translates to on the FETCH, or null when
/// this tab is local-only (which is what arms `localOnlyFilterActive`).
Map<String, Set<String>>? statusTabServerFilters(
  EntityType type,
  String modeId,
) {
  for (final spec in kListStatusTabs[type] ?? const <ListStatusTabSpec>[]) {
    if (spec.modeId == modeId) {
      return spec.serverFilters.isEmpty ? null : spec.serverFilters;
    }
  }
  return null;
}

/// Whether this tab's rows are still being narrowed **locally** after the
/// fetch — i.e. whether it needs `GenericListViewModel`'s auto-chain.
///
/// True in two cases, and conflating them is what makes this a single
/// predicate rather than a null check on [statusTabServerFilters]:
///
///  * **no server mapping** — the fetch isn't narrowed at all, so the tab's
///    matches can sit entirely past page 1; and
///  * **a [ListStatusTabSpec.widened] mapping** — the fetch IS narrowed, but to
///    a superset, so the local predicate throws rows away afterwards and a page
///    can still come back short.
///
/// Either way an emission shorter than a page has no scroll extent, the
/// scroll-driven load-more never fires, and the list renders a false "No
/// records found" the user cannot scroll out of.
bool statusTabNarrowsLocally(EntityType type, String modeId) {
  for (final spec in kListStatusTabs[type] ?? const <ListStatusTabSpec>[]) {
    if (spec.modeId == modeId) {
      return spec.serverFilters.isEmpty || spec.widened;
    }
  }
  return false;
}

/// Whether [modeId] is a tab this build still offers for [type].
///
/// Read on hydrate: a `badge_mode` restored from `nav_state` or a saved view
/// written by a build that offered a mode this one dropped would otherwise sit
/// there filtering nothing visible while keeping `hasActiveFilters` true
/// forever. Degrading to `All` mirrors how `SidebarBadgeModeController` drops
/// an unknown stored mode back to `total`.
bool isKnownStatusTabMode(EntityType type, String modeId) {
  for (final spec in kListStatusTabs[type] ?? const <ListStatusTabSpec>[]) {
    if (spec.modeId == modeId) return true;
  }
  return false;
}
