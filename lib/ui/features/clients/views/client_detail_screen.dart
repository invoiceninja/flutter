import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/list/deep_link_filter_intent.dart';
import 'package:admin/ui/core/list/embedded_list_parent_scope.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/core/widgets/phone_number_value.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/clients/view_models/client_detail_view_model.dart';
import 'package:admin/ui/features/clients/view_models/client_past_due_view_model.dart';
import 'package:admin/ui/features/clients/widgets/client_actions.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_header.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_profile.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_standing.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_tabs.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_past_due_line.dart';
import 'package:admin/utils/formatting.dart';

/// The client record screen, and the first on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions, standing,
/// comments and the profile above a pinned tab strip.
class ClientDetailScreen extends StatefulWidget {
  const ClientDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen>
    with FormatterHostMixin {
  late final ClientDetailViewModel _vm;
  late final EntityActivityViewModel _activityVm;
  late final RecordScreenController _record;

  /// Behind the past-due line: built for the record's **server** id, so it
  /// stays null for a client created offline until it syncs, and is rebuilt
  /// if that id ever changes under an open screen.
  ClientPastDueViewModel? _pastDueVm;
  String? _pastDueFor;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = ClientDetailViewModel(
      repo: _services.clients,
      companyId: _companyId,
      id: widget.id,
    );
    // Owned here, not by the Activity tab, so the Comments card, the Comments
    // tab and the Activity tab share one fetch. Armed from `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'client',
      entityId: widget.id,
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'client',
      refreshRecord: (id) =>
          _services.clients.refreshByIds(companyId: _companyId, ids: [id]),
      hasRecord: () => _vm.item != null,
      countFilterKey: 'client_id',
      // One small request per related tab, for the number beside its label.
      countFetchers: {
        DetailTabIds.invoices: _services.invoices.api.count,
        DetailTabIds.quotes: _services.quotes.api.count,
        DetailTabIds.payments: _services.payments.api.count,
        DetailTabIds.recurringInvoices: _services.recurringInvoices.api.count,
        DetailTabIds.credits: _services.credits.api.count,
        DetailTabIds.projects: _services.projects.api.count,
        DetailTabIds.tasks: _services.tasks.api.count,
        DetailTabIds.expenses: _services.expenses.api.count,
      },
      refreshWith: [_activityVm.refresh],
      refreshAfter: [() => _pastDueVm?.refresh() ?? Future<void>.value()],
      // Rebuilds once, which is what kicks the past-due fetch — with whatever
      // record the re-check left.
      onSettled: () {
        if (mounted) setState(() {});
      },
      onBackOnline: () => _pastDueVm?.retryIfUnanswered(),
    );
    loadFormatter(_services, _companyId);
  }

  /// Builds the past-due view model for [c] once it has a server id, and
  /// again if that id ever differs from the one it was built for. From the
  /// **record**, never from `widget.id`: a screen opened on a client created
  /// offline keeps its `tmp_…` route after the client syncs.
  void _ensurePastDue(Client c) {
    if (isUnsynced(c.id) || c.id == _pastDueFor) return;
    final retired = _pastDueVm;
    _pastDueFor = c.id;
    _pastDueVm = ClientPastDueViewModel(
      invoices: _services.invoices,
      companyId: _companyId,
      clientId: c.id,
    );
    // Widgets built last frame still listen to the old one; let this frame
    // move them to the new one before it goes.
    WidgetsBinding.instance.addPostFrameCallback((_) => retired?.dispose());
  }

  @override
  void dispose() {
    _pastDueVm?.dispose();
    _record.dispose();
    _activityVm.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// Opens the Invoices tab on exactly the invoices the past-due line
  /// counted: the list's own `overdue` filter, as a chip the user can remove,
  /// widened to archived invoices only when one of them is among the late.
  void _openPastDue() {
    _record.listIntents.send(
      EntityType.invoice,
      ListFilterIntent(
        extraFilters: const {
          'overdue': {'true'},
        },
        states: (_pastDueVm?.hasArchivedPastDue(today: Date.today()) ?? false)
            ? const {EntityState.active, EntityState.archived}
            : null,
      ),
    );
    _record.selectTab.selectId(DetailTabIds.invoices);
  }

  void _dispatch(Client c, ClientAction action) =>
      ClientActions.dispatch(context, _services, _companyId, c, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Client>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.clients.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.client),
      emptyIcon: Icons.person_off_outlined,
      emptyTitle: context.tr('client_not_found'),
      emptySubtitle: context.tr('client_not_found_subtitle'),
      // `c` is captured at item-tap time — a late-arriving stream update
      // can't change which client gets archived/restored mid-action.
      actionsForItem: (context, c) => EntityDetailActionsRow<ClientAction>(
        items: ClientActions.itemsFor(context, c, (a) => _dispatch(c, a)),
      ),
      compactTitleForItem: (context, c) =>
          _CompactTitle(client: c, formatter: formatter),
      // A deleted client is read-only until restored.
      isReadOnly: (c) => c.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, c) => recordStateBanner<ClientAction>(
        context,
        items: ClientActions.itemsFor(context, c, (a) => _dispatch(c, a)),
        restoreKind: ClientAction.restore,
        entityId: c.id,
        isDeleted: c.isDeleted,
        archivedAt: c.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, c) => _body(context, c),
    );
  }

  Widget _body(BuildContext context, Client c) {
    _activityVm.kick();
    Future<void> submit(String text) => _services.clients.addComment(
      companyId: _companyId,
      entityId: c.id,
      text: text,
    );
    // Built once here, not in `initState` (`promptLogCallFor` needs a subject
    // and the party id off the resolved record) and not twice (the card and the
    // tabs must not each hold their own copy — see `EntityNoteActions`).
    //
    // A deleted client takes no new notes: the feed stays readable, its
    // buttons go.
    final notes = c.isDeleted
        ? EntityNoteActions.none
        : EntityNoteActions(
            onAddComment: () =>
                promptAddCommentFor(context, entityId: c.id, submit: submit),
            onLogCall: () => promptLogCallFor(
              context,
              companyId: _companyId,
              entityId: c.id,
              subject: c.displayName,
              clientId: c.id,
              submit: submit,
            ),
          );
    final me = _services.auth.session.value?.currentCompany;
    final tabIds = ClientDetailTabs.relatedTabIds(
      (t) => me?.moduleEnabled(t) ?? false,
    );
    _record.attach(recordId: c.id, revision: c.updatedAt, tabIds: tabIds);
    _ensurePastDue(c);
    if (_record.settled) {
      _pastDueVm?.kick(c, enabled: tabIds.contains(DetailTabIds.invoices));
    }
    // The tabs own the `TabController`, so they wrap the page and hand back
    // the strip and the body for it to place — which is what lets the strip
    // stay pinned while a long list scrolls under it.
    //
    // The scope tells the lists embedded in those tabs what they cannot know
    // from a client id alone: that this client is deleted (no New), or not
    // yet synced (New goes through the sync guard).
    return EmbeddedListParentScope(
      parentId: c.id,
      readOnly: c.isDeleted,
      intents: _record.listIntents,
      child: ClientDetailTabs(
        client: c,
        formatter: formatter,
        activityVm: _activityVm,
        selectTab: _record.selectTab,
        notes: notes,
        readOnly: c.isDeleted,
        counts: _record,
        onReveal: _record.page.revealTabs,
        layoutBuilder: (context, strip, body) => _record.buildPage(
          strip: strip,
          body: body,
          top: _top(context, c, notes, tabIds),
        ),
      ),
    );
  }

  /// Everything above the tabs.
  ///
  /// One company watch, hoisted here, feeds the whole profile: which contact
  /// rows and which Details rows exist depends on the labels the company has
  /// given its custom fields.
  Widget _top(
    BuildContext context,
    Client c,
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
        header: ClientDetailHeader(
          client: c,
          formatter: formatter,
          // The banner above the page already says Deleted / Archived.
          showStatePills: !c.isDeleted && c.archivedAt == null,
        ),
        // Call comes and goes with the tap-to-call preference, and this
        // screen stays mounted behind `/settings` while it is flipped.
        quickActions: PhoneActionsScope(
          builder: (context) => EntityQuickActions<ClientAction>(
            priority: ClientActions.quickItemsFor(
              context,
              c,
              (a) => _dispatch(c, a),
            ),
          ),
        ),
        standing: ClientDetailStanding(
          client: c,
          formatter: formatter,
          tabIds: tabIds,
          onOpenTab: _record.selectTab.selectId,
          // Its own listenable, inside the card: an invoice arriving
          // re-draws one line, not the page.
          footnoteBuilder: (context, money) {
            final pastDueVm = _pastDueVm;
            if (pastDueVm == null) return null;
            return ListenableBuilder(
              listenable: pastDueVm,
              builder: (context, _) {
                final pastDue = pastDueVm.valueFor(c, today: Date.today());
                if (pastDue == null) return const SizedBox.shrink();
                final amount = money(pastDue.amount);
                // No currency to format in yet: the figures above are
                // blank, and a label with no amount after it is not.
                if (amount.isEmpty) return const SizedBox.shrink();
                return ClientPastDueLine(
                  pastDue: pastDue,
                  amount: amount,
                  onTap: _openPastDue,
                );
              },
            );
          },
        ),
        comments: EntityCommentsCard(
          vm: _activityVm,
          formatter: formatter,
          actions: notes,
          hostWireName: 'client',
          onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
          matchFormColumn: true,
        ),
        profile: ClientDetailProfile(
          client: c,
          company: company.data,
          formatter: formatter,
        ),
      ),
    );
  }
}

/// The client's name and balance, for the fixed bar once the header has
/// scrolled away — so a long invoice list still says whose it is.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.client, required this.formatter});

  final Client client;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // The header's cascade, to its end: a client with no name at all
          // is "(no name)" there, and must not be a blank line here.
          client.displayName.isNotEmpty
              ? client.displayName
              : (client.name.isNotEmpty
                    ? client.name
                    : context.tr('no_name_fallback')),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        PartyCurrencyBuilder(
          clientId: client.id,
          builder: (context, currencyId) => Text(
            formatter?.money(
                  client.balance,
                  clientCurrencyId: currencyId ?? client.currencyId,
                ) ??
                '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: tokens.ink2)
                .merge(moneyTextStyle()),
          ),
        ),
      ],
    );
  }
}
