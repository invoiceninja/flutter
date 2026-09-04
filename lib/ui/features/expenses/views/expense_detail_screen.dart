import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/features/expenses/view_models/expense_detail_view_model.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_detail_actions_row.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_detail_cards_grid.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_detail_header.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_detail_kpi_strip.dart';
import 'package:admin/ui/features/expenses/widgets/expense_actions.dart';

/// Read-only Expense detail screen.
class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen>
    with FormatterHostMixin {
  late final ExpenseDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;
  late final EntityActivityViewModel _activityVm;
  final TabSelectionController _selectTab = TabSelectionController();

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = ExpenseDetailViewModel.bound(
      _services.expenses.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'expense',
      entityId: widget.id,
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _activityVm.dispose();
    _selectTab.dispose();
    _vm.dispose();
    super.dispose();
  }

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
      actionsForItem: (context, e) => ExpenseDetailActionsRow(
        expense: e,
        onAction: (a) =>
            ExpenseActions.dispatch(context, _services, _companyId, e, a),
      ),
      bodyBuilder: (context, e) {
        _activityVm.kick();
        // Built here, not in `initState`: `promptLogCallFor` needs a
        // subject off the resolved record.
        final notes = EntityNoteActions(
          onAddComment: () => promptAddCommentFor(
            context,
            entityId: e.id,
            submit: (text) => _services.expenses.addComment(
              companyId: _companyId,
              expenseId: e.id,
              text: text,
            ),
          ),
          onLogCall: () => promptLogCallFor(
            context,
            companyId: _companyId,
            entityId: e.id,
            subject: e.number.isEmpty ? '' : '#${e.number}',
            submit: (text) => _services.expenses.addComment(
              companyId: _companyId,
              expenseId: e.id,
              text: text,
            ),
          ),
        );
        return SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExpenseDetailHeader(expense: e, formatter: formatter),
              const SizedBox(height: InSpacing.xl),
              EntityCommentsCard(
                vm: _activityVm,
                formatter: formatter,
                actions: notes,
                hostWireName: 'expense',
                onViewAll: () => _selectTab.select(0),
              ),
              EntityDetailTabs(
                initialIndex: 2,
                selectTab: _selectTab,
                tabs: [
                  EntityDetailTab(
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
                    label: context.tr('activity'),
                    icon: Icons.history_outlined,
                    bodyBuilder: (_) => EntityActivityTab(
                      vm: _activityVm,
                      formatter: formatter,
                      actions: notes,
                      hostWireName: 'expense',
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('overview'),
                    icon: Icons.dashboard_outlined,
                    bodyBuilder: (_) => Padding(
                      padding: EdgeInsets.all(InSpacing.lg(context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ExpenseDetailKpiStrip(
                            expense: e,
                            formatter: formatter,
                          ),
                          SizedBox(height: InSpacing.md(context)),
                          ExpenseDetailCardsGrid(
                            expense: e,
                            companyId: _companyId,
                            formatter: formatter,
                          ),
                        ],
                      ),
                    ),
                  ),
                  buildStandardDocumentsTab(
                    context: context,
                    companyId: _companyId,
                    entityId: e.id,
                    documents: e.documents,
                    repo: _services.expenses,
                    formatter: formatter,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
