import 'package:flutter/foundation.dart';

import 'package:admin/data/repositories/auth/auth_helpers.dart';

/// The Invoice Ninja server that served this web page, read from the boot page
/// Deploy to Web stages (`tools/web_deploy/index.blade.php`,
/// docs/web-deploy.md). Null everywhere else: native builds, the GitHub Pages
/// demo and `flutter run -d chrome` serve `web/index.html`, which carries no
/// `data-served`.
///
/// When it is set, the login and signup screens use [apiUrl] and nothing else,
/// as admin-portal did with the page's own URL (`WebUtils.apiUrl`): a server's
/// `APP_URL` can be wrong (a LAN address, http behind an https proxy) without
/// locking anyone out of the page that server just served.
@immutable
class ServingServer {
  const ServingServer({
    required this.apiUrl,
    required this.isHosted,
    this.signup = false,
    this.referralCode = '',
    this.whiteLabel = false,
    this.googleClientId = '',
    this.microsoftClientId = '',
    this.appleClientId = '',
  });

  /// The API root, in [canonicalBaseUrl] form. It must be byte-stable across
  /// visits: `AuthRepository` wipes local data when the canonical server of a
  /// new sign-in differs from the stored one.
  final String apiUrl;

  /// The page came from the hosted platform (`data-hosted="1"`).
  final bool isHosted;

  /// The server asked for the signup screen (`?signup=true`).
  final bool signup;

  /// The signup referral code the server passed through (`?rc=`).
  final String referralCode;

  /// A white-labelled self-hosted account: no Invoice Ninja logo before login.
  final bool whiteLabel;

  /// The OAuth client IDs this page signs in with (`data-google-client-id`,
  /// `data-microsoft-client-id`, `data-apple-client-id`), empty for a provider
  /// it doesn't offer. The hosted page carries the hosted platform's public
  /// IDs (`tools/web_deploy/hosted_sign_in.json`); a self-hosted server passes
  /// its own `MICROSOFT_CLIENT_ID` and nothing else (docs/web-deploy.md §
  /// Web sign-in).
  final String googleClientId;
  final String microsoftClientId;
  final String appleClientId;
}

/// [ServingServer] from the boot page's `data-*` attributes ([attribute]) and
/// the page's own location. Null unless the page says it was served
/// (`data-served="1"`).
///
/// The API root is `data-api-url` when the page names one: the hosted page on
/// Cloudflare Pages (`admin.invoicing.co`) is not on the API's host, so its
/// own location says nothing about the server (docs/web-deploy.md § Going
/// live). A value that is not an absolute http(s) URL with a host makes the
/// page unserved rather than guessing, since [canonicalBaseUrl] would turn
/// garbage into a "server" and a later sign-in would wipe the local data over
/// it. Otherwise the API root is the page's origin plus its path, never
/// `document.baseURI` (which ends in the build's `/flutter/` folder), with a
/// trailing `index.php` dropped, then canonicalised:
/// `https://Host:443/index.php?rc=a#/login` and `https://host/` are the same
/// server.
ServingServer? parseServingServer({
  required String? Function(String name) attribute,
  required String origin,
  required String pathname,
}) {
  if (attribute('data-served') != '1') return null;
  final String apiUrl;
  final stated = (attribute('data-api-url') ?? '').trim();
  if (stated.isNotEmpty) {
    final uri = Uri.tryParse(stated);
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      return null;
    }
    apiUrl = canonicalBaseUrl(stated);
  } else {
    var path = pathname;
    if (path.endsWith('index.php')) {
      path = path.substring(0, path.length - 'index.php'.length);
    }
    apiUrl = canonicalBaseUrl('$origin$path');
  }
  if (apiUrl.isEmpty) return null;
  return ServingServer(
    apiUrl: apiUrl,
    isHosted: attribute('data-hosted') == '1',
    signup: attribute('data-signup') == 'true',
    referralCode: (attribute('data-rc') ?? '').trim(),
    whiteLabel: attribute('data-white-label') == '1',
    googleClientId: (attribute('data-google-client-id') ?? '').trim(),
    microsoftClientId: (attribute('data-microsoft-client-id') ?? '').trim(),
    appleClientId: (attribute('data-apple-client-id') ?? '').trim(),
  );
}
