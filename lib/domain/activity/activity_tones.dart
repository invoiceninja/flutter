/// The meaning of an activity row, as a colour family — and the
/// `activity_type_id` → meaning map taken from the server's catalog.
///
/// A leaf with no Flutter import: `ActivityFormatter` paints these, and the
/// `/activity` timeline (`activity_timeline.dart`) buckets by them.
library;

/// Status colors map for activity circles. Indexed by [ActivityTone].
enum ActivityTone { paid, sent, viewed, draft, expense, neutral }

/// `activity_type_id` → tone, taken from the server's own catalog
/// (`~/Code/invoiceninja/app/Models/Activity.php`) rather than guessed.
///
/// **Deliberately partial.** Only events whose *meaning* maps onto one of the
/// five tones are listed; archive / delete / restore, and the payment-failure
/// ids (39 `VOIDED_PAYMENT`, 40 `REFUNDED_PAYMENT`, 41 `FAILED_PAYMENT`), fall
/// through to [ActivityTone.neutral] on purpose. There is no failure tone, and
/// [ActivityTone.expense] paints `overdueSoft`/`overdue` — red — so widening it
/// to cover failures would shout at the user about the wrong rows.
///
/// The tone follows what the event *means*, not the verb: a payment being
/// entered is money arriving (`paid`), a payment being edited is a record
/// changing (`draft`).
///
/// The map shipped wrong and nothing noticed, because a wrong tone is a grey
/// circle rather than an error. It mapped 10 and 25 to `viewed` —
/// `CREATE_PAYMENT` and `RESTORE_INVOICE` — while the four real view events
/// (7 / 21 / 60 / 136) fell through to neutral, so "the client opened your
/// invoice" rendered identically to "someone archived a vendor". Eight arms
/// were dropped outright (22, 23, 24, 26, 27, 32, 36, 37 — all archive, delete
/// or restore) and one re-homed (10, to `paid`). `activity_formatter_test.dart`
/// now derives the `viewed` and `sent` sets from the bundled `en.json`
/// templates in both directions, so the same class of drift fails the build.
const Map<int, ActivityTone> kActivityTones = {
  // The other side looked at the document.
  7: ActivityTone.viewed, // VIEW_INVOICE
  21: ActivityTone.viewed, // VIEW_QUOTE
  56: ActivityTone.viewed, // (no server constant — vestigial "viewed ticket")
  60: ActivityTone.viewed, // VIEW_CREDIT
  136: ActivityTone.viewed, // VIEW_PURCHASE_ORDER
  // Something left the building.
  6: ActivityTone.sent, // EMAIL_INVOICE
  20: ActivityTone.sent, // EMAIL_QUOTE
  53: ActivityTone.sent, // MARK_SENT_INVOICE
  63: ActivityTone.sent, // INVOICE_REMINDER1_SENT
  64: ActivityTone.sent, // INVOICE_REMINDER2_SENT
  65: ActivityTone.sent, // INVOICE_REMINDER3_SENT
  66: ActivityTone.sent, // INVOICE_REMINDER_ENDLESS_SENT
  135: ActivityTone.sent, // EMAIL_PURCHASE_ORDER
  138: ActivityTone.sent, // payment emailed
  139: ActivityTone.sent, // expense notification sent
  140: ActivityTone.sent, // statement sent
  142: ActivityTone.sent, // quote reminder 1 sent
  145: ActivityTone.sent, // e-invoice sent
  149: ActivityTone.sent, // credit emailed
  154: ActivityTone.sent, // e-invoice sent to AEAT
  156: ActivityTone.sent, // invoice cancellation sent to AEAT
  // Money arrived, or the other side said yes.
  10: ActivityTone.paid, // CREATE_PAYMENT
  29: ActivityTone.paid, // APPROVE_QUOTE
  54: ActivityTone.paid, // PAID_INVOICE
  137: ActivityTone.paid, // ACCEPT_PURCHASE_ORDER — the vendor side of 29
  // A record was created or edited.
  4: ActivityTone.draft, // CREATE_INVOICE
  5: ActivityTone.draft, // UPDATE_INVOICE
  11: ActivityTone.draft, // UPDATE_PAYMENT — an edit, not a receipt
  14: ActivityTone.draft, // CREATE_CREDIT
  15: ActivityTone.draft, // UPDATE_CREDIT
  18: ActivityTone.draft, // CREATE_QUOTE
  19: ActivityTone.draft, // UPDATE_QUOTE
  100: ActivityTone.draft, // CREATE_RECURRING_INVOICE
  101: ActivityTone.draft, // UPDATE_RECURRING_INVOICE
  130: ActivityTone.draft, // CREATE_PURCHASE_ORDER
  131: ActivityTone.draft, // UPDATE_PURCHASE_ORDER

  34: ActivityTone.expense, // CREATE_EXPENSE
  47: ActivityTone.expense, // UPDATE_EXPENSE
};

ActivityTone activityToneFor(int id) =>
    kActivityTones[id] ?? ActivityTone.neutral;
