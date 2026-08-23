import 'package:admin/data/models/api/activity_api_model.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/services/api_client.dart';

/// How many of the most-recent company activity rows one user-activity screen
/// load pulls down before filtering to a single actor. The `?reactv2` branch is
/// unpaginated (`->take($rows)`), so this is the whole scan window — see
/// [ActivitiesApi.fetchUserActivities].
const int kUserActivityScanRows = 250;

/// API for the `/api/v1/activities/*` family. Two endpoints, neither
/// rooted on a per-entity path — `BaseEntityApi` doesn't fit, so this
/// service wraps `ApiClient` directly.
///
/// The endpoints differ in the singular/plural form of `entity`:
/// `/notes` (the write) wants `"clients"`; `/entity` (the read) wants
/// `"client"`. Confirmed against demo.invoiceninja.com and matches both
/// legacy admin-portal and the React reference client.
class ActivitiesApi {
  ActivitiesApi(this.client);

  final ApiClient client;

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
  }

  /// `POST /api/v1/activities/entity` — fetch the activity stream for a
  /// single entity. Returns the rich denormalized form with `user.label`,
  /// `client.label`, `invoice.label` populated, so callers can render names
  /// without joining against a users table.
  Future<List<ActivityApi>> fetchForEntity({
    required String entity,
    required String entityId,
  }) async {
    final raw = await client.postJson(
      '/api/v1/activities/entity',
      readOnly: true,
      body: {'entity': entity, 'entity_id': entityId},
    );
    if (raw is! Map<String, dynamic>) return const [];
    final parsed = ActivityListApi.fromJson(raw);
    return parsed.data;
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
