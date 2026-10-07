import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/list/embedded_list_parent_scope.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/features/billing_shared/ledger/ledger_tab.dart';
import 'package:admin/ui/features/expenses/views/expense_list_screen.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_list_screen.dart';
import 'package:admin/ui/features/recurring_expenses/views/recurring_expense_list_screen.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_detail_view_model.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_spend_view_model.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_actions_row.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_header.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_profile.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_standing.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_actions.dart';
import 'package:admin/utils/formatting.dart';

/// The vendor record screen, on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions, standing,
/// comments and the profile above a pinned tab strip.
class VendorDetailScreen extends StatefulWidget {
  const VendorDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen>
    with FormatterHostMixin {
  late final VendorDetailViewModel _vm;
  late final EntityActivityViewModel _activityVm;
  late final RecordScreenController _record;

  /// Behind the standing card — see `VendorSpendViewModel`.
  late final VendorSpendViewModel _spend;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = VendorDetailViewModel(
      repo: _services.vendors,
      companyId: _companyId,
      id: widget.id,
    );
    // Owned here, not by the Activity tab, so the Comments card, the Comments
    // tab and the Activity tab share one fetch. Armed from `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'vendor',
      entityId: widget.id,
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'vendor',
      refreshRecord: (id) =>
          _services.vendors.refreshByIds(companyId: _companyId, ids: [id]),
      hasRecord: () => _vm.item != null,
      // What all three embedded lists send (`vendor_id`, which the server's
      // base `QueryFilters` applies to any table with that column).
      countFilterKey: 'vendor_id',
      // One small request per related tab, for the number beside its label.
      countFetchers: {
        DetailTabIds.purchaseOrders: _services.purchaseOrders.api.count,
        DetailTabIds.expenses: _services.expenses.api.count,
        DetailTabIds.recurringExpenses: _services.recurringExpenses.api.count,
      },
      // The Expenses tab's own request carries this (every expense fetch that
      // is not scoped to a client does — `ExpenseRepository.ensurePageLoaded`),
      // and the server then leaves out expenses billed to an archived or
      // deleted client. Counted without it, the badge is a number of rows the
      // tab will not list, and the standing card would take the difference
      // for expenses this device has yet to fetch.
      countExtras: const {
        DetailTabIds.expenses: {'without_deleted_clients': 'true'},
      },
      refreshWith: [_activityVm.refresh],
      refreshAfter: [() => _spend.refresh()],
      onBackOnline: () => _spend.retryIfUnanswered(),
    );
    _spend = VendorSpendViewModel(
      // The same rows the count is of and the fetch below brings: not those
      // billed to an archived or deleted client.
      watch: (vendorId) => _services.expenses.watchForVendor(
        companyId: _companyId,
        vendorId: vendorId,
        activeClientsOnly: true,
      ),
      // The Expenses tab's own request, a page at a time: `vendor_id` with
      // the list's default `status=active`. Scoped, so it neither reads nor
      // moves the expense sync cursor.
      fetchPage: (vendorId, page) => _services.expenses.ensurePageLoaded(
        companyId: _companyId,
        page: page,
        extraFilters: {
          'vendor_id': {vendorId},
        },
      ),
      pageSize: _services.expenses.pageSize,
      // The count the Expenses tab's badge already asks for.
      counts: _record,
      countTabId: DetailTabIds.expenses,
      isCurrent: () =>
          _services.auth.session.value?.currentCompanyId == _companyId,
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    // Before the controller it listens to.
    _spend.dispose();
    _record.dispose();
    _activityVm.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(Vendor v, VendorAction action) =>
      VendorActions.dispatch(context, _services, _companyId, v, action);

  /// Whether this user is shown what was spent with the vendor at all.
  ///
  /// The module has to be on, and the user has to be allowed to see *every*
  /// expense. Without `view_expense` the server lists — and counts — only the
  /// expenses a user created or is assigned, so the device holds exactly as
  /// many as the server counted, the total would pass as proven, and "Total
  /// Expenses" would be the sum of their own under the vendor's name. The
  /// project screen draws nothing from tasks without `view_task` for the same
  /// reason.
  bool get _showsSpend {
    final me = _services.auth.session.value?.currentCompany;
    return (me?.moduleEnabled(EntityType.expense) ?? false) &&
        (me?.can('view_expense') ?? false);
  }

  /// The related-record tabs this company's modules allow, by id.
  ///
  /// The one gate for both halves of the screen: the strip draws a tab only
  /// for an id in this set, the standing card exists only with the Expenses
  /// tab it opens, and a count is asked for only for a tab that is there.
  static Set<String> _relatedTabIds(
    bool Function(EntityType) moduleEnabled,
  ) => {
    if (moduleEnabled(EntityType.purchaseOrder)) DetailTabIds.purchaseOrders,
    if (moduleEnabled(EntityType.expense)) DetailTabIds.expenses,
    if (moduleEnabled(EntityType.recurringExpense))
      DetailTabIds.recurringExpenses,
  };

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Vendor>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.vendors.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.vendor),
      emptyIcon: Icons.store_outlined,
      emptyTitle: context.tr('vendor_not_found'),
      emptySubtitle: context.tr('vendor_not_found_subtitle'),
      actionsForItem: (context, v) => VendorDetailActionsRow(
        vendor: v,
        services: _services,
        companyId: _companyId,
      ),
      compactTitleForItem: (context, v) => _CompactTitle(
        vendor: v,
        formatter: formatter,
        // The total is the standing card's, and goes with it.
        spend: _showsSpend ? _spend : null,
      ),
      // A deleted vendor is read-only until restored.
      isReadOnly: (v) => v.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, v) => recordStateBanner<VendorAction>(
        context,
        items: VendorActions.itemsFor(context, v, (a) => _dispatch(v, a)),
        restoreKind: VendorAction.restore,
        entityId: v.id,
        isDeleted: v.isDeleted,
        archivedAt: v.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, v) => _body(context, v),
    );
  }

  Widget _body(BuildContext context, Vendor v) {
    _activityVm.kick();
    Future<void> submit(String text) => _services.vendors.addComment(
      companyId: _companyId,
      entityId: v.id,
      text: text,
    );
    // Built once here, not in `initState` (`promptLogCallFor` needs a subject
    // and the party id off the resolved record) and not twice (the card and
    // the tabs must not each hold their own copy — see `EntityNoteActions`).
    //
    // A deleted vendor takes no new notes: the feed stays readable, its
    // buttons go.
    final notes = v.isDeleted
        ? EntityNoteActions.none
        : EntityNoteActions(
            onAddComment: () =>
                promptAddCommentFor(context, entityId: v.id, submit: submit),
            onLogCall: () => promptLogCallFor(
              context,
              companyId: _companyId,
              entityId: v.id,
              subject: v.name,
              vendorId: v.id,
              submit: submit,
            ),
          );
    final me = _services.auth.session.value?.currentCompany;
    final tabIds = _relatedTabIds((t) => me?.moduleEnabled(t) ?? false);
    _record.attach(recordId: v.id, revision: v.updatedAt, tabIds: tabIds);
    // From the record, never the route: a vendor opened while still `tmp_…`
    // keeps that route after it syncs. Not at all when the figure is not
    // shown — there is nothing to feed, and it would hold a query open.
    if (_showsSpend) _spend.attach(v.id);
    // The scope tells the lists embedded in the tabs what they cannot know
    // from a vendor id alone: that this vendor is deleted (no New), or not
    // yet synced (New goes through the sync guard).
    return EmbeddedListParentScope(
      parentId: v.id,
      readOnly: v.isDeleted,
      intents: _record.listIntents,
      // A count lands after the strip is on screen.
      child: ListenableBuilder(
        listenable: _record,
        builder: (context, _) => _tabs(context, v, notes, tabIds),
      ),
    );
  }

  /// Keys an embedded list on the vendor's id.
  ///
  /// A list builds its view model once, with the id it was first given. A
  /// vendor opened while still `tmp_…` and synced with the screen open comes
  /// back through here with its server id — and without a key the list would
  /// keep asking about, and watching for, an id that no longer exists.
  static Widget _scoped(String vendorId, Widget list) =>
      KeyedSubtree(key: ValueKey<String>(vendorId), child: list);

  /// The tabs own the `TabController`, so they wrap the page and hand back the
  /// strip and the body for it to place — which is what lets the strip stay
  /// pinned while a long list scrolls under it.
  Widget _tabs(
    BuildContext context,
    Vendor v,
    EntityNoteActions notes,
    Set<String> tabIds,
  ) {
    return EntityDetailTabs(
      initialIndex: 2,
      selectTab: _record.selectTab,
      onReveal: _record.page.revealTabs,
      layoutBuilder: (context, strip, body) => _record.buildPage(
        strip: strip,
        body: body,
        top: _top(context, v, notes, tabIds),
      ),
      tabs: [
        EntityDetailTab(
          id: DetailTabIds.comments,
          label: context.tr('comments'),
          icon: Icons.comment_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: _activityVm,
            formatter: formatter,
            actions: notes,
            commentsOnly: true,
            hostWireName: 'vendor',
          ),
        ),
        EntityDetailTab(
          id: DetailTabIds.activity,
          label: context.tr('activity'),
          icon: Icons.history_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: _activityVm,
            formatter: formatter,
            actions: notes,
            hostWireName: 'vendor',
          ),
        ),
        if (tabIds.contains(DetailTabIds.purchaseOrders))
          EntityDetailTab(
            id: DetailTabIds.purchaseOrders,
            count: _record.countFor(DetailTabIds.purchaseOrders),
            label: context.tr('purchase_orders'),
            icon: Icons.shopping_bag_outlined,
            bodyBuilder: (_) => _scoped(
              v.id,
              PurchaseOrderListScreen(vendorId: v.id, embedded: true),
            ),
          ),
        if (tabIds.contains(DetailTabIds.expenses))
          EntityDetailTab(
            id: DetailTabIds.expenses,
            count: _record.countFor(DetailTabIds.expenses),
            label: context.tr('expenses'),
            icon: Icons.account_balance_wallet_outlined,
            bodyBuilder: (_) => _scoped(
              v.id,
              ExpenseListScreen(vendorId: v.id, embedded: true),
            ),
          ),
        if (tabIds.contains(DetailTabIds.recurringExpenses))
          EntityDetailTab(
            id: DetailTabIds.recurringExpenses,
            count: _record.countFor(DetailTabIds.recurringExpenses),
            label: context.tr('recurring_expenses'),
            icon: Icons.event_repeat_outlined,
            bodyBuilder: (_) => _scoped(
              v.id,
              RecurringExpenseListScreen(vendorId: v.id, embedded: true),
            ),
          ),
        EntityDetailTab(
          id: DetailTabIds.ledger,
          label: context.tr('ledger'),
          icon: Icons.account_balance_outlined,
          bodyBuilder: (_) => LedgerTab(
            scope: LedgerScope.vendor,
            companyId: _companyId,
            entityId: v.id,
            formatter: formatter,
            openingAt: v.createdAt,
          ),
        ),
        buildStandardDocumentsTab(
          context: context,
          companyId: _companyId,
          entityId: v.id,
          documents: v.documents,
          repo: _services.vendors,
          formatter: formatter,
          // A deleted vendor's documents stay viewable; nothing is added.
          readOnly: v.isDeleted,
        ),
      ],
    );
  }

  /// Everything above the tabs.
  ///
  /// One company watch, hoisted here, feeds the whole profile: which contact
  /// rows and which Details rows exist depends on the labels the company has
  /// given its custom fields.
  Widget _top(
    BuildContext context,
    Vendor v,
    EntityNoteActions notes,
    Set<String> tabIds,
  ) {
    return WatchBuilder<Company?>(
      cacheKey: _companyId,
      // Seeded from what is already in memory, so the rows that depend on the
      // company (custom-field labels) are there in the first frame rather
      // than arriving a frame late and pushing the tabs down.
      initialData: _services.company.peek(
        companyId: _companyId,
        id: _companyId,
      ),
      create: () => _services.company.watchCompany(_companyId),
      builder: (context, company) => EntityRecordColumn(
        header: VendorDetailHeader(
          vendor: v,
          formatter: formatter,
          // The banner above the page already says Deleted / Archived.
          showStatePills: !v.isDeleted && v.archivedAt == null,
        ),
        // Call comes and goes with the tap-to-call preference, and this
        // screen stays mounted behind `/settings` while it is flipped.
        quickActions: PhoneActionsScope(
          builder: (context) => EntityQuickActions<VendorAction>(
            priority: VendorActions.quickItemsFor(
              context,
              v,
              (a) => _dispatch(v, a),
            ),
          ),
        ),
        // What was spent, and when last — figures about expenses, which mean
        // nothing (and open nothing) with that module off, and are not this
        // user's to see without `view_expense` (see [_showsSpend]).
        standing: _showsSpend
            ? VendorDetailStanding(
                vendor: v,
                formatter: formatter,
                spend: _spend,
                onOpenExpenses: () =>
                    _record.selectTab.selectId(DetailTabIds.expenses),
              )
            : null,
        comments: EntityCommentsCard(
          vm: _activityVm,
          formatter: formatter,
          actions: notes,
          hostWireName: 'vendor',
          onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
          matchFormColumn: true,
        ),
        profile: VendorDetailProfile(
          vendor: v,
          company: company.data,
          formatter: formatter,
        ),
      ),
    );
  }
}

/// The vendor's name and what has been spent with them, for the fixed bar
/// once the header has scrolled away — so a long expense list still says
/// whose it is.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({
    required this.vendor,
    required this.formatter,
    required this.spend,
  });

  final Vendor vendor;
  final Formatter? formatter;

  /// Null with the Expenses module off: there is no total to show.
  final VendorSpendViewModel? spend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final spend = this.spend;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // The header's cascade, to its end: a vendor with no name at all is
          // "(no name)" there, and must not be a blank line here.
          vendorDisplayName(context, vendor),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (spend != null)
          ListenableBuilder(
            listenable: spend,
            builder: (context, _) {
              final f = formatter;
              final currencyId = f == null
                  ? ''
                  : VendorDetailStanding.currencyIdOf(vendor, f);
              final value = f == null
                  ? null
                  : spend.valueFor(currencyId: currencyId);
              // Blank while the total is not known — the same rule as the
              // standing card, so the bar never says less than it does.
              return Text(
                value == null || f == null
                    ? ''
                    : f.money(value.total, clientCurrencyId: currencyId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: tokens.ink2)
                    .merge(moneyTextStyle()),
              );
            },
          ),
      ],
    );
  }
}
