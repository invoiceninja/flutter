import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/domain/activity/activity_view_events.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_reveal_controller.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/widgets/party_contacts_builder.dart';
import 'package:admin/utils/formatting.dart';

/// The one line a pointer user sees on hover: who looked, and exactly when.
///
/// Pure so it is unit-testable — every string arrives resolved, because
/// `context.tr` is a `BuildContext` extension and a helper that reached for it
/// could not be tested without pumping a widget.
///
/// Shaped like the Email History row it duplicates
/// (`billing_doc_sends_tab.dart`, `'<label>: <date>'`) so the two surfaces read
/// alike. [moreLabel] is the localized `+N more` for the other viewers; it
/// counts **people, not views** — the server stamps `viewed_date` once per
/// contact and keeps no count of repeat visits, so anything phrased as a number
/// of views would be a lie.
String viewedByTooltip({
  required String name,
  required String viewedLabel,
  required String formattedDate,
  String? moreLabel,
}) {
  final head = formattedDate.isEmpty
      ? name
      : '$name · $viewedLabel: $formattedDate';
  return moreLabel == null ? head : '$head · $moreLabel';
}

/// Turns a billing doc's `Viewed` status pill into the way into the activity
/// that recorded the view (invoiceninja/flutter#154).
///
/// A **builder**, not a wrapper, and that is forced: the tap and the tooltip
/// have to be *inside* `StatusPill`'s decorated box — around it the ink paints
/// under the opaque tint, and a second `Tooltip` would nest inside
/// `StatusBounceOverlay`'s `Stack` and fight the bounce badge's own for the
/// same hover. So this resolves the two values and hands them down.
///
/// **Gated on [isViewed], which is the pill's own rendered status** — never on
/// `hasViewedInvitation`. `calculatedStatusId` checks its viewed branch last,
/// so a paid-or-overdue invoice can be viewed while the pill reads something
/// else; gating on the invitations would hang a "viewed by" tooltip under a
/// pill saying *Paid*. The durable answer for those documents is the header
/// caption's `Viewed <date>` segment, which is status-independent.
///
/// When the gate is closed this mounts no Drift watch at all, so the common
/// path costs nothing.
class ViewedStatusPillLink extends StatelessWidget {
  const ViewedStatusPillLink({
    super.key,
    required this.isViewed,
    required this.invitations,
    required this.entityWireName,
    required this.companyId,
    required this.clients,
    required this.vendors,
    required this.selectTab,
    required this.reveal,
    this.formatter,
    this.clientId = '',
    this.vendorId = '',
    required this.builder,
  });

  /// `calculatedStatusId == <entity>StatusComputed.viewed`.
  final bool isViewed;

  final List<Invitation> invitations;

  /// `'invoice'` / `'quote'` / `'credit'` / `'purchase_order'` — the key into
  /// [kViewActivityTypeIds]. A name with no entry (a recurring invoice) is
  /// correctly inert.
  final String entityWireName;

  final String companyId;
  final ClientRepository clients;
  final VendorRepository vendors;
  final TabSelectionController selectTab;
  final ActivityRevealController reveal;

  /// Passed in rather than read from `FormatterScope`: the purchase-order
  /// detail screen mounts no scope and threads its formatter by hand.
  final Formatter? formatter;

  final String clientId;
  final String vendorId;

  /// Rebuilt with the two strings and the handler the pill needs.
  ///
  /// `tooltip` and `semanticsLabel` are **separate on purpose**: the tooltip is
  /// pointer-only (on touch it would hide behind a long-press nobody will try),
  /// while the semantics label must carry the answer on *every* platform —
  /// touch is where VoiceOver and TalkBack are the primary way in, so gating
  /// both on the same flag would leave a screen reader hearing only "Viewed"
  /// exactly where it matters most.
  final Widget Function(
    BuildContext context,
    String? tooltip,
    String? semanticsLabel,
    VoidCallback? onTap,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final typeId = kViewActivityTypeIds[entityWireName];
    final newest = invitations.newestViewed;
    if (!isViewed || typeId == null || newest == null) {
      return builder(context, null, null, null);
    }
    return PartyContactsBuilder(
      companyId: companyId,
      clients: clients,
      vendors: vendors,
      clientId: clientId,
      vendorId: vendorId,
      builder: (context, contacts) {
        final name = partyContactLabel(
          contacts,
          invitationContactId(newest),
          fallback: context.tr('contact'),
        );
        final others = invitations.viewedCount - 1;
        final line = viewedByTooltip(
          name: name,
          viewedLabel: context.tr('viewed'),
          formattedDate:
              formatter?.date(
                newest.viewedDate,
                showTime: true,
                showSeconds: false,
              ) ??
              '',
          moreLabel: others > 0
              ? context.tr('plus_n_more', {'count': '$others'})
              : null,
        );
        return builder(
          context,
          // Pointer only. On touch a `Tooltip` is reachable only by a
          // long-press nobody will try — this app has no long-press-reveals-
          // info pattern, and the one the issue remembers (the phone icon)
          // actually *copies* on long-press. Touch gets the answer visually
          // from the header caption and from the row this tap lands on.
          Env.isTouchPrimary ? null : line,
          // Ungated: a screen reader has no hover either way, and touch is
          // where it is most likely to be the only way the user reads this.
          line,
          () => _open(context, typeId, line),
        );
      },
    );
  }

  void _open(BuildContext context, int typeId, String announcement) {
    // Tab FIRST, request second. On the common path the Activity body is not
    // mounted yet, so it reads `reveal.request` in its `initState` — but on the
    // path where it *is* mounted and offstage, notifying first would run its
    // listener while the controller still points at another tab.
    selectTab.select(kActivityTabIndex);
    reveal.reveal(typeId);
    // A tab change, a scroll and a flash are all invisible to a screen reader:
    // focus never moves, so as far as the semantics tree is concerned the
    // button did nothing. Same mechanism `ToastHost` uses for its own overlay.
    SemanticsService.sendAnnouncement(
      View.of(context),
      announcement,
      Directionality.of(context),
    );
  }
}
