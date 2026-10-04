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
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_amount_tax_section.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_banking_section.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_currency_conversion_section.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_custom_fields_section.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_documents_section.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_identity_section.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_invoicing_section.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_notes_section.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_payment_section.dart';

/// Lays out the expense edit-screen sections using the v2 two-column pattern:
/// expanded main column + fixed-width sidebar on wide widths, single column
/// on narrow. Direct mirror of `ClientEditLayout`.
///
/// - ≥1000 px: two columns. Left (`Expanded`) holds Identity, Amount/Tax, and
///   Payment — the core transaction fields. Right (`_sidebarWidth` 360 px)
///   holds Documents (create only, where the plan allows attachments —
///   [showsExpenseDocumentsCard]), Notes, Invoicing, and the three
///   collapsible secondary sections (Currency conversion, Banking, Custom
///   fields).
/// - <1000 px: single centered column (≤820 px), pre-refactor order, with
///   Documents (create only) straight after Identity.
class ExpenseEditLayout extends StatelessWidget {
  const ExpenseEditLayout({super.key, required this.vm});

  final ExpenseEditViewModel vm;

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
            final documents = showsExpenseDocumentsCard(
              isCreate: vm.isCreate,
              session: context.read<Services>().auth.session.value,
            );
            return SingleChildScrollView(
              padding: EdgeInsets.all(InSpacing.lg(context)),
              child: twoCol
                  ? _wide(context, documents: documents)
                  : CenteredFormColumn(
                      child: _narrow(context, documents: documents),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _wide(BuildContext context, {required bool documents}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ExpenseEditIdentitySection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              ExpenseEditAmountTaxSection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              ExpenseEditPaymentSection(vm: vm),
            ],
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        SizedBox(
          width: _sidebarWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // First in the sidebar, so a receipt shared into the app is in
              // view the moment New Expense opens.
              if (documents) ...[
                ExpenseEditDocumentsSection(vm: vm),
                SizedBox(height: InSpacing.md(context)),
              ],
              ExpenseEditNotesSection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              ExpenseEditInvoicingSection(vm: vm),
              SizedBox(height: InSpacing.md(context)),
              _CollapsibleFormSection(
                title: context.tr('currency_conversion'),
                initiallyExpanded:
                    vm.draft.invoiceCurrencyId.isNotEmpty &&
                    vm.draft.invoiceCurrencyId != vm.draft.currencyId,
                child: ExpenseEditCurrencyConversionSection(vm: vm),
              ),
              SizedBox(height: InSpacing.md(context)),
              _CollapsibleFormSection(
                title: context.tr('banking'),
                initiallyExpanded:
                    vm.draft.bankId.isNotEmpty ||
                    vm.draft.transactionId.isNotEmpty,
                child: ExpenseEditBankingSection(vm: vm),
              ),
              SizedBox(height: InSpacing.md(context)),
              _CustomFieldsCollapsible(vm: vm),
            ],
          ),
        ),
      ],
    );
  }

  Widget _narrow(BuildContext context, {required bool documents}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpenseEditIdentitySection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        if (documents) ...[
          ExpenseEditDocumentsSection(vm: vm),
          SizedBox(height: InSpacing.md(context)),
        ],
        ExpenseEditAmountTaxSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        ExpenseEditPaymentSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        ExpenseEditInvoicingSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        ExpenseEditNotesSection(vm: vm),
        SizedBox(height: InSpacing.md(context)),
        _CollapsibleFormSection(
          title: context.tr('currency_conversion'),
          initiallyExpanded:
              vm.draft.invoiceCurrencyId.isNotEmpty &&
              vm.draft.invoiceCurrencyId != vm.draft.currencyId,
          child: ExpenseEditCurrencyConversionSection(vm: vm),
        ),
        SizedBox(height: InSpacing.md(context)),
        _CollapsibleFormSection(
          title: context.tr('banking'),
          initiallyExpanded:
              vm.draft.bankId.isNotEmpty || vm.draft.transactionId.isNotEmpty,
          child: ExpenseEditBankingSection(vm: vm),
        ),
        SizedBox(height: InSpacing.md(context)),
        _CustomFieldsCollapsible(vm: vm),
      ],
    );
  }
}

/// The "Custom Fields" collapsible — shown only when the company has at least
/// one configured `expense1..4` label (matching React, which hides custom
/// fields with no label). Without this gate, a company that hasn't configured
/// expense custom fields would see an empty collapsible card.
class _CustomFieldsCollapsible extends StatelessWidget {
  const _CustomFieldsCollapsible({required this.vm});
  final ExpenseEditViewModel vm;

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
          child: ExpenseEditCustomFieldsSection(vm: vm),
        );
      },
    );
  }
}

/// Small collapsible card. Wraps the children in a [DashboardCardShell]
/// header that toggles a chevron; when expanded, the body renders inside
/// the same card's interior padding. Private to the expense edit layout —
/// promote to a shared widget if a second screen needs the same shape.
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
