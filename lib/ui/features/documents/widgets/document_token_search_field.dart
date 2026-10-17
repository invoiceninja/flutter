import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:admin/ui/features/documents/view_models/document_list_view_model.dart';
import 'package:admin/ui/features/documents/widgets/document_filter_keys.dart';

/// Thin wrapper wiring [TokenSearchField] for the Documents list.
///
/// The one list whose hint is a plain "Search Documents" rather than the
/// shared "Search or try is:archived": it has no `is:` key to advertise
/// (see [buildDocumentFilterKeys]), so that hint would be a lie —
/// `search_hint_key_convention_test` exempts it by name.
class DocumentTokenSearchField extends StatelessWidget {
  const DocumentTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final DocumentListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return TokenSearchField(
      vm: vm,
      filterKeys: buildDocumentFilterKeys(),
      wide: wide,
      hintKey: 'search_documents',
    );
  }
}
