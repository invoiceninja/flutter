/// The tab set for the dashboard's consolidated Invoices & Quotes panel
/// (invoiceninja/flutter#155).
///
/// A **view over two existing catalogs**, never a third one. Each tab names, per
/// entity, the [SidebarBadgeMode] id that entity contributes to it — so the
/// panel's counts and rows come from exactly the same `badgeModePredicate` the
/// sidebar counter and the list strip use, and the badge above a list can never
/// describe a different population from the rows under it.
///
/// A leaf on purpose: it imports only `entity_type.dart`,
/// `sidebar_badge_modes.dart` and `list_status_tabs.dart`, none of which reach
/// `lib/ui/**`.
library;

import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

/// One tab of the panel's strip.
///
/// **The per-entity ids are explicit and can never be inferred from the tab
/// itself.** Both seams that consume them fail *open* on an id the DAO does not
/// recognise: `badgeModeListFilter` returns null and `watchPage` then skips its
/// WHERE (every row), and `watchBadgeCount` does `if (extra != null)` and then
/// counts every active row — not zero. So handing the quote-only `approved` to
/// the invoice side would silently list and count **every invoice**, and it
/// type-checks. A null id here means "this entity does not participate", and
/// callers must skip that half rather than pass the tab's own id.
class BillingStatusTab {
  const BillingStatusTab({
    required this.mode,
    required this.invoiceModeId,
    required this.quoteModeId,
  });

  /// The badge mode supplying this tab's label and tone, or null for `All`.
  ///
  /// Where both halves participate this is the **invoice** side's mode. That is
  /// invisible today only because the one such non-`All` tab (`draft`) is
  /// spelled identically in both catalogs; `billing_status_tabs_test` asserts
  /// the two agree on `labelKey` and `tone` so it stays invisible.
  final SidebarBadgeMode? mode;

  /// Invoice-side [SidebarBadgeMode.id], or null when invoices do not
  /// participate in this tab.
  final String? invoiceModeId;

  /// Quote-side [SidebarBadgeMode.id], or null when quotes do not participate.
  final String? quoteModeId;

  bool get isAll => mode == null;

  /// Stable identity for persistence and selection. `All` is the empty string
  /// rather than a mode id, matching `ResolvedStatusTab.listModeId`'s null.
  String get id => mode?.id ?? '';

  String get labelKey => mode?.labelKey ?? 'all';

  SidebarBadgeTone get tone => mode?.tone ?? SidebarBadgeTone.neutral;

  bool get hasInvoices => invoiceModeId != null;
  bool get hasQuotes => quoteModeId != null;

  /// True when this tab sums two populations, so its badge is a total across
  /// both entities and its rows are a merge.
  bool get isMixed => hasInvoices && hasQuotes;

  /// True when **no** participating half narrows its fetch server-side, so this
  /// tab's count is bounded by whatever ordinary sync happens to have cached.
  ///
  /// Only `rejected` qualifies today (`QuoteFilters::client_status` has no such
  /// branch — BACKEND.md § F1), and the panel uses this to qualify that tab's
  /// empty state rather than let it claim the company has none.
  ///
  /// It lives here rather than being re-derived at the call site, because the
  /// derivation is what got it wrong: asking
  /// `statusTabServerFilters(quote, quoteModeId)` directly also answers null
  /// for `All`, whose `kBadgeModeTotal` simply has no `ListStatusTabSpec` —
  /// which is the absence of a narrowing *bucket*, not an unnarrowed fetch.
  bool get isLocalOnly {
    if (isAll) return false;
    if (hasInvoices &&
        statusTabServerFilters(EntityType.invoice, invoiceModeId!) != null) {
      return false;
    }
    if (hasQuotes &&
        statusTabServerFilters(EntityType.quote, quoteModeId!) != null) {
      return false;
    }
    return true;
  }
}

