import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/projects/view_models/project_detail_view_model.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_cards_grid.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_header.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_tabs.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_progress_card.dart';
import 'package:admin/ui/features/projects/widgets/project_actions.dart';

/// Read-only Project detail screen.
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with FormatterHostMixin {
  late final ProjectDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;
  late final EntityActivityViewModel _activityVm;
  final TabSelectionController _selectTab = TabSelectionController();

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = ProjectDetailViewModel.bound(
      _services.projects.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'project',
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
    return EntityDetailScaffold<Project>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.projects.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.project),
      emptyIcon: Icons.work_outline,
      emptyTitle: context.tr('project_not_found'),
      actionsForItem: (context, p) => EntityDetailActionsRow<ProjectAction>(
        items: ProjectActions.itemsFor(
          context,
          p,
          (a) => ProjectActions.dispatch(context, _services, _companyId, p, a),
        ),
      ),
      bodyBuilder: (context, p) {
        _activityVm.kick();
        return SingleChildScrollView(
          controller: DetailScrollScope.maybeOf(context),
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProjectDetailHeader(project: p, formatter: formatter),
              const SizedBox(height: InSpacing.xl),
              ProjectProgressCard(
                project: p,
                companyId: _companyId,
                formatter: formatter,
              ),
              const SizedBox(height: InSpacing.xl),
              EntityCommentsCard(
                vm: _activityVm,
                formatter: formatter,
                hostWireName: 'project',
                // -2: second to last, i.e. the Comments tab beside Activity.
                onViewAll: () => _selectTab.select(-2),
                matchFormColumn: true,
              ),
              // Detail cards sit above the tab strip (Client-style); the
              // tabs are purely the project-scoped related lists.
              ProjectDetailCardsGrid(
                project: p,
                companyId: _companyId,
                formatter: formatter,
              ),
              const SizedBox(height: InSpacing.xl),
              ProjectDetailTabs(
                project: p,
                formatter: formatter,
                activityVm: _activityVm,
                selectTab: _selectTab,
              ),
            ],
          ),
        );
      },
    );
  }
}
