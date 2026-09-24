import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart' show OutboxRow;
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/notify_async.dart';
import 'package:admin/ui/core/widgets/party_contacts_builder.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/billing_shared/activity/activity_list_card.dart';
import 'package:admin/utils/formatting.dart';

/// Shared "Email History" tab for billing-doc detail screens (invoice, quote,
/// credit, purchase order, recurring invoice) and for the Send Email
/// composer's History pane — six mount sites. Lists each invitation that has
/// actually been sent to: the contact it went to, the sent/opened/viewed
/// lifecycle, a delivery-state pill, and any delivery error — plus a
/// Postmark-gated "Reactivate email" action for bounced sends.
/// Mirrors the legacy admin-portal invoice-view-contacts surface, which
/// called the same tab "Contacts".
///
/// **Rows with no send history are dropped** ([InvitationAccessors.
/// hasSendHistory]). The server creates one invitation per send-email contact
/// at *document-save* time, so a draft listed every contact with nothing
/// beneath it under a heading saying "Email History" — read by testers as
/// proof the contact had been emailed (invoiceninja/flutter#146).
///
/// That filter applies **here only**. Everywhere else `invitations` means the
/// *recipient set*, and narrowing it is a hard regression:
/// `BillingDocEmailScreen`'s `_hasDeliverable` (→ `_canSend`) would disable
/// Send on exactly the documents this fix is about; `_recipientText()` /
/// `noEmail` would blank the "To:" line; `hasInvitations:` feeds
/// `emailPreviewBinding`, and flipping a bound preview to the server's
/// generic sample re-opens #31; `BillingDocEditViewModel.hasInvitations` and
/// `seedClientInvitationsIfEmpty` would re-seed contacts on already-sent docs
/// and clobber manual Contacts-tab selections. `_allBounced` is correct as it
/// stands — adding a never-emailed contact genuinely makes "resending just
/// bounces again" false.
///
/// `clientId` (invoices/quotes/credits/recurring) or `vendorId`
/// (purchase orders) names the entity whose contacts label each row;
/// exactly one is non-empty. Reactivation rides the outbox through
/// [onReactivate] (the owning repo's `reactivateInvitationEmail`), so it
/// retries offline and the in-flight row shows a spinner until it drains.
class BillingDocSendsTab extends StatefulWidget {
  const BillingDocSendsTab({
    super.key,
    required this.services,
    required this.companyId,
    required this.entityWireName,
    required this.entityId,
    required this.invitations,
    required this.isHosted,
    required this.isDirty,
    required this.onReactivate,
    this.clientId = '',
    this.vendorId = '',
  });

  final Services services;
  final String companyId;

  /// Outbox entity-type key ('invoice', 'quote', …) — scopes
  /// [_BillingDocSendsTabState._pendingMutations] to this record, so the right
  /// rows show as in-flight and a queued send is attributed to this doc.
  final String entityWireName;
  final String entityId;
  final List<Invitation> invitations;

  /// Reactivation is a Postmark-only server feature (legacy gated on
  /// `isUsingPostmark`); on self-hosted SMTP the button is hidden.
  final bool isHosted;

  /// Whether the record has an unsynced local edit — it softens the empty
  /// state, and it is not cosmetic.
  ///
  /// `Invitation.toApiJson()` emits only `id` + the two contact ids, and
  /// `_domainToCompanion` stores that projection as the Drift payload (with
  /// `_fromRow` reading the domain back out of it), so **any local edit-save
  /// strips every invitation's sent/viewed/opened/status/error from the local
  /// row** until the outbox `update` drains — unbounded offline, and
  /// permanent if that row dies. Claiming "no emails have been sent" there
  /// would be a confident falsehood about a document the user demonstrably
  /// emailed, so a dirty record falls back to the non-committal
  /// `no_records_found`: we hold no record, which is all we know.
  ///
  /// It is deliberately a **superset**, not an exact predicate: only `save()`
  /// and `create()` rewrite the payload, but `archive()` / `restore()` /
  /// `delete()` also raise the flag (through `RawValuesInsertable`s that touch
  /// the flag columns alone, leaving `payload` intact). The extra cases only
  /// soften copy on a record with nothing to show, so erring wide is free.
  /// What the flag buys over watching the outbox is that it survives a **dead**
  /// `update` row — `_releaseDeadLifecycleDirty` deliberately skips
  /// `create`/`update`, and that is exactly when the strip is permanent.
  ///
  /// Known limit it cannot cover: removing a contact soft-deletes its
  /// invitations (`ClientContactObserver`) and the transformer's
  /// `includeInvitations` has no `withTrashed()`, so the history leaves the
  /// API with nothing local dirty. The tab then reports no sends on a document
  /// that was emailed.
  final bool isDirty;

