import 'package:flutter/material.dart';

import 'package:admin/ui/core/utils/external_url.dart';

/// Build the vendor-portal silent auto-login URL from a contact's portal
/// [contactLink]. The server returns a ready `vendor/key_login/<key>` URL that
/// already authenticates; append `silent=true` to skip the portal landing
/// (mirrors `clientPortalUrl`). Returns `''` when [contactLink] is empty — that
/// contact has no portal yet (e.g. an unsynced `tmp_` vendor).
String vendorPortalUrl({required String contactLink}) {
  if (contactLink.isEmpty) return '';
  final sep = contactLink.contains('?') ? '&' : '?';
  return '$contactLink${sep}silent=true';
}

/// Validate ([isSafeWebUrl] — http/https only) and launch [url] in the external
/// browser, surfacing a toast on failure. Mirror of `launchClientPortal`.
Future<void> launchVendorPortal(BuildContext context, String url) =>
    openExternalUrl(context, url);
