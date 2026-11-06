import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:admin/app/review_prompt_controller.dart';

import 'package:admin/domain/review_prompt.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Opens [channel]'s review page — the store listing, or Capterra — with the
/// standard "Couldn't open the link" toast when nothing opens. Returns
/// whether it opened.
///
/// Call it first thing in a tap handler, before any await: the launcher must
/// run inside the user's gesture, or a browser's popup blocker eats the tab.
Future<bool> openReviewListing(BuildContext context, ReviewChannel channel) {
  final uri = reviewListingUri(channel);
  if (uri == null) return Future.value(false);
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    return openExternalUrl(context, uri.toString());
  }
  // The Microsoft Store's own scheme, which `openExternalUrl`'s http(s)-only
  // gate would refuse; a device without the Store app gets the web listing.
  final toasts = Notify.capture(context);
  final failed =
      Localization.of(context)?.lookup('failed_to_open_url') ??
      'failed_to_open_url';
  final fallback = reviewListingFallbackUri(channel);
  return launchExternalUri(uri).then((opened) async {
    if (opened) return true;
    if (fallback != null && await launchExternalUri(fallback)) return true;
    toasts?.error(failed);
    return false;
  });
}

/// "Rate the app" from About or the command palette: a static link to the
/// review page — never the OS sheet, which a button may not trigger — that,
/// once it opened, stops the automatic asks for good. Call it first thing in
/// the tap; it launches before anything else runs.
void rateAppManually(BuildContext context, ReviewPromptController controller) {
  final opening = openReviewListing(context, controller.channel);
  unawaited(
    opening.then((opened) {
      if (opened) unawaited(controller.noteRatedManually());
    }),
  );
}

/// The name of the place [channel] sends a review, for "Opens :store".
/// Capterra is a brand; the Microsoft Store is translated.
String reviewDestinationName(BuildContext context, ReviewChannel channel) =>
    switch (channel) {
      ReviewChannel.capterra => 'Capterra',
      ReviewChannel.microsoftStore => context.tr('microsoft_store'),
      ReviewChannel.appleStore => context.tr('mac_app_store'),
      ReviewChannel.playStore => context.tr('google_play'),
      ReviewChannel.none => '',
    };
