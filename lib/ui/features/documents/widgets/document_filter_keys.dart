import 'package:admin/ui/core/list/search/filter_key.dart';

/// The filter keys the Documents search field offers: none.
///
/// Not even `is:` — the server never archives or soft-deletes a document, so
/// every file is active and an `is:archived` chip could only ever empty the
/// list. Free text searches the file name, which is what
/// `DocumentFilters::filter` matches on the server. (`type:` is left out on
/// purpose: `DocumentFilters::type` ANDs its values, so `pdf,image` matches
/// nothing — BACKEND.md § Documents list.)
List<FilterKey> buildDocumentFilterKeys() => const <FilterKey>[];
