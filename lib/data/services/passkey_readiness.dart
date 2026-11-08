import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'package:admin/app/entity_links.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/passkey_authenticator.dart';
import 'package:admin/domain/mobile_app_promo.dart' show isLoopbackHost;

/// The apps' identity in the domain-association files (docs/passkeys.md).
const String kAppleAppId = 'NPC44Y2C98.com.invoiceninja.admin';
const String kAndroidPackage = 'com.invoiceninja.admin';

const String _getLoginCreds = 'delegate_permission/common.get_login_creds';

/// `MainActivity`'s channel for the origins this install presents to a
/// passkey relying party.
const MethodChannel kAppIdentityChannel = MethodChannel(
  'invoice_ninja/app_identity',
);

/// `android:apk-key-hash:<h>` for each certificate this Android install is
/// signed with (`MainActivity.apkKeyHashes`). Empty when it cannot say.
Future<List<String>> androidAppOrigins() async {
  try {
    final hashes = await kAppIdentityChannel.invokeListMethod<String>(
      'apkKeyHashes',
    );
    return [
      for (final hash in hashes ?? const <String>[])
        'android:apk-key-hash:$hash',
    ];
  } on Object catch (_) {
    return const [];
  }
}

/// Which passkey stack a platform uses — they need different things proven.
enum PasskeyPlatform { android, apple, windows, web, none }

/// Whether passkeys can actually work, here, against this server — proven at
/// runtime and failing closed, so the app can ship before the server and
/// hosting changes it depends on are deployed (docs/passkeys.md § Safe until
/// the PRs merge and deploy).
///
/// A ceremony that cannot succeed is worse than no button: a failed Android
/// sign-in counts toward the server's password lockout, and a failed
/// registration leaves the credential the OS already saved orphaned in the
/// user's password manager. So:
///  * **Android** needs the relying party's `assetlinks.json` to grant the app
///    `get_login_creds` ([isReady], which decides whether the button shows),
///    *and* the server to accept this install's origin, which it says by
///    listing it in the options' `android_origins` ([allowsCeremony], checked
///    before the OS sheet opens against the hashes `MainActivity` reports — a
///    server without the fix lists none).
///  * **iOS / macOS** need the hosted relying party's
///    `apple-app-site-association` to list the app under `webcredentials`
///    (the entitlement is compile-time, so a self-hosted domain never can).
///  * **Windows** needs nothing: its WebAuthn API takes any RP ID.
///  * **Web** needs the page to be on the RP ID's host (the browser's rule).
///
/// Any error, non-200 or non-JSON body (an SPA's `index.html`) is "not ready".
class PasskeyReadiness {
  PasskeyReadiness({
    PasskeyAuthenticator authenticator = const PlatformPasskeyAuthenticator(),
    http.Client? client,
    PasskeyPlatform? platform,
    String? pageHost,
    DateTime Function()? now,
    Future<List<String>> Function()? appOrigins,
  }) : _authenticator = authenticator,
       _appOrigins = appOrigins ?? androidAppOrigins,
       _client = client,
       _platform = platform ?? _currentPlatform(),
       _pageHost = pageHost ?? (kIsWeb ? Uri.base.host : ''),
       _now = now ?? DateTime.now;

  final PasskeyAuthenticator _authenticator;
  final http.Client? _client;
  final PasskeyPlatform _platform;
  final String _pageHost;
  final DateTime Function() _now;
  final Future<List<String>> Function() _appOrigins;
  Future<List<String>>? _ownOrigins;

  /// How long an answer stands. A "no" is not permanent — the files appear
  /// when the pull requests deploy — but re-asking on every screen would
  /// fetch two files per visit.
  static const Duration cacheFor = Duration(minutes: 10);

  static const Duration _timeout = Duration(seconds: 5);

  /// Only a yes is remembered: a no can change while the app runs (the user
  /// adds a Google account or a password provider).
  bool _availableSeen = false;
  final Map<String, (DateTime, Future<bool>)> _files = {};

  /// Whether a passkey ceremony can succeed against [apiBaseUrl]. [rpId] is
  /// the relying party the server named in its options; before any options
  /// have been fetched it is inferred (the hosted RP, or the API host).
  Future<bool> isReady({
    required String apiBaseUrl,
    required bool isHosted,
    String? rpId,
  }) async {
    if (_platform == PasskeyPlatform.none) return false;
    final apiHost = Uri.tryParse(apiBaseUrl)?.host.toLowerCase() ?? '';
    final rp = (rpId ?? (isHosted ? kHostedPasskeyRpId : apiHost))
        .toLowerCase();
    if (rp.isEmpty) return false;
    // No app can use a loopback RP. A page on that host can (a developer's
    // local server), and on web the browser enforces the rest.
    if (_platform != PasskeyPlatform.web && isLoopbackRelyingParty(rp)) {
      return false;
    }
    if (!_availableSeen) {
      try {
        _availableSeen = await _authenticator.isAvailable();
      } on Object catch (_) {
        return false;
      }
      if (!_availableSeen) return false;
    }
    switch (_platform) {
      case PasskeyPlatform.windows:
        return true;
      case PasskeyPlatform.web:
        return _pageHost == rp || _pageHost.endsWith('.$rp');
      case PasskeyPlatform.apple:
        if (!isHosted || rp != kHostedPasskeyRpId) return false;
        return _check(
          'https://$rp/.well-known/apple-app-site-association',
          appleAssociationGrantsWebCredentials,
        );
      case PasskeyPlatform.android:
        return _check(
          'https://$rp/.well-known/assetlinks.json',
          assetLinksGrantLoginCredentials,
        );
      case PasskeyPlatform.none:
        return false;
    }
  }

