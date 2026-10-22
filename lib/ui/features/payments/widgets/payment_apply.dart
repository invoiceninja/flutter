import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';

/// Applies [payment]'s unapplied funds to the client's oldest unpaid invoice.
///
/// **It says which invoice before it does it.** This used to be a button on
/// the payment screen that allocated the money the moment it was pressed, to
/// an invoice the user was never shown — and an allocation cannot be taken
/// back from this app. The invoice is now looked up first and named in a
/// dialog with what is owed on it and what will be applied; the money moves
/// when that is confirmed. Because it opens its own dialog, the action that
/// calls this is deliberately not `confirm: true`.
///
/// An explicit "apply to a chosen invoice" picker is still not built; until
/// then, allocating to a specific invoice happens on the create form.
Future<void> applyPaymentToOldestInvoice(
  BuildContext context,
  Services services,
  String companyId,
  Payment payment,
) async {
  if (!requireSynced(context, payment.id)) return;
  try {
    final target = await oldestUnpaidInvoice(
      services.invoices,
      companyId: companyId,
      clientId: payment.clientId,
    );
    if (!context.mounted) return;
    if (target == null) {
      Notify.error(context, context.tr('no_unpaid_invoices'));
      return;
    }
    final amount = payment.unapplied < target.balance
        ? payment.unapplied
        : target.balance;
    final formatter = await services.formatterFor(companyId);
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ApplyPaymentDialog(
        invoice: target,
        amount: amount,
        currencyId: payment.currencyId,
        formatter: formatter,
      ),
    );
    if (confirmed != true) return;
    await services.payments.apply(
      companyId: companyId,
      paymentId: payment.id,
      allocations: [
        // `_id` is a client-row identifier the server ignores (React sends a
        // fresh uuid here); `invoice_id` + `amount` are the fields it reads.
        <String, dynamic>{
          '_id': const Uuid().v4(),
          'invoice_id': target.id,
          'amount': amount.toString(),
        },
      ],
    );
    if (context.mounted) {
      Notify.success(context, context.tr('applied_payment'));
    }
  } on StaleApplyTargetsException {
    // Not "no unpaid invoices": an unchecked one may well be unpaid, and the
    // re-fetches corrected the cache, so trying again gets past them.
    if (context.mounted) {
      Notify.error(context, context.tr('an_error_occurred_try_again'));
    }
  } on CompanySwitchedException {
    // The company changed under the prefetch. Benign — the payment belongs to
    // the workspace the user just left.
    return;
  } catch (e) {
    // `ensurePageLoaded` is a real network round-trip, and offline it throws
    // out of a tap handler that discards the future — the tile would simply
    // look dead. A money action must say when it did not happen.
    // A translated title, with what went wrong beneath it — never the raw
    // exception as the headline.
    if (context.mounted) {
      Notify.error(context, context.tr('an_error_occurred'), error: e);
    }
  }
}

/// How many cached winners [oldestUnpaidInvoice] re-checks against the server
/// before it gives up. Each one it re-fetches is corrected in the cache, so a
/// second tap starts past them.
const int _kMaxTargetChecks = 3;

/// [oldestUnpaidInvoice] ran out of re-checks with candidates still unchecked:
/// every one it looked at had been paid since it was cached. Distinct from
/// "none" — there may well be an unpaid invoice further down.
@visibleForTesting
class StaleApplyTargetsException implements Exception {
  const StaleApplyTargetsException();
}

