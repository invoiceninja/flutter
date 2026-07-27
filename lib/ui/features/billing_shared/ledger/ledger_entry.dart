import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';

/// What kind of document a [LedgerEntry] represents — drives the row icon,
/// the filter chips, and tap-through routing.
enum LedgerKind {
  invoice(EntityType.invoice),
  payment(EntityType.payment),
  credit(EntityType.credit),
  expense(EntityType.expense),
  purchaseOrder(EntityType.purchaseOrder);

  const LedgerKind(this.entityType);

  final EntityType entityType;
}

/// One row in a client / vendor ledger. [adjustment] is the signed delta
/// applied to the running balance (a debit is positive — it increases what
/// is owed; a payment / credit is negative). [runningBalance] is the balance
/// *after* this entry, computed in chronological order over the full ledger
/// (filtering rows in the UI never changes a row's balance — same as a
/// real account statement).
///
/// [isOpening] marks the synthetic genesis row (client/vendor created) — it
/// carries no entity, zero adjustment/balance, and renders without
/// tap-through (parity with admin-portal's "Client Created" anchor).
class LedgerEntry {
  const LedgerEntry({
    required this.kind,
    required this.id,
    required this.number,
    required this.date,
    required this.adjustment,
    required this.runningBalance,
    this.isOpening = false,
  });

  final LedgerKind kind;
  final String id;
  final String number;
  final Date? date;
  final Decimal adjustment;
  final Decimal runningBalance;
  final bool isOpening;
}

class _Raw {
  _Raw(
    this.kind,
    this.id,
    this.number,
    this.date,
    this.createdAt,
    this.adjustment,
  );
  final LedgerKind kind;
  final String id;
  final String number;
  final Date? date;

  /// Precise record timestamp — the deterministic tiebreak for same-`date`
  /// rows (the day-granular business `date` alone leaves same-day entries
  /// ambiguously ordered; admin-portal effectively orders by server
  /// `created_at`).
  final DateTime createdAt;
  final Decimal adjustment;
}

/// Sort key: by business `date` (the statement convention), then the precise
/// `createdAt` timestamp, then `id` for full determinism. Undated rows sort
/// oldest — they're almost always legacy / imported rows.
int _compare(_Raw a, _Raw b) {
  final ad = a.date, bd = b.date;
  if (ad != null && bd != null) {
    final c = ad.compareTo(bd);
    if (c != 0) return c;
  } else if (ad == null && bd != null) {
    return -1;
  } else if (ad != null && bd == null) {
    return 1;
  }
  final t = a.createdAt.compareTo(b.createdAt);
  if (t != 0) return t;
  return a.id.compareTo(b.id);
}

List<LedgerEntry> _assemble(List<_Raw> raws, {DateTime? openingAt}) {
  raws.sort(_compare);
  var running = Decimal.zero;
  final out = <LedgerEntry>[];
  for (final r in raws) {
    running += r.adjustment;
    out.add(
      LedgerEntry(
        kind: r.kind,
        id: r.id,
        number: r.number,
        date: r.date,
        adjustment: r.adjustment,
        runningBalance: running,
      ),
    );
  }
  // Newest first for display; running balance was computed chronologically
  // above so each row still carries its correct as-of balance.
  final display = out.reversed.toList();
  if (openingAt != null) {
    // Genesis anchor pinned to the bottom (oldest) — parity with
    // admin-portal's "Client Created" row. Zero adjustment/balance so it
    // never perturbs the running-balance math above.
    display.add(
      LedgerEntry(
        kind: LedgerKind.invoice, // unused — isOpening rows render specially
        id: '',
        number: '',
        date: Date(openingAt.year, openingAt.month, openingAt.day),
        adjustment: Decimal.zero,
        runningBalance: Decimal.zero,
        isOpening: true,
      ),
    );
  }
  return List.unmodifiable(display);
}

/// Client receivables ledger: invoices add to what's owed; payments and
/// credits reduce it. Deleted **and draft** invoices/credits are excluded —
/// a draft isn't a receivable yet, so including it would inflate the local
/// running balance away from the authoritative `client.balance` (the
/// server's own ledger only logs sent documents). This is still a
/// client-side approximation of the server ledger; the tab's summary header
/// shows the authoritative figures alongside it.
List<LedgerEntry> buildClientLedger({
  required List<Invoice> invoices,
  required List<Payment> payments,
  required List<Credit> credits,
  DateTime? openingAt,
}) {
  final raws = <_Raw>[
    for (final i in invoices)
      if (!i.isDeleted && !i.isDraft)
        _Raw(LedgerKind.invoice, i.id, i.number, i.date, i.createdAt, i.amount),
    for (final p in payments)
      if (!p.isDeleted)
        _Raw(
          LedgerKind.payment,
          p.id,
          p.number,
          p.date,
          p.createdAt,
          // Net of refunds: a refund credits the client's balance back on the
          // server (`updateBalanceAndPaidToDate($amount, -$amount)`), so
          // subtracting the gross made the running balance disagree with the
          // authoritative summary header on the same tab.
          -(p.amount - p.refunded),
        ),
    for (final c in credits)
      if (!c.isDeleted && !c.isDraft)
        _Raw(LedgerKind.credit, c.id, c.number, c.date, c.createdAt, -c.amount),
  ];
  return _assemble(raws, openingAt: openingAt);
}

/// Vendor ledger: expenses + (non-draft) purchase orders both add to spend.
/// There's no authoritative vendor ledger server-side; this is purely a
/// local chronological roll-up.
List<LedgerEntry> buildVendorLedger({
  required List<Expense> expenses,
  required List<PurchaseOrder> purchaseOrders,
  DateTime? openingAt,
}) {
  final raws = <_Raw>[
    for (final e in expenses)
      if (!e.isDeleted)
        _Raw(LedgerKind.expense, e.id, e.number, e.date, e.createdAt, e.amount),
    for (final po in purchaseOrders)
      if (!po.isDeleted && !po.isDraft)
        _Raw(
          LedgerKind.purchaseOrder,
          po.id,
          po.number,
          po.date,
          po.createdAt,
          po.amount,
        ),
  ];
  return _assemble(raws, openingAt: openingAt);
}
