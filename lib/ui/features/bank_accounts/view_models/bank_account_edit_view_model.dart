import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/bank_account_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the `/settings/bank_accounts/new` + `/:id/edit` screen.
class BankAccountEditViewModel extends GenericEditViewModel<BankAccount> {
  BankAccountEditViewModel({
    required this.repo,
    required this.companyId,
    BankAccount? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: existing ?? _emptyAccount(),
         original: existing,
         companyId: companyId,
       );

  final BankAccountRepository repo;
  final String companyId;

  @override
  bool draftIsNonEmpty() => draft.name.isNotEmpty;

  @override
  Future<SaveResult<BankAccount>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, account: draft);
  }

  void setName(String v) => updateDraft(draft.copyWith(name: v));
  void setFromDate(Date? v) => updateDraft(draft.copyWith(fromDate: v));
  void setAutoSync(bool v) => updateDraft(draft.copyWith(autoSync: v));
  void setCurrency(String v) => updateDraft(draft.copyWith(currency: v));
  void setType(String v) => updateDraft(draft.copyWith(type: v));
}

BankAccount _emptyAccount() => BankAccount(
  id: '',
  name: '',
  status: '',
  type: '',
  provider: '',
  balance: Decimal.zero,
  currency: '',
  fromDate: null,
  autoSync: false,
  disabledUpstream: false,
  integrationType: '',
  nordigenInstitutionId: '',
  isDeleted: false,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
);
