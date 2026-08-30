import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_detail_view_model.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/detail/recurring_expense_detail_actions_row.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/detail/recurring_expense_detail_cards_grid.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/detail/recurring_expense_detail_header.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/detail/recurring_expense_detail_kpi_strip.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_actions.dart';

/// Read-only Recurring Expense detail screen. Same chrome as
/// `ExpenseDetailScreen`; the body composes a header, an Overview tab
/// (summary + schedule + entity link cards), and a Documents tab.
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
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<RecurringExpense>(
      vm: _vm,
      hydrate: () => _services.recurringExpenses.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.recurringExpense),
      emptyIcon: Icons.event_repeat_outlined,
      emptyTitle: context.tr('recurring_expense_not_found'),
      actionsForItem: (context, e) => RecurringExpenseDetailActionsRow(
        recurringExpense: e,
        onAction: (a) => RecurringExpenseActions.dispatch(
          context,
          _services,
          _companyId,
          e,
          a,
        ),
      ),
      bodyBuilder: (context, e) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RecurringExpenseDetailHeader(
                recurringExpense: e,
                formatter: formatter,
              ),
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
                          RecurringExpenseDetailKpiStrip(
                            recurringExpense: e,
                            formatter: formatter,
                          ),
                          SizedBox(height: InSpacing.md(context)),
                          RecurringExpenseDetailCardsGrid(
                            recurringExpense: e,
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
                    repo: _services.recurringExpenses,
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
