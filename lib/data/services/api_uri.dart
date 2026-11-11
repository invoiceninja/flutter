/// The URL of [path] on the server at [baseUrl], keeping [baseUrl]'s own path.
///
/// A self-hosted install can live under a sub-path (`https://host/ninja`).
/// `Uri.parse(baseUrl).resolve('/api/v1/login')` drops that path, because a
/// reference starting with `/` replaces the whole path, so every request went
/// to `https://host/api/v1/login` and a sub-path install could not sign in on
/// any platform. admin-portal appended the route to the full base URL instead
/// (`formatApiUrl`); this does the same, for every request the app builds.
///
/// [path] is a server route (`/api/v1/x`, with or without the leading slash)
/// and may carry its own query (`/api/v1/refresh?first_load=true`), which is
/// kept as written. An absolute [path] (a URL the server handed back) is
/// returned unchanged, as `resolve` did.
Uri apiUri(String baseUrl, String path) {
  final ref = Uri.parse(path);
  if (ref.hasScheme) return ref;
  final base = Uri.parse(baseUrl);
  var basePath = base.path;
  while (basePath.endsWith('/')) {
    basePath = basePath.substring(0, basePath.length - 1);
  }
  final routePath = ref.path.startsWith('/') ? ref.path : '/${ref.path}';
  return Uri(
    scheme: base.scheme,
    userInfo: base.userInfo.isEmpty ? null : base.userInfo,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '$basePath$routePath',
    query: ref.hasQuery ? ref.query : null,
  );
}
