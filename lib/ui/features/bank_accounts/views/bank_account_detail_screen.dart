import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/list/embedded_list_parent_scope.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/bank_accounts/views/bank_account_list_screen.dart'
    show kBankAccountsListSearchKeys;
import 'package:admin/ui/features/bank_accounts/widgets/bank_account_actions.dart';
import 'package:admin/ui/features/bank_accounts/widgets/detail/bank_account_detail_header.dart';
import 'package:admin/ui/features/bank_accounts/widgets/detail/bank_account_detail_profile.dart';
import 'package:admin/ui/features/bank_accounts/widgets/detail/bank_account_detail_standing.dart';
import 'package:admin/ui/features/bank_accounts/widgets/reconnect_banner.dart';
import 'package:admin/ui/features/transactions/views/transaction_list_screen.dart';
import 'package:admin/utils/formatting.dart';

/// `/settings/bank_accounts/:id` — the bank-account record screen, on the
/// record layout (`docs/detail-screen-layout.md`): identity, quick actions,
/// the balance as its standing and a Details card, above a pinned strip whose
/// one tab is the account's transactions.
///
/// The reconnect banner still leads when the upstream provider has dropped
/// the connection — it explains why and carries the button, which is why
/// there is no Reconnect tile.
///
/// It does not go through `SettingsFormShell`, and never did: the embedded
/// transactions table needs the width, the way a client's invoices do.
class BankAccountDetailScreen extends StatefulWidget {
  const BankAccountDetailScreen({required this.id, super.key});

  /// Search keys for the in-app settings search — re-exports the list
  /// screen's keys so the detail page surfaces in the same searches.
  static const searchKeys = kBankAccountsListSearchKeys;

  final String id;

  @override
  State<BankAccountDetailScreen> createState() =>
      _BankAccountDetailScreenState();
}