/// The client's oldest invoice that money can be applied to, re-read from the
/// server so its balance is current; null when there is none.
///
/// Two things made the old pick wrong:
///
/// - **The fetch was the client's newest page of any status.** A client with
///   fifty newer invoices never had the oldest unpaid one in the cache, so the
///   "oldest" was whatever old-enough invoice happened to be there. It now asks
///   for the client's unpaid invoices, oldest first (`client_status`, `sort` —
///   a narrowed fetch, so it neither reads nor advances the list's cursor).
///   Still `ensurePageLoaded`, not `ensureUnpaidForClientLoaded`: that one is
///   newest-first too, and swallows the error this action has to report.
/// - **The pick reads the whole local cache**, which can hold an invoice that
///   was paid since it was cached. So the winner is re-fetched
///   ([InvoiceRepository.refreshByIds]), re-read and re-filtered; one that no
///   longer qualifies yields to the next, up to [_kMaxTargetChecks] times;
///   past that, with candidates left, it throws [StaleApplyTargetsException]
///   rather than claim there are none. `refreshByIds` swallows errors, so a
///   failed re-fetch keeps the cached balance — the server still validates
///   the payment.
@visibleForTesting
Future<Invoice?> oldestUnpaidInvoice(
  InvoiceRepository invoices, {
  required String companyId,
  required String clientId,
}) async {
  // Make sure the client's invoices are in Drift before reading the local
  // cache. Without this, a user landing on the payment before ever opening
  // the invoices list would be told there is nothing unpaid when the server
  // has plenty.
  await invoices.ensurePageLoaded(
    companyId: companyId,
    page: 1,
    extraFilters: {
      'client_id': {clientId},
      // Sent + Partial, server-side — the oldest of them first, so the page
      // holds the invoice this is looking for.
      'client_status': const {'unpaid'},
      'sort': const {'date|asc'},
    },
  );
  final cached = await invoices
      .watchForClient(companyId: companyId, clientId: clientId)
      .first;
  final candidates = cached.where(_isApplyTarget).toList()
    ..sort((a, b) {
      final ad = a.date?.toIso() ?? '';
      final bd = b.date?.toIso() ?? '';
      return ad.compareTo(bd);
    });
  for (final candidate in candidates.take(_kMaxTargetChecks)) {
    await invoices.refreshByIds(companyId: companyId, ids: [candidate.id]);
    final current = await invoices
        .watchByRealId(companyId: companyId, id: candidate.id)
        .first;
    if (current != null && _isApplyTarget(current)) return current;
  }
  if (candidates.length > _kMaxTargetChecks) {
    throw const StaleApplyTargetsException();
  }
  return null;
}

/// Drafts and archived invoices are NOT targets: the server's `applyPayment`
/// calls `markSent()` first, so applying to a draft would silently send AND
/// pay it. Mirrors the manual picker's filter in
/// `payment_allocations_section.dart`.
bool _isApplyTarget(Invoice i) =>
    i.balance > Decimal.zero &&
    !i.isDeleted &&
    !i.isDraft &&
    i.archivedAt == null;

/// Names the invoice, what is owed on it and what will be applied — label and
/// value pairs rather than a sentence, so there is no word order for a
/// translation to get wrong.
class _ApplyPaymentDialog extends StatelessWidget {
  const _ApplyPaymentDialog({
    required this.invoice,
    required this.amount,
    required this.currencyId,
    required this.formatter,
  });

  final Invoice invoice;
  final Decimal amount;
  final String currencyId;
  final Formatter formatter;

  @override
  Widget build(BuildContext context) {
    String money(Decimal value) {
      final text = formatter.money(value, clientCurrencyId: currencyId);
      return text.isEmpty ? value.toString() : text;
    }

    final date = invoice.date;
    return AlertDialog(
      title: Text(context.tr('apply_payment')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Line(
              label: context.tr('invoice'),
              value: invoice.number.isEmpty
                  ? context.tr('no_name_fallback')
                  : '#${invoice.number}',
            ),
            if (date != null)
              _Line(
                label: context.tr('date'),
                value: formatter.date(date.toIso()),
              ),
            _Line(
              label: context.tr('balance_due'),
              value: money(invoice.balance),
            ),
            _Line(
              label: context.tr('amount'),
              value: money(amount),
              strong: true,
            ),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          // The safe action takes focus, as in the shared confirm dialog: a
          // stray Enter must not be what moves the money.
          autofocus: true,
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('apply'),
          autofocus: false,
          showEnterHint: false,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink2),
            ),
          ),
          const SizedBox(width: InSpacing.sm),
          LtrText(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(
                  color: tokens.ink,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                )
                .merge(moneyTextStyle()),
          ),
        ],
      ),
    );
  }
}
