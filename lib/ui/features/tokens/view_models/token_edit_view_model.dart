import 'package:admin/data/models/domain/token.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/token_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the token edit/create screen. Token edit is name-only — the
/// `token` value is server-owned (minted on create, masked thereafter).
class TokenEditViewModel extends GenericEditViewModel<Token> {
  TokenEditViewModel({
    required this.repo,
    required this.companyId,
    Token? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: existing ?? _emptyToken(),
         original: existing,
         companyId: companyId,
       );

  final TokenRepository repo;
  final String companyId;

  @override
  bool draftIsNonEmpty() => draft.name.trim().isNotEmpty;

  @override
  Future<SaveResult<Token>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, token: draft);
  }

  void setName(String v) => updateDraft(draft.copyWith(name: v));
}

Token _emptyToken() => Token(
  id: '',
  userId: '',
  token: '',
  name: '',
  isSystem: false,
  isDeleted: false,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
);
