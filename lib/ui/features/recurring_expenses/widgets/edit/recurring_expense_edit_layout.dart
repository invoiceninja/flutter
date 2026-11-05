import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/edit/recurring_expense_edit_amount_tax_section.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/edit/recurring_expense_edit_currency_conversion_section.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/edit/recurring_expense_edit_custom_fields_section.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/edit/recurring_expense_edit_identity_section.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/edit/recurring_expense_edit_invoicing_section.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/edit/recurring_expense_edit_notes_section.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/edit/recurring_expense_edit_schedule_section.dart';
import 'package:admin/ui/core/edit/create_form_documents.dart';

/// Lays out the recurring-expense edit-screen sections using the v2 two-column
/// pattern: expanded main column + fixed-width sidebar on wide widths, single
/// column on narrow. Mirrors `ExpenseEditLayout` with Schedule sitting at the
/// top of the left column — it's the field set that distinguishes this entity
/// from a one-shot expense.
class RecurringExpenseEditLayout extends StatelessWidget {
  const RecurringExpenseEditLayout({super.key, required this.vm});

  final RecurringExpenseEditViewModel vm;

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
              RecurringExpenseEditScheduleSection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              RecurringExpenseEditIdentitySection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              RecurringExpenseEditAmountTaxSection(vm: vm),
            ],
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        SizedBox(
          width: _sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RecurringExpenseEditNotesSection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              RecurringExpenseEditInvoicingSection(vm: vm),
              if (vm.offersDocuments) ...[
                SizedBox(height: InSpacing.md(context)),
                CreateFormDocumentsCard(vm: vm),
              ],
              SizedBox(height: InSpacing.md(context)),
              _CollapsibleFormSection(
                title: context.tr('currency_conversion'),
                initiallyExpanded:
                    vm.draft.invoiceCurrencyId.isNotEmpty &&
                    vm.draft.invoiceCurrencyId != vm.draft.currencyId,
                child: RecurringExpenseEditCurrencyConversionSection(vm: vm),
              ),
              SizedBox(height: InSpacing.md(context)),
              _CustomFieldsCollapsible(vm: vm),
            ],
          ),
        ),
      ],
    );
  }

  Widget _narrow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecurringExpenseEditScheduleSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        RecurringExpenseEditIdentitySection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        RecurringExpenseEditAmountTaxSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        RecurringExpenseEditInvoicingSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        RecurringExpenseEditNotesSection(vm: vm),
        if (vm.offersDocuments) ...[
          SizedBox(height: InSpacing.md(context)),
          CreateFormDocumentsCard(vm: vm),
        ],
        SizedBox(height: InSpacing.md(context)),
        _CollapsibleFormSection(
          title: context.tr('currency_conversion'),
          initiallyExpanded:
              vm.draft.invoiceCurrencyId.isNotEmpty &&
              vm.draft.invoiceCurrencyId != vm.draft.currencyId,
          child: RecurringExpenseEditCurrencyConversionSection(vm: vm),
        ),
        SizedBox(height: InSpacing.md(context)),
        _CustomFieldsCollapsible(vm: vm),
      ],
    );
  }
}

/// The "Custom Fields" collapsible — shown only when the company has at least
/// one configured `expense1..4` label (recurring expenses reuse the expense
/// custom fields). Without this gate, a company with no expense custom fields
/// would see an empty collapsible card.
class _CustomFieldsCollapsible extends StatelessWidget {
  const _CustomFieldsCollapsible({required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(vm.companyId),
      builder: (context, snapshot) {
        final company = snapshot.data;
        final hasLabels =
            company != null &&
            [
              1,
              2,
              3,
              4,
            ].any((i) => company.customFieldLabel('expense$i').isNotEmpty);
        if (!hasLabels) return const SizedBox.shrink();
        return _CollapsibleFormSection(
          title: context.tr('custom_fields'),
          initiallyExpanded:
              vm.draft.customValue1.isNotEmpty ||
              vm.draft.customValue2.isNotEmpty ||
              vm.draft.customValue3.isNotEmpty ||
              vm.draft.customValue4.isNotEmpty,
          child: RecurringExpenseEditCustomFieldsSection(vm: vm),
        );
      },
    );
  }
}

/// Private collapsible card — same shape as `ExpenseEditLayout`'s. Promote
/// to a shared widget once a non-expense screen needs it.
class _CollapsibleFormSection extends StatefulWidget {
  const _CollapsibleFormSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_CollapsibleFormSection> createState() =>
      _CollapsibleFormSectionState();
}

class _CollapsibleFormSectionState extends State<_CollapsibleFormSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      title: widget.title,
      trailing: IconButton(
        tooltip: _expanded ? context.tr('collapse') : context.tr('expand'),
        icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
        onPressed: () => setState(() => _expanded = !_expanded),
      ),
      child: AnimatedCrossFade(
        firstChild: const SizedBox.shrink(),
        secondChild: widget.child,
        crossFadeState: _expanded
            ? CrossFadeState.showSecond
            : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 150),
      ),
    );
  }
}
