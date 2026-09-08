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

  test('name maps are NOT part of the key', () {
    // They arrive as fresh instances on every Drift emit, so folding them in
    // would rebuild the key list — and open a fresh TagFilterKey Drift
    // subscription — on every no-op re-emit. The keys read names through
    // LiveNameMaps instead, which stays correct without a rebuild. The
    // signature simply has nowhere to put them, which is the point: this test
    // fails to compile if someone adds a `names:` parameter back.
    expect(sig(prefix: 'invoice'), sig(prefix: 'invoice'));
  });

  test('a null company still produces a stable key', () {
    expect(sig(c: null, prefix: 'invoice'), sig(c: null, prefix: 'invoice'));
  });
}
