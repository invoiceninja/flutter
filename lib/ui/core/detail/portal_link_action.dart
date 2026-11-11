import 'package:flutter/material.dart';

import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// The app hands out two kinds of link, and each is named for who can open it
/// — everywhere, in the same words:
///
/// - **Internal Link** (`copyLinkActionItem`): opens the record in this app, for a
///   colleague who signs in.
/// - **Client Portal Link** / **Vendor Portal Link** (this file): the page the
///   customer or vendor opens, with no account.
///
/// A beta user sent a customer the first believing it was the second: on an
/// invoice both were called "Link", and only the first was in the menu. See
/// `docs/deep-links.md` § The two links are named for who can open them.

/// One person a portal link can be sent to.
@immutable
class PortalLinkTarget {
  const PortalLinkTarget({required this.link, this.name = '', this.email = ''});

  /// The URL exactly as it is to be shared.
  final String link;
  final String name;
  final String email;
}

/// "Client Portal Link" / "Vendor Portal Link" — the noun, as the copy toast
/// and the contact picker's title use it.
String portalLinkNoun(BuildContext context, {required bool vendor}) =>
    context.tr(vendor ? 'vendor_portal_link' : 'client_portal_link');

/// "Share Client Portal Link" on touch, "Copy Client Portal Link" elsewhere —
/// following what the tap does, as the Internal Link's label does.
String portalLinkActionLabel(BuildContext context, {required bool vendor}) =>
    context.tr(
      Env.isTouchPrimary
          ? (vendor ? 'share_vendor_portal_link' : 'share_client_portal_link')
          : (vendor ? 'copy_vendor_portal_link' : 'copy_client_portal_link'),
    );

/// The glyph of a contact row's portal-link button: it shares on touch and
/// copies elsewhere, so it shows which.
IconData portalLinkButtonIcon() =>
    Env.isTouchPrimary ? Icons.share_outlined : Icons.content_copy;

/// The record menu's portal-link item, placed directly above the Internal Link so
/// the two read as a pair.
///
/// Returns null when there is nothing to share yet — no contact with a link,
/// which is a record created offline and not yet synced.
EntityActionItem<A>? portalLinkActionItem<A>({
  required BuildContext context,
  required A kind,
  required bool vendor,
  required bool hasLink,
  required VoidCallback onTap,
}) {
  if (!hasLink) return null;
  return EntityActionItem(
    kind: kind,
    // A globe — the link anyone can open — beside the Internal Link's chain.
    icon: Icons.public,
    label: portalLinkActionLabel(context, vendor: vendor),
    enabled: true,
    // Sharing is not an edit: on the edit screen a tap would save the form
    // first (`EntityActionItem.isNavigationOnly`), so it is not offered there.
    isNavigationOnly: true,
    onTap: onTap,
  );
}

/// Share (touch) or copy (elsewhere) one of [targets]' portal links.
///
/// With several contacts the user picks one: each link is that contact's own,
/// and the portal records a view against whoever's link was opened.
Future<void> sharePortalLink(
  BuildContext context, {
  required bool vendor,
  required List<PortalLinkTarget> targets,
}) async {
  final linked = [
    for (final t in targets)
      if (t.link.isNotEmpty) t,
  ];
  if (linked.isEmpty) {
    Notify.error(context, context.tr('an_error_occurred'));
    return;
  }
  final noun = portalLinkNoun(context, vendor: vendor);
  var target = linked.first;
  if (linked.length > 1) {
    final picked = await showDialog<PortalLinkTarget>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Semantics(header: true, headingLevel: 1, child: Text(noun)),
        children: [
          for (final (i, t) in linked.indexed)
            ListTile(
              title: Text(_title(dialogContext, t, i)),
              subtitle: t.name.isNotEmpty && t.email.isNotEmpty
                  ? LtrText(t.email)
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(t),
            ),
        ],
      ),
    );
    if (picked == null || !context.mounted) return;
    target = picked;
  }
  await shareOrCopyLink(context, target.link, label: noun);
}

String _title(BuildContext context, PortalLinkTarget t, int index) {
  if (t.name.isNotEmpty) return t.name;
  if (t.email.isNotEmpty) return t.email;
  return '${context.tr('contact')} ${index + 1}';
}
