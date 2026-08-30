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
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_tab.dart';
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

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = ExpenseDetailViewModel.bound(
      _services.expenses.watch(companyId: _companyId, id: widget.id),
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Expense>(
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
        return SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExpenseDetailHeader(expense: e, formatter: formatter),
              const SizedBox(height: InSpacing.xl),
              EntityDetailTabs(
                tabs: [
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
                  EntityDetailTab(
                    label: context.tr('activity'),
                    icon: Icons.history_outlined,
                    bodyBuilder: (_) => BillingDocActivityTab(
                      entityWireName: 'expense',
                      entityId: e.id,
                      companyId: _companyId,
                      activitiesApi: _services.activities,
                      outboxDao: _services.db.outboxDao,
                      formatter: formatter,
                    ),
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
