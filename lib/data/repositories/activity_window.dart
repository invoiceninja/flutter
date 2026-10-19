/// How a fresh `GET /activities?reactv2` answer joins the activity window
/// already cached.
///
/// Pure, over the raw JSON maps the cache row stores, so it is unit-testable
/// without a database (`test/data/repositories/activity_window_test.dart`).
library;

import 'package:admin/data/services/dashboard_api.dart'
    show kActivityCursorWindowMax, kActivityWindowMax;

int _createdAt(Object? row) {
  if (row is! Map) return 0;
  final raw = row['created_at'];
  if (raw is int) return raw;
  return int.tryParse('$raw') ?? 0;
}

String _id(Object? row) => row is Map ? '${row['id']}' : '';

/// Newest first; within a second, the higher raw id first — the server's own
/// `orderBy('created_at', 'DESC')` leaves that order to the table, and the
/// `reactv2` id is the raw auto-increment, so this matches it in practice.
int _newestFirst(Object? a, Object? b) {
  final byTime = _createdAt(b).compareTo(_createdAt(a));
  if (byTime != 0) return byTime;
  final ia = int.tryParse(_id(a));
  final ib = int.tryParse(_id(b));
  if (ia != null && ib != null) return ib.compareTo(ia);
  return _id(b).compareTo(_id(a));
}

/// [fetched] (the newest N rows) merged over [cached] (the window held).
///
/// The cache row is shared: the dashboard card refreshes it with 250 rows,
/// and the `/activity` screen's Load more asks for up to
/// [kActivityWindowMax]. Replacing the row on every fetch threw away the
/// screen's grown window the next time the card refreshed. So older rows
/// survive a fetch — but only under two rules:
///
///  * **No gap.** If the fetch doesn't reach back to the newest row held,
///    something happened in between that neither window has. The fetch
///    replaces the cache rather than leaving a silent hole in the timeline.
///  * **The fetch owns its own span.** A cached row from inside the fetched
///    period that the fetch no longer returns is dropped, so a row the server
///    has since removed doesn't linger. Only rows *older* than everything
///    fetched (or tied with its oldest second, which the fetch may have cut
///    through) are carried over.
///
/// The result is newest first, trimmed to [cap] — the cursor cap, not the
/// growing-window one: a window paged back with the cursor must survive the
/// card's next refresh, and a fetch without it never asks for more than
/// [kActivityWindowMax] anyway.
List<Object?> mergeActivityWindow({
  required List<Object?> fetched,
  required List<Object?>? cached,
  int cap = kActivityCursorWindowMax,
}) {
  final out = [...fetched]..sort(_newestFirst);
  if (fetched.isEmpty || cached == null || cached.isEmpty) {
    return out.length > cap ? out.sublist(0, cap) : out;
  }
  var fetchedOldest = _createdAt(fetched.first);
  for (final row in fetched) {
    final t = _createdAt(row);
    if (t < fetchedOldest) fetchedOldest = t;
  }
  var cachedNewest = 0;
  for (final row in cached) {
    final t = _createdAt(row);
    if (t > cachedNewest) cachedNewest = t;
  }
  if (cachedNewest < fetchedOldest) {
    return out.length > cap ? out.sublist(0, cap) : out;
  }
  final have = {for (final row in fetched) _id(row)};
  for (final row in cached) {
    final t = _createdAt(row);
    if (t > fetchedOldest) continue;
    if (have.add(_id(row))) out.add(row);
  }
  out.sort(_newestFirst);
  return out.length > cap ? out.sublist(0, cap) : out;
}

/// The row a Load more pages back from: the oldest row held, by the same
/// order [mergeActivityWindow] keeps. Null for an empty window.
///
/// The payload's `created_at` is whole seconds while the server orders by the
/// stored microseconds, so inside one second this may not be the row the feed
/// itself lists last. That costs nothing: the server answers with every row
/// after it in feed order, a few of them already held, and
/// [appendOlderActivities] drops those by id — nothing older can be skipped.
Object? oldestActivityRow(List<Object?> rows) {
  if (rows.isEmpty) return null;
  return ([...rows]..sort(_newestFirst)).last;
}

/// Whether [page] honoured a `before` cursor naming [boundary]: no row in it
/// is newer than the boundary's second.
///
/// A server without the cursor ignores the parameter and answers with the
/// newest rows, which sit after the boundary — so this tells the two apart
/// from the reply itself, with no version check.
bool pageHonouredCursor(List<Object?> page, Object? boundary) {
  final limit = _createdAt(boundary);
  return page.every((row) => _createdAt(row) <= limit);
}

/// [older] (a page fetched with a `before` cursor) appended to [cached].
///
/// The page is contiguous with the window by the server's guarantee, so —
/// unlike [mergeActivityWindow] — nothing is dropped as a gap; rows already
/// held are skipped by id. Newest first, trimmed to [cap].
List<Object?> appendOlderActivities({
  required List<Object?> cached,
  required List<Object?> older,
  int cap = kActivityCursorWindowMax,
}) {
  final out = [...cached];
  final have = {for (final row in cached) _id(row)};
  for (final row in older) {
    if (have.add(_id(row))) out.add(row);
  }
  out.sort(_newestFirst);
  return out.length > cap ? out.sublist(0, cap) : out;
}
