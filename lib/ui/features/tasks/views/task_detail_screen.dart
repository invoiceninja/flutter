import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_tab.dart';
import 'package:admin/ui/features/tasks/view_models/task_detail_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_cards_grid.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_header.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_kpi_strip.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';

/// Read-only Task detail screen.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with FormatterHostMixin {
  late final TaskDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = TaskDetailViewModel.bound(
      _services.tasks.watch(companyId: _companyId, id: widget.id),
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
    return EntityDetailScaffold<Task>(
      vm: _vm,
      hydrate: () =>
          _services.tasks.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.task),
      emptyIcon: Icons.task_outlined,
      emptyTitle: context.tr('task_not_found'),
      actionsForItem: (context, t) => EntityDetailActionsRow<TaskAction>(
        items: TaskActions.itemsFor(
          context,
          t,
          (a) => TaskActions.dispatch(context, _services, _companyId, t, a),
        ),
      ),
      bodyBuilder: (context, t) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskDetailHeader(task: t, formatter: formatter),
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
                          TaskDetailKpiStrip(
                            task: t,
                            companyId: _companyId,
                            formatter: formatter,
                          ),
                          SizedBox(height: InSpacing.md(context)),
                          TaskDetailCardsGrid(
                            task: t,
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
                    entityId: t.id,
                    documents: t.documents,
                    repo: _services.tasks,
                    formatter: formatter,
                  ),
                  EntityDetailTab(
                    label: context.tr('activity'),
                    icon: Icons.history_outlined,
                    bodyBuilder: (_) => BillingDocActivityTab(
                      entityWireName: 'task',
                      entityId: t.id,
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
