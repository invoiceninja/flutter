/// Re-export of the leaf at `lib/utils/combine_latest.dart`.
///
/// The implementation moved out of `lib/ui/` so `lib/data/**` can use it too —
/// `TagRepository.watchLookup` folds the `id_remap` alias table into the tag
/// stream, and `test/lint/layering_test.dart` forbids a data-layer import of
/// `lib/ui/**`. This file stays so the list-stack call sites are unchanged.
library;

export 'package:admin/utils/combine_latest.dart';
