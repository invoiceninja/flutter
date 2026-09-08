import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/ui/core/list/search/entity_token_search_field.dart';

/// `filterKeySignature` is the cache key for an entity list's `FilterKey`s,
/// and the whole bug surface of `EntityTokenSearchField`.
///
/// Both directions cost something real. Miss an input and the keys go stale —
/// the filter menu keeps showing a custom field's old label after a settings
/// change. Include something that churns and every Drift re-emit rebuilds the
/// key list, which leaks one live `TagFilterKey` Drift query per rebuild (that
/// subscription opens in its constructor). Live name maps are the churning
/// input, and are deliberately excluded.
///
/// The *absence* of name maps from the key is a compile-time fact — the
/// function has no `names` parameter — so there is nothing here to assert
/// about it; a test comparing one call with itself would pass for every
/// possible implementation. It is stated in `filterKeySignature`'s own doc
/// instead.
///
/// Tested directly because the field itself never settles under
/// `pumpAndSettle` — its `OverlayPortal` and focus-driven subscriptions keep a
/// frame pending — which is the same reason `token_search_field_test` unit-
/// tests the parser rather than pumping the widget.
void main() {
  const company = Company(
    customFields: {'invoice1': 'Region|singleline', 'client1': 'Tier|dropdown'},
  );

  String sig({
    String companyId = 'co',
    Company? c = company,
    String? prefix,
    String extra = '',
  }) => filterKeySignature(
    companyId: companyId,
    company: c,
    customFieldPrefix: prefix,
    extra: extra,
  );

  test('a different company is a different key', () {
    expect(sig(companyId: 'a'), isNot(sig(companyId: 'b')));
  });

  test('renaming a watched custom-field slot changes the key', () {
    expect(
      sig(prefix: 'invoice'),
      isNot(
        sig(
          prefix: 'invoice',
          c: const Company(customFields: {'invoice1': 'Zone|singleline'}),
        ),
      ),
    );
  });

  test(
    'the slot prefix is honoured — quotes read invoice1..4, not quote1..4',
    () {
      // Quotes, credits, purchase orders and recurring invoices all share
      // Invoice Ninja's `invoice1..4` slots. Passing the entity's own name would
      // silently watch four slots nobody configures, so a real label change
      // would never invalidate the cache.
      expect(sig(prefix: 'invoice'), isNot(sig(prefix: 'quote')));
      expect(sig(prefix: 'quote'), sig(prefix: 'purchase_order'));
    },
  );

  test('no prefix means custom-field labels do not shape the key', () {
    expect(
      sig(),
      sig(c: const Company(customFields: {'invoice1': 'Anything|singleline'})),
    );
  });

  test(
    'the extra signature participates (Products gates on trackInventory)',
    () {
      expect(sig(extra: 'true'), isNot(sig(extra: 'false')));
    },
  );

  test('a null company drops the label half of the key without throwing', () {
    // Reached on the first frame, before the company stream emits. The prefix
    // must stop mattering — otherwise two entities sharing a companyId would
    // collide, or the key would churn once the company arrives.
    expect(sig(c: null, prefix: 'invoice'), sig(c: null, prefix: 'product'));
    expect(sig(c: null, prefix: 'invoice'), sig(c: null));
    expect(sig(c: null, prefix: 'invoice'), isNot(sig(prefix: 'invoice')));
  });
}
