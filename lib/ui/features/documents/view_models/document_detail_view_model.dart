import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';

/// State for the read-only document record screen. No derived state — an
/// alias of [GenericDetailViewModel], like `ExpenseCategoryDetailViewModel`.
typedef DocumentDetailViewModel = GenericDetailViewModel<DocumentRecord>;
