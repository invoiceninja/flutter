/// The minimum set of credentials the API client needs to make an
/// authenticated request. The auth layer (M1.8) populates this; the API
/// client only reads it.
///
/// Deliberately declares no `operator ==`. `AuthRepository` holds these in a
/// `ValueNotifier` that the router listens to via `refreshListenable`, and
/// `ValueNotifier` only notifies when `_value != newValue` — so value equality
/// would silently swallow a credentials change whenever two instances happened
/// to compare equal. Identity equality means every assignment notifies.
class ApiCredentials {
  const ApiCredentials({
    required this.baseUrl,
    required this.token,
    this.apiSecret = '',
    this.isHosted = false,
    this.companyId = '',
  });

  /// e.g. `https://invoicing.co` or a self-hosted URL.
  final String baseUrl;

  /// The user's API token. Empty means unauthenticated.
  final String token;

  /// `X-API-SECRET` value — sent on hosted builds only.
  final String apiSecret;

  /// True when talking to the hosted Invoice Ninja server.
  final bool isHosted;

  /// The company these credentials authenticate as — [token] is a *per-company*
  /// token, so this is the only thing that ties a request back to a workspace.
  /// Never sent on the wire; it exists so a 401 can be attributed to the
  /// company whose token was rejected rather than to the whole session (see
  /// `AuthRepository.handleUnauthorized`) and so the diagnostics log can name
  /// it. Empty on credentials built outside the auth layer (tests).
  final String companyId;

  bool get isAuthenticated => token.isNotEmpty && baseUrl.isNotEmpty;
}
