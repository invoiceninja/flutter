import 'package:flutter/foundation.dart';

import 'package:admin/data/models/api/document_version_api_model.dart';
import 'package:admin/data/models/domain/document_version.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/domain/activity/activity_view_events.dart';

/// The server's per-document activity window, and therefore the ceiling on how
/// many versions can ever be listed.
///
/// `Invoice::activities()` — and the identical relation on Quote, Credit,
/// RecurringInvoice and PurchaseOrder — is
/// `->orderBy('id','DESC')->take(50)`, with **no pagination**. There is no
/// parameter to widen it, so a document with more history than this loses its
/// oldest versions silently. The UI says so rather than implying the list is
/// complete; see `DocumentVersionPage.truncated`.
const int kDocumentVersionWindow = 50;

/// How long a fetched history stays worth painting on sight.
///
/// Short on purpose. The cache is a **first-frame seed**, never a fetch
/// suppressor — `kick` adopts it and then requests anyway, exactly as the
/// sibling activity feed does. What it buys: stepping back onto a record
/// paints instantly, and tapping a version on narrow hands the `/pdf` route a
/// list the History tab already fetched instead of re-GETting the document.
@visibleForTesting
const Duration kDocumentVersionCacheTtl = Duration(minutes: 2);

/// Cap on the history cache. Same reasoning as `kEntityActivityCacheLimit`:
/// `MasterDetailLayout`'s J/K binding walks a whole list, so an unbounded map
/// would grow one entry per record visited.
@visibleForTesting
const int kDocumentVersionCacheLimit = 24;

class _VersionCacheEntry {
  _VersionCacheEntry(this.page, this.at);
  final DocumentVersionPage page;
  final DateTime at;
}

