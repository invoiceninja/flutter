import 'package:admin/data/models/domain/activity.dart';

/// Priority order for naming the **document** an activity row is about.
///
/// Two consumers, both in `activity_record_row.dart`: the source label on a
/// note's meta line ([activityNoteSourceRef]) and the record the row itself
/// opens ([activityRowTargetRef]).
///
/// Two deliberate departures from the server's own `harvestNoteEntities` list:
///
/// `client` — and `vendor` — are **absent**. `ActivityController::note()`
/// stamps `client_id` alongside the document id for almost every entity, so
/// leaving it in made a comment filed on an invoice — read on that same
/// invoice — print the client's name, which is already in the header and is not
/// the record the note was filed against. The same omission is what keeps a
/// *row target* honest: on a party's own tab the party is the host, and on a
/// document's tab the detail header already carries a cued link to it, so a
/// party fallback would put an identical chevron on every row of the screen.
/// (`activityDeepLinkTarget` does fall back to the party, because the global
/// `/activity` feed has no host and no other way to make a client-created row
/// reachable.)
///
/// `purchase_order` and `recurring_expense` sort **before** `expense`, because
/// `note()` writes `$activity->expense_id = $entity->id` for both of them — the
/// document's own id in the expense column. The two tables have independent
/// auto-increment ids, so that frequently resolves to a real but unrelated
/// expense, and a PO comment would be labelled with its number.
///
/// Ordering alone does **not** cover those two on their *own* detail screen —
/// see [kExpenseIdAliasHosts].
const List<String> kActivityDocumentTokens = [
  'invoice',
  'quote',
  'credit',
  'payment',
  'task',
  'purchase_order',
  'recurring_invoice',
  'recurring_expense',
  'expense',
];

/// Hosts whose own id `ActivityController::note()` *also* writes into
/// `activities.expense_id` (`ActivityController.php`, the `PurchaseOrder` and
/// `RecurringExpense` cases both do `$activity->expense_id = $entity->id`).
///
/// Sorting these ahead of `expense` in [kActivityDocumentTokens] is enough
/// everywhere the note is read from *another* record's feed — the document's
/// own token matches first. It is not enough on the document's own screen,
/// where that token is skipped as the host and the loop falls straight through
/// to the aliased `expense` ref. There the ref is never a real relation, only
/// the id collision, so it is dropped outright.
///
/// Not a general "skip the parent" rule: `Credit` copies `$entity->invoice_id`,
/// the credit's *real* invoice, so a credit's comment naming that invoice is
/// true and stays.
const Set<String> kExpenseIdAliasHosts = {
  'purchase_order',
  'recurring_expense',
};

/// First ref in [kActivityDocumentTokens] order that isn't the record on screen
/// and that [accept]s.
///
/// [accept] takes the token as well as the ref, because the two callers ask
/// different questions of it: the row target asks whether the *sentence* named
/// this token, and the note source asks whether the ref carries a label — and
/// [kExpenseIdAliasHosts] applies to one of them and not the other.
ActivityRef? _firstDocumentRef(
  Activity a, {
  required String? host,
  required bool Function(String token, ActivityRef ref) accept,
}) {
  for (final token in kActivityDocumentTokens) {
    if (token == host) continue;
    final ref = a.refs[token];
    if (ref != null && accept(token, ref)) return ref;
  }
  return null;
}

/// The record a **note** was filed against, when that isn't the one on screen.
///
/// A note typed on invoice #0012 also lands in that invoice's *client's* feed —
/// `ActivityController::note()` copies `client_id` off the parent — so on a busy
/// client the comments are a mixed pile with nothing saying which document each
/// one is about. The server ships the source refs for exactly this
/// (`Activity::harvestNoteEntities` is a type-141 special case populating
/// `:invoice` / `:task` / … even though the template has no tokens for them).
///
/// Label-only, deliberately: a note bypasses the templated sentence entirely, so
/// there is no span to hang a link on. The whole ref is returned because two
/// surfaces need different halves of it — the meta line prints the label, and
/// `CommentRowMenu` turns the same ref into a `View record` item.
ActivityRef? activityNoteSourceRef(Activity a, {required String? host}) {
  // Notes only, enforced here rather than at the call site: the rule this
  // function owns — refs are *harvested* for a type-141 row, so an `expense`
  // on an alias host is an id collision — is only true of a note, and
  // `activityRowTargetRef` is the answer for everything else.
  if (host == null || !a.isComment) return null;
  final aliasesExpense = kExpenseIdAliasHosts.contains(host);
  return _firstDocumentRef(
    a,
    host: host,
    // The alias skip belongs here and **only** here: a note's refs are
    // harvested rather than named, so on those two hosts an `expense` ref is
    // an id collision rather than a relation. A templated row is the opposite
    // case — see [activityRowTargetRef].
    accept: (token, ref) =>
        !(aliasesExpense && token == 'expense') && ref.label.trim().isNotEmpty,
  );
}

/// The record a **templated** activity row navigates to, or null for a row that
/// must stay inert (invoiceninja/flutter#143).
///
/// [namedTokens] is the set of template tokens the rendered sentence actually
/// substituted (`ActivitySpans.refTokens`), and filtering on it is load-bearing
/// rather than tidy: `refs` is **broader than the template**, because the server
/// stamps related ids the sentence never mentions. `RefundPayment::createActivity`
/// sets `invoice_id` on a `REFUNDED_PAYMENT` row whose template is
/// *":user refunded :adjustment of a :payment_amount payment :payment"*, and
/// `InvoicePaidActivity` sets `payment_id` on a *":user paid invoice :invoice"*
/// row — so a walk over raw refs would put a chevron on a refund row that opens
/// an invoice the row never names. That is the defect [kExpenseIdAliasHosts]
/// guards against for notes, generalized: **a row may only open a record it
/// names.**
///
/// Token *membership* is locale-stable — translators move `:tokens`, they do not
/// delete them — so this stays deterministic and English fixtures stay valid.
/// Ties break on [kActivityDocumentTokens] order, never on the order the tokens
/// appear in the sentence, which is not stable across locales. The one template
/// where that order is observable is `activity_10` (payment *and* invoice are
/// both named); invoice wins, which is also what `activityDeepLinkTarget`
/// answers, so the two agree *there*. They do not agree in general, and the
/// difference is this filter: the global feed still walks raw ids, so a refund
/// row — which names no invoice — opens the payment here and the invoice from
/// `/activity`. Fixing that means teaching `ActivityFormatter` to report the
/// tokens it substituted; until then the divergence is known, not accidental.
///
/// It deliberately does **not** take [kExpenseIdAliasHosts]' skip. That rule
/// exists because `note()` *harvests* refs the sentence never mentions, which
/// is exactly what [namedTokens] already excludes — and seven templates
/// (`activity_34/35/36/37/47/139/148`) do name `:expense`, so applying it here
/// would strand a genuinely-named expense on a purchase-order or
/// recurring-expense tab with no chevron, no row tap and, on touch, no link.
ActivityRef? activityRowTargetRef(
  Activity a, {
  required String? host,
  required Set<String> namedTokens,
}) {
  if (namedTokens.isEmpty) return null;
  return _firstDocumentRef(
    a,
    host: host,
    accept: (token, ref) => namedTokens.contains(token) && ref.isLink,
  );
}
