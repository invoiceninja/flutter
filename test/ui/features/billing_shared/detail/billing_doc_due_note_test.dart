import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_due_note.dart';

/// `billingDocDueNote` is pure and takes its "today", so every case here is
/// exact — nothing depends on the day the suite runs.
void main() {
  const today = Date(2026, 3, 15);

  BillingDocDueNote? note(Date? due, {bool isOpen = true}) =>
      billingDocDueNote(due: due, today: today, isOpen: isOpen);

  test('a deadline behind today is late, by whole days', () {
    expect(
      note(const Date(2026, 3, 3)),
      const BillingDocDueNote(BillingDocDueState.late, 12),
    );
    expect(
      note(const Date(2026, 3, 14)),
      const BillingDocDueNote(BillingDocDueState.late, 1),
      reason: 'yesterday is one day late, not zero',
    );
  });

  test('the deadline day itself is "today" — not late, not ahead', () {
    final n = note(today)!;
    expect(n.state, BillingDocDueState.today);
    expect(n.days, 0);
    expect(n.isLate, isFalse);
  });

  test('a deadline ahead of today counts the days left', () {
    expect(
      note(const Date(2026, 3, 20)),
      const BillingDocDueNote(BillingDocDueState.upcoming, 5),
    );
    expect(
      note(const Date(2026, 3, 16)),
      const BillingDocDueNote(BillingDocDueState.upcoming, 1),
    );
  });

  test('a count across a spring-forward is not a day short', () {
    // Local midnights differ by 23 h across the changeover; the count is
    // taken in UTC date-space so it does not depend on the machine's zone.
    expect(
      billingDocDueNote(
        due: const Date(2026, 3, 1),
        today: const Date(2026, 4, 1),
        isOpen: true,
      ),
      const BillingDocDueNote(BillingDocDueState.late, 31),
    );
  });

  test('no date, no note', () {
    expect(note(null), isNull);
  });

  test('a document that is not waiting on its date has no note at all', () {
    // A paid invoice is not "12 days overdue"; a draft has been sent to
    // nobody who could be late.
    expect(note(const Date(2026, 3, 3), isOpen: false), isNull);
    expect(note(const Date(2026, 3, 20), isOpen: false), isNull);
    expect(note(today, isOpen: false), isNull);
  });
}
