import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// Status pill rendered next to invoices / quotes / payments.
///
/// The overdue variant inlines `" · 3d"` inside the same pill so we don't end
/// up with two adjacent chips fighting for attention.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.tone, required this.label});

  final StatusTone tone;
  final String label;

  /// Invoice status_id → tone. Status IDs from `EntityStatus` in
  /// admin-portal (`lib/data/models/static/invoice_status_model.dart`).
  static StatusTone toneForInvoiceStatus(int statusId, {bool overdue = false}) {
    if (overdue) return StatusTone.overdue;
    switch (statusId) {
      case 4:
        return StatusTone.paid;
      case 3:
        return StatusTone.partial;
      case 2:
        return StatusTone.sent;
      case 1:
      default:
        return StatusTone.draft;
    }
  }

  static StatusTone toneForQuoteStatus(int statusId, {bool expired = false}) {
    if (expired) return StatusTone.overdue;
    switch (statusId) {
      case 4:
        return StatusTone.paid;
      case 5: // rejected — negative terminal state (matches QuoteStatusPill)
        return StatusTone.overdue;
      // cancelled — inert, so the muted tone. `StatusTone` has no `ink3`, so
      // this is as close as the badge palette gets to `QuoteStatusPill`'s
      // cancelled colour; identical in the light themes, marginally lighter in
      // dark. Spelled out rather than left to `default` so the map reads as
      // complete.
      case 6:
        return StatusTone.draft;
      case 3:
        return StatusTone.partial;
      case 2:
        return StatusTone.sent;
      case 1:
      default:
        return StatusTone.draft;
    }
  }

  /// Localized label for an invoice status id, with overdue taking precedence.
  static String invoiceStatusLabel(
    BuildContext context,
    int statusId, {
    required bool overdue,
  }) {
    if (overdue) return context.tr('overdue');
    switch (statusId) {
      case 4:
        return context.tr('paid');
      case 3:
        return context.tr('partial');
      case 2:
        return context.tr('sent');
      case 1:
      default:
        return context.tr('draft');
    }
  }

  /// Localized label for a quote status id. Expiry is layered on top by the
  /// caller (it overrides the status), not resolved here.
  static String quoteStatusLabel(BuildContext context, int statusId) {
    // Quote wire status_id: 1 draft, 2 sent, 3 approved, 4 converted,
    // 5 rejected, 6 cancelled (see quote_status.dart). The earlier mapping was
    // shifted (3→"partial", 4→"approved", 5→"converted") — corrected here.
    // Note this int-keyed map is independent of `QuoteStatusPill`: a missing
    // arm here reads "Draft" rather than failing.
    switch (statusId) {
      case 6:
        return context.tr('cancelled');
      case 5:
        return context.tr('rejected');
      case 4:
        return context.tr('converted');
      case 3:
        return context.tr('approved');
      case 2:
        return context.tr('sent');
      case 1:
      default:
        return context.tr('draft');
    }
  }

  /// Resolves a payment status id to a `(localizedLabel, badgeTone)` pair.
  static (String, StatusTone) paymentStatus(
    BuildContext context,
    int statusId,
  ) {
    switch (statusId) {
      case 4:
        return (context.tr('completed'), StatusTone.paid);
      case 5:
        return (context.tr('partially_refunded'), StatusTone.partial);
      case 6:
        return (context.tr('refunded'), StatusTone.overdue);
      case 3:
        return (context.tr('failed'), StatusTone.overdue);
      case 2:
        return (context.tr('voided'), StatusTone.draft);
      case 1:
      default:
        return (context.tr('pending'), StatusTone.draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (bg, fg) = _resolve(tokens, tone);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: InSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(InRadii.r1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  (Color bg, Color fg) _resolve(InTheme t, StatusTone tone) {
    switch (tone) {
      case StatusTone.paid:
        return (t.paidSoft, t.paid);
      case StatusTone.overdue:
        return (t.overdueSoft, t.overdue);
      case StatusTone.draft:
        return (t.draftSoft, t.draft);
      case StatusTone.sent:
        return (t.sentSoft, t.sent);
      case StatusTone.partial:
        return (t.partialSoft, t.partial);
    }
  }
}

enum StatusTone { paid, overdue, draft, sent, partial }
