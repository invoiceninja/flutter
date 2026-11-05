import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/edit/entity_custom_fields_section.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/features/projects/view_models/project_edit_view_model.dart';
import 'package:admin/ui/features/projects/widgets/edit/project_edit_budget_section.dart';
import 'package:admin/ui/features/projects/widgets/edit/project_edit_details_section.dart';
import 'package:admin/ui/features/projects/widgets/edit/project_edit_notes_section.dart';
import 'package:admin/ui/core/edit/create_form_documents.dart';

/// Lays out the project edit cards (Details, Budget, Notes, Custom Fields)
/// using the same `1fr` main + fixed-width sidebar pattern as
/// `ClientEditLayout` / `ProductEditLayout`.
///
/// - ≥1000 px: two columns. Left holds Details + Budget; right holds Notes
///   + Custom Fields.
/// - <1000 px: single centered column (≤820 px).
class ProjectEditLayout extends StatelessWidget {
  const ProjectEditLayout({super.key, required this.vm});

  final ProjectEditViewModel vm;

  static const double _sidebarWidth = 360;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final twoCol =
                constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
            return SingleChildScrollView(
              padding: EdgeInsets.all(InSpacing.lg(context)),
              child: twoCol
                  ? _wide(context)
                  : CenteredFormColumn(child: _narrow(context)),
            );
          },
        );
      },
    );
  }

  Widget _wide(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProjectEditDetailsSection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              ProjectEditBudgetSection(vm: vm),
            ],
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        SizedBox(
          width: _sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProjectEditNotesSection(vm: vm),
              if (vm.offersDocuments) ...[
                SizedBox(height: InSpacing.md(context)),
                CreateFormDocumentsCard(vm: vm),
              ],
              SizedBox(height: InSpacing.md(context)),
              _customFieldsSection(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _customFieldsSection(BuildContext context) {
    final services = context.read<Services>();
    return EntityCustomFieldsSection(
      keyPrefix: 'project',
      companyStream: services.company.watchCompany(vm.companyId),
      formatter: services.formatterIfReady(vm.companyId),
      values: [
        vm.draft.customValue1,
        vm.draft.customValue2,
        vm.draft.customValue3,
        vm.draft.customValue4,
      ],
      onChanged: [
        vm.setCustomValue1,
        vm.setCustomValue2,
        vm.setCustomValue3,
        vm.setCustomValue4,
      ],
      cardTitle: context.tr('custom_fields'),
    );
  }

  Widget _narrow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProjectEditDetailsSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        ProjectEditBudgetSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        ProjectEditNotesSection(vm: vm),
        if (vm.offersDocuments) ...[
          SizedBox(height: InSpacing.md(context)),
          CreateFormDocumentsCard(vm: vm),
        ],
        SizedBox(height: InSpacing.md(context)),
        _customFieldsSection(context),
      ],
    );
  }
}
