import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/quote.dart';

/// What a needs-attention row's action should do once the record it names has
/// been re-read.
///
/// The dashboard's rows are a cached copy of the server's list. Between that
/// fetch and the tap an invoice can have been paid — by the client in the
/// portal, by a colleague, on another device — so an action never runs on the
/// row. It runs on the record as it is *now*, and this decides whether there is
/// still anything to act on.
enum AttentionVerdict {
  /// Still open: run the action.
  act,

  /// Settled, cancelled or deleted since the list was fetched: say so, and
  /// refresh the band so the row goes.
  resolved,

  /// Not on this device and it could not be fetched (offline): say so rather
  /// than open a screen with nothing in it.
  unavailable,
}

/// The verdict for an invoice. Null means it is neither cached nor fetchable.
AttentionVerdict invoiceVerdict(Invoice? invoice) {
  if (invoice == null) return AttentionVerdict.unavailable;
  if (invoice.isDeleted ||
      invoice.isPaid ||
      invoice.isCancelled ||
      invoice.isReversed ||
      invoice.balance <= Decimal.zero) {
    return AttentionVerdict.resolved;
  }
  return AttentionVerdict.act;
}

/// The verdict for a quote awaiting an answer: still worth a reminder only
/// while it is sent and not yet approved, converted, rejected or cancelled.
AttentionVerdict quoteVerdict(Quote? quote) {
  if (quote == null) return AttentionVerdict.unavailable;
  if (quote.isDeleted || !quote.isSent || quote.isConverted) {
    return AttentionVerdict.resolved;
  }
  return AttentionVerdict.act;
}
