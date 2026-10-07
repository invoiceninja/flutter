import 'package:flutter/foundation.dart';

import 'package:admin/data/models/value/date.dart';

/// Which side of its deadline a document is on.
enum BillingDocDueState { late, today, upcoming }

/// Where a billing document stands against the date it is held to — an
/// invoice's due date, a quote's valid-until.
///
/// A count of days rather than a date: the date is already in the header, and
/// what a user reads the standing card for is how long is left, or how late it
/// is.
@immutable
class BillingDocDueNote {
  const BillingDocDueNote(this.state, this.days);

  final BillingDocDueState state;

  /// Whole days between the deadline and the day asked about — always
  /// positive, and 0 for [BillingDocDueState.today].
  final int days;

  bool get isLate => state == BillingDocDueState.late;

  @override
  bool operator ==(Object other) =>
      other is BillingDocDueNote && other.state == state && other.days == days;

  @override
  int get hashCode => Object.hash(state, days);

  @override
  String toString() => 'BillingDocDueNote(${state.name}, $days)';
}

/// The note for a deadline of [due], read on [today].
///
/// Null — and so no line at all — when there is no date, or when the document
/// is not [isOpen]: a paid invoice is not "12 days overdue", and a draft has
/// not been sent to anyone who could be late. What counts as open is each
/// document's own rule, so the caller supplies it.
///
/// [today] is a parameter so this can be tested either side of midnight; a
/// screen passes `Date.today()`.
BillingDocDueNote? billingDocDueNote({
  required Date? due,
  required Date today,
  required bool isOpen,
}) {
  if (!isOpen || due == null) return null;
  final daysPast = today.differenceInDays(due);
  if (daysPast > 0) return BillingDocDueNote(BillingDocDueState.late, daysPast);
  if (daysPast == 0) {
    return const BillingDocDueNote(BillingDocDueState.today, 0);
  }
  return BillingDocDueNote(BillingDocDueState.upcoming, -daysPast);
}