  /// Enqueues the reactivate mutation for a message id (the owning repo's
  /// `reactivateInvitationEmail`) and returns the outbox row id, so the tab can
  /// confirm the result against the server when online.
  final Future<int> Function(String messageId) onReactivate;

  final String clientId;
  final String vendorId;

  @override
  State<BillingDocSendsTab> createState() => _BillingDocSendsTabState();
}

class _BillingDocSendsTabState extends State<BillingDocSendsTab> {
  Formatter? _formatter;

  /// Stable watch subscriptions — created ONCE here, never inside `build()`.
  /// A fresh stream per rebuild makes `StreamBuilder` re-subscribe and retain
  /// the *previous* stream's last value during the gap; a rebuild burst (e.g.
  /// the failure modal opening the instant a reactivate row fail-fasts to
  /// `dead`) can then drop the dead-excluded `[]` emission and leave the
  /// button stuck on its "syncing…" spinner. One stable instance keeps the
  /// live subscription and reliably delivers every state change — same pattern
  /// as `ClientEmailHistoryViewModel`.
  ///
  /// [_pendingMutations] holds **every** pending mutation for this record, not
  /// just reactivations — the `kind:` filter is dropped and the partition
  /// happens in `build`.
  ///
  /// The send itself rides the outbox (`MutationKind.emailEntity`) and does
  /// NOT dirty the entity row, so nothing else on the screen shows it in
  /// flight; without this the tab would flatly deny a send the user had just
  /// made. The drain heals the data on its own — the handler returns the
  /// refreshed entity and `BaseEntitySyncDispatcher` routes it through
  /// `applyUpdateResponse` *before* deleting the row, so there is no flash on
  /// success — but offline that window is unbounded.
  ///
  /// The price is that this now ticks on any pending mutation for the entity
  /// (a queued edit included), not only reactivations. Dropping `kind:`
  /// cannot cross entities or companies: those clauses still AND, and only
  /// the kind clause was conditional.
  late final Stream<List<OutboxRow>> _pendingMutations;
  late final Stream<PartyContacts> _contacts;

  @override
  void initState() {
    super.initState();
    _pendingMutations = widget.services.db.outboxDao.watchPendingForEntity(
      companyId: widget.companyId,
      entityType: widget.entityWireName,
      entityId: widget.entityId,
    );
    _contacts = _contactsLookup();
    // Resolve the company formatter once (same pattern as
    // FormatterHostMixin) so timestamps honor the company date format;
    // until it lands, rows render raw ISO.
    widget.services.formatterFor(widget.companyId).then((f) {
      if (mounted) setState(() => _formatter = f);
    });
    // List-sourced rows prefetch only page 1, so the doc's client/vendor
    // (hence its contacts) may not be in Drift yet. Deduped + safe to fire
    // unconditionally, same as the invoice actions row's `_ensureClient`.
    if (widget.clientId.isNotEmpty) {
      widget.services.clients.ensureLoaded(
        companyId: widget.companyId,
        id: widget.clientId,
      );
    } else if (widget.vendorId.isNotEmpty) {
      widget.services.vendors.ensureLoaded(
        companyId: widget.companyId,
        id: widget.vendorId,
      );
    }
  }

