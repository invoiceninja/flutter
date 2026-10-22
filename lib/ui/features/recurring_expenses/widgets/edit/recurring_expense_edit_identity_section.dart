import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/assigned_user_picker_field.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/core/widgets/entity_picker_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/clients/widgets/client_picker_field_with_create.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_picker_field.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_picker_field.dart';

/// Identity & links section — mirrors `ExpenseEditIdentitySection` except
/// for one field: there is **no Date**. `RecurringExpenseToExpenseFactory`
/// stamps every generated expense with `date = now()` and never reads the
/// template's `date`, so a Date control here would edit a value nothing uses
/// (the schedule card's next-send date is what decides when one is made). The
/// assignee does carry over to each generated expense, so it is here. Kept as
/// a duplicate (per task spec) instead of lifting Expense's section into a
/// shared widget; the two diverge once recurring-specific assignments (next
/// vendor, last sent vendor, etc.) land.
class RecurringExpenseEditIdentitySection extends StatelessWidget {
  const RecurringExpenseEditIdentitySection({super.key, required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      title: context.tr('details'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          EntityEditField(
            label: context.tr('number'),
            initial: vm.draft.number,
            onChanged: vm.setNumber,
            errorText: vm.fieldErrorFor('number'),
            hintText: vm.isCreate ? context.tr('auto_generated') : null,
            autocorrect: false,
          ),
          _VendorPicker(vm: vm),
          _ClientPicker(vm: vm),
          _ProjectPicker(vm: vm),
          _CategoryPicker(vm: vm),
          AssignedUserPickerField(
            companyId: vm.companyId,
            selectedId: vm.draft.assignedUserId,
            onChanged: vm.setAssignedUserId,
          ),
          _CurrencyPicker(vm: vm),
          SizedBox(height: InSpacing.md(context)),
          EntityTagsField(
            entityType: 'recurring_expense',
            selectedIds: vm.draft.tagIds,
            onChanged: vm.setTagIds,
          ),
        ],
      ),
    );
  }
}

class _VendorPicker extends StatelessWidget {
  const _VendorPicker({required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return VendorPickerField(
      companyId: vm.companyId,
      selectedId: vm.draft.vendorId,
      onChanged: (v) {
        vm.setVendorId(v?.id ?? '');
        if (v != null && vm.draft.currencyId.isEmpty) {
          vm.setCurrencyId(v.currencyId);
        }
      },
      errorText: vm.fieldErrorFor('vendor_id'),
    );
  }
}

class _ClientPicker extends StatelessWidget {
  const _ClientPicker({required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    // `ClientPickerField`, not a local-list picker: it searches the server
    // before offering "Create «x»", so a client outside this device's cache
    // is found rather than duplicated.
    return ClientPickerFieldWithCreate(
      companyId: vm.companyId,
      selectedClientId: vm.draft.clientId,
      label: context.tr('client'),
      errorText: vm.fieldErrorFor('client_id'),
      onSelected: (c) {
        vm.setClientId(c?.id ?? '');
        // Seed the invoice currency from the client's currency when none
        // is set yet — mirrors ExpenseEditIdentitySection + admin-portal
        // (the expense is invoiced to the client in their currency).
        if (c != null &&
            c.currencyId.isNotEmpty &&
            vm.draft.invoiceCurrencyId.isEmpty) {
          vm.setInvoiceCurrencyId(c.currencyId);
          // Seed the exchange rate too, so the converted amount is right
          // immediately — same as the currency-conversion section's picker,
          // and the half this mirror had been missing: setting the invoice
          // currency without the rate left the conversion on whatever rate
          // the form already held. Left alone when it can't be resolved
          // (no expense currency yet / unknown).
          final rate = crossCurrencyRate(
            services.statics.currencies,
            fromExpenseCurrencyId: vm.draft.currencyId,
            toInvoiceCurrencyId: c.currencyId,
          );
          if (rate != null) vm.setExchangeRate(rate.toString());
        }
      },
    );
  }
}

class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return EntityPickerField<Project>(
      label: context.tr('project'),
      // The list narrows to the picked client, so the client id is part of
      // what invalidates the stream.
      cacheKey: (vm.companyId, vm.draft.clientId),
      selectedId: vm.draft.projectId,
      itemsStream: () => vm.draft.clientId.isEmpty
          ? services.projects.watchPage(
              companyId: vm.companyId,
              loadedPages: 100,
            )
          : services.projects.watchForClient(
              companyId: vm.companyId,
              clientId: vm.draft.clientId,
            ),
      watchById: (id) =>
          services.projects.watch(companyId: vm.companyId, id: id),
      displayString: (p) => p.name.isEmpty ? p.id : p.name,
      idOf: (p) => p.id,
      emptyHintKey: 'no_records_found',
      onChanged: (p) => vm.setProjectId(p?.id ?? ''),
      errorText: vm.fieldErrorFor('project_id'),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExpenseCategoryPickerField(
          companyId: vm.companyId,
          selectedId: vm.draft.categoryId,
          onChanged: (c) => vm.setCategoryId(c?.id ?? ''),
          errorText: vm.fieldErrorFor('category_id'),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () => context.go('/settings/expense_categories'),
            icon: Icon(Icons.tune, size: 16, color: tokens.primary),
            label: Text(context.tr('manage_categories')),
          ),
        ),
      ],
    );
  }
}

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final currencies = services.statics.currencies.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    Currency? selected;
    for (final c in currencies) {
      if (c.id == vm.draft.currencyId) {
        selected = c;
        break;
      }
    }
    return SearchableDropdownField<Currency>(
      label: context.tr('currency'),
      items: currencies,
      initialValue: selected,
      displayString: (c) => '${c.code} · ${c.name}',
      idOf: (c) => c.id,
      onChanged: (c) => vm.setCurrencyId(c?.id ?? ''),
      errorText: vm.fieldErrorFor('currency_id'),
    );
  }
}
