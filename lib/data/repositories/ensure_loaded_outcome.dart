/// What a single-record hydrate (`ensureLoaded`) found.
///
/// A detail screen opened on a record that is not in the local cache used to
/// have one thing to say when the hydrate did not produce it: "not found".
/// That was true when the server said so, and a confident lie when the device
/// was simply offline — the record exists, it just could not be fetched. The
/// screen now tells the two apart, and offers Retry for the one that can be
/// retried.
///
/// The repository methods that return this are declared `Future<void>` and
/// hand back the template's future unchanged, so the value arrives at any
/// caller that looks for it without every `ensureLoaded` signature changing.
enum EnsureLoadedOutcome {
  /// Already in the local cache; no request was made.
  cached,

  /// Fetched from the server and written to the cache.
  fetched,

  /// The server says there is no such record (or none this user may see).
  missing,

  /// The request never got an answer — offline, DNS, a dropped connection.
  unreachable,

  /// The server answered with something other than the record or "not found"
  /// (a 5xx, a rate limit, a stale token).
  failed,

  /// Nothing to fetch: an empty id, or a local `tmp_` record the server has
  /// not seen yet.
  skipped;

  /// Whether trying again could plausibly succeed.
  bool get isRetryable => this == unreachable || this == failed;
}
