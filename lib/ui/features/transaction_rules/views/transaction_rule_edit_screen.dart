import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/mdi_icons.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/models/domain/transaction_rule.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/transaction_rules/rule_evaluator.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';
import 'package:admin/ui/features/transaction_rules/view_models/transaction_rule_edit_view_model.dart';
import 'package:admin/ui/features/transaction_rules/widgets/rule_criterion_editor_sheet.dart';

/// `/settings/bank_accounts/transaction_rules/new` and `/.../:id`.
class TransactionRuleEditScreen extends StatelessWidget {
  const TransactionRuleEditScreen({this.existingId, super.key});

  final String? existingId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.transactionRules;

    return SettingsEntityEditScaffold<
      TransactionRule,
      TransactionRuleEditViewModel
    >(
      existingId: existingId,
      backRoute: '/settings/bank_accounts/transaction_rules',
      createTitleKey: 'new_transaction_rule',
      editTitleKey: 'edit_transaction_rule',
      wireName: 'transaction_rule',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete: (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) => TransactionRuleEditViewModel(
        repo: repo,
        companyId: companyId,
        existing: existing,
        sync: services.sync,
        connectivity: services.connectivity,
      ),
      isArchivedOf: (r) => r.archivedAt != null,
      isDeletedOf: (r) => r.isDeleted,
      canSave: (vm) =>
          !vm.isSaving && vm.isDirty && vm.draft.name.trim().isNotEmpty,
      bodyBuilder: (context, vm) => [
        FormSection(
          title: context.tr('transaction_rule'),
          children: [
            SettingsTextField(
              initialValue: vm.draft.name,
              labelKey: 'name',
              onChanged: vm.setName,
              errorText: vm.fieldErrorFor('name'),
              textInputAction: TextInputAction.next,
              externalSyncKey: vm.original?.id,
            ),
            const SizedBox(height: 8),
            _AppliesToSelector(vm: vm),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('match_all_rules')),
              subtitle: Text(context.tr('match_all_rules_help')),
              value: vm.draft.matchesOnAll,
              onChanged: vm.setMatchesOnAll,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.tr('auto_convert')),
              subtitle: Text(
                vm.draft.isCredit
                    ? context.tr('auto_convert_credit_help')
                    : context.tr('auto_convert_help'),
              ),
              value: vm.draft.autoConvert,
              onChanged: vm.setAutoConvert,
            ),
            // Vendor + category are the targets a matched WITHDRAWAL is
            // converted to (an expense). They're meaningless for a DEPOSIT
            // rule (which links to a payment), so the server ignores them and
            // `setAppliesTo` clears them on CREDIT — render only for DEBIT.
            if (!vm.draft.isCredit) ...[
              _VendorPicker(vm: vm),
              _CategoryPicker(vm: vm),
            ],
          ],
        ),
        FormSection(
          title: context.tr('rules'),
          children: [
            _RuleMatchPreview(vm: vm, companyId: companyId),
            _CriteriaList(vm: vm),
          ],
        ),
      ],
    );
  }
}

class _AppliesToSelector extends StatelessWidget {
  const _AppliesToSelector({required this.vm});
  final TransactionRuleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '${context.tr('applies_to')}:',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: kTransactionRuleAppliesDebit,
                label: Text(context.tr('withdrawal')),
              ),
              ButtonSegment(
                value: kTransactionRuleAppliesCredit,
                label: Text(context.tr('deposit')),
              ),
            ],
            selected: {vm.draft.appliesTo},
            onSelectionChanged: (set) =>
                set.isEmpty ? null : vm.setAppliesTo(set.first),
          ),
        ),
      ],
    );
  }
}

/// Live "matches N of M cached transactions" preview. Counts, among the
/// company's locally-cached unmatched DEBIT transactions, how many the
/// in-progress rule would match — recomputed on every criterion edit
/// (`bodyBuilder` rebuilds on the VM). The transactions stream is cached in
/// State so a criterion edit doesn't re-subscribe Drift.
///
/// Shown only for DEBIT rules: CREDIT-side criteria (`$invoice.*` etc.)
/// match a transaction against a related invoice/payment and aren't locally
/// evaluable (see `rule_evaluator.dart`). Count is over *cached* rows, so
/// it's an estimate, not an authoritative server match.
class _RuleMatchPreview extends StatefulWidget {
  const _RuleMatchPreview({required this.vm, required this.companyId});
  final TransactionRuleEditViewModel vm;
  final String companyId;

