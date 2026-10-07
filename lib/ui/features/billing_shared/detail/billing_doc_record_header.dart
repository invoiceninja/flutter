import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/detail/recent_visit_recorder.dart';
import 'package:admin/ui/core/widgets/avatar_tint.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/party_call_button.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/utils/formatting.dart';

/// The date a billing document is held to, as its header and its standing
/// card both read it.
///
/// A deposit's due date stands in for the document's own while there is one —
/// the same rule `Invoice.isPastDueOn` applies — except on a quote, whose
/// second date is "valid until" and has nothing to do with when a deposit
/// falls due.
Date? billingDocEffectiveDue(BillingDocType type, BillingDocFields doc) {
  if (type == BillingDocType.quote) return doc.dueDate;
  if (doc is BillingDocPartialFields) return doc.partialDueDate ?? doc.dueDate;
  return doc.dueDate;
}

/// How a billing document is named wherever a short label is wanted — the
/// Recent list, a confirm prompt, a call note's subject. Empty when the
/// document has no number yet (a company can hold numbers back until a
/// document is sent).
String billingDocSubject(BillingDocFields doc) =>
    doc.number.isEmpty ? '' : '#${doc.number}';

/// Who a billing document is and whose: what it is, its number and status,
/// the party it is addressed to (a link to that client or vendor, and a call
/// button beside it), its dates, and its tags.
///
/// One header for all five documents, in the shape the client screen's has —
/// a tinted tile, a name, a muted line of facts — so a user moving between a
/// client and its invoices is not re-learning where things are. It replaces
/// five bordered header cards that had drifted apart: three shared a dates
/// caption and a money strip, two hand-rolled a label/value wrap, and none of
/// them said the document was deleted, archived or not yet synced.
///
/// **The money is not here.** It was the bottom row of the old card; it is
/// the standing card now (`BillingDocStanding`), directly below.
///
/// **The status pill and the party label are slots**, and not for flexibility:
///
///  * the pill's `Viewed` link has to be mounted where its reveal controller
///    is built and disposed (`comments_surface_wiring_test`), and each
///    document has its own pill widget;
///  * a cross-entity `*NameLabel` link is allowed on a short, named list of
///    detail surfaces (`no_list_tile_name_link_test`), and the five screens
///    are on it. Build the label with [partyStyle] so the name row keeps the
///    line box `PartyCallButton` is sized against.
///
/// **The tile's tint is the party's, not the document's.** Seeded on the
/// client or vendor id, every invoice for one client carries that client's
/// colour — the same one beside its name in the Clients list — so stepping
/// down a list of documents, the tile changes when the customer does.
class BillingDocRecordHeader extends StatelessWidget {
  const BillingDocRecordHeader({
    super.key,
    required this.type,
    required this.doc,
    required this.statusPill,
    required this.party,
    this.formatter,
    this.banner,
    this.facts = const [],
  });

  final BillingDocType type;
  final BillingDocFields doc;
  final Widget statusPill;

  /// The client or vendor name, as a link — see the class doc.
  final Widget party;

  /// Null while it loads; the dates wait for it rather than print ISO.
  final Formatter? formatter;

  /// Drawn above everything — the invoice's lock notice. Must collapse to
  /// nothing on its own when it has nothing to say.
  final Widget? banner;

  /// Extra subtitle segments for a document whose dates come from somewhere
  /// else — the recurring invoice's frequency and last send.
  final List<Widget> facts;

