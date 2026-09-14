import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/invitation_api_model.dart';

part 'invitation.freezed.dart';

/// Bridges a billing doc (invoice / quote / credit / purchase_order) to a
/// specific client or vendor contact. Tracks the email/portal lifecycle:
/// sent → viewed → opened, plus any delivery error.
///
/// Dates stay as wire strings (ISO timestamps); the UI parses with
/// `DateTime.tryParse` at render time so we don't burn a `Decimal`-like
/// custom value type for fields the user only reads.
@freezed
abstract class Invitation with _$Invitation {
  const factory Invitation({
    @Default('') String id,
    @Default('') String key,
    @Default('') String link,
    @Default('') String clientContactId,
    @Default('') String vendorContactId,
    @Default('') String sentDate,
    @Default('') String viewedDate,
    @Default('') String openedDate,
    @Default('') String emailStatus,
    @Default('') String emailError,
    @Default('') String messageId,
  }) = _Invitation;

  factory Invitation.fromApi(InvitationApi a) => Invitation(
    id: a.id,
    key: a.key,
    link: a.link,
    clientContactId: a.clientContactId,
    vendorContactId: a.vendorContactId,
    sentDate: a.sentDate,
    viewedDate: a.viewedDate,
    openedDate: a.openedDate,
    emailStatus: a.emailStatus,
    emailError: a.emailError,
    messageId: a.messageId,
  );
}

/// The delivery state an invitation row shows as a status pill. Resolved by
/// [InvitationAccessors.sendState]; the label + colour map lives at the call
/// site (`billing_doc_sends_tab.dart`) so this stays free of `dart:ui`.
enum InvitationSendState { bounced, spam, errored, delivered, none }

extension InvitationAccessors on Invitation {
  /// Surfaces the per-invitation lifecycle status without round-tripping
  /// through the raw strings. Mirrors admin-portal
  /// `invitation_entity.dart` accessors.
  bool get hasBeenSent => sentDate.isNotEmpty;
  bool get hasBeenViewed => viewedDate.isNotEmpty;
  bool get hasBeenOpened => openedDate.isNotEmpty;
  bool get hasBounced => emailStatus == 'bounced';
  bool get hasError => emailStatus == 'error' || emailError.isNotEmpty;

  /// True when this invitation has something to report in the Email History
  /// tab (`BillingDocSendsTab`, which also lists the reads that must NOT use
  /// this).
  ///
  /// The server creates one invitation per send-email contact at
  /// *document-save* time — `CreateInvitations.php`, plus
  /// `BaseRepository::alternativeSave`'s `count() == 0` fail-safe — with
  /// `sent_date = null`, so a never-emailed document always has N of them and
  /// `invitations.isNotEmpty` is never the question. This is, per row.
  ///
  /// A disjunction, **never [hasBeenSent] alone**: `NinjaMailerJob` (and
  /// `Services/Email/Email.php`) writes `email_error` with no `sent_date` on a
  /// failed send, and that is the row that most needs to survive.
  ///
  /// Deliberately **not** gated on `messageId`, which is the precise "a real
  /// email left the building" discriminator (only `MailSentListener` writes
  /// it) and would also filter the marked-sent-but-never-emailed false
  /// positive — but that listener swallows its own exceptions and post-dates
  /// plenty of stored rows, so gating on it would *hide real history*. One
  /// extra `Sent:` line is the safe direction; a hidden send is not.
  ///
  /// [hasBeenViewed] alone is a *portal* view rather than a send — a link
  /// shared by other means stamps `viewed_date` — so such a row appears under
  /// "Email History" having never been emailed. Kept: it is still history.
  ///
  /// The delivery half delegates to [sendState] rather than testing
  /// `emailStatus`/`emailError` directly, so the filter and the pill are one
  /// predicate. Spelled out separately they drift: this admitted *any*
  /// non-empty `emailStatus` while [sendState] mapped three, so a fourth
  /// server value would have rendered a name, an email and nothing else —
  /// invoiceninja/flutter#146 by construction. Unreachable today (the column
  /// is a strict MySQL enum of those three), and now unreachable by shape.
  bool get hasSendHistory =>
      hasBeenSent ||
      hasBeenOpened ||
      hasBeenViewed ||
      sendState != InvitationSendState.none;

