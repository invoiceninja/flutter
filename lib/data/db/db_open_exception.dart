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

/// The keychain no longer holds the key that encrypted the local store — a
/// device restored from a backup does not bring `first_unlock_this_device`
/// keychain items with it, and a code-signing change can orphan the item — so
/// the store can never be decrypted again. Reported as the reason a reset
/// salvaged nothing; the store itself is kept as `.unrecovered.<ts>`.
class DatabaseKeyLostException implements Exception {
  const DatabaseKeyLostException();

  @override
  String toString() =>
      'DatabaseKeyLostException: the key that encrypted the local store is '
      'gone from the keychain';
}

/// Another copy of the app has the local store open: a second instance on
/// Linux, whose runner is `G_APPLICATION_NON_UNIQUE`, `open -n` on macOS, or
/// two launches racing Windows' single-instance check. Thrown before the key
/// is read, so that copy neither opens the store nor touches the keychain
/// item that encrypts it (`holdStoreLock`).
///
/// Two copies on one store used to both drain its outbox — each change sent
/// twice — and the second copy's boot screen offered a Reset that moved the
/// store out from under the first, which kept writing to it.
class DatabaseInUseException implements Exception {
  const DatabaseInUseException();

  @override
  String toString() =>
      'DatabaseInUseException: the local data is open in another copy of '
      'the app';
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

/// Why opening the local database failed — the one question
/// `openAppDatabase()` must answer before it decides whether destroying the
/// store could possibly help.
///
/// The store holds the only copy of the user's unsynced work (the outbox,
/// `id_remap`, dirty and `tmp_` rows, local-only saved views), so the default
/// has to be "leave it alone": only [corrupt] and [migrationFailed] are
/// failures a fresh store actually fixes. Everything else — a lock another
/// tab or process holds, a full disk, an error nobody has classified — is at
/// best cured by trying again and at worst unaffected by a reset, and in both
/// cases a reset would have thrown the user's edits away for nothing.
enum DbOpenFailureKind {
  /// Worth retrying as-is: a lock or busy handle (another tab, another
  /// process, a stale browser context), an I/O hiccup, the web open timing
  /// out behind a lock.
  transient,

  /// Another copy of the app has the store open ([DatabaseInUseException]).
  /// A reset would move the store out from under it, and the boot screen
  /// offers none.
  inUse,

  /// The disk or the browser's storage quota is full. Deleting the store
  /// would "work" only by destroying the data that was taking the space.
  storageFull,

  /// SQLite says the file is damaged or is not a database — including the
  /// wrong encryption key, which surfaces as SQLITE_NOTADB on the first read.
  corrupt,

  /// One of our own `onUpgrade` steps threw (see
  /// [DatabaseMigrationException]).
  migrationFailed,

  /// Nothing above matched. Treated like [transient]: an error we cannot name
  /// is not evidence that the data is gone.
  unknown;

  /// Whether a reset (destroy + reopen) is the recovery for this failure.
  bool get resetRecovers =>
      this == DbOpenFailureKind.corrupt ||
      this == DbOpenFailureKind.migrationFailed;
}

/// Thrown by `openAppDatabase()` when the store could not be opened and the
/// failure is one a reset would not fix — see [DbOpenFailureKind]. The store
/// is left exactly as it was, so the user's unsynced work survives to the next
/// attempt; `main` renders a retry screen instead.
///
/// This replaced resetting on every open failure, which destroyed the outbox
/// whenever something merely got in the way — on web, simply having the app
/// open in a second tab (the store's lock makes the open time out).
class DatabaseUnavailableException implements Exception {
  const DatabaseUnavailableException(this.kind, this.cause);

  final DbOpenFailureKind kind;

  /// The underlying error, for the boot screen's detail line and bug reports.
  final Object cause;

  @override
  String toString() => 'DatabaseUnavailableException(${kind.name}): $cause';
}

/// Thrown out of `AppDatabase`'s `onUpgrade` when a migration step fails, so
/// the opener can tell a failed upgrade (a fresh store fixes it) apart from
/// an ordinary error that happened to surface during the open. drift rethrows
/// this exact object from every later query on the connection, which is what
/// lets `classifyDbOpenFailure` see it.
class DatabaseMigrationException implements Exception {
  const DatabaseMigrationException({
    required this.from,
    required this.to,
    required this.cause,
  });

  final int from;
  final int to;
  final Object cause;

  @override
  String toString() => 'DatabaseMigrationException(v$from → v$to): $cause';
}