/// Tab order after `All`.
///
/// **Derived, not invented.** Filtered to each entity's participating ids this
/// reproduces that entity's own `kListStatusTabs` order exactly — invoices read
/// `draft, unpaid` (their strip minus the deliberately-omitted `overdue`) and
/// quotes read `draft, sent, approved, rejected, cancelled, expired` — so the
/// panel can
/// never disagree with the list its footer links land on.
/// `billing_status_tabs_test` pins that property in both directions.
///
/// `unpaid` sits second rather than last because it is not a lifecycle *stage*:
/// draft → sent are stages and approved/rejected/cancelled/expired are terminal
/// outcomes of a sent quote, so lifecycle order is silent about where a
/// cross-cutting money state goes. Parking it last would cost the strip's most actionable
/// number the most horizontal travel.
///
/// `overdue` is omitted deliberately: the shipped "Needs your attention" panel
/// already lists past-due invoices, and a second surface for it would compete
/// with that one rather than add anything.
const List<String> kBillingPipelineTabOrder = [
  'draft',
  'unpaid',
  'sent',
  'approved',
  'rejected',
  // Between `rejected` and `expired` so the quote-filtered subsequence still
  // equals `kListStatusTabs[EntityType.quote]` — asserted in
  // `billing_status_tabs_test`, which is also what forces a new list-catalog
  // mode to reach this panel rather than silently skipping it.
  'cancelled',
  'expired',
];

/// The panel's strip: `All` first, then every tab at least one participating
/// entity declares.
///
/// [invoiceModes] / [quoteModes] are the entities' own
/// `EntityHandlers.badgeModes`, passed in rather than looked up so this file
/// needs no registry import (which would drag the whole UI graph in).
/// [includeInvoices] / [includeQuotes] come from the dashboard's single panel
/// gate — a company with the module off, or a user without the view permission,
/// contributes no half.
List<BillingStatusTab> billingStatusTabsFor({
  required List<SidebarBadgeMode> invoiceModes,
  required List<SidebarBadgeMode> quoteModes,
  required bool includeInvoices,
  required bool includeQuotes,
}) {
  if (!includeInvoices && !includeQuotes) return const [];

  Map<String, SidebarBadgeMode> byId(List<SidebarBadgeMode> modes) => {
    for (final m in modes) m.id: m,
  };
  final invoiceById = includeInvoices
      ? byId(invoiceModes)
      : const <String, SidebarBadgeMode>{};
  final quoteById = includeQuotes
      ? byId(quoteModes)
      : const <String, SidebarBadgeMode>{};

  final out = <BillingStatusTab>[
    BillingStatusTab(
      mode: null,
      invoiceModeId: includeInvoices ? kBadgeModeTotal : null,
      quoteModeId: includeQuotes ? kBadgeModeTotal : null,
    ),
  ];

  for (final id in kBillingPipelineTabOrder) {
    // A mode is only usable here if the entity ALSO offers it as a tab —
    // `isKnownStatusTabMode` is what keeps `assigned_to_me` (a personal lens,
    // never a tab) and any counter-only mode out.
    final invoice =
        includeInvoices && isKnownStatusTabMode(EntityType.invoice, id)
        ? invoiceById[id]
        : null;
    final quote = includeQuotes && isKnownStatusTabMode(EntityType.quote, id)
        ? quoteById[id]
        : null;
    if (invoice == null && quote == null) continue;
    out.add(
      BillingStatusTab(
        mode: invoice ?? quote,
        invoiceModeId: invoice?.id,
        quoteModeId: quote?.id,
      ),
    );
  }

  // `All` alone is chrome with no function — the same rule `listStatusTabsFor`
  // applies to a one-tab strip.
  return out.length > 1 ? out : const [];
}

/// The tab [id] names, or null when this build / this company no longer offers
/// it.
///
/// Read on hydrate: a tab id restored from `nav_state` that names a mode this
/// company can't use (quotes module switched off, `view_quote` revoked, a mode
/// retired) must degrade to `All`, or the panel renders nothing selected and
/// subscribes to a tab with no participating halves.
BillingStatusTab? billingStatusTabById(
  List<BillingStatusTab> tabs,
  String? id,
) {
  if (id == null || id.isEmpty) return null;
  for (final tab in tabs) {
    if (tab.id == id) return tab;
  }
  return null;
}
