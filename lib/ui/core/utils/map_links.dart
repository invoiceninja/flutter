import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:admin/ui/core/utils/external_url.dart';

/// The https URL that shows [address] on a map.
///
/// Apple Maps on Apple platforms, Google Maps everywhere else — each opens in
/// its own app where one is installed and in the browser where it is not.
/// Both are plain `https`, so the launch goes through `openExternalUrl` and
/// its `isSafeWebUrl` gate like every other outbound link; nothing here needs
/// a scheme exemption.
///
/// [address] is a free-text query, so pass the whole thing *including the
/// country*: a street and a city alone resolve to whichever "Springfield" the
/// provider likes best.
Uri mapSearchUri(String address) {
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return Uri.https('maps.apple.com', '/', {'q': address});
    case TargetPlatform.android:
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': address,
      });
  }
}

/// Opens [address] on a map. Toasts "couldn't open the link" on failure, like
/// any other external link.
Future<bool> openMapFor(BuildContext context, String address) =>
    openExternalUrl(context, mapSearchUri(address).toString());
