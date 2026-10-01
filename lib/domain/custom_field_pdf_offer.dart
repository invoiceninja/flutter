import 'package:admin/data/static/pdf_catalogs.dart';

/// A custom field that just got a label and could be printed on the PDF
/// (React #3360). Only the three kinds a design actually prints: invoice
/// fields (invoice details), product fields (line-item columns) and custom
/// surcharges (totals).
class PdfFieldOffer {
  const PdfFieldOffer({
    required this.customKey,
    required this.label,
    required this.section,
    required this.variable,
  });

  /// `invoice1` / `product3` / `surcharge2`.
  final String customKey;

  /// The label the user gave it.
  final String label;

  /// The `pdf_variables` section it goes in ([PdfVariableSection]).
  final String section;

  /// The design token it adds, e.g. `$invoice.custom1`.
  final String variable;
}

const _kOfferKinds = <(String prefix, String section, String Function(int))>[
  ('invoice', PdfVariableSection.invoiceDetails, _invoiceVar),
  ('product', PdfVariableSection.productColumns, _productVar),
  ('surcharge', PdfVariableSection.totalColumns, _surchargeVar),
];

String _invoiceVar(int n) => '\$invoice.custom$n';
String _productVar(int n) => '\$product.product$n';
String _surchargeVar(int n) => '\$custom_surcharge$n';

/// The label part of a stored custom field (`Label|type|options`).
String _labelOf(Map<String, String> fields, String key) =>
    (fields[key] ?? '').split('|').first.trim();

/// Fields that had no label in [before] and have one in [after] — the ones
/// worth offering to print. A field that was already labelled is the user's
/// existing design decision, printed or not, and is left alone.
List<PdfFieldOffer> newlyLabelledPdfFields({
  required Map<String, String> before,
  required Map<String, String> after,
}) => [
  for (final (prefix, section, variableFor) in _kOfferKinds)
    for (var n = 1; n <= 4; n++)
      if (_labelOf(before, '$prefix$n').isEmpty &&
          _labelOf(after, '$prefix$n').isNotEmpty)
        PdfFieldOffer(
          customKey: '$prefix$n',
          label: _labelOf(after, '$prefix$n'),
          section: section,
          variable: variableFor(n),
        ),
];

/// [current] (`settings.pdf_variables`) with each [offers] variable appended
/// to its section — after whatever is already there, so the design keeps its
/// order. A section with no saved list starts from the catalog default the
/// server prints, so adding one field doesn't replace every default column
/// with that single field. Already-present variables are skipped.
Map<String, List<String>> withPdfFields(
  Map<String, List<String>>? current,
  Iterable<PdfFieldOffer> offers,
) {
  final next = <String, List<String>>{
    for (final e in (current ?? const <String, List<String>>{}).entries)
      e.key: List<String>.of(e.value),
  };
  for (final o in offers) {
    final list = next.putIfAbsent(
      o.section,
      () => List<String>.of(
        kPdfVariableSections[o.section]?.defaultSelected ?? const <String>[],
      ),
    );
    if (!list.contains(o.variable)) list.add(o.variable);
  }
  return next;
}
