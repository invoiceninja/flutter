import 'package:admin/domain/entity_registry.dart';

/// The app's custom URL scheme. Registered on iOS/macOS (`CFBundleURLTypes`),
/// Android (an `<intent-filter>` per host) and Windows (`msix_config`
/// `protocol_activation` — packaged installs only). Linux registers nothing.
const String kAppLinkScheme = 'invoiceninja';

/// Constant host for *in-app route* links, e.g.
/// `invoiceninja://app/clients/Wpmbk5ezJn?company=Xrtq1oa8Aq`.
///
/// The whole route lives in the URI **path**, never the host, and that is
/// load-bearing: `Uri.parse` lower-cases a reg-name host (`_normalizeRegName`
/// in the SDK's `uri.dart`) but never the path, and entity ids are
/// case-sensitive hashids. Encoding the route as the host would work today
/// only because every `routePath` happens to be lowercase snake_case — a
/// future `/customFields` route would produce a silently dead link rather
/// than a build error. A constant host also keeps this namespace separate
/// from the server-owned OAuth-return hosts ([kCalendarLinkHost]), which lets
/// Android keep host-pinned intent filters instead of claiming the whole
/// scheme.
const String kAppLinkHost = 'app';

/// OAuth-return host used by the calendar connection handshake.
const String kCalendarLinkHost = 'calendar_connection';

/// In-app route for the calendar OAuth return.
const String kCalendarCompleteRoute = '/calendar_connection/complete';

/// Pure decision for `goEntityRecord`'s target path. Extracted so the
/// rule is unit-testable without a widget tree, and kept in this leaf
/// (re-exported from `router.dart`) so link building doesn't have to import
/// the router — and the router's whole UI graph — to reach it.
///
/// Row-click always opens the read-only **view** (detail) screen. The
/// only exception is the no-detail-screen guard: entities that have no
/// detail screen fall back to edit so the route is never dead.
String entityRecordPath({
  required String routePath,
  required String id,
  required bool hasDetailScreen,
}) => hasDetailScreen ? '$routePath/$id' : '$routePath/$id/edit';

/// Shareable deep link to one record, or null when the record isn't
/// linkable.
///
/// Null for a sync-only / `disabled` / routeless entity, for an empty id, for
/// a `tmp_` id (a local-only offline-create id means nothing on another
/// device), and when there's no active company — the company is what lets the
/// recipient's app switch workspaces before it navigates.
///
/// The path is [entityRecordPath], i.e. exactly where tapping the row goes.
/// Deliberately NOT `entityDestination`, whose `user` / `company` / `design`
/// special cases point at the *reader's own* settings screens rather than a
/// record.
String? buildEntityDeepLink({
  required EntityHandlers? handlers,
  required String entityId,
  required String companyId,
}) {
  if (handlers == null || handlers.disabled || handlers.routePath.isEmpty) {
    return null;
  }
  final id = entityId.trim();
  if (!_isPlausibleRecordId(id)) return null;
  final company = companyId.trim();
  if (company.isEmpty) return null;
  return Uri(
    scheme: kAppLinkScheme,
    host: kAppLinkHost,
    path: entityRecordPath(
      routePath: handlers.routePath,
      id: id,
      hasDetailScreen: handlers.detailBuilder != null,
    ),
    queryParameters: {'company': company},
  ).toString();
}

/// Target of a parsed record deep link: an in-app route with **no query
/// string**, plus the company the sender was in (null when the link carries
/// none).
typedef DeepLinkTarget = ({String path, String? companyId});

/// The calendar OAuth return, or null when [uri] isn't one.
///
/// Kept separate from [parseAppDeepLink] because this one must **preserve**
/// its query string: it carries a single-use `handoff` token the completion
/// screen consumes.
String? parseCalendarCompleteLink(Uri uri) {
  final isMatch = uri.host == kCalendarLinkHost
      ? (uri.path == '/complete' || uri.path == '/complete/')
      // Defensive: a future universal-link form ".../calendar_connection/complete".
      : uri.path.endsWith(kCalendarCompleteRoute);
  if (!isMatch) return null;
  return Uri(
    path: kCalendarCompleteRoute,
    queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
  ).toString();
}

