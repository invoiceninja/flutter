import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/edit_action_filter.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/entity_tags_field.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/transactions/view_models/transaction_edit_view_model.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_actions.dart';

/// `/transactions/new` and `/transactions/:id/edit`. Bare manual-entry form
/// — most transactions arrive via bank-feed sync, but the API supports
/// manual rows for reconciliation, so the entity needs a create/edit path
/// for completeness.
class TransactionEditScreen extends StatelessWidget {
  const TransactionEditScreen({this.existingId, super.key});

  final String? existingId;

  @override
  Widget build(BuildContext context) {
    return EntityEditScreenScaffold<BankTransaction, TransactionEditViewModel>(
      existingId: existingId,
      entityTypeName: 'transaction',
      fetchExisting: (ctx, services, companyId, id) =>
          services.bankTransactions.watch(companyId: companyId, id: id).first,
      buildVm: (ctx, services, companyId, existing) {
        return TransactionEditViewModel(
          repo: services.bankTransactions,
          companyId: companyId,
          existing: existing,
          bankAccountRequiredMessage: ctx.tr('please_select_a_bank_account'),
          sync: services.sync,
          connectivity: services.connectivity,
        );
      },
      titleWhileLoading: (ctx) =>
          existingId == null ? ctx.tr('new_transaction') : ctx.tr('edit'),
      titleBuilder: (ctx, vm) =>
          vm.isCreate ? ctx.tr('new_transaction') : ctx.tr('edit_transaction'),
      bodyBuilder: (ctx, vm) => _TransactionEditBody(vm: vm),
      resetToEmpty: (vm) => vm.resetToEmpty(),
      entityIdOf: (t) => t.id,
      actionsBuilder: (ctx, vm, onTap, saveButton) =>
          EntityOverflowActionBar<TransactionAction>(
            leading: saveButton,
            items: filterForEditScreen(
              TransactionActions.itemsFor(ctx, vm.draft, (a) => onTap(a)),
              isCreate: vm.isCreate,
              isLifecycle: TransactionActions.isLifecycle,
            ),
          ),
      onAfterSaveAction: (ctx, saved, a) {
        final services = ctx.read<Services>();
        return TransactionActions.dispatch(
          ctx,
          services,
          services.auth.session.value!.currentCompanyId,
          saved,
          a as TransactionAction,
        );
      },
      onSaved: (ctx, vm, saved) => goAfterEntitySave(
        ctx,
        isCreate: vm.isCreate,
        basePath: '/transactions',
        savedId: saved.id,
      ),
    );
  }
}

class _TransactionEditBody extends StatelessWidget {
  const _TransactionEditBody({required this.vm});
  final TransactionEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    // Comma-locale users type `19,50`; without this their amount runs through
    // `Decimal.tryParse`, which rejects the comma and silently saves 0.
    final useComma =
        services.formatterIfReady(companyId)?.settings.useCommaAsDecimalPlace ??
        false;
    return SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: CenteredFormColumn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // CREDIT / DEBIT segmented switcher — drives both the panel
            // selection on the detail screen and the deposit/withdrawal
            // column rendering on the list.
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: kTransactionTypeCredit,
                  label: Text(context.tr('deposit')),
                  icon: const Icon(Icons.south_west, size: 16),
                ),
                ButtonSegment(
                  value: kTransactionTypeDebit,
                  label: Text(context.tr('withdrawal')),
                  icon: const Icon(Icons.north_east, size: 16),
                ),
              ],
              selected: {vm.draft.baseType},
              onSelectionChanged: (set) {
                if (set.isEmpty) return;
                vm.setBaseType(set.first);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: vm.draft.amount == Decimal.zero
                  ? ''
                  : (useComma
                        ? vm.draft.amount.toString().replaceAll('.', ',')
                        : vm.draft.amount.toString()),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // Allow the comma so comma-locale users can type their decimal
              // separator; `parseDecimal` interprets it via `useComma`.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: context.tr('amount'),
                errorText: vm.fieldErrorFor('amount'),
              ),
              onChanged: (v) {
                final parsed =
                    parseDecimal(v, useCommaAsDecimalPlace: useComma) ??
                    Decimal.zero;
                vm.setAmount(parsed);
              },
            ),
            const SizedBox(height: 12),
            _CurrencyPicker(vm: vm),
            const SizedBox(height: 12),
            InDateField(
              value: vm.draft.date?.toDateTime(),
              labelText: context.tr('date'),
              clearable: true,
              onChanged: (dt) => vm.setDate(
                dt == null ? null : Date(dt.year, dt.month, dt.day),
              ),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<BankAccount>>(
              stream: services.bankAccounts.watchAll(companyId: companyId),
              builder: (context, snapshot) {
                final accounts = snapshot.data ?? const <BankAccount>[];
                // Auto-seed: if the user hasn't picked a bank account yet
                // and exactly one active account exists, default to it.
                // Idempotent — the post-frame callback only fires once
                // per "no selection + one candidate" state.
                if (vm.draft.bankAccountId.isEmpty && accounts.length == 1) {
                  final only = accounts.first.id;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    // The pane can close on the very frame the accounts stream
                    // first emits; without this guard the seed lands on a
                    // disposed VM.
                    if (vm.isDisposed) return;
                    if (vm.draft.bankAccountId.isEmpty) {
                      vm.setBankAccountId(only);
                    }
                  });
                }
                final selected = accounts
                    .where((a) => a.id == vm.draft.bankAccountId)
                    .toList(growable: false);
                return SearchableDropdownField<BankAccount>(
                  label: context.tr('bank_account'),
                  items: accounts,
                  initialValue: selected.isEmpty ? null : selected.first,
                  idOf: (a) => a.id,
                  displayString: (a) => a.name.isEmpty ? a.id : a.name,
                  onChanged: (a) => vm.setBankAccountId(a?.id ?? ''),
                  emptyHintKey: 'connect_a_bank_account_first',
                  errorText: vm.fieldErrorFor('bank_integration_id'),
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: vm.draft.description,
              decoration: InputDecoration(
                labelText: context.tr('description'),
                errorText: vm.fieldErrorFor('description'),
              ),
              maxLines: 3,
              onChanged: vm.setDescription,
            ),
            const SizedBox(height: 12),
            EntityTagsField(
              entityType: 'bank_transaction',
              selectedIds: vm.draft.tagIds,
              onChanged: vm.setTagIds,
            ),
          ],
        ),
      ),
    );
  }
}

/// Currency picker backed by the cached `/api/v1/statics` map. Replaces
/// the previous free-text field so users see "USD — US Dollar" labels
/// instead of typing a wire id from memory.
class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({required this.vm});

  final TransactionEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final currencies = services.statics.currencies.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    final selected = currencies
        .where((c) => c.id == vm.draft.currencyId)
        .toList(growable: false);
    return SearchableDropdownField<Currency>(
      label: context.tr('currency'),
      items: currencies,
      initialValue: selected.isEmpty ? null : selected.first,
      idOf: (c) => c.id,
      displayString: (c) => c.code.isEmpty ? c.name : '${c.code} — ${c.name}',
      onChanged: (c) => vm.setCurrencyId(c?.id ?? ''),
      errorText: vm.fieldErrorFor('currency_id'),
    );
  }
}