/// Reads a billing document's version history, and fetches one version's PDF.
///
/// Not a `BaseEntityApi`: the list read is a GET on *another* entity's path
/// with a nested include, and the PDF read is rooted on `/activities/`, so
/// neither fits the generic contract. `ActivitiesApi` is the sibling
/// precedent, and this class mirrors its four cache rules.
///
/// **Deliberately bypasses Drift**, like the per-entity activity feed: this is
/// remote-only metadata about remote blobs. Nothing here is offline-editable,
/// nothing goes through the outbox, and there is no table to migrate.
class DocumentVersionsApi {
  DocumentVersionsApi(this.client, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ApiClient client;
  final DateTime Function() _now;

  final Map<String, _VersionCacheEntry> _cache = <String, _VersionCacheEntry>{};
  final Map<String, Future<DocumentVersionPage>> _inFlight =
      <String, Future<DocumentVersionPage>>{};

  /// Bumped by [clearCache] so a request still on the wire when the session
  /// ends can't write the outgoing user's rows back into the emptied map.
  int _generation = 0;

  /// Keyed by the credential fingerprint, not by company — the activity rows
  /// a user is allowed to see are narrowed per-user server-side, so two users
  /// on one install legitimately get different answers for the same record.
  String _key(String basePath, String id) =>
      '${client.credentialFingerprint}/$basePath/$id';

  /// Cached history for [basePath]/[id] if one landed within
  /// [kDocumentVersionCacheTtl], else null.
  ///
  /// A **first-frame seed only**, the same contract as
  /// `ActivitiesApi.peekForEntity`: callers paint it and then fetch anyway.
  /// Never branch on it — a seed that suppresses the request is a second,
  /// unsynchronised copy of state the server owns.
  DocumentVersionPage? peekForEntity({
    required String basePath,
    required String id,
  }) {
    final key = _key(basePath, id);
    final hit = _cache[key];
    if (hit == null) return null;
    if (_now().difference(hit.at) > kDocumentVersionCacheTtl) {
      _cache.remove(key);
      return null;
    }
    _cache
      ..remove(key)
      ..[key] = hit;
    return hit.page;
  }

  /// Drop every cached history. Wired into the logout fan-out and the Sync
  /// tail in `Services` beside `ActivitiesApi.clearCache()` — these rows carry
  /// amounts and actor ids, and a Sync pass makes them stale.
  void clearCache() {
    _generation++;
    _cache.clear();
    _inFlight.clear();
  }

  /// `GET <basePath>/<id>?include=activities.history` — the versions of one
  /// billing document, newest first.
  ///
  /// [basePath] is the entity's collection path (`/api/v1/invoices`), so this
  /// serves all five document types without a per-entity subclass.
  ///
  /// No `readOnly` flag: `getOneWithQuery` has none and needs none, because
  /// the demo-mode gate only rejects non-GET methods.
  ///
  /// Concurrent callers for the same record share one request. The tab and
  /// the wide pane can both ask on the same frame when a screen opens
  /// already scrolled to History.
  Future<DocumentVersionPage> fetchForEntity({
    required String basePath,
    required String id,
  }) {
    final key = _key(basePath, id);
    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final generation = _generation;
    final future = _fetchUncached(basePath: basePath, id: id);
    _inFlight[key] = future;
    return future
        .whenComplete(() {
          if (identical(_inFlight[key], future)) _inFlight.remove(key);
        })
        .then((page) {
          if (generation == _generation) _remember(key, page);
          return page;
        });
  }

  Future<DocumentVersionPage> _fetchUncached({
    required String basePath,
    required String id,
  }) async {
    final raw = await client.getOneWithQuery(
      '$basePath/$id',
      query: const {'include': 'activities.history'},
    );
    if (raw is! Map<String, dynamic>) return const DocumentVersionPage.empty();
    // The RAW wire count, before `tolerantList` drops anything: the server's
    // `take(50)` applies pre-filter, so counting survivors would report a
    // complete list whenever a malformed row was skipped.
    final wireRows = raw['data'] is Map<String, dynamic>
        ? (raw['data'] as Map<String, dynamic>)['activities']
        : null;
    final wireCount = wireRows is List ? wireRows.length : 0;
    final rows = DocumentVersionItemApi.fromJson(raw).data.activities;
    return DocumentVersionPage(
      versions: versionsFrom(rows),
      // `>=`, so a document with exactly 50 activities reports truncated
      // although it is complete. Unavoidable without a `take(51)` probe the
      // API does not offer; over-reporting is the safe direction.
      truncated: wireCount >= kDocumentVersionWindow,
    );
  }

  /// `GET /api/v1/activities/download_entity/{activityId}` — the PDF of one
  /// version.
  ///
  /// `readOnly: true` **is** required here: `getRaw` rejects every call in
  /// demo mode without it.
  ///
  /// A 404 carrying `{"message":"No backup exists for this activity"}` is a
  /// real data condition rather than a bad URL — a `Backup` row whose document
  /// had no invitation or no design is stored with a null filename, and still
  /// passes the `history.id` gate. It surfaces as a `ServerException`; the
  /// caller renders the server's own message.
  Future<Uint8List> downloadVersionPdf(String activityId) => client.getRaw(
    '/api/v1/activities/download_entity/$activityId',
    readOnly: true,
  );

  void _remember(String key, DocumentVersionPage page) {
    _cache
      ..remove(key)
      ..[key] = _VersionCacheEntry(page, _now());
    while (_cache.length > kDocumentVersionCacheLimit) {
      _cache.remove(_cache.keys.first);
    }
  }
}

/// The activity rows that carry a real backup, newest first.
///
/// Two filters, both load-bearing:
///
/// * `history.id` must be non-empty — the server serializes an empty `history`
///   shell for an activity that produced no backup.
/// * **view events are dropped**, via the shared [kViewActivityTypeIds]. Every
///   portal view writes a backup identical to the one before it, so without
///   this the list is mostly duplicates of the same document. Legacy
///   admin-portal filtered the same four ids; the React client does not, and
///   its history lists are noisier for it.
@visibleForTesting
List<DocumentVersion> versionsFrom(List<DocumentVersionActivityApi> rows) {
  // The four portal *view* events. `kViewActivityTypeIds` is keyed by wire
  // name so a caller "needs no entity switch"; flattening its values here
  // would silently start dropping any fifth type a future Activity-tab change
  // adds, from all five History tabs at once. Pin the four this means.
  const viewTypes = {'7', '21', '60', '136'};
  assert(
    kViewActivityTypeIds.values
        .map((id) => '$id')
        .toSet()
        .containsAll(viewTypes),
    'kViewActivityTypeIds no longer carries the four view events',
  );
  final out = <({int index, DocumentVersion version})>[];
  for (final row in rows) {
    if (viewTypes.contains(row.activityTypeId)) continue;
    final version = DocumentVersion.fromApi(row);
    if (version != null) out.add((index: out.length, version: version));
  }
  out.sort((a, b) {
    final byDate = b.version.createdAt.compareTo(a.version.createdAt);
    if (byDate != 0) return byDate;
    // `created_at` is second-resolution, so ties are routine — a save
    // followed immediately by mark-sent, or any bulk action, lands several
    // rows on one second. Fall back to the **arrival order**, which is the
    // server's own `orderBy('id','DESC')`.
    //
    // NOT `activityId.compareTo`: that value is a *hashid*, deliberately
    // non-monotonic, so comparing it lexicographically is an arbitrary
    // permutation of real activity order (`docs/dashboard-panels.md` §
    // Most recent needs a tie-break records the same trap). And not sort
    // stability either — `List.sort` is only stable below
    // `_INSERTION_SORT_THRESHOLD` (32) and this window holds up to 50.
    //
    // It matters beyond ordering: the History tab derives each row's amount
    // delta from list *adjacency*, so a mis-ordered pair renders its delta
    // with the wrong sign.
    return a.index.compareTo(b.index);
  });
  return [for (final e in out) e.version];
}
