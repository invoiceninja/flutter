/// Storage keys used in `flutter_secure_storage`. The map of `(companyId →
/// token)` is stored as a single JSON blob to keep the secure-storage API
/// minimal.
const String kAuthTokensKey = 'invoiceninja.tokens.v1';
const String kAuthBaseUrlKey = 'invoiceninja.base_url.v1';
const String kAuthIsHostedKey = 'invoiceninja.is_hosted.v1';
const String kAuthCurrentCompanyIdKey = 'invoiceninja.current_company.v1';

/// Identity of the session whose data is currently on disk. Written on every
/// login / refresh; read only by the login entry points, which wipe the local
/// database when a DIFFERENT user or account signs in on this device.
///
/// This exists because an involuntary logout (401, or an idle timeout with
/// unsynced work) deliberately PRESERVES the Drift database — right for the
/// same user coming back, but it means nothing else stands between one user's
/// cached invoices/payments/drafts and the next person to sign in on a shared
/// device. Cross-user isolation used to be in-memory cache clearing alone,
/// which the UI never reads from; this covers the store it does read from.
///
/// Cleared by a destructive `logout()` (the DB is already gone at that point,
/// so a stale identity would only cause a redundant wipe).
const String kAuthUserIdKey = 'invoiceninja.user_id.v1';
const String kAuthAccountIdKey = 'invoiceninja.account_id.v1';

/// Whether the user has opted in to biometric (FaceID / TouchID) gating on
/// cold launch. Persisted as `'true'` / absent; any other value is treated as
/// disabled so a corrupt write can't accidentally enable the gate without an
/// explicit user action.
const String kAuthBiometricEnabledKey = 'invoiceninja.biometric_enabled.v1';

/// Set when the idle session-timeout re-locks a session that still has unsynced
/// outbox work (so the local DB + tokens are preserved instead of wiped — see
/// `AuthRepository.logout(preserveLocalData:)`). On the next `restore()` this
/// forces a re-auth gate before re-entering — biometric if enabled, otherwise a
/// fresh sign-in — instead of silently auto-restoring the prior session. Cleared
/// on successful re-entry. Persisted as `'true'` / absent.
const String kAuthSessionLockedKey = 'invoiceninja.session_locked.v1';

/// Reduce a base URL to a form two spellings of the SAME server share, for
/// the identity comparison in `AuthRepository._wipeIfIdentityChanged`.
///
/// Lower-cases the scheme + host, drops a default port and any trailing
/// slashes, and keeps the path (two installs can legitimately share a host
/// under `/a` and `/b`). Query and fragment are dropped — they are never part
/// of an API root.
///
/// The asymmetry drives the aggressiveness: a false NEGATIVE leaves one
/// server's cache visible to another, which is the leak this is closing; a
/// false POSITIVE wipes a database including its unsent outbox rows. So
/// normalize generously, and on anything unparseable fall back to a trimmed,
/// lower-cased, slash-stripped string rather than guessing.
String canonicalBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final uri = Uri.tryParse(trimmed);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    var s = trimmed.toLowerCase();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
  final scheme = uri.scheme.toLowerCase();
  final isDefaultPort =
      !uri.hasPort ||
      (scheme == 'https' && uri.port == 443) ||
      (scheme == 'http' && uri.port == 80);
  var path = uri.path;
  while (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final authority = isDefaultPort
      ? uri.host.toLowerCase()
      : '${uri.host.toLowerCase()}:${uri.port}';
  return '$scheme://$authority$path';
}

/// Invoice Ninja stores the user-visible company name inside `settings.name`.
/// The top-level `display_name` / `name` fields are typically empty, so they
/// only serve as fallbacks. Mirrors admin-portal's `company_model.dart:528`.
String companyDisplayName({
  required Map<String, dynamic> settings,
  required String displayName,
  required String name,
}) {
  final settingsName = settings['name'];
  if (settingsName is String && settingsName.trim().isNotEmpty) {
    return settingsName;
  }
  if (displayName.isNotEmpty) return displayName;
  if (name.isNotEmpty) return name;
  return 'Untitled';
}

/// `settings.company_logo` carries an absolute URL on self-hosted instances
/// and an Invoice Ninja CDN URL on hosted ones. Empty / missing → null so the
/// avatar falls through to its initials path.
String? companyLogoUrl(Map<String, dynamic> settings) {
  final v = settings['company_logo'];
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return null;
}

/// Appends a cache-busting `v=<updatedAt>` to a resolved logo URL. Invoice
/// Ninja reuses the same `company_logo` URL when a logo is replaced (it
/// overwrites the file at a stable path), so without this (a) the derived
/// `AuthCompany.logoUrl` string wouldn't change, so `_onCompaniesChanged`'s
/// diff never fires and the picker session never re-emits, and (b) the
/// avatar's `Image.network` would serve the stale cached bytes. Mirrors the
/// cache-bust in `logo_screen.dart`. Null / empty in → returned unchanged so
/// the avatar still falls through to its initials path.
String? cacheBustedLogoUrl(String? rawUrl, int updatedAt) {
  if (rawUrl == null || rawUrl.isEmpty) return rawUrl;
  final sep = rawUrl.contains('?') ? '&' : '?';
  return '$rawUrl${sep}v=$updatedAt';
}
