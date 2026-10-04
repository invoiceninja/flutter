import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/deep_link_router.dart';
import 'package:admin/app/entity_links.dart';

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
/// On **Android** the OS never hands a link to MainActivity: the manifest
/// routes every VIEW intent to the engine-free `DeepLinkReceiverActivity`,
/// which passes the URI over in-process and brings MainActivity forward with a
/// launcher-shaped intent (a link delivered to MainActivity itself can start a
/// second one — docs/deep-links.md). So there this class also *pulls* those
/// links over [kChannel] — at construction, on the native `linksAvailable`
/// ping, and on every resume — exactly as `AppShareIntake` pulls shares.
/// `app_links` stays subscribed everywhere: it is still the path on iOS, macOS
/// and Windows, and on Android only an explicit VIEW sent straight to the
/// exported MainActivity reaches it, which [DeepLinkRouter] validates as ever.
///
/// Web has no native hop to intercept, but it does have a link: there the URL
/// the page was loaded from *is* the delivery, so the initial location is read
/// once at boot and handed to [DeepLinkRouter.openWebInitialLocation]. An OAuth
/// return is an ordinary route load, and a link can also arrive by paste (the
/// command palette accepts one).
class AppDeepLinks with WidgetsBindingObserver {
  /// [onShareHandoff] runs for the iOS Share Extension's
  /// `invoiceninja://share` ([isShareHandoffLink]) instead of handing it to
  /// [DeepLinkRouter] — it means "files are waiting", not "go somewhere".
  ///
  /// [pullsLinks] defaults to "on Android"; [subscribe] to "anywhere but
  /// web" (tests turn the `app_links` plugin off).
  AppDeepLinks(
    this._deepLinks, {
    VoidCallback? onShareHandoff,
    MethodChannel linkChannel = kChannel,
    bool? pullsLinks,
    bool subscribe = true,
  }) : _onShareHandoff = onShareHandoff,
       _linkChannel = linkChannel,
       _pullsLinks = pullsLinks ?? _platformForwardsLinks {
    if (kIsWeb) {
      // `Uri.base` is the page here (and a file path under `flutter test`,
      // which never reaches this branch). Everything it decides lives in
      // `openWebInitialLocation`, where it is testable on the VM.
      unawaited(_deepLinks.openWebInitialLocation(Uri.base));
      return;
    }
    if (_pullsLinks) {
      _linkChannel.setMethodCallHandler(_onLinkCall);
      WidgetsBinding.instance.addObserver(this);
      unawaited(pullLinks());
    }
    if (!subscribe) return;
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

  /// Hard-coded on the native side too: `MainActivity.kt`.
  static const kChannel = MethodChannel('invoice_ninja/deep_links');

  static bool get _platformForwardsLinks =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final DeepLinkRouter _deepLinks;
  final VoidCallback? _onShareHandoff;
  final MethodChannel _linkChannel;
  final bool _pullsLinks;
  final _log = Logger('AppDeepLinks');
  StreamSubscription<Uri>? _sub;

  /// Serialises pulls, as `AppShareIntake.pull` does.
  Future<void> _pulling = Future.value();

  /// Take the links Android's `DeepLinkReceiverActivity` handed over and route
  /// each. Never throws.
  Future<void> pullLinks() {
    if (!_pullsLinks) return Future.value();
    return _pulling = _pulling.then((_) => _pullOnce());
  }

  Future<void> _pullOnce() async {
    final List<String>? links;
    try {
      links = await _linkChannel.invokeListMethod<String>('takeLinks');
    } on MissingPluginException {
      return; // A host without the native half (tests, an older build).
    } catch (e, st) {
      _log.warning('takeLinks failed', e, st);
      return;
    }
    for (final link in links ?? const <String>[]) {
      final uri = Uri.tryParse(link);
      if (uri != null) _handle(uri);
    }
  }

  Future<void> _onLinkCall(MethodCall call) async {
    if (call.method == 'linksAvailable') await pullLinks();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(pullLinks());
  }

  void _handle(Uri uri) {
    if (isShareHandoffLink(uri)) {
      _onShareHandoff?.call();
      return;
    }
    unawaited(_deepLinks.open(uri));
  }

  void dispose() {
    unawaited(_sub?.cancel());
    if (_pullsLinks && !kIsWeb) {
      _linkChannel.setMethodCallHandler(null);
      WidgetsBinding.instance.removeObserver(this);
    }
  }
}