  /// The one delivery state worth a status pill.
  ///
  /// **`email_error` is not a failure signal**, which is the whole reason for
  /// the ordering below. `ProcessPostmarkWebhook::handle()` assigns
  /// `email_error = $request['Details']` *before* its `RecordType` switch, and
  /// the file's own payload samples carry `Details` on **Delivery** as well as
  /// Bounce and SpamComplaint — on a delivered mail it is the remote MTA's
  /// success line (`smtp;250 2.0.0 OK …`). Mailgun and Brevo do the same with
  /// `delivery-status.message` / `reason`; only SES never writes it.
  ///
  /// So **`email_status` wins whenever it is set**, and `errored` is reached
  /// only when no webhook has spoken — the `NinjaMailerJob` MTA failure and
  /// the VeriFactu `'primed'` sentinel. Rank `errored` above `delivered`
  /// instead and every successful send on the default hosted ESP paints a red
  /// "Error" pill over an SMTP success string, with a Reactivate button on
  /// mail that arrived; the green arm becomes near-unreachable in production.
  ///
  /// The server writes exactly three `email_status` values — `delivered`,
  /// `bounced`, `spam`, twelve sites across the four ESP webhook jobs, behind
  /// an `enum('delivered','bounced','spam')` column — and never `'error'`, so
  /// [hasError]'s `== 'error'` arm is dead code.
  ///
  /// Resolved here rather than in the widget so it is unit-testable, and
  /// carrying no `Color` so `lib/data` never reaches `lib/ui` — the same
  /// split `SystemLogTone` makes.
  InvitationSendState get sendState {
    if (hasBounced) return InvitationSendState.bounced;
    if (emailStatus == 'spam') return InvitationSendState.spam;
    if (emailStatus == 'delivered') return InvitationSendState.delivered;
    if (hasError) return InvitationSendState.errored;
    return InvitationSendState.none;
  }
}

extension InvitationPayload on Invitation {
  Map<String, dynamic> toApiJson() => <String, dynamic>{
    if (id.isNotEmpty) 'id': id,
    if (clientContactId.isNotEmpty) 'client_contact_id': clientContactId,
    if (vendorContactId.isNotEmpty) 'vendor_contact_id': vendorContactId,
  };
}

extension InvitationClone on Invitation {
  /// An invitation copy suitable for a *cloned* billing doc: preserves the
  /// recipient (the contact ids) but drops every per-send lifecycle field —
  /// the server `id`/`key`/portal `link`, the sent/viewed/opened dates, and
  /// the delivery status/error/`messageId`. Without this a clone inherits the
  /// source's sent/viewed/bounced state (e.g. a bounce badge or a vendor-portal
  /// link pointing at the original doc) onto a brand-new draft.
  Invitation freshClone() => Invitation(
    clientContactId: clientContactId,
    vendorContactId: vendorContactId,
  );
}

/// Who looked at the document, and when — the one home for that scan
/// (invoiceninja/flutter#154).
///
/// Three surfaces need it and they need different parts of the same row: the
/// header caption wants [newestViewed]'s `viewedDate`, the pill's tooltip wants
/// that same row's contact id, and the multi-viewer suffix wants
/// [viewedCount]. A bare "newest ISO string" helper could only serve the first,
/// so this returns the `Invitation` itself.
///
/// It lives here rather than in a `lib/domain/` leaf because it is the same
/// kind of rule as [InvitationAccessors.sendState] — resolved on the model so
/// it is unit-testable and carries no `dart:ui` — and because
/// `docs/contacts-and-invitations.md` is already this file's doc home.
extension InvitationViewers on Iterable<Invitation> {
  /// Every invitation that has been viewed, most recent first.
  ///
  /// **Ordered by parsed instant, never by `String.compareTo`.** `viewedDate`
  /// is a raw wire string typed as `String`, and the server currently sends a
  /// MySQL datetime (`2026-09-11 15:50:31`). A lexical sort happens to be
  /// correct while every value shares that shape, and becomes silently wrong
  /// the first time one arrives ISO-`T`-separated: `'T'` (84) sorts above `' '`
  /// (32), so the T-form row would beat a space-form row at the same instant.
  /// Values that will not parse fall back to lexical order among themselves
  /// rather than being dropped — an unparseable date is still a view.
  List<Invitation> get viewedNewestFirst {
    final rows = where((i) => i.hasBeenViewed).toList();
    rows.sort((a, b) {
      final da = DateTime.tryParse(a.viewedDate);
      final db = DateTime.tryParse(b.viewedDate);
      if (da != null && db != null) return db.compareTo(da);
      if (da != null) return -1;
      if (db != null) return 1;
      return b.viewedDate.compareTo(a.viewedDate);
    });
    return rows;
  }

  /// The most recently viewed invitation, or null if nobody has looked.
  Invitation? get newestViewed {
    final rows = viewedNewestFirst;
    return rows.isEmpty ? null : rows.first;
  }

  /// How many contacts have viewed the document.
  ///
  /// **Contacts, not views.** `markViewed()` is gated on
  /// `! $invitation->viewed_date` (`ClientPortal/InvitationController.php`), so
  /// `viewed_date` records the *first* view per contact and the server keeps no
  /// count of repeat visits. Anything rendered from this must say "people", not
  /// "times".
  int get viewedCount => where((i) => i.hasBeenViewed).length;
}
