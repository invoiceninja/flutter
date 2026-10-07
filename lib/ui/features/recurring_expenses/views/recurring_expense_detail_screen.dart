import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
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
import 'package:admin/ui/features/expenses/widgets/detail/expense_linked_names.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_detail_view_model.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/detail/recurring_expense_detail_header.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/detail/recurring_expense_detail_profile.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/detail/recurring_expense_detail_standing.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/detail/recurring_expense_schedule_tab.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_actions.dart';
import 'package:admin/utils/formatting.dart';

/// The recurring expense record screen, on the record layout
/// (`docs/detail-screen-layout.md`) — the same shape as `ExpenseDetailScreen`,
/// built from the same header entries and profile rows.
///
/// Above the pinned strip: identity, quick actions (Start or Stop first),
/// standing and the profile. Under it: Documents, and the Schedule — the
/// dates it will run on, asked for when that tab is opened.
///
/// There is no comments card and no Activity tab here, unlike the expense:
/// this screen has never mounted the activity feed.
class RecurringExpenseDetailScreen extends StatefulWidget {
  const RecurringExpenseDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<RecurringExpenseDetailScreen> createState() =>
      _RecurringExpenseDetailScreenState();
}

class _RecurringExpenseDetailScreenState
    extends State<RecurringExpenseDetailScreen>
    with FormatterHostMixin {
  late final RecurringExpenseDetailViewModel _vm;
  late final RecordScreenController _record;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = RecurringExpenseDetailViewModel.bound(
      _services.recurringExpenses.watch(companyId: _companyId, id: widget.id),
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'recurring_expense',
      refreshRecord: (id) => _services.recurringExpenses.refreshByIds(
        companyId: _companyId,
        ids: [id],
      ),
      hasRecord: () => _vm.item != null,
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(RecurringExpense e, RecurringExpenseAction action) =>
      RecurringExpenseActions.dispatch(
        context,
        _services,
        _companyId,
        e,
        action,
      );

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<RecurringExpense>(
      id: widget.id,
      vm: _vm,
      hydrate: () => _services.recurringExpenses.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.recurringExpense),
      emptyIcon: Icons.event_repeat_outlined,
      emptyTitle: context.tr('recurring_expense_not_found'),
      // `e` is captured at item-tap time — a late-arriving stream update
      // can't change which record gets stopped or archived mid-action.
      actionsForItem: (context, e) =>
          EntityDetailActionsRow<RecurringExpenseAction>(
            items: RecurringExpenseActions.itemsFor(
              context,
              e,
              (a) => _dispatch(e, a),
            ),
          ),
      compactTitleForItem: (context, e) =>
          _CompactTitle(recurringExpense: e, formatter: formatter),
      // A deleted record is read-only until restored.
      isReadOnly: (e) => e.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, e) => recordStateBanner<RecurringExpenseAction>(
        context,
        items: RecurringExpenseActions.itemsFor(
          context,
          e,
          (a) => _dispatch(e, a),
        ),
        restoreKind: RecurringExpenseAction.restore,
        entityId: e.id,
        isDeleted: e.isDeleted,
        archivedAt: e.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, e) => _body(context, e),
    );
  }

  Widget _body(BuildContext context, RecurringExpense e) {
    _record.attach(recordId: e.id, revision: e.updatedAt);
    // The tabs own the `TabController`, so they wrap the page and hand back
    // the strip and the body for it to place — which is what keeps the strip
    // pinned while the page scrolls under it.
    return EntityDetailTabs(
      selectTab: _record.selectTab,
      onReveal: _record.page.revealTabs,
      layoutBuilder: (context, strip, body) =>
          _record.buildPage(strip: strip, body: body, top: _top(context, e)),
      tabs: [
        buildStandardDocumentsTab(
          context: context,
          companyId: _companyId,
          entityId: e.id,
          documents: e.documents,
          repo: _services.recurringExpenses,
          formatter: formatter,
          // A deleted record keeps its files readable and takes no more.
          readOnly: e.isDeleted,
        ),
        // Second, so it is built — and its dates asked for — only when the
        // user opens it.
        EntityDetailTab(
          id: DetailTabIds.schedule,
          label: context.tr('schedule'),
          icon: Icons.calendar_month_outlined,
          bodyBuilder: (_) => RecurringExpenseScheduleTab(
            recurringExpenseId: e.id,
            revision: e.updatedAt,
            formatter: formatter,
          ),
        ),
      ],
    );
  }

  /// Everything above the tabs.
  ///
  /// The company (custom-field labels decide which Details rows exist) and
  /// the names of the records this one points at are each resolved once here
  /// and handed down, because the header and the profile need the same
  /// answer.
  Widget _top(BuildContext context, RecurringExpense e) {
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
        builder: (context, names) => EntityRecordColumn(
          header: RecurringExpenseDetailHeader(
            recurringExpense: e,
            names: names,
            formatter: formatter,
            // The banner above the page already says Deleted / Archived.
            showStatePills: !e.isDeleted && e.archivedAt == null,
          ),
          quickActions: EntityQuickActions<RecurringExpenseAction>(
            priority: RecurringExpenseActions.quickItemsFor(
              context,
              e,
              (a) => _dispatch(e, a),
            ),
          ),
          standing: RecurringExpenseDetailStanding(
            recurringExpense: e,
            formatter: formatter,
          ),
          profile: RecurringExpenseDetailProfile(
            recurringExpense: e,
            company: company.data,
            names: names,
            formatter: formatter,
          ),
        ),
      ),
    );
  }
}

/// The record's number and amount, for the fixed bar once the header has
/// scrolled away.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({
    required this.recurringExpense,
    required this.formatter,
  });

  final RecurringExpense recurringExpense;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final e = recurringExpense;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // The header's own fallback, so this is never a blank line.
          e.number.isEmpty ? context.tr('recurring_expense') : '#${e.number}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          formatter?.money(e.amount, clientCurrencyId: e.currencyId) ?? '',
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
