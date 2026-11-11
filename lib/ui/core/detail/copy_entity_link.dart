import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:admin/app/entity_links.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Share the Internal Link to one record — the link that opens it in this app, for
/// someone who signs in. The dispatch half of [copyLinkActionItem] —
/// every entity's `<Entity>Actions.dispatch` routes its `copyLink` case here.
///
/// On touch the platform's own answer is the **share sheet**: "copy, leave the
/// app, paste" is three steps for what one tap does, and sharing a record with
/// a colleague is the whole point of the action (invoiceninja/flutter#144).
/// Everywhere else it copies, because a desktop share sheet is either absent or
/// worse than the clipboard. The gate is `Env.isTouchPrimary`, the app's
/// input-device gate — a narrow desktop window still has a mouse.
///
/// The identifiers here stay `copyLink` / `copyEntityLink` on purpose: what
/// changes is presentation, the way `InSizes.touchTarget` branches on the
/// device. Renaming would churn twenty `*_actions.dart` files and both literals
/// `entity_copy_link_coverage_test.dart` greps for, and buy nothing a user can
/// see.
Future<void> copyEntityLink(
  BuildContext context,
  EntityType type,
  String id,
) async {
  final services = context.read<Services>();
  final session = services.auth.session.value;
  final link = buildEntityDeepLink(
    handlers: services.entityRegistry[type],
    entityId: id,
    companyId: session?.currentCompanyId ?? '',
    // Without a base this falls back to the `invoiceninja://` form, which is
    // the right answer when there is no session to build an https link from.
    baseUrl: session?.baseUrl,
  );
  // Nothing linkable (no active company, or a `tmp_` id that slipped past the
  // item's own gate). Say so — silently leaving the clipboard untouched, or
  // worse writing an empty string over what was there, is the one outcome a
  // share action must never have.
  if (link == null) {
    // No await has run yet, so `context` is necessarily still mounted.
    Notify.error(context, context.tr('an_error_occurred'));
    return;
  }

  await shareOrCopyLink(context, link, label: context.tr('internal_link'));
}

/// The share sheet on touch, the clipboard elsewhere: the second half of
/// [copyEntityLink], for a link built another way (a DocuNinja document's,
/// `buildDocuNinjaDeepLink`; a portal link, `sharePortalLink`).
///
/// [label] names which link it is — `tr('internal_link')`, or the portal's noun —
/// and the caller reads it before any await.
Future<void> shareOrCopyLink(
  BuildContext context,
  String link, {
  required String label,
}) async {
  if (Env.isTouchPrimary && await _shareLink(context, link, label)) return;
  if (!context.mounted) return;
  // The toast names the kind of link rather than the URL itself, so it reads
  // "Copied Internal Link to the clipboard" — which link went out, and not a URL
  // chopped at 40 characters by `ellipsizeForToast`.
  await copyToClipboard(context, link, label: label);
}

/// The system share sheet, or false when it couldn't be raised — in which case
/// the caller falls back to the clipboard rather than leaving the user with
/// nothing.
///
/// Only a *throw* counts as "couldn't be raised": no plugin on the other end of
/// the channel, or a platform with no sheet at all. Every returned status means
/// the sheet was shown, including `unavailable` — which does not mean what it
/// looks like (share_plus returns it when the platform shared successfully but
/// can't say which app the user picked, the normal outcome on much of Android).
/// Dismissing counts as handled too: the user saw the sheet and said no, and
/// silently writing the clipboard behind that is not what they asked for.
///
/// `sharePositionOrigin` must be non-null or iPadOS has nowhere to anchor the
/// popover. It is read here, before any await: `guardedOnTap` returns
/// `item.onTap` **unchanged** for an action that isn't `confirm:`
/// (`confirm_action_dialog.dart`), and Copy Link deliberately isn't one, so
/// nothing has run between the tap and this line.
///
/// The context is the *caller's*, and it need not be a box: a list hands its
/// `tileBuilder` the `ListView.builder` item context, whose render object is
/// the `RenderSliverList`. A bare `as RenderBox?` threw there — outside the
/// `try`, inside a fire-and-forget `onTap` — so Share Link from a list row's
/// `⋮` did nothing at all on a phone while the detail screen's worked
/// ([anchorRectFor]).
Future<bool> _shareLink(BuildContext context, String link, String label) async {
  try {
    await SharePlus.instance.share(
      ShareParams(
        uri: Uri.parse(link),
        // The sheet's own heading, where the platform shows one (Android):
        // which of the two links is about to go out.
        title: label,
        sharePositionOrigin: anchorRectFor(context),
      ),
    );
    return true;
  } catch (_) {
    // No platform implementation, no share target, a malformed URI: the
    // clipboard is always available, so fall through to it.
    return false;
  }
}

/// The global rect of [context]'s nearest laid-out [RenderBox] — its own
/// render object when that is a box, else the closest box above it (for a
/// sliver context, the list's viewport) — or null when there is none.
@visibleForTesting
Rect? anchorRectFor(BuildContext context) {
  final own = context.findRenderObject();
  final box = own is RenderBox
      ? own
      : context.findAncestorRenderObjectOfType<RenderBox>();
  if (box == null || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