class _BankAccountDetailScreenState extends State<BankAccountDetailScreen>
    with FormatterHostMixin {
  late final GenericDetailViewModel<BankAccount> _vm;
  late final RecordScreenController _record;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = GenericDetailViewModel<BankAccount>.bound(
      _services.bankAccounts.watch(companyId: _companyId, id: widget.id),
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'bank_account',
      // By id, on open and on a pull: a balance moves whenever the feed
      // syncs, and the row is otherwise only as fresh as the last `/refresh`.
      refreshRecord: (id) =>
          _services.bankAccounts.refreshByIds(companyId: _companyId, ids: [id]),
      hasRecord: () => _vm.item != null,
      // The key the embedded list itself sends — plural, and the only form
      // `BankTransactionFilters` reads (the singular is silently ignored).
      countFilterKey: 'bank_integration_ids',
      countFetchers: {
        DetailTabIds.transactions: _services.bankTransactions.api.count,
      },
      // The transactions list always sends this
      // (`BankTransactionRepository.ensurePageLoaded`), and the server then
      // returns nothing for an account that is archived or deleted. Counted
      // without it, such an account wears a badge over a list that fetches
      // no rows.
      countExtras: const {
        DetailTabIds.transactions: {'active_banks': 'true'},
      },
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(BankAccount account, BankAccountAction action) =>
      BankAccountActions.dispatch(
        context,
        _services,
        _companyId,
        account,
        action,
      );

  /// Quick-edit auto_sync — flips a single field and persists immediately via
  /// the standard outbox path. No save button since this is the only edit on
  /// the record; the full edit form is one tap away.
  Future<void> _toggleAutoSync(BankAccount account, bool value) async {
    await _services.bankAccounts.save(
      companyId: _companyId,
      account: account.copyWith(autoSync: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<BankAccount>(
      id: widget.id,
      vm: _vm,
      hydrate: () => _services.bankAccounts.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.bankAccount),
      emptyIcon: Icons.account_balance_outlined,
      emptyTitle: context.tr('bank_account_not_found'),
      actionsForItem: (context, a) => EntityDetailActionsRow<BankAccountAction>(
        items: BankAccountActions.itemsFor(
          context,
          a,
          (action) => _dispatch(a, action),
        ),
      ),
      compactTitleForItem: (context, a) =>
          _CompactTitle(account: a, formatter: formatter),
      // A deleted account is read-only until restored.
      isReadOnly: (a) => a.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, a) => recordStateBanner<BankAccountAction>(
        context,
        items: BankAccountActions.itemsFor(
          context,
          a,
          (action) => _dispatch(a, action),
        ),
        restoreKind: BankAccountAction.restore,
        entityId: a.id,
        isDeleted: a.isDeleted,
        archivedAt: a.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, a) => _body(context, a),
    );
  }

  Widget _body(BuildContext context, BankAccount a) {
    final me = _services.auth.session.value?.currentCompany;
    final hasTransactions = me?.moduleEnabled(EntityType.transaction) ?? false;
    _record.attach(
      recordId: a.id,
      revision: a.updatedAt,
      tabIds: {if (hasTransactions) DetailTabIds.transactions},
    );
    final canEdit = me?.can('edit_bank_integration') ?? false;
    final top = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Owns its trailing gap, and builds nothing while the connection is
        // up.
        ReconnectBanner(account: a),
        EntityRecordColumn(
          header: BankAccountDetailHeader(
            account: a,
            formatter: formatter,
            // The banner above the page already says Deleted / Archived.
            showStatePills: !a.isDeleted && a.archivedAt == null,
          ),
          quickActions: EntityQuickActions<BankAccountAction>(
            priority: BankAccountActions.quickItemsFor(
              context,
              a,
              (action) => _dispatch(a, action),
            ),
          ),
          standing: BankAccountDetailStanding(
            account: a,
            formatter: formatter,
            onOpenTransactions: hasTransactions
                ? () => _record.selectTab.selectId(DetailTabIds.transactions)
                : null,
          ),
          profile: BankAccountDetailProfile(
            account: a,
            formatter: formatter,
            // A deleted account is read-only, and the switch is an edit.
            onAutoSyncChanged: a.isDeleted || !canEdit
                ? null
                : (value) => _toggleAutoSync(a, value),
          ),
        ),
      ],
    );
    if (!hasTransactions) {
      // No module, no tab — and a strip with no tabs is not a strip. The
      // record is then just its top, in a scroll view of its own.
      return RefreshIndicator(
        onRefresh: _record.refresh,
        child: SingleChildScrollView(
          controller: DetailScrollScope.maybeOf(context),
          // Handed a controller, so it has to ask to be pullable when the
          // record is shorter than the viewport (`docs/pull-to-refresh.md`).
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: top,
        ),
      );
    }
    // The tabs own the `TabController`, so they wrap the page and hand back
    // the strip and the body for it to place — which is what lets the strip
    // stay pinned while a long list scrolls under it.
    //
    // The scope tells the embedded list what it cannot know from an account
    // id alone: that the account is deleted (no New), or not yet synced.
    return EmbeddedListParentScope(
      parentId: a.id,
      readOnly: a.isDeleted,
      intents: _record.listIntents,
      child: ListenableBuilder(
        // A count lands after the strip is on screen.
        listenable: _record,
        builder: (context, _) => EntityDetailTabs(
          selectTab: _record.selectTab,
          onReveal: _record.page.revealTabs,
          layoutBuilder: (context, strip, body) =>
              _record.buildPage(strip: strip, body: body, top: top),
          tabs: [
            EntityDetailTab(
              id: DetailTabIds.transactions,
              count: _record.countFor(DetailTabIds.transactions),
              label: context.tr('transactions'),
              icon: Icons.swap_horiz,
              // Keyed on the account's id: a list builds its view model once,
              // with the id it was first given, and an account opened while
              // still `tmp_…` comes back through here with its server id.
              bodyBuilder: (_) => KeyedSubtree(
                key: ValueKey<String>(a.id),
                child: TransactionListScreen(
                  bankAccountId: a.id,
                  embedded: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The account's name and balance, for the fixed bar once the header has
/// scrolled away — so a long transaction list still says whose it is.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.account, required this.formatter});

  final BankAccount account;
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
          account.name.trim().isEmpty ? context.tr('untitled') : account.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          bankAccountBalanceText(account, formatter),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: tokens.ink2)
              .merge(moneyTextStyle()),
        ),
      ],
    );
  }
}
