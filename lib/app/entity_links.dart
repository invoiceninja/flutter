import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';

/// Entity types whose `routePath` is a **settings screen, not an addressable
/// `<root>/<id>` record route**. Both link building and link parsing must
/// refuse them.
///
/// `EntityHandlers.routePath` alone does not tell you which, and
/// `!disabled && routePath.isNotEmpty` is not the test — `user` and `company`
/// are registered directly in `Services.build` rather than as
/// `EntityModuleSpec`s, so they carry neither flag:
///
///   * `user` → `/settings/account`, which is **not a route at all** (the
///     real one is `/settings/account_management`);
///   * `company` → `/settings/company_details`, whose only children are the
///     tab slugs `address|logo|defaults|documents`;
///   * `design` → `/settings/invoice_design/custom_designs`, a tab slug too —
///     custom designs are edited in a modal (`showDesignEditScreen`). It is
///     `disabled: true` today, so the old filter happened to catch it; listed
///     here so promoting it to `kWiredEntityModules` can't silently reopen
///     this.
///
/// Handing any of those to `go()` matches nothing, and go_router's top-level
/// `errorBuilder` then replaces the WHOLE app with the route-error screen —
/// outside the shell, sidebar gone. `entityDestination`
/// (`lib/ui/core/detail/entity_destination.dart`) special-cases the same three
/// for the same reason; it answers "where should this type go instead", which
/// is a different question from this one and is why it can't be reused here.
const Set<EntityType> kNonRecordRouteEntityTypes = {
  EntityType.user,
  EntityType.company,
  EntityType.design,
};

/// Whether a record of [type] can be addressed as `<routePath>/<id>` — i.e.
/// whether a deep link to one can exist at all. See
/// [kNonRecordRouteEntityTypes].
bool entityTypeHasRecordRoute(EntityType type) =>
    !kNonRecordRouteEntityTypes.contains(type);

/// The app's custom URL scheme. Registered on iOS/macOS (`CFBundleURLTypes`),
/// Android (an `<intent-filter>` per host) and Windows (`msix_config`
/// `protocol_activation` — packaged installs only). Linux registers nothing.
const String kAppLinkScheme = 'invoiceninja';

/// Constant host for *in-app route* links, e.g.
/// `invoiceninja://app/clients/Wpmbk5ezJn?company=Xrtq1oa8Aq`, and — as
/// [kAppLinkPathPrefix] — the first path segment of the https form,
/// `https://invoicing.co/app/clients/Wpmbk5ezJn?company=Xrtq1oa8Aq`.
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

/// The https form's path prefix — the same segment as [kAppLinkHost], derived
/// from it so the two can never drift.
///
/// It is what makes the OS claim **scoped**: Android matches an `<intent-filter>`
/// on scheme/host/path, so `pathPrefix="/app/"` claims shared links and nothing
/// else on the host. `invoicing.co` also serves the client portal and payment
/// pages, and a host-wide claim would hijack them.
const String kAppLinkPathPrefix = '/$kAppLinkHost';

/// The one host whose https links the OS can hand us: Android's
/// `<intent-filter>` and Apple's `applinks:` entitlement both need a literal at
/// build time, so a self-hosted origin can never be verified.
///
/// Those links still work — they route through the server's `/app/` bridge
/// page, which offers the `invoiceninja://` launch and then falls through to the
/// web client. See `APP_LINKS.md`. Pinned against `Env.hostedApiUrl`, the
/// manifest and both entitlements by `test/lint/universal_links_test.dart`.
const String kHostedAppLinkHost = 'invoicing.co';

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

