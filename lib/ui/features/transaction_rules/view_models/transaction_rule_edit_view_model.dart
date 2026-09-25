import 'package:admin/data/models/domain/transaction_rule.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/transaction_rule_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the transaction-rule edit/create screen.
class TransactionRuleEditViewModel
    extends GenericEditViewModel<TransactionRule> {
  TransactionRuleEditViewModel({
    required this.repo,
    required this.companyId,
    TransactionRule? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: existing ?? _emptyRule(),
         original: existing,
         companyId: companyId,
       );

  final TransactionRuleRepository repo;
  final String companyId;

  @override
  bool draftIsNonEmpty() => draft.name.isNotEmpty || draft.rules.isNotEmpty;

  @override
  Future<SaveResult<TransactionRule>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, rule: draft);
  }

  void setName(String v) => updateDraft(draft.copyWith(name: v));
  void setAppliesTo(String v) {
    // Flipping CREDIT clears DEBIT-only fields (vendor, category) since the
    // server ignores them on credit rules and leaving them populated would
    // confuse a user reading the saved row.
    var next = draft.copyWith(appliesTo: v);
    if (v == kTransactionRuleAppliesCredit) {
      next = next.copyWith(vendorId: '', categoryId: '');
    }
    updateDraft(next);
  }

  void setMatchesOnAll(bool v) => updateDraft(draft.copyWith(matchesOnAll: v));
  void setAutoConvert(bool v) => updateDraft(draft.copyWith(autoConvert: v));
  void setVendorId(String v) => updateDraft(draft.copyWith(vendorId: v));
  void setCategoryId(String v) => updateDraft(draft.copyWith(categoryId: v));

  void addCriterion(RuleCriterion c) {
    updateDraft(draft.copyWith(rules: [...draft.rules, c]));
  }

  void updateCriterion(int index, RuleCriterion c) {
    if (index < 0 || index >= draft.rules.length) return;
    final next = List<RuleCriterion>.from(draft.rules);
    next[index] = c;
    updateDraft(draft.copyWith(rules: next));
  }

  void removeCriterion(int index) {
    if (index < 0 || index >= draft.rules.length) return;
    final next = List<RuleCriterion>.from(draft.rules)..removeAt(index);
    updateDraft(draft.copyWith(rules: next));
  }
}

TransactionRule _emptyRule() => TransactionRule(
  id: '',
  name: '',
  appliesTo: kTransactionRuleAppliesDebit,
  matchesOnAll: true,
  autoConvert: false,
  vendorId: '',
  categoryId: '',
  rules: const <RuleCriterion>[],
  isDeleted: false,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
);
