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
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
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
  late final EntityActivityViewModel _activityVm;
  final TabSelectionController _selectTab = TabSelectionController();

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = TaskDetailViewModel.bound(
      _services.tasks.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'task',
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
    return EntityDetailScaffold<Task>(
      id: widget.id,
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
        _activityVm.kick();
        return SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskDetailHeader(task: t, formatter: formatter),
              const SizedBox(height: InSpacing.xl),
              EntityCommentsCard(
                vm: _activityVm,
                formatter: formatter,
                hostWireName: 'task',
                // -2: second to last, i.e. the Comments tab beside Activity.
                onViewAll: () => _selectTab.select(-2),
              ),
              EntityDetailTabs(
                selectTab: _selectTab,
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
                  // Read-only: `TaskRepository` has no `addComment`, so this
                  // tab sits beside Activity rather than taking first place
                  // the way the writable entities do.
                  EntityDetailTab(
                    label: context.tr('comments'),
                    icon: Icons.comment_outlined,
                    bodyBuilder: (_) => EntityActivityTab(
                      vm: _activityVm,
                      formatter: formatter,
                      commentsOnly: true,
                      hostWireName: 'task',
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('activity'),
                    icon: Icons.history_outlined,
                    bodyBuilder: (_) => EntityActivityTab(
                      vm: _activityVm,
                      formatter: formatter,
                      hostWireName: 'task',
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
