import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/value/date.dart';

/// How much of a client's balance is late, and across how many invoices.
typedef ClientPastDue = ({Decimal amount, int count});

/// The past-due part of [client]'s balance — or **null when it cannot be
/// proven** from what is on this device.
///
/// The server has no per-client "overdue" figure, so this is worked out from
/// the locally cached invoices. A cache can be incomplete or stale, and a
/// wrong number in red under a client's balance is worse than no number, so
/// the answer is only given when all of these hold:
///
///  1. [fetchComplete] — this screen just asked the server for the client's
///     unpaid invoices and got the whole answer in one page. Without it the
///     local set can be missing an invoice that was never browsed to.
///  2. Nothing in play is mid-edit: the client row is clean, and no invoice
///     in [unpaid] is dirty or still a local `tmp_` record. A dirty invoice
///     carries totals this app stamped optimistically.
///  3. **The balances agree.** The server defines `client.balance` as the sum
///     of `balance` over the client's Sent and Partial invoices
///     (`ClientService::calculateBalance`), which is exactly what [unpaid]
///     holds. If the two sums differ, something is out of step — a stale
///     local invoice the narrowed fetch could not correct (one that has since
///     been paid is simply absent from the response, so its old row stays),
///     a stale client row, or drift in the server's running total — and
///     there is no telling which side is right.
///
/// (1) and (3) cover each other's gap. The sum check alone can be fooled:
/// with equal monthly invoices, a stale "unpaid" March and an uncached April
/// add up to the right balance and would call March overdue. The fetch brings
/// April in, the sums then disagree, and the answer is withheld.
///
/// **The amount is what is late, not what is owed on late invoices** — see
/// [lateAmountOf] for an invoice whose deposit is overdue and whose own due
/// date is not. The count is still of invoices.
///
/// What is returned is therefore *consistent with the balance shown above it*
/// rather than guaranteed current: if the client row itself is stale, both
/// are stale together, like any cached figure before a refresh.
///
/// [unpaid] must be the client's Sent and Partial invoices, not deleted,
/// archived included — `InvoiceRepository.watchUnpaidForClient`. [today] is a
/// parameter so nothing here reads a clock.
ClientPastDue? clientPastDue({
  required Client client,
  required List<Invoice> unpaid,
  required bool fetchComplete,
  required Date today,
}) {
  if (!fetchComplete) return null;
  if (client.isDirty || client.id.startsWith('tmp_')) return null;
  var total = Decimal.zero;
  for (final invoice in unpaid) {
    if (invoice.isDirty || invoice.id.startsWith('tmp_')) return null;
    total += invoice.balance;
  }
  if (total != client.balance) return null;

  var amount = Decimal.zero;
  var count = 0;
  for (final invoice in unpaid) {
    if (!invoice.isPastDueOn(today)) continue;
    amount += lateAmountOf(invoice, today);
    count++;
  }
  return (amount: amount, count: count);
}

/// How much of a past-due [invoice]'s balance is actually late as of [today].
///
/// An invoice can ask for a deposit ahead of its own due date (`partial` by
/// `partial_due_date`; the server requires that date to fall *before*
/// `due_date`). `Invoice.isPastDueOn` — and the list's Past Due pill — turn
/// on the moment the deposit's date passes, and they are right to: the
/// invoice is late. But only the **deposit** is, until the invoice's own due
/// date passes too. Counting the whole balance printed "Past Due: $10,000"
/// for a $1,000 deposit a week overdue.
///
/// So: the whole balance once the full due date has passed (or there is no
/// deposit in play); otherwise the deposit, capped at what is still owed.
Decimal lateAmountOf(Invoice invoice, Date today) => lateAmount(
  dueDate: invoice.dueDate,
  partialDueDate: invoice.partialDueDate,
  partial: invoice.partial,
  balance: invoice.balance,
  today: today,
);

/// The rule behind [lateAmountOf], on bare fields.
///
/// The dashboard's past-due rows are the server's list, not `Invoice` models,
/// and they total the same thing a client screen does. One function for both,
/// so "Past Due" on the dashboard and on the client it belongs to cannot
/// disagree.
Decimal lateAmount({
  required Date? dueDate,
  required Date? partialDueDate,
  required Decimal partial,
  required Decimal balance,
  required Date today,
}) {
  if (dueDate != null && dueDate.compareTo(today) < 0) return balance;
  if (partialDueDate == null || partial <= Decimal.zero) return balance;
  return partial < balance ? partial : balance;
}
