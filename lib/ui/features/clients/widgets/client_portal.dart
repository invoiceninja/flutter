import 'package:flutter/material.dart';

import 'package:admin/ui/core/utils/external_url.dart';

/// Build the client-portal silent auto-login URL for a contact's portal
/// [contactLink]. Mirrors admin-portal (`ClientContactEntity.silentLink`)
/// and React (`useActions`): append `silent=true` (skip the portal login
/// screen) and the client's [clientHash] (auth token). Returns `''` when
/// [contactLink] is empty — that contact has no portal yet (e.g. an unsynced
/// `tmp_` client), so callers should treat empty as "no portal".
String clientPortalUrl({
  required String contactLink,
  required String clientHash,
}) {
  if (contactLink.isEmpty) return '';
  final sep = contactLink.contains('?') ? '&' : '?';
  final base = '$contactLink${sep}silent=true';
  return clientHash.isEmpty ? base : '$base&client_hash=$clientHash';
}

/// Validate ([isSafeWebUrl] — http/https only, no `javascript:`/`file:`/…) and
/// launch [url] in the external browser, surfacing a toast on failure. Shared
/// by the contacts-card *View Portal* button and the top-level Client Portal
/// action so both build + open the portal the same way.
Future<void> launchClientPortal(BuildContext context, String url) =>
    openExternalUrl(context, url);
