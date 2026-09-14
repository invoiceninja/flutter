import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/dashboard/view_models/billing_pipeline_view_model.dart';

/// The cross-entity merge order for the Invoices & Quotes panel.
///
/// It has to reproduce `watchRecent`'s SQL exactly — `date DESC`, then
/// `created_at DESC` with epoch 0 first, then `id` — because merging two
/// individually-correct top-Ns and truncating is only the overall top-N when
/// both halves share one total order. `billing_recent_order_test` pins the SQL
/// side; this pins the Dart side.
void main() {
  BillingPipelineRow row(
    String id, {
    String date = '2026-09-14',
    int created = 0,
    EntityType type = EntityType.invoice,
  }) => BillingPipelineRow(
    type: type,
    id: id,
    number: id,
    clientId: 'c1',
    statusId: '1',
    date: null,
    amount: Decimal.zero,
    hasBounce: false,
    sortDate: date,
    sortCreatedAt: created,
  );

  List<String> sorted(List<BillingPipelineRow> rows) =>
      (rows.toList()..sort(compareRows)).map((r) => r.id).toList();

  test('the later date leads, whichever entity it is', () {
    expect(
      sorted([
        row('older', date: '2026-09-01'),
        row('newer', date: '2026-09-14', type: EntityType.quote),
      ]),
      ['newer', 'older'],
    );
  });

  test('a blank date sorts last, as the non-null TEXT column does', () {
    // The Drift column is non-null TEXT defaulting to `''`, which sorts last
    // under DESC. The domain models carry `Date?`, so the projection maps null
    // to `''` and the two agree.
    expect(sorted([row('nodate', date: ''), row('dated')]), [
      'dated',
      'nodate',
    ]);
  });

  test('created_at breaks a date tie, newest first', () {
    expect(sorted([row('old', created: 100), row('new', created: 900)]), [
      'new',
      'old',
    ]);
  });

  test('an unsynced row (created_at == 0) LEADS', () {
    // The trap: `b.createdAt.compareTo(a.createdAt)` would sort the invoice the
    // user just created OFFLINE to the bottom, and the five-row window would
    // then drop it — on the panel that exists to show recent work.
    expect(sorted([row('synced', created: 500), row('local')]), [
      'local',
      'synced',
    ]);
  });

  test('two unsynced rows still order deterministically, by id', () {
    expect(sorted([row('b'), row('a')]), ['a', 'b']);
  });

  test('id is the final backstop across entities', () {
    // Two rows can tie on both keys — a bulk import shares a date and a
    // whole-second `created_at`. Without a total order the merged list could
    // reshuffle between emissions.
    final rows = [
      row('q1', created: 100, type: EntityType.quote),
      row('i1', created: 100),
    ];
    expect(sorted(rows), ['i1', 'q1']);
    expect(sorted(rows.reversed.toList()), ['i1', 'q1']);
  });
}
