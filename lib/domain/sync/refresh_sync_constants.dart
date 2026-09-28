/// Tuning constants for the `/api/v1/refresh` delta-sync engine. Mirrors the
/// legacy admin-portal's sync cadence (its `lib/constants.dart`):
///   * `kMillisecondsToTimerRefreshData = 5 min`
///   * `kUpdatedAtBufferSeconds = 600`
///   * `kMillisecondsToRefreshStaticData = 24 h`
///
/// Kept in one place so the auth layer and the foreground refresh scheduler
/// agree on the numbers.
library;

/// Subtracted from a company's stored `last_sync_at` before it's sent as the
/// `updated_at` query param, so a clock skew / in-flight write that landed
/// server-side around the previous refresh isn't missed. v1 used 600 s.
const int kUpdatedAtBufferSeconds = 600;

/// The static catalog (currencies, countries, …) changes rarely. A delta
/// refresh only re-requests it (`include_static=true`) when the cached blob
/// is older than this. v1 used 24 h.
const Duration kStaticsStaleAfter = Duration(hours: 24);

/// Foreground auto-refresh period. While the app is active and authenticated
/// the scheduler fires a delta refresh on this cadence. v1 used 5 min.
const Duration kRefreshInterval = Duration(minutes: 5);

/// De-dup window between scheduler-driven refreshes — its only job is to
/// stop an app-resume that lands moments after a periodic tick (or vice
/// versa) from double-firing. It must stay **well below** [kRefreshInterval]:
/// the gap is measured from refresh *completion* while the periodic timer
/// schedules from tick start, so a value equal to the interval would suppress
/// essentially every periodic tick (each lands ~`interval − refreshDuration`
/// after the previous completion). The interval itself is the cadence
/// throttle, mirroring v1's timer.
const Duration kMinRefreshGap = Duration(minutes: 1);

/// Quiet period before a pushed "something changed" event (hosted real-time
/// updates, `RealtimeService`) becomes a delta refresh, so a burst of events —
/// a bulk action, a payment that marks three invoices paid — costs one request.
const Duration kPushRefreshDebounce = Duration(seconds: 2);

/// Floor between two push-driven refreshes. Under [kMinRefreshGap] — a push is
/// a *reason* to refresh — but each one is a full `/refresh` (company envelope,
/// reference bundles and roster rewritten in one transaction), so a busy
/// account's stream of portal views must not become one per event. 30 s caps
/// an open client at two a minute, matching the dashboard's own refetch gap;
/// the first change after a quiet spell still lands in about the debounce.
const Duration kMinPushRefreshGap = Duration(seconds: 30);
