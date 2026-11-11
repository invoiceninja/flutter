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
}

/// [ServingServer] from the boot page's `data-*` attributes ([attribute]) and
/// the page's own location. Null unless the page says it was served
/// (`data-served="1"`).
///
/// The API root is the page's origin plus its path, never `document.baseURI`
/// (which ends in the build's `/flutter/` folder), with a trailing `index.php`
/// dropped, then canonicalised: `https://Host:443/index.php?rc=a#/login` and
/// `https://host/` are the same server.
ServingServer? parseServingServer({
  required String? Function(String name) attribute,
  required String origin,
  required String pathname,
}) {
  if (attribute('data-served') != '1') return null;
  var path = pathname;
  if (path.endsWith('index.php')) {
    path = path.substring(0, path.length - 'index.php'.length);
  }
  final apiUrl = canonicalBaseUrl('$origin$path');
  if (apiUrl.isEmpty) return null;
  return ServingServer(
    apiUrl: apiUrl,
    isHosted: attribute('data-hosted') == '1',
    signup: attribute('data-signup') == 'true',
    referralCode: (attribute('data-rc') ?? '').trim(),
    whiteLabel: attribute('data-white-label') == '1',
  );
}
