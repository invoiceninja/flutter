/// Country-aware postal address formatting.
///
/// Mirrors the server's `EntityPresenter::cityStateZip` /
/// `ClientPresenter::address` (the same logic that renders addresses on
/// PDFs), so the in-app display agrees with the printed document. The one
/// country-specific variation the field set (city / state / postal code)
/// exposes is postal-code placement, driven by the statics country's
/// `swap_postal_code` flag:
///
/// - normal:               `City, State PostalCode`
/// - `swap_postal_code`:   `PostalCode City, State`
///
/// This is intentionally the server's own model rather than a generic
/// address-format library (e.g. libaddressinput), which would diverge from
/// the PDF the customer actually receives.
library;

/// The city / state / postal-code line, ordered for the country.
///
/// Empty parts are dropped cleanly (no stray separators or leading/trailing
/// spaces, unlike the raw server concatenation). Returns `''` when all three
/// parts are empty.
String cityStateZip({
  required String city,
  required String state,
  required String postalCode,
  required bool swapPostalCode,
}) {
  var str = city;
  if (state.isNotEmpty) {
    if (str.isNotEmpty) str += ', ';
    str += state;
  }
  if (postalCode.isEmpty) return str;
  if (str.isEmpty) return postalCode;
  return swapPostalCode ? '$postalCode $str' : '$str $postalCode';
}

/// The full set of address lines in country order:
/// `address1`, `address2`, the [cityStateZip] line, then `countryName`.
///
/// Only non-empty lines are returned. Pass an empty [countryName] to omit the
/// country line (callers typically suppress it when it equals the company's
/// own country).
List<String> formatAddressLines({
  required String address1,
  required String address2,
  required String city,
  required String state,
  required String postalCode,
  required bool swapPostalCode,
  String countryName = '',
}) {
  final line = cityStateZip(
    city: city,
    state: state,
    postalCode: postalCode,
    swapPostalCode: swapPostalCode,
  );
  return <String>[
    if (address1.isNotEmpty) address1,
    if (address2.isNotEmpty) address2,
    if (line.isNotEmpty) line,
    if (countryName.isNotEmpty) countryName,
  ];
}
