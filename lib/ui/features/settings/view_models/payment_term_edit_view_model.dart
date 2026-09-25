import 'package:admin/data/models/domain/payment_term.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/payment_term_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the `/settings/payment_terms/new` + `/:id` edit screen.
/// Optimistic — `save()` lands the draft in Drift via the repo; the
/// outbox handles the server round-trip.
class PaymentTermEditViewModel extends GenericEditViewModel<PaymentTerm> {
  PaymentTermEditViewModel({
    required this.repo,
    required this.companyId,
    PaymentTerm? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: existing ?? _emptyTerm(),
         original: existing,
         companyId: companyId,
       );

  final PaymentTermRepository repo;
  final String companyId;

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.name.isNotEmpty || d.numDays > 0;
  }

  @override
  Future<SaveResult<PaymentTerm>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, term: draft);
  }

  void resetToEmpty() => reset(emptyDraft: _emptyTerm());

  void setName(String v) => updateDraft(draft.copyWith(name: v));
  void setNumDays(int v) => updateDraft(draft.copyWith(numDays: v));
}

PaymentTerm _emptyTerm() => PaymentTerm(
  id: '',
  name: '',
  numDays: 0,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);