/// The https origin (plus any sub-path) a shareable link is built on, or null
/// when [baseUrl] can't carry one.
///
/// Named *base* rather than *origin* because it keeps a sub-path: a
/// self-hosted install at `https://example.com/invoiceninja` is real, and
/// [parseAppDeepLink] already accepts that shape.
///
/// `Uri.origin` does most of the work and is stdlib-tested — it lower-cases
/// scheme and host, **drops `userInfo`** (a credentialed base URL must never
/// reach the clipboard), drops a default port while keeping a non-default one,
/// and brackets IPv6 — and it throws only for the two cases rejected above it.
///
/// Deliberately NOT `canonicalBaseUrl` (`lib/data/repositories/auth/`): that is
/// a data-layer file, so importing it would drag the data layer into this leaf,
/// and its contract is tuned so that a false positive wipes a database — the
/// wrong bias for a URL someone is about to share. Nor `connectBankUrl`, which
/// strips the **first** `/api/v1` anywhere in the string rather than a trailing
/// segment.
///
/// `http` is accepted: LAN self-hosting is real (`resolveSelfHostedBaseUrl`
/// permits it), and such a link can never be an App Link anyway, which costs
/// nothing because its host is unverifiable either way.
String? appLinkBaseFrom(String? baseUrl) {
  final raw = baseUrl?.trim() ?? '';
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  var path = _withoutTrailingSlashes(uri.path);
  const apiSuffix = '/api/v1';
  if (path.toLowerCase().endsWith(apiSuffix)) {
    path = _withoutTrailingSlashes(
      path.substring(0, path.length - apiSuffix.length),
    );
  }
  return '${uri.origin}$path';
}

String _withoutTrailingSlashes(String path) {
  var end = path.length;
  while (end > 0 && path[end - 1] == '/') {
    end--;
  }
  return path.substring(0, end);
}

/// Shareable deep link to one record, or null when the record isn't
/// linkable.
///
/// Two shapes, one grammar. With a usable [baseUrl] this is the **https** form,
/// `<base>/app/<route>?company=<id>` — the only kind a messenger will linkify,
/// which is the whole of invoiceninja/flutter#144, and the only kind an OS can
/// hand back to the app. Without one it falls back to the `invoiceninja://`
/// form, which is what every link already in the wild looks like.
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
  String? baseUrl,
}) {
  if (handlers == null ||
      handlers.disabled ||
      handlers.routePath.isEmpty ||
      // Symmetry with `parseAppDeepLink` is the point: building a link the
      // app itself refuses to open would report success from Copy Link and
      // hand out a URL that blanks the recipient's app.
      !entityTypeHasRecordRoute(handlers.type)) {
    return null;
  }
  final id = entityId.trim();
  if (!_isPlausibleRecordId(id)) return null;
  final company = companyId.trim();
  if (company.isEmpty) return null;
  final route = entityRecordPath(
    routePath: handlers.routePath,
    id: id,
    hasDetailScreen: handlers.detailBuilder != null,
  );
  final query = {'company': company};
  final base = appLinkBaseFrom(baseUrl);
  if (base != null) {
    // Through `Uri.replace`, never interpolation: it percent-encodes the id and
    // keeps a sub-path install's own path ahead of the prefix. `Uri.resolve`
    // would eat that path's last segment instead.
    final origin = Uri.parse(base);
    return origin
        .replace(
          path: '${origin.path}$kAppLinkPathPrefix$route',
          queryParameters: query,
        )
        .toString();
  }
  return Uri(
    scheme: kAppLinkScheme,
    host: kAppLinkHost,
    path: route,
    queryParameters: query,
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
///   * `https://<host>/…/app/<route>` — what [buildEntityDeepLink] now emits,
///     and what the OS hands back for a verified App Link / Universal Link.
///     The host is deliberately not checked here: only [kHostedAppLinkHost] can
///     ever be verified, but a self-hosted link reaches us through that
///     instance's own bridge page, and `DeepLinkRouter` is where a link
///     belonging to another server is caught.
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
          .where(
            (h) =>
                !h.disabled &&
                h.routePath.isNotEmpty &&
                // Not every registered `routePath` is a record route. Without
                // this, `/settings/account` and `/settings/company_details/<id>`
                // parse as valid targets and reach `go()`, which matches
                // nothing and replaces the whole app with the route-error
                // screen. See [kNonRecordRouteEntityTypes].
                entityTypeHasRecordRoute(h.type),
          )
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

/// The part of [path] after its last [kAppLinkPathPrefix] segment, or null when
/// it has none.
///
/// The **last**, so a sub-path install (`https://example.com/app/app/clients/x`,
/// for a site that itself lives at `/app`) resolves to the route rather than to
/// the host's own prefix.
String? _afterAppSegment(String path) {
  if (path == kAppLinkPathPrefix) return '/';
  const marker = '$kAppLinkPathPrefix/';
  final i = path.lastIndexOf(marker);
  if (i < 0) return null;
  return path.substring(i + marker.length - 1);
}
