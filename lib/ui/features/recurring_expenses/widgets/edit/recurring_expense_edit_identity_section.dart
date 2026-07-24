import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';

/// Identity & links section — mirrors `ExpenseEditIdentitySection`
/// field-for-field. Kept as a duplicate (per task spec) instead of
/// lifting Expense's section into a shared widget; the two diverge once
/// recurring-specific assignments (next vendor, last sent vendor, etc.)
/// land.
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
          _VendorPicker(vm: vm),
          _ClientPicker(vm: vm),
          _ProjectPicker(vm: vm),
          _CategoryPicker(vm: vm),
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
    final services = context.read<Services>();
    return StreamBuilder<List<Vendor>>(
      stream: services.vendors.watchPage(
        companyId: vm.companyId,
        loadedPages: 100,
      ),
      builder: (context, snapshot) {
        final vendors = snapshot.data ?? const <Vendor>[];
        Vendor? selected;
        for (final v in vendors) {
          if (v.id == vm.draft.vendorId) {
            selected = v;
            break;
          }
        }
        return SearchableDropdownField<Vendor>(
          label: context.tr('vendor'),
          items: vendors,
          initialValue: selected,
          displayString: (v) => v.name.isEmpty ? v.id : v.name,
          idOf: (v) => v.id,
          onChanged: (v) {
            vm.setVendorId(v?.id ?? '');
            if (v != null && vm.draft.currencyId.isEmpty) {
              vm.setCurrencyId(v.currencyId);
            }
          },
          errorText: vm.fieldErrorFor('vendor_id'),
        );
      },
    );
  }
}

class _ClientPicker extends StatelessWidget {
  const _ClientPicker({required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<List<Client>>(
      stream: services.clients.watchPage(
        companyId: vm.companyId,
        loadedPages: 100,
      ),
      builder: (context, snapshot) {
        final clients = snapshot.data ?? const <Client>[];
        Client? selected;
        for (final c in clients) {
          if (c.id == vm.draft.clientId) {
            selected = c;
            break;
          }
        }
        return SearchableDropdownField<Client>(
          label: context.tr('client'),
          items: clients,
          initialValue: selected,
          displayString: (c) => c.displayName.isEmpty
              ? (c.name.isEmpty ? c.id : c.name)
              : c.displayName,
          idOf: (c) => c.id,
          onChanged: (c) {
            vm.setClientId(c?.id ?? '');
            // Seed the invoice currency from the client's currency when none
            // is set yet — mirrors ExpenseEditIdentitySection + admin-portal
            // (the expense is invoiced to the client in their currency).
            if (c != null &&
                c.currencyId.isNotEmpty &&
                vm.draft.invoiceCurrencyId.isEmpty) {
              vm.setInvoiceCurrencyId(c.currencyId);
            }
          },
          errorText: vm.fieldErrorFor('client_id'),
        );
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
    final stream = vm.draft.clientId.isEmpty
        ? services.projects.watchPage(companyId: vm.companyId, loadedPages: 100)
        : services.projects.watchForClient(
            companyId: vm.companyId,
            clientId: vm.draft.clientId,
          );
    return StreamBuilder<List<Project>>(
      stream: stream,
      builder: (context, snapshot) {
        final projects = snapshot.data ?? const <Project>[];
        Project? selected;
        for (final p in projects) {
          if (p.id == vm.draft.projectId) {
            selected = p;
            break;
          }
        }
        return SearchableDropdownField<Project>(
          label: context.tr('project'),
          items: projects,
          initialValue: selected,
          displayString: (p) => p.name.isEmpty ? p.id : p.name,
          idOf: (p) => p.id,
          onChanged: (p) => vm.setProjectId(p?.id ?? ''),
          errorText: vm.fieldErrorFor('project_id'),
        );
      },
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final tokens = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<List<ExpenseCategory>>(
          stream: services.expenseCategories.watchActive(
            companyId: vm.companyId,
          ),
          builder: (context, snapshot) {
            final cats = snapshot.data ?? const <ExpenseCategory>[];
            ExpenseCategory? selected;
            for (final c in cats) {
              if (c.id == vm.draft.categoryId) {
                selected = c;
                break;
              }
            }
            return SearchableDropdownField<ExpenseCategory>(
              label: context.tr('category'),
              items: cats,
              initialValue: selected,
              displayString: (c) => c.name.isEmpty ? c.id : c.name,
              idOf: (c) => c.id,
              onChanged: (c) => vm.setCategoryId(c?.id ?? ''),
              errorText: vm.fieldErrorFor('category_id'),
            );
          },
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
