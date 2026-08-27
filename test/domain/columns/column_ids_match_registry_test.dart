import 'package:flutter_test/flutter_test.dart';

// The id sets + `*FieldIds` arrive through these registries' re-export of
// `lib/domain/columns/ids/*` — which is itself part of the contract here: UI
// call sites must keep resolving them from the registry import they already
// have, so moving the constants stayed source-compatible.
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/domain/columns/vendor_columns.dart';

/// `ClientDao` / `VendorDao` guard `_sortExpression` on "is this a known column
/// id at all", and they can't ask the registry: `clientColumnsById` is a map of
/// `ColumnDefinition`s carrying `Widget Function(...) cellBuilder`, so importing
/// it from the data layer drags the whole UI graph into every data-layer compile
/// (that was a 917-file import cycle — see `test/lint/layering_test.dart`).
///
/// So the id set lives in a leaf the DAO can import, and this test is what keeps
/// the two honest. Without it the failure is silent in the direction that
/// matters: add a column to `kAllClientColumns` and forget the leaf, and the new
/// header renders fine but sorting by it degrades to name-order in release —
/// the DAO's guard rejects an id it has never heard of.
void main() {
  test('kClientColumnIds matches the client column registry', () {
    expect(
      kClientColumnIds,
      equals(clientColumnsById.keys.toSet()),
      reason:
          'lib/domain/columns/ids/client_column_ids.dart has drifted from '
          'kAllClientColumns. Add the id to BOTH, or remove it from both.',
    );
  });

  test('kVendorColumnIds matches the vendor column registry', () {
    expect(
      kVendorColumnIds,
      equals(vendorColumnsById.keys.toSet()),
      reason:
          'lib/domain/columns/ids/vendor_column_ids.dart has drifted from '
          'kAllVendorColumns. Add the id to BOTH, or remove it from both.',
    );
  });

  test('every id set entry is a non-empty wire id', () {
    for (final id in {...kClientColumnIds, ...kVendorColumnIds}) {
      expect(id, isNotEmpty);
      expect(
        id,
        isNot(contains(' ')),
        reason: 'column ids are snake_case wire strings',
      );
    }
  });

  test(
    'VendorFieldIds.currencyId is deliberately absent from kVendorColumnIds',
    () {
      // It is a wire field with no column in `kAllVendorColumns`, so the
      // `vendorColumnsById.containsKey` guard this set replaced already
      // rejected it. Pinned so a future "the set looks incomplete" cleanup
      // doesn't quietly widen what VendorDao will sort by.
      expect(kVendorColumnIds, isNot(contains(VendorFieldIds.currencyId)));
      expect(
        vendorColumnsById.keys,
        isNot(contains(VendorFieldIds.currencyId)),
      );
    },
  );
}