  @override
  State<_RuleMatchPreview> createState() => _RuleMatchPreviewState();
}

class _RuleMatchPreviewState extends State<_RuleMatchPreview> {
  Stream<List<BankTransaction>>? _tx;

  void _bind() {
    _tx = context.read<Services>().bankTransactions.watchPage(
      companyId: widget.companyId,
      statusIds: const {kTransactionStatusUnmatched},
      baseType: kTransactionTypeDebit,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tx == null) _bind();
  }

  @override
  void didUpdateWidget(_RuleMatchPreview old) {
    super.didUpdateWidget(old);
    if (old.companyId != widget.companyId) _bind();
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.vm.draft;
    // CREDIT-side rules aren't locally evaluable — hide the preview rather
    // than show a misleading 0.
    if (rule.appliesTo != kTransactionRuleAppliesDebit) {
      return const SizedBox.shrink();
    }
    final hasCriteria = rule.rules.any((c) => c.searchKey.isNotEmpty);
    if (!hasCriteria) return const SizedBox.shrink();

    final tokens = context.inTheme;
    return StreamBuilder<List<BankTransaction>>(
      stream: _tx,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final txs = snap.data!;
        final matched = transactionRuleMatchCount(txs, rule);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.md(context),
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: tokens.accentSoft,
            borderRadius: BorderRadius.circular(InRadii.r2),
          ),
          child: Row(
            children: [
              Icon(
                Icons.filter_alt_outlined,
                size: 18,
                color: tokens.accentInk,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('rule_matches_n_of_total', {
                    'count': '$matched',
                    'total': '${txs.length}',
                  }),
                  style: TextStyle(
                    color: tokens.accentInk,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CriteriaList extends StatelessWidget {
  const _CriteriaList({required this.vm});
  final TransactionRuleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final isCredit = vm.draft.isCredit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (vm.draft.rules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              context.tr('no_rules'),
              style: TextStyle(color: tokens.ink2),
            ),
          )
        else
          for (var i = 0; i < vm.draft.rules.length; i++)
            _CriterionRow(
              key: ValueKey('crit-$i'),
              criterion: vm.draft.rules[i],
              isCredit: isCredit,
              onEdit: () async {
                final updated = await showRuleCriterionSheet(
                  context: context,
                  initial: vm.draft.rules[i],
                  isCredit: isCredit,
                );
                if (updated != null) vm.updateCriterion(i, updated);
              },
              onRemove: () => vm.removeCriterion(i),
            ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () async {
              final added = await showRuleCriterionSheet(
                context: context,
                initial: const RuleCriterion(),
                isCredit: isCredit,
              );
              if (added != null) vm.addCriterion(added);
            },
            icon: const Icon(Icons.add),
            label: Text(context.tr('add_rule')),
          ),
        ),
      ],
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({
    super.key,
    required this.criterion,
    required this.isCredit,
    required this.onEdit,
    required this.onRemove,
  });

  final RuleCriterion criterion;
  final bool isCredit;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final searchKeyLabel = criterion.searchKey.isEmpty
        ? context.tr('field')
        : labelForSearchKey(criterion.searchKey);
    final operatorLabel = criterion.operator.isEmpty
        ? context.tr('operator')
        : labelForOperator(criterion.operator);
    final valueLabel =
        criterion.operator == kRuleOperatorIsEmpty || criterion.value.isEmpty
        ? '—'
        : isCredit
        ? labelForSearchKey(criterion.value)
        : criterion.value;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('$searchKeyLabel  $operatorLabel  $valueLabel'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(MdiIcons.circleEditOutline),
              onPressed: onEdit,
              tooltip: context.tr('edit'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
              tooltip: context.tr('remove'),
            ),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

/// Vendor assignment for a DEBIT rule's auto-converted expense. Mirrors the
/// expense-edit vendor picker (`expense_edit_identity_section.dart`) — a
/// searchable list over the vendor pages, clearable to "none".
class _VendorPicker extends StatelessWidget {
  const _VendorPicker({required this.vm});
  final TransactionRuleEditViewModel vm;

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
          onChanged: (v) => vm.setVendorId(v?.id ?? ''),
          errorText: vm.fieldErrorFor('vendor_id'),
        );
      },
    );
  }
}

/// Expense-category assignment for a DEBIT rule's auto-converted expense.
/// Categories are bundled, so `watchActive` returns the full list.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({required this.vm});
  final TransactionRuleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<List<ExpenseCategory>>(
      stream: services.expenseCategories.watchActive(companyId: vm.companyId),
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
    );
  }
}
