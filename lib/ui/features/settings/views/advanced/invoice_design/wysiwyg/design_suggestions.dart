import 'package:admin/data/models/domain/design.dart';

/// Something about a layout worth a second look. Never an error: a design
/// with any of these saves and prints.
enum DesignSuggestion {
  /// No products table: the document would not list what is being billed.
  noLineItems('suggestion_no_line_items', fixWithBlock: 'table'),

  /// No totals block: no amount due — and no paid stamp either, which the
  /// server anchors to the totals (or failing that the table).
  noTotals('suggestion_no_totals', fixWithBlock: 'total'),

  /// More than one totals block.
  twoTotals('suggestion_two_totals'),

  /// A logo block on a company that has not uploaded a logo.
  noCompanyLogo('suggestion_no_company_logo');

  const DesignSuggestion(this.messageKey, {this.fixWithBlock});

  final String messageKey;

  /// The block type that settles it by being added, when one does.
  final String? fixWithBlock;
}

/// What is worth pointing out about [blocks]. An empty page has nothing to
/// say — it cannot be saved at all.
List<DesignSuggestion> designSuggestions(
  List<DesignBlock> blocks, {
  required bool companyHasLogo,
}) {
  if (blocks.isEmpty) return const [];
  int count(String type) => blocks.where((b) => b.type == type).length;
  final usesCompanyLogo = blocks.any(
    (b) =>
        b.type == 'logo' ||
        (b.type == 'image' &&
            (b.properties['source'] as String?)?.trim() == r'$company.logo'),
  );
  return [
    if (count('table') == 0) DesignSuggestion.noLineItems,
    if (count('total') == 0) DesignSuggestion.noTotals,
    if (count('total') > 1) DesignSuggestion.twoTotals,
    if (usesCompanyLogo && !companyHasLogo) DesignSuggestion.noCompanyLogo,
  ];
}
