import 'package:flutter/foundation.dart';

import 'package:admin/data/models/api/activity_api_model.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/services/api_client.dart';

/// How many of the most-recent company activity rows one user-activity screen
/// load pulls down before filtering to a single actor. The `?reactv2` branch is
/// unpaginated (`->take($rows)`), so this is the whole scan window — see
/// [ActivitiesApi.fetchUserActivities].
///
/// Sibling of `kActivityFeedRows` in `dashboard_api.dart`, which sizes the
/// company-wide feed behind the dashboard card and the `/activity` screen.
const int kUserActivityScanRows = 250;

/// How many rows one `POST /activities/entity` call asks for.
///
/// The endpoint's window is over **all** activity for the record, not just the
/// notes — `ActivityController::entityActivity` runs
/// `orderBy('created_at','DESC')->take($rows)` and only then does the app filter
/// to `activity_type_id == 141` — so on a record whose newest rows are all
/// invoice-created / email-sent / payment-applied, a comment falls out of the
/// window entirely and the Comments surfaces render a silent zero. The server
/// default is 75. Widening to 200 does not *fix* that (only a server-side
/// notes filter can — see BACKEND.md) but moves the cliff out by 2.7× for one
/// bounded payload.
///
/// Sibling of [kUserActivityScanRows] and `kActivityFeedRows`.
const int kEntityActivityRows = 200;

/// How long a per-entity feed stays worth painting on sight.
///
/// Short on purpose: the cache exists to make a re-opened record paint
/// instantly, **not** to skip the network — see [ActivitiesApi.fetchForEntity].
@visibleForTesting
const Duration kEntityActivityCacheTtl = Duration(minutes: 2);

/// Cap on the per-entity feed cache.
///
/// Deliberately far smaller than `BaseEntityRepository.peekCacheLimit` (128):
/// an entry here is up to [kEntityActivityRows] denormalized activity rows, not
/// one domain object, and the only case it needs to cover is "step back onto a
/// record I just left". `MasterDetailLayout`'s J/K binding walks a whole list,
/// so an unbounded map would grow one entry per row visited.
@visibleForTesting
const int kEntityActivityCacheLimit = 24;

/// One cached per-entity feed plus the instant it landed.
class _FeedCacheEntry {
  _FeedCacheEntry(this.rows, this.at);
  final List<ActivityApi> rows;
  final DateTime at;
}

