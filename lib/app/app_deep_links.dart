import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'package:admin/app/deep_link_router.dart';

/// Bridges OS deep links into the app.
///
/// The OS hands us two shapes. A **record link** a colleague shared, which is
/// now an ordinary `https://<instance>/app/clients/<id>?company=<id>` — a
/// custom scheme is not hyperlinked by any messenger, so that is the only form
/// that survives being sent to someone (invoiceninja/flutter#144) — and reaches
/// us on the one host the manifest and entitlements claim. And the
/// `invoiceninja://` scheme, still carrying the calendar OAuth return
/// (`invoiceninja://calendar_connection/complete?…handoff=…`), every record
/// link already in the wild, and the hand-off from the server's `/app/` bridge
/// page on hosts that can never be verified.
///
/// This class only *transports* them; [DeepLinkRouter] decides what each one
/// means. Covers cold-start (the launching link) and warm (stream) deliveries —
/// though on iOS the cold-start half depends on `SceneDelegate.swift` handing
/// the launch URL over by hand; see docs/upstream-workarounds.md.
///
/// Web has no native hop to intercept, but it does have a link: there the URL
/// the page was loaded from *is* the delivery, so the initial location is read
/// once at boot and handed to [DeepLinkRouter.openWebInitialLocation]. An OAuth
/// return is an ordinary route load, and a link can also arrive by paste (the
/// command palette accepts one).
class AppDeepLinks {
  AppDeepLinks(this._deepLinks) {
    if (kIsWeb) {
      // `Uri.base` is the page here (and a file path under `flutter test`,
      // which never reaches this branch). Everything it decides lives in
      // `openWebInitialLocation`, where it is testable on the VM.
      unawaited(_deepLinks.openWebInitialLocation(Uri.base));
      return;
    }
    try {
      final links = AppLinks();
      _sub = links.uriLinkStream.listen(_handle, onError: (_) {});
      // Cold start: the deep link that launched the app, if any. Note Android
      // ALSO replays this into the stream above; `DeepLinkRouter` de-dups.
      unawaited(
        links
            .getInitialLink()
            .then((uri) {
              if (uri != null) _handle(uri);
            })
            .catchError((_) {}),
      );
    } catch (_) {
      // Deep links are a convenience; never let init crash app boot.
    }
  }

  final DeepLinkRouter _deepLinks;
  StreamSubscription<Uri>? _sub;

  void _handle(Uri uri) => unawaited(_deepLinks.open(uri));

  void dispose() {
    unawaited(_sub?.cancel());
  }
}