  Future<void> _reactivate(String messageId) => runQueuedActionWithNotify(
    context,
    services: widget.services,
    companyId: widget.companyId,
    enqueue: () => widget.onReactivate(messageId),
    successMsg: context.tr('email_reactivated'),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
      child: StreamBuilder<PartyContacts>(
        stream: _contacts,
        builder: (context, contactsSnap) {
          final contacts =
              contactsSnap.data ??
              const <String, ({String name, String email})>{};
          return StreamBuilder<List<OutboxRow>>(
            stream: _pendingMutations,
            builder: (context, pendingSnap) {
              final rows = pendingSnap.data ?? const <OutboxRow>[];
              final pendingIds = _pendingMessageIds(
                rows.where(
                  (r) =>
                      r.mutationKind == MutationKind.reactivateEmail.wireName,
                ),
              );
              // `scheduleEmail` is deliberately excluded: it posts to
              // `/api/v1/task_schedulers` and its handler returns null, so
              // nothing is applied when it drains — the row would appear for
              // a second and vanish, teaching the user their scheduled email
              // evaporated. "No emails have been sent" is simply true for a
              // scheduled send. Two neighbours are also correctly absent:
              // recurring "Send now" reaches the wire as a
              // `MutationKind.update` carrying `send_now=true`
              // (`RecurringInvoiceRepository.sendNow` calls `save(extraQuery:)`
              // — `MutationKind.sendNow` does exist, with a dispatcher case and
              // no enqueuer anywhere in `lib/`, so it is dead wiring and not
              // what that action produces), and `sendEInvoice` is a
              // transmission, not an email.
              final sends = rows.where(
                (r) => r.mutationKind == MutationKind.emailEntity.wireName,
              );
              return ActivityListCard(
                child: _buildList(
                  context,
                  contacts,
                  pendingIds,
                  sendQueued: sends.isNotEmpty,
                  sendUnconfirmed: sends.any((r) => r.state == 'unconfirmed'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    PartyContacts contacts,
    Set<String> pendingIds, {
    required bool sendQueued,
    required bool sendUnconfirmed,
  }) {
    final invitations = widget.invitations
        .where((i) => i.hasSendHistory)
        .toList();
    if (invitations.isEmpty && !sendQueued) {
      return EmptyState(
        icon: Icons.outgoing_mail,
        // A dirty row's payload came from `toApiJson`, which drops the
        // invitation lifecycle — see [BillingDocSendsTab.isDirty]. We cannot
        // claim nothing was sent, only that we hold no record.
        title: context.tr(
          widget.isDirty ? 'no_records_found' : 'no_emails_sent',
        ),
      );
    }
    // Pending first, as the Comments card does, and `isLast` counted against
    // the combined total so the divider lands on the real final row.
    final total = (sendQueued ? 1 : 0) + invitations.length;
    final children = <Widget>[
      if (sendQueued)
        _QueuedSendRow(isLast: total == 1, unconfirmed: sendUnconfirmed),
    ];
    for (var i = 0; i < invitations.length; i++) {
      final inv = invitations[i];
      children.add(
        _InvitationRow(
          invitation: inv,
          contact: contacts[invitationContactId(inv)],
          formatter: _formatter,
          isHosted: widget.isHosted,
          isReactivating: pendingIds.contains(inv.messageId),
          onReactivate: () => _reactivate(inv.messageId),
          isLast: children.length == total - 1,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// Builds a `contactId → (label, email)` map from the doc's client or
  /// vendor. Falls back to an empty map until the entity loads.
  Stream<PartyContacts> _contactsLookup() {
    if (widget.clientId.isNotEmpty) {
      return widget.services.clients
          .watch(companyId: widget.companyId, id: widget.clientId)
          .map(contactsOfClient);
    }
    if (widget.vendorId.isNotEmpty) {
      return widget.services.vendors
          .watch(companyId: widget.companyId, id: widget.vendorId)
          .map(contactsOfVendor);
    }
    return Stream.value(const {});
  }

  static Set<String> _pendingMessageIds(Iterable<OutboxRow> rows) {
    final ids = <String>{};
    for (final row in rows) {
      try {
        final decoded = jsonDecode(row.payload);
        if (decoded is Map && decoded['message_id'] is String) {
          ids.add(decoded['message_id'] as String);
        }
      } catch (_) {}
    }
    return ids;
  }
}

/// The row chrome every entry in this card shares: a [kEntityListRowHeight]
/// floor, the card's 16/14 inset, and a hairline under everything but the last
/// row.
///
/// Extracted so the queued row is not a fifth hand-copy of it —
/// `ClientEmailHistoryTab._RecordBlock`, `PendingCommentRow` and
/// `ActivityRecordRow` hold the other three, and they have diverged enough
/// (hover fill, parameterized padding, cross-axis alignment) that a shared
/// cross-file widget would have to parameterize all of it. Local to this file
/// is the cheap half of that trade.
class _SendsRowShell extends StatelessWidget {
  const _SendsRowShell({required this.child, required this.isLast});

  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kEntityListRowHeight),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: isLast ? BorderSide.none : BorderSide(color: tokens.border),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A send still sitting in the outbox, rendered above the real history so the
/// tab never denies something the user has just done.
///
/// Shaped after [PendingCommentRow], the app's other queued-mutation row:
/// mail vocabulary on the body line, sync vocabulary as the grey sub-line.
/// The two are deliberately NOT joined into one string — `in_flight`
/// ("Syncing…") lives in `_app_pending.json` and so is missing from all eight
/// non-English bundles, so a concatenation would read half-translated on the
/// one row that exists to reassure. `email_queued` is translated everywhere
/// and is the exact string the composer's own toast shows, so the tab echoes
/// it word for word rather than minting a third name for one action.
///
/// A **dead** send row is excluded by `watchPendingForEntity`, so the tab
/// reverts to the (truthful) empty state; the failure surfaces through the
/// Outbox screen and the sync failure toast, the same trade `OutboxDao`
/// documents for the Comments card. N queued sends collapse into one row —
/// `emailEntity` is enqueued without deduping, and this reports "a send is in
/// flight", not how many.
///
/// The spinner is indeterminate and runs for as long as the row is queued, so
/// `pumpAndSettle` over any screen in this state never returns; pump
/// explicitly, as `pending_comment_row_test.dart` records for its twin.
///
/// Except an `unconfirmed` send — it may already have gone out, and nothing
/// sends it again until the user decides on the Outbox screen — which shows
/// that instead of a spinner that would run forever.
class _QueuedSendRow extends StatelessWidget {
  const _QueuedSendRow({required this.isLast, required this.unconfirmed});

  final bool isLast;
  final bool unconfirmed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return _SendsRowShell(
      isLast: isLast,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: unconfirmed
                ? Icon(
                    Icons.sync_problem_outlined,
                    size: 16,
                    color: tokens.warning,
                  )
                : CircularProgressIndicator(strokeWidth: 2, color: tokens.ink3),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('email_queued'),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr(unconfirmed ? 'may_have_been_sent' : 'in_flight'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: unconfirmed ? tokens.warning : tokens.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InvitationRow extends StatelessWidget {
  const _InvitationRow({
    required this.invitation,
    required this.contact,
    required this.formatter,
    required this.isHosted,
    required this.isReactivating,
    required this.onReactivate,
    required this.isLast,
  });

  final Invitation invitation;
  final ({String name, String email})? contact;
  final Formatter? formatter;
  final bool isHosted;
  final bool isReactivating;
  final VoidCallback onReactivate;
  final bool isLast;

  String _fmt(BuildContext context, String iso) {
    if (iso.isEmpty) return '';
    return formatter?.date(iso, showTime: true, showSeconds: false) ?? iso;
  }

  /// Label, tooltip and tones for the row's one delivery state. The precedence
  /// lives on the model ([InvitationAccessors.sendState]) so it is
  /// unit-testable and carries no colour; this is only the map, exactly the
  /// split `SystemLogTone` makes.
  ///
  /// The tooltip is branched with the label. It used to be hardcoded to
  /// `email_bounced` while the label said "Error", so a pure SMTP failure
  /// carried a tooltip contradicting the pill it was attached to — on the one
  /// row that also prints the real error text below. It matters beyond hover:
  /// `Tooltip` sets `SemanticsProperties.tooltip`, so under the merge below
  /// this is how a screen reader learns what "Spam" means.
  ({String labelKey, String tooltipKey, Color fg, Color bg})? _pill(
    InTheme tokens,
  ) => switch (invitation.sendState) {
    InvitationSendState.bounced => (
      labelKey: 'bounced',
      tooltipKey: 'email_bounced',
      fg: tokens.overdue,
      bg: tokens.overdueSoft,
    ),
    InvitationSendState.spam => (
      labelKey: 'spam',
      tooltipKey: 'email_spam_complaint',
      fg: tokens.overdue,
      bg: tokens.overdueSoft,
    ),
    InvitationSendState.errored => (
      labelKey: 'error',
      tooltipKey: 'email_error',
      fg: tokens.overdue,
      bg: tokens.overdueSoft,
    ),
    InvitationSendState.delivered => (
      labelKey: 'delivered',
      tooltipKey: 'email_delivered',
      fg: tokens.paid,
      bg: tokens.paidSoft,
    ),
    InvitationSendState.none => null,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final state = invitation.sendState;
    final pill = _pill(tokens);
    // The cascade lives in `party_contacts_builder.dart` so this tab and the
    // `Viewed` pill's tooltip, which show the same fact, cannot drift.
    final name = contactLabelOf(contact, fallback: context.tr('contact'));
    final lifecycle = <String>[
      if (invitation.hasBeenSent)
        '${context.tr('sent')}: ${_fmt(context, invitation.sentDate)}',
      if (invitation.hasBeenOpened)
        '${context.tr('opened')}: ${_fmt(context, invitation.openedDate)}',
      if (invitation.hasBeenViewed)
        '${context.tr('viewed')}: ${_fmt(context, invitation.viewedDate)}',
    ].join(' · ');
    // Reactivate clears a Postmark **suppression**, and only a bounce creates
    // one — so this is `bounced`, not the `hasBounced || hasError` it replaces.
    // Spam carries `"CanActivate": false` in Postmark's own payload; a
    // delivered mail has nothing to clear; a pure MTA failure has no bounce
    // record and no `message_id` either. The old gate leaned on `hasError`,
    // which every webhook ESP sets from the payload's `Details` on delivery
    // too — so the button had been offering itself on every successfully
    // delivered hosted row, and would have 400'd on each one.
    final showReactivate =
        isHosted &&
        state == InvitationSendState.bounced &&
        invitation.messageId.isNotEmpty;

    return _SendsRowShell(
      isLast: isLast,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Merged so a screen reader announces one row instead of four
          // unrelated nodes (name, email, lifecycle, and a detached pill).
          // Scoped to this Row and NOT the whole Column: the Reactivate button
          // below is interactive, and a merge over it would fold its tap
          // action into the row node — undiscoverable on the only row that
          // has an action to take.
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: tokens.ink,
                        ),
                      ),
                      if (contact?.email.isNotEmpty ?? false)
                        Text(
                          contact!.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.ink3,
                          ),
                        ),
                      if (lifecycle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          lifecycle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.ink3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (pill != null) ...[
                  SizedBox(width: InSpacing.md(context)),
                  // Capped, never wrapped in `Flexible`: a bare Flexible
                  // beside the Expanded makes `totalFlex` 2, and Expanded is
                  // `FlexFit.tight`, so the identity column would be pinned to
                  // exactly half the row with the remainder stranded as
                  // trailing space — on most rows, once `delivered` fires for
                  // every webhook-ESP user. Same constant and rationale as
                  // `ClientListTile`'s money column; the cap binds only for a
                  // long label (fr "Courrier indésirable") at large text
                  // scale, which is the case worth protecting.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: StatusPill(
                      label: context.tr(pill.labelKey),
                      fgColor: pill.fg,
                      bgColor: pill.bg,
                      tooltip: context.tr(pill.tooltipKey),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Suppressed on a delivered row: `email_error` there is the MTA's
          // *success* line, which every webhook ESP writes from the payload's
          // `Details` before it branches on record type. Printing it in
          // `overdue` red under a green pill reads as a failure report.
          if (state != InvitationSendState.delivered &&
              invitation.emailError.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              invitation.emailError,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.overdue),
            ),
          ],
          if (showReactivate) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: isReactivating ? null : onReactivate,
                icon: isReactivating
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tokens.ink3,
                        ),
                      )
                    : const Icon(Icons.mark_email_read_outlined, size: 18),
                label: Text(
                  context.tr(isReactivating ? 'in_flight' : 'reactivate_email'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
