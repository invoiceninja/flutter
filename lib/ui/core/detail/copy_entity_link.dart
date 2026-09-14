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

/// Share a link to one record. The dispatch half of [copyLinkActionItem] —
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

  if (Env.isTouchPrimary && await _shareLink(context, link)) return;
  if (!context.mounted) return;
  // The toast is labelled `link` rather than the URL itself, so it reads
  // "Copied Link to the clipboard" instead of a URL chopped at 40 characters by
  // `ellipsizeForToast`.
  await copyToClipboard(context, link, label: context.tr('link'));
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
/// popover. It is read here, before any await, and that is safe for a reason
/// worth writing down: `guardedOnTap` returns `item.onTap` **unchanged** for an
/// action that isn't `confirm:` (`confirm_action_dialog.dart`), and Copy Link
/// deliberately isn't one — so nothing has run between the tap and this line,
/// and `context` is still the surface that built the menu item (a list row, the
/// detail header). That also makes the rect the right anchor rather than merely
/// a safe one.
Future<bool> _shareLink(BuildContext context, String link) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin = box != null && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
  try {
    await SharePlus.instance.share(
      ShareParams(uri: Uri.parse(link), sharePositionOrigin: origin),
    );
    return true;
  } catch (_) {
    // No platform implementation, no share target, a malformed URI: the
    // clipboard is always available, so fall through to it.
    return false;
  }
}
