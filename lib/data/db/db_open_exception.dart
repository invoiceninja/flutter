/// Thrown by the native DB opener when the OS secret store (keychain /
/// keyring) is unreachable, so the per-install SQLCipher key can be neither
/// read nor written — e.g. a Linux snap whose `password-manager-service` plug
/// hasn't been connected (the keyring is locked / libsecret is unavailable).
///
/// Distinct from a corrupt or schema-drifted database: the open orchestrator
/// must NOT reset-and-reopen on this (resetting renames the user's DB file and
/// then re-throws here on the next key fetch, blanking the window on every
/// launch — the original Linux crash-loop). `main` catches it and renders an
/// actionable error screen instead.
class KeyringUnavailableException implements Exception {
  const KeyringUnavailableException(this.message, [this.stackTrace]);

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => 'KeyringUnavailableException: $message';
}

/// Thrown by `openAppDatabase()` when recovery ran but did not produce a
/// usable database: the store was destroyed (or abandoned) and reopened, and
/// the result is *still* missing tables or columns the generated code needs.
///
/// Exists so the reset can stop claiming a success it did not achieve. It used
/// to return `wasReset: true` unconditionally, which on web meant reopening
/// the very store the browser had just refused to delete — the app then ran on
/// a schema-drifted database where every read of `nav_state` threw
/// "Null check operator used on a null value" and every write to `tasks` /
/// `projects` threw `no column named tag_names`, with no way out across
/// reloads. An error screen the user can act on beats that.
class DatabaseResetFailedException implements Exception {
  const DatabaseResetFailedException(this.message);

  final String message;

  @override
  String toString() => 'DatabaseResetFailedException: $message';
}