  /// The style for [party]: `bodyMedium`, whose line box the inline call
  /// button is pinned to (`docs/tap-to-call.md` § The billing-doc header
  /// button is sized on the axis that has room), in `ink2` — `ink3` at this
  /// size is under the contrast floor.
  static TextStyle? partyStyle(BuildContext context) => Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: context.inTheme.ink2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final vendorParty = type.party == BillingDocParty.vendor;
    final partyId = vendorParty ? doc.vendorId : doc.clientId;
    final typeLabel = context.tr(type.singularLabelKey);
    final subject = billingDocSubject(doc);
    final hasNumber = subject.isNotEmpty;
    final segments = _segments(context);
    final nameStyle = theme.textTheme.headlineSmall?.copyWith(
      color: tokens.ink,
      fontWeight: FontWeight.w600,
    );
    return RecentVisitRecorder(
      type: type.entityType,
      id: doc.id,
      label: hasNumber ? subject : typeLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?banner,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeTile(
                // A document with no party yet still gets a stable colour.
                seed: partyId.isEmpty ? doc.id : partyId,
                icon: context
                    .read<Services>()
                    .entityRegistry[type.entityType]
                    ?.icon,
              ),
              SizedBox(width: InSpacing.lg(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // What it is, above its number — unless there is no
                    // number, when the word *is* the name and saying it twice
                    // would be noise.
                    if (hasNumber)
                      Text(
                        typeLabel.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: tokens.ink2,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          letterSpacing: 0.4,
                        ),
                      ),
                    // A `Wrap`, so a long number pushes the pills to a second
                    // line instead of being cut down to make room for them.
                    Wrap(
                      spacing: InSpacing.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          hasNumber ? subject : typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nameStyle,
                        ),
                        statusPill,
                        // Not a lifecycle state and no banner repeats it, so
                        // it is said here.
                        if (doc.isDirty) const UnsyncedPill(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(child: party),
                        PartyCallButton(
                          clientId: vendorParty ? null : doc.clientId,
                          vendorId: vendorParty ? doc.vendorId : null,
                          // Filed against the *document*, not the party: the
                          // server stamps the party id on the note anyway, so
                          // it still reaches that feed — and this way the
                          // note also says which document the call was about.
                          logTarget: (
                            type: type.entityType,
                            id: doc.id,
                            subject: subject,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (segments.isEmpty)
                      DetailHeaderTimestamps(
                        createdAt: doc.createdAt,
                        updatedAt: doc.updatedAt,
                        formatter: formatter,
                      )
                    else
                      DetailSubtitle(segments: segments),
                    if (doc.tagIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: EntityTagsView(
                          entityType: type.wireName,
                          tagIds: doc.tagIds,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The line of dates: when it was issued, when it is due (or how long it is
  /// valid), and — whatever the status has since become — when it was looked
  /// at.
  ///
  /// The `Viewed` segment is status-independent on purpose
  /// (`docs/comments-and-activity.md` § A `Viewed` pill is the way into the
  /// activity that recorded the view): the pill stops saying Viewed the moment
  /// anything outranks it, and "they are forty days late — did they ever open
  /// it?" is asked exactly then. Date-only, like its neighbours; the time is in
  /// the pill's tooltip and on the Activity row.
  ///
  /// There is no overdue chip here any more. How late the document is, is the
  /// standing card's line, in the one red on the screen.
  List<Widget> _segments(BuildContext context) {
    final f = formatter;
    if (f == null) return const [];
    final dueKey = type.dueDateLabelKey;
    final due = billingDocEffectiveDue(type, doc);
    final date = doc.date;
    final viewed = doc.invitations.newestViewed?.viewedDate ?? '';
    // `Formatter.date` answers '' for a value it cannot parse.
    final viewedOn = viewed.isEmpty ? '' : f.date(viewed);
    return [
      // The recurring invoice has no date of its own; its dates are its
      // schedule's.
      if (dueKey != null && date != null) Text(f.date(date.toIso())),
      if (dueKey != null && due != null)
        Text('${context.tr(dueKey)}: ${f.date(due.toIso())}'),
      ...facts,
      if (viewedOn.isNotEmpty) Text('${context.tr('viewed')}: $viewedOn'),
    ];
  }
}

/// The tinted tile at the head of the header: the document type's icon, where
/// a client's would show initials — a number has none.
///
/// Same footprint as `EntityDetailHeader`'s avatar, so the two headers line up
/// when a pane swaps one for the other.
class _TypeTile extends StatelessWidget {
  const _TypeTile({required this.seed, required this.icon});

  final String seed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 56,
    height: 56,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: avatarTintFor(seed),
      borderRadius: BorderRadius.circular(InRadii.r2),
    ),
    child: Icon(
      icon ?? Icons.description_outlined,
      color: Colors.white,
      size: 28,
    ),
  );
}
