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
import 'package:admin/ui/core/widgets/entity_picker_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';

/// Identity & links section — vendor, client, project (narrowed by client),
/// category, and currency. All pickers go through [SearchableDropdownField]
/// so long lists stay searchable per CLAUDE.md § Forms. The category picker
/// uses the dropdown's `footerBuilder` to surface a "Manage categories" link
/// inside the popover.
class ExpenseEditIdentitySection extends StatelessWidget {
  const ExpenseEditIdentitySection({super.key, required this.vm});
  final ExpenseEditViewModel vm;

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
            entityType: 'expense',
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
  final ExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return EntityPickerField<Vendor>(
      label: context.tr('vendor'),
      cacheKey: vm.companyId,
      selectedId: vm.draft.vendorId,
      itemsStream: () =>
          services.vendors.watchPage(companyId: vm.companyId, loadedPages: 100),
      watchById: (id) =>
          services.vendors.watch(companyId: vm.companyId, id: id),
      displayString: (v) => v.name.isEmpty ? v.id : v.name,
      idOf: (v) => v.id,
      onChanged: (v) {
        // Don't auto-clear the client when the vendor changes — per
        // the UX spec a user routinely logs the same expense against
        // different vendors for the same client. A future toast +
        // "also clear linked client?" confirm would land here.
        vm.setVendorId(v?.id ?? '');
        // Mirror admin-portal: if the new vendor carries a currency,
        // seed it as the expense currency when the form hasn't yet
        // picked one.
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
  final ExpenseEditViewModel vm;

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
            // Mirror admin-portal: seed the invoice currency from the
            // client's currency when the form hasn't picked one yet (the
            // expense is invoiced to the client in their currency).
            if (c != null &&
                c.currencyId.isNotEmpty &&
                vm.draft.invoiceCurrencyId.isEmpty) {
              vm.setInvoiceCurrencyId(c.currencyId);
              // Seed the exchange rate from the expense vs. client currency so
              // the converted amount is right immediately — same as the
              // currency-conversion section's picker. Left at the current rate
              // when it can't be resolved (no expense currency yet / unknown).
              final rate = crossCurrencyRate(
                services.statics.currencies,
                fromExpenseCurrencyId: vm.draft.currencyId,
                toInvoiceCurrencyId: c.currencyId,
              );
              if (rate != null) vm.setExchangeRate(rate.toString());
            }
            // If the user picks a client, narrow the project picker
            // automatically. The project picker re-evaluates against the
            // new clientId via its `watchForClient` stream below.
            if (c == null || vm.draft.projectId.isEmpty) return;
            // Keep the project until the user changes it — narrowing the
            // list is enough; surprise-clearing is annoying.
          },
          errorText: vm.fieldErrorFor('client_id'),
        );
      },
    );
  }
}

class _ProjectPicker extends StatelessWidget {
  const _ProjectPicker({required this.vm});
  final ExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    // Narrow by client when one is picked; otherwise list all active.
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
      onChanged: (p) => vm.setProjectId(p?.id ?? ''),
      errorText: vm.fieldErrorFor('project_id'),
    );
  }
}

class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.vm});
  final ExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return EntityPickerField<ExpenseCategory>(
      label: context.tr('category'),
      cacheKey: vm.companyId,
      selectedId: vm.draft.categoryId,
      itemsStream: () =>
          services.expenseCategories.watchActive(companyId: vm.companyId),
      watchById: (id) =>
          services.expenseCategories.watch(companyId: vm.companyId, id: id),
      displayString: (c) => c.name.isEmpty ? c.id : c.name,
      idOf: (c) => c.id,
      onChanged: (c) => vm.setCategoryId(c?.id ?? ''),
      errorText: vm.fieldErrorFor('category_id'),
      footerBuilder: (footerContext) {
        final accent = Theme.of(footerContext).colorScheme.primary;
        return InkWell(
          onTap: () => footerContext.go('/settings/expense_categories'),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: InSpacing.md(footerContext),
              vertical: InSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.tune, size: 16, color: accent),
                SizedBox(width: InSpacing.sm),
                Text(
                  footerContext.tr('manage_categories'),
                  style: TextStyle(color: accent),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({required this.vm});
  final ExpenseEditViewModel vm;

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