  /// The last check before the OS sheet opens, against the options the server
  /// actually sent: the relying party they name must be one this platform can
  /// use ([isReady] with it), and on Android the server must list an app
  /// origin it will verify.
  Future<bool> allowsCeremony({
    required String apiBaseUrl,
    required bool isHosted,
    required PasskeyLoginOptions options,
  }) async {
    final rp = options.relyingPartyId;
    if (rp.isEmpty) return false;
    if (!await isReady(apiBaseUrl: apiBaseUrl, isHosted: isHosted, rpId: rp)) {
      return false;
    }
    if (_platform != PasskeyPlatform.android) return true;
    // This install's own origin, not just any: a build signed with a key the
    // server does not list (a debug or upload-key build, or config drift)
    // would have its assertion rejected.
    final mine = await (_ownOrigins ??= _appOrigins());
    return options.androidOrigins.any(mine.contains);
  }

  /// [url]'s verdict, from the cache while it is fresh. Only a definitive
  /// answer is cached; a transient failure (offline at launch, a timeout, a
  /// 5xx) is asked again next time rather than hiding passkeys for
  /// [cacheFor].
  Future<bool> _check(String url, bool Function(Object? json) parse) {
    final cached = _files[url];
    if (cached != null && _now().difference(cached.$1) < cacheFor) {
      return cached.$2;
    }
    late final Future<bool> result;
    result = _fetch(url, parse).then((answer) {
      // Evicted before anyone awaiting [result] resumes.
      if (answer == null && identical(_files[url]?.$2, result)) {
        _files.remove(url);
      }
      return answer ?? false;
    });
    _files[url] = (_now(), result);
    return result;
  }

  /// True or false when the server answered: a 200 whose body [parse]
  /// accepts or rejects (an SPA's `index.html` is a rejection), or a 404.
  /// Null when it could not be asked.
  Future<bool?> _fetch(String url, bool Function(Object? json) parse) async {
    final client = _client ?? http.Client();
    try {
      // No redirects: Apple and Google fetch these files without following
      // one, so a redirected file would read as ready and fail on device.
      final request = http.Request('GET', Uri.parse(url))
        ..followRedirects = false;
      final response = await http.Response.fromStream(
        await client.send(request).timeout(_timeout),
      ).timeout(_timeout);
      if (response.statusCode == 404) return false;
      if (response.statusCode != 200) return null;
      try {
        return parse(jsonDecode(response.body));
      } on FormatException {
        return false;
      }
    } on Object catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  static PasskeyPlatform _currentPlatform() {
    if (kIsWeb) return PasskeyPlatform.web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => PasskeyPlatform.android,
      TargetPlatform.iOS || TargetPlatform.macOS => PasskeyPlatform.apple,
      TargetPlatform.windows => PasskeyPlatform.windows,
      _ => PasskeyPlatform.none,
    };
  }
}

/// `apple-app-site-association` lists this app under `webcredentials.apps`.
bool appleAssociationGrantsWebCredentials(Object? json) {
  if (json is! Map) return false;
  final webCredentials = json['webcredentials'];
  if (webCredentials is! Map) return false;
  final apps = webCredentials['apps'];
  return apps is List && apps.contains(kAppleAppId);
}

/// `assetlinks.json` grants this app `get_login_creds`.
bool assetLinksGrantLoginCredentials(Object? json) {
  if (json is! List) return false;
  for (final statement in json) {
    if (statement is! Map) continue;
    final relation = statement['relation'];
    final target = statement['target'];
    if (relation is List &&
        relation.contains(_getLoginCreds) &&
        target is Map &&
        target['namespace'] == 'android_app' &&
        target['package_name'] == kAndroidPackage) {
      return true;
    }
  }
  return false;
}

/// A relying party no app can use: a loopback host — the RP ID a self-hosted
/// server still on `.env.example`'s `REACT_URL` reports. [isLoopbackHost]
/// with the forms an RP ID can take: bare, bracketed or trailing-dot.
bool isLoopbackRelyingParty(String host) {
  var h = host.trim().toLowerCase();
  if (h.startsWith('[') && h.endsWith(']')) h = h.substring(1, h.length - 1);
  while (h.endsWith('.')) {
    h = h.substring(0, h.length - 1);
  }
  if (h.isEmpty) return false;
  return isLoopbackHost(h.contains(':') ? 'https://[$h]' : 'https://$h');
}