/// Validate an incoming record deep link and return where to navigate.
///
/// Returns null for anything unrecognised — and that matters more than it
/// looks: an unmatched `router.go` falls through to go_router's top-level
/// `errorBuilder`, which replaces the WHOLE app with the route-error screen,
/// outside the shell with the sidebar gone. Nothing external may reach `go()`
/// unvalidated.
///
/// Accepted shapes:
///
///   * `invoiceninja://app/<route>` — canonical.
///   * `invoiceninja:/app/<route>` — empty authority; some senders normalise
///     `scheme://x` to `scheme:/x`.
///   * `https://<host>/…/app/<route>` — defensive, so that turning on
///     universal links later is a manifest + entitlement + `.well-known`
///     change with no Dart change.
///
/// `<route>` must be `<routePath>`, `<routePath>/<id>` or
/// `<routePath>/<id>/edit` for a registered, non-`disabled` entity.
///
/// Deliberately NOT checked here: whether the entity's module is enabled for
/// the active company. The router's own redirect already bounces a module-off
/// route to the post-login route with a `?module_off=` notice, which is a
/// better outcome than the silent drop a check here would produce.
DeepLinkTarget? parseAppDeepLink(Uri uri, EntityRegistry registry) {
  final route = _appRouteFrom(uri);
  if (route == null) return null;

  // Longest root first: `/settings/bank_accounts/transaction_rules` nests
  // under `/settings/bank_accounts`, and the shorter root would otherwise
  // claim the nested entity's ids. Same ordering rule as
  // `companySafeLocation`.
  final roots =
      registry.all
          .where((h) => !h.disabled && h.routePath.isNotEmpty)
          .map((h) => h.routePath)
          .toList()
        ..sort((a, b) => b.length.compareTo(a.length));

  for (final root in roots) {
    if (route != root && !route.startsWith('$root/')) continue;
    final rest = route.substring(root.length);
    if (!_isValidRecordSuffix(rest)) return null;
    return (path: '$root$rest', companyId: _companyIdFrom(uri));
  }
  return null;
}

/// `''`, `/<id>` or `/<id>/edit`.
bool _isValidRecordSuffix(String rest) {
  if (rest.isEmpty) return true;
  final segments = rest.split('/')..removeAt(0); // leading '' before the '/'
  if (segments.length > 2) return false;
  if (segments.length == 2 && segments[1] != 'edit') return false;
  return _isPlausibleRecordId(segments.first);
}

/// Shared by [buildEntityDeepLink] and [parseAppDeepLink], deliberately: if
/// build accepted an id that parse rejects, `Copy Link` would report success
/// and hand out a URL the app itself refuses to open.
///
/// `new` is the create route, not a record; a `tmp_` id is local-only to the
/// device that created it and resolves to nothing anywhere else. Everything
/// else must look like a server hashid.
bool _isPlausibleRecordId(String id) {
  if (id.isEmpty || id == 'new' || id.startsWith('tmp_')) return false;
  return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id);
}

String? _companyIdFrom(Uri uri) {
  final raw = uri.queryParameters['company']?.trim() ?? '';
  return raw.isEmpty ? null : raw;
}

/// The in-app route encoded in [uri], normalised, or null when [uri] isn't a
/// link for us. Strips a trailing slash and **drops the entire query string**:
/// a surviving `?company=` (or anything else) would be handed to `go()` and
/// then persisted into `nav_state`, which knows how to strip only
/// `module_off` and `view=full` — so it would be replayed on every cold start.
String? _appRouteFrom(Uri uri) {
  final scheme = uri.scheme.toLowerCase();
  String? path;
  if (scheme == kAppLinkScheme) {
    if (uri.host == kAppLinkHost) {
      path = uri.path;
    } else if (uri.host.isEmpty) {
      path = _afterAppSegment(uri.path);
    }
  } else if (scheme == 'http' || scheme == 'https') {
    path = _afterAppSegment(uri.path);
  }
  if (path == null || !path.startsWith('/')) return null;
  final trimmed = path.length > 1 && path.endsWith('/')
      ? path.substring(0, path.length - 1)
      : path;
  if (trimmed == '/' || trimmed.contains('..')) return null;
  return trimmed;
}

/// The part of [path] after its last `/app` segment, or null when it has none.
String? _afterAppSegment(String path) {
  if (path == '/app') return '/';
  const marker = '/app/';
  final i = path.lastIndexOf(marker);
  if (i < 0) return null;
  return path.substring(i + marker.length - 1);
}
