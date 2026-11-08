/// Why a passkey ceremony did not produce a credential.
enum PasskeyFailure {
  /// The user dismissed the OS sheet. Not an error to show.
  cancelled,

  /// The app is not associated with the relying party's domain (no
  /// `webcredentials` / `get_login_creds` entry there), or the OS has not
  /// fetched it yet.
  notAssociated,

  /// No passkey for this account is available on this device.
  noCredentials,

  /// This device already holds one of the account's passkeys
  /// (`excludeCredentials` matched).
  alreadyRegistered,

  /// The device or OS cannot use passkeys here (too old, no provider, no
  /// Google account, …).
  unsupported,

  /// Anything else: a timeout, a failed verification, an unknown platform
  /// error. [PasskeyException.message] carries the platform's text.
  failed,
}

/// A passkey ceremony that ended without a credential.
class PasskeyException implements Exception {
  const PasskeyException(this.failure, [this.message]);

  final PasskeyFailure failure;
  final String? message;

  @override
  String toString() =>
      'PasskeyException($failure${message == null ? '' : ': $message'})';
}
