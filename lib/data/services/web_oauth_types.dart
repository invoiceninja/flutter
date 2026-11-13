/// Why a browser sign-in window gave no token, when it wasn't the user
/// closing it (closing it is a null token, not an error).
enum WebOAuthFailure {
  /// The browser refused to open the window. A pop-up blocker, or a window
  /// opened after the tap's user activation ran out.
  blocked,

  /// The provider's script hasn't loaded: still downloading, or blocked by an
  /// extension or a network filter.
  notLoaded,

  /// The provider's script loaded but can't run here (MSAL on a page without
  /// `crypto.subtle`), or never loaded at all. Retrying won't help.
  unavailable,

  /// Anything else; [WebOAuthException.message] says what, for the log.
  failed,
}

class WebOAuthException implements Exception {
  const WebOAuthException(this.failure, [this.message = '']);

  final WebOAuthFailure failure;
  final String message;

  @override
  String toString() => 'WebOAuthException($failure, $message)';
}
