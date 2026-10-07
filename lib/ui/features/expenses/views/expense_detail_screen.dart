import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/features/expenses/view_models/expense_detail_view_model.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_detail_header.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_detail_profile.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_detail_standing.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_linked_names.dart';
import 'package:admin/ui/features/expenses/widgets/expense_actions.dart';
import 'package:admin/utils/formatting.dart';

/// The expense record screen, on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions, standing,
/// comments and the profile above a pinned tab strip.
///
/// Everything that used to sit under an Overview tab is above the strip now,
/// so the strip is the record's history and its files — Comments, Activity,
/// Documents — and the screen opens on Documents: the receipt is the part of
/// an expense that is not already on screen.
class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen>
    with FormatterHostMixin {
  late final ExpenseDetailViewModel _vm;
  late final EntityActivityViewModel _activityVm;
  late final RecordScreenController _record;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = ExpenseDetailViewModel.bound(
      _services.expenses.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from `_body`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'expense',
      entityId: widget.id,
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'expense',
      refreshRecord: (id) =>
          _services.expenses.refreshByIds(companyId: _companyId, ids: [id]),
      hasRecord: () => _vm.item != null,
      refreshWith: [_activityVm.refresh],
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _activityVm.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(Expense e, ExpenseAction action) =>
      ExpenseActions.dispatch(context, _services, _companyId, e, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Expense>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.expenses.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.expense),
      emptyIcon: Icons.account_balance_wallet_outlined,
      emptyTitle: context.tr('expense_not_found'),
      // `e` is captured at item-tap time — a late-arriving stream update
      // can't change which expense gets archived mid-action.
      actionsForItem: (context, e) => EntityDetailActionsRow<ExpenseAction>(
        items: ExpenseActions.itemsFor(context, e, (a) => _dispatch(e, a)),
      ),
      compactTitleForItem: (context, e) =>
          _CompactTitle(expense: e, formatter: formatter),
      // A deleted expense is read-only until restored.
      isReadOnly: (e) => e.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, e) => recordStateBanner<ExpenseAction>(
        context,
        items: ExpenseActions.itemsFor(context, e, (a) => _dispatch(e, a)),
        restoreKind: ExpenseAction.restore,
        entityId: e.id,
        isDeleted: e.isDeleted,
        archivedAt: e.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, e) => _body(context, e),
    );
  }

  Widget _body(BuildContext context, Expense e) {
    _activityVm.kick();
    Future<void> submit(String text) => _services.expenses.addComment(
      companyId: _companyId,
      entityId: e.id,
      text: text,
    );
    // Built once here, not in `initState` (`promptLogCallFor` needs a subject
    // and the party ids off the resolved record) and not twice (the card and
    // the tabs must not each hold their own copy — see `EntityNoteActions`).
    //
    // A deleted expense takes no new notes: the feed stays readable, its
    // buttons go.
    final notes = e.isDeleted
        ? EntityNoteActions.none
        : EntityNoteActions(
            onAddComment: () =>
                promptAddCommentFor(context, entityId: e.id, submit: submit),
            onLogCall: () => promptLogCallFor(
              context,
              companyId: _companyId,
              entityId: e.id,
              subject: e.number.isEmpty ? '' : '#${e.number}',
              vendorId: e.vendorId,
              clientId: e.clientId,
              submit: submit,
            ),
          );
    _record.attach(recordId: e.id, revision: e.updatedAt);
    // The tabs own the `TabController`, so they wrap the page and hand back
    // the strip and the body for it to place — which is what keeps the strip
    // pinned while the page scrolls under it.
    return EntityDetailTabs(
      initialIndex: 2,
      selectTab: _record.selectTab,
      onReveal: _record.page.revealTabs,
      layoutBuilder: (context, strip, body) => _record.buildPage(
        strip: strip,
        body: body,
        top: _top(context, e, notes),
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
            hostWireName: 'expense',
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
            hostWireName: 'expense',
          ),
        ),
        buildStandardDocumentsTab(
          context: context,
          companyId: _companyId,
          entityId: e.id,
          documents: e.documents,
          repo: _services.expenses,
          formatter: formatter,
          // A deleted expense keeps its receipts readable and takes no more.
          readOnly: e.isDeleted,
        ),
      ],
    );
  }

  /// Everything above the tabs.
  ///
  /// Two things are resolved once here and handed down, because two widgets
  /// need the same answer: the company (custom-field labels decide which
  /// Details rows exist) and the names of the records this expense points at
  /// (the header prints three of them, the profile the rest).
  Widget _top(BuildContext context, Expense e, EntityNoteActions notes) {
    return WatchBuilder<Company?>(
      cacheKey: _companyId,
      // Seeded, so a record opened from a list has its company in the frame
      // it mounts rather than one frame later.
      initialData: _services.company.peek(
        companyId: _companyId,
        id: _companyId,
      ),
      create: () => _services.company.watchCompany(_companyId),
      builder: (context, company) => ExpenseLinkedNamesBuilder(
        companyId: _companyId,
        vendorId: e.vendorId,
        clientId: e.clientId,
        categoryId: e.categoryId,
        projectId: e.projectId,
        invoiceId: e.invoiceId,
        recurringExpenseId: e.recurringExpenseId,
        transactionId: e.transactionId,
        builder: (context, names) => EntityRecordColumn(
          header: ExpenseDetailHeader(
            expense: e,
            names: names,
            formatter: formatter,
            // The banner above the page already says Deleted / Archived.
            showStatePills: !e.isDeleted && e.archivedAt == null,
          ),
          quickActions: EntityQuickActions<ExpenseAction>(
            priority: ExpenseActions.quickItemsFor(
              context,
              e,
              (a) => _dispatch(e, a),
            ),
          ),
          standing: ExpenseDetailStanding(expense: e, formatter: formatter),
          comments: EntityCommentsCard(
            vm: _activityVm,
            formatter: formatter,
            actions: notes,
            hostWireName: 'expense',
            onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
            matchFormColumn: true,
          ),
          profile: ExpenseDetailProfile(
            expense: e,
            company: company.data,
            names: names,
            formatter: formatter,
          ),
        ),
      ),
    );
  }
}

/// The expense's number and amount, for the fixed bar once the header has
/// scrolled away — so a long activity feed still says whose it is.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.expense, required this.formatter});

  final Expense expense;
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
          // The header's own fallback: an expense not numbered yet is
          // "Expense" there, and must not be a blank line here.
          expense.number.isEmpty ? context.tr('expense') : '#${expense.number}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          formatter?.money(
                expense.amount,
                clientCurrencyId: expense.currencyId,
              ) ??
              '',
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