/// API for the `/api/v1/activities/*` family. Two endpoints, neither
/// rooted on a per-entity path — `BaseEntityApi` doesn't fit, so this
/// service wraps `ApiClient` directly.
///
/// The endpoints differ in the singular/plural form of `entity`:
/// `/notes` (the write) wants `"clients"`; `/entity` (the read) wants
/// `"client"`. Confirmed against demo.invoiceninja.com and matches both
/// legacy admin-portal and the React reference client.
class ActivitiesApi {
  ActivitiesApi(this.client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ApiClient client;
  final DateTime Function() _now;

  /// Per-entity feed cache. Insertion-ordered, so the oldest key is the first
  /// one `keys.first` yields — the same LRU shape `BaseEntityRepository`
  /// uses for `_lastSeen`.
  final Map<String, _FeedCacheEntry> _feedCache = <String, _FeedCacheEntry>{};

  /// In-flight [fetchForEntity] calls, so N observers of the same record issue
  /// one request. Mirrors `BaseEntityRepository._ensureInFlight`.
  final Map<String, Future<List<ActivityApi>>> _feedInFlight =
      <String, Future<List<ActivityApi>>>{};

  /// Bumped by [clearCache]. A request already on the wire when the session
  /// ends completes *after* the wipe, and would otherwise write the previous
  /// user's rows straight back into the emptied map. `_ensureInFlight` has no
  /// such hazard because its result lands in Drift; a value cache does.
  int _feedGeneration = 0;

  /// The cache is keyed by the credential fingerprint, not by company: the
  /// endpoint narrows its result to the acting user for anyone who
  /// `cannot('view', $entity)`, so two users on the same install legitimately
  /// get different rows for the same record.
  String _feedKey(String entity, String entityId) =>
      '${client.credentialFingerprint}/$entity/$entityId';

  /// `POST /api/v1/activities/notes` — append a user comment to [entity]'s
  /// activity stream. The server creates an Activity row with
  /// `activity_type_id = 141`. Response body is discarded.
  Future<void> addNote({
    required String entity,
    required String entityId,
    required String notes,
    required String idempotencyKey,
  }) async {
    await client.mutate(
      method: 'POST',
      path: '/api/v1/activities/notes',
      idempotencyKey: idempotencyKey,
      body: {'entity': entity, 'entity_id': entityId, 'notes': notes},
    );
    // Drop the WHOLE feed cache, not just this record's entry, and note that
    // this runs at *drain* time — so an offline comment landing minutes later
    // invalidates too, and a comment written from a list row's `⋯` menu (where
    // no detail screen is mounted) can't leave a stale feed behind it.
    //
    // Whole-cache because a note fans out: `ActivityController::note()` copies
    // `client_id` off the parent, so a comment filed on an invoice also lands
    // in that invoice's *client's* feed. Invalidating one key would leave the
    // client's copy stale, and the mapping needed to find it is exactly the
    // sort of thing that fails silently ([entity] here is the PLURAL wire name,
    // `fetchForEntity` takes the singular). Comments are rare and the cache
    // holds at most [kEntityActivityCacheLimit] entries, so the cost is a
    // handful of re-fetches that were going to happen anyway.
    clearCache();
  }

  /// The cached feed for [entity]/[entityId] if one landed within
  /// [kEntityActivityCacheTtl], else null.
  ///
  /// A **first-frame seed only**, the same contract as
  /// `BaseEntityRepository.peek`: callers paint it and then call
  /// [fetchForEntity] anyway. Never branch on it.
  List<ActivityApi>? peekForEntity({
    required String entity,
    required String entityId,
  }) {
    final key = _feedKey(entity, entityId);
    final hit = _feedCache[key];
    if (hit == null) return null;
    if (_now().difference(hit.at) > kEntityActivityCacheTtl) {
      _feedCache.remove(key);
      return null;
    }
    // Refresh recency so the LRU evicts what nobody is revisiting.
    _feedCache
      ..remove(key)
      ..[key] = hit;
    return hit.rows;
  }

  /// Drop every cached feed. Wired into the logout fan-out in `Services`:
  /// these rows carry comment bodies, author names and IP addresses, and a
  /// second user signing in on the same install must not inherit them.
  void clearCache() {
    _feedGeneration++;
    _feedCache.clear();
    _feedInFlight.clear();
  }

  /// `POST /api/v1/activities/entity` — fetch the activity stream for a
  /// single entity. Returns the rich denormalized form with `user.label`,
  /// `client.label`, `invoice.label` populated, so callers can render names
  /// without joining against a users table.
  ///
  /// **Always hits the network.** The cache behind [peekForEntity] is
  /// stale-while-revalidate, never a fetch suppressor: these rows back a
  /// comments surface whose whole point is "view it and others", and a cache
  /// that skipped the request would make a colleague's comment arrive late —
  /// the one failure that surface cannot have. What the cache buys is an
  /// instant first paint on a record you just left.
  ///
  /// Concurrent callers for the same record share one request. That matters
  /// because `MasterDetailLayout` binds J/K/↑/↓ to step through a list and the
  /// router re-keys the detail subtree per `:id`, so a held key would otherwise
  /// issue one uncancelled POST per repeat.
  Future<List<ActivityApi>> fetchForEntity({
    required String entity,
    required String entityId,
    int rows = kEntityActivityRows,
  }) {
    final key = _feedKey(entity, entityId);
    final inFlight = _feedInFlight[key];
    if (inFlight != null) return inFlight;

    final generation = _feedGeneration;
    final future = _fetchForEntityUncached(
      entity: entity,
      entityId: entityId,
      rows: rows,
    );
    _feedInFlight[key] = future;
    return future
        .whenComplete(() {
          // `identical`, not a bare `remove`: `addNote` calls `clearCache()` on
          // every comment, so a *newer* request for the same record is routinely
          // registered while an older one is still on the wire. An unconditional
          // remove would evict the newer entry when the older future settled,
          // turning the dedupe off for the rest of its flight and letting the
          // slower of two overlapping responses win the cache.
          if (identical(_feedInFlight[key], future)) _feedInFlight.remove(key);
        })
        .then((parsed) {
          // A session that ended while this was on the wire already emptied the
          // map; writing here would resurrect the previous user's rows.
          if (generation == _feedGeneration) _remember(key, parsed);
          return parsed;
        });
  }

  Future<List<ActivityApi>> _fetchForEntityUncached({
    required String entity,
    required String entityId,
    required int rows,
  }) async {
    final raw = await client.postJson(
      '/api/v1/activities/entity',
      readOnly: true,
      body: {'entity': entity, 'entity_id': entityId, 'rows': rows},
    );
    if (raw is! Map<String, dynamic>) return const [];
    final parsed = ActivityListApi.fromJson(raw);
    return parsed.data;
  }

  void _remember(String key, List<ActivityApi> rows) {
    _feedCache
      ..remove(key)
      ..[key] = _FeedCacheEntry(rows, _now());
    while (_feedCache.length > kEntityActivityCacheLimit) {
      _feedCache.remove(_feedCache.keys.first);
    }
  }

  /// `GET /api/v1/activities?reactv2` — the denormalized company activity
  /// feed, filtered **client-side** down to [userId] (FEATURES "User activity
  /// log" / "User action audit trail").
  ///
  /// The server has no `user_id` filter on `/activities`: there is no
  /// `ActivityFilters` class, `Activity` doesn't use the `Filterable` trait,
  /// and `QueryFilters::apply` skips unknown params silently — so the endpoint
  /// returns the whole company feed no matter what is passed. That was
  /// invoiceninja/flutter#45: every user's Activity section listed every
  /// action. See BACKEND.md for the server-side ask.
  ///
  /// Two consequences shape this method:
  ///
  /// * It uses the `reactv2` branch rather than the flat `ActivityTransformer`
  ///   shape, because its nested `{label, hashed_id}` objects carry each row's
  ///   **true** actor. That is what makes the local filter honest, and it lets
  ///   `ActivityFormatter` render real names instead of localized nouns. On a
  ///   server predating that branch the response falls back to the flat shape,
  ///   where `DashboardActivity.refId` reads the equivalent flat `user_id` —
  ///   attribution still holds, the labels degrade to localized nouns, and the
  ///   actor-less rows below come back (the flat shape has no way to tell them
  ///   apart). Acceptable: that branch is below the client-version floor.
  /// * That branch is unpaginated (`->take($rows)`), so [scanRows] is the whole
  ///   window: a rarely-active user in a very busy account can legitimately
  ///   come back empty. That resolves itself once the server filter lands.
  ///
  /// **Rows that name no human actor are excluded, deliberately.**
  /// `Activity::activity_string()` scans the `activity_<N>` template for
  /// `:tokens` and emits a `{label, hashed_id}` object only for the ones it
  /// finds — so the 34-of-120 templates with no `:user` (`:contact viewed
  /// invoice :invoice`, `System failed to email invoice :invoice`, `Statement
  /// sent to :client`, …) arrive with no `user` object at all and drop out
  /// here. Those rows do carry the *record owner* in the `activity.user_id`
  /// column, but the owner didn't do them; surfacing them under that person's
  /// name would be the same misattribution this method exists to fix. Don't
  /// "restore" them by falling back to a flat `user_id`.
  Future<List<DashboardActivity>> fetchUserActivities(
    String userId, {
    int scanRows = kUserActivityScanRows,
    int limit = 50,
  }) async {
    if (userId.isEmpty) return const [];
    final raw = await client.getOneWithQuery(
      '/api/v1/activities',
      // `user_id` is inert today (see above) — sent anyway so the request
      // narrows at the source the day the server filter lands. The local
      // `where` below stays authoritative either way.
      query: {'reactv2': '', 'rows': '$scanRows', 'user_id': userId},
    );
    final list = raw is Map<String, dynamic> ? raw['data'] : raw;
    final rows = DashboardActivity.listFromJson(
      list,
    ).where((r) => r.userId == userId).toList(growable: false);
    return rows.length > limit ? rows.sublist(0, limit) : rows;
  }
}
