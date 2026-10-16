import 'dart:async';

/// One `(id, name)` row of an entity's active-names stream
/// (`ClientRepository.watchActiveNames` and its vendor / project twins).
typedef NameRow = ({String id, String name});

/// The value list behind a `client:` / `vendor:` / `project:` key: the local
/// cache's names that contain [query], joined by the rows the **server**
/// finds for it.
///
/// The keys used to read only Drift, which holds only the pages someone has
/// browsed. On an account with thousands of clients, `client:acme` answered
/// "No values match" for a client that exists, and nothing said the list was
/// partial.
///
/// * **The server is asked for every settled query**, not only when the
///   cache has nothing. Asking only then left one cached partial match —
///   "Acme Ltd" — hiding every uncached one: "Acme Corp" never appeared.
/// * **The cache answers first.** Its matches are emitted at once, and the
///   server's join them when they land; typing through a cached name never
///   waits on the network.
/// * **An empty first answer is held back** until the server has replied.
///   The menu shows its loading row until a stream emits for the current
///   query (`_ValueListState`), so emitting the cache's `[]` first would
///   flash "No values match" in front of a hit that is on its way.
/// * **Debounced, and dropped with the query.** The menu resubscribes on
///   every keystroke and cancels the previous stream; cancelling here cancels
///   the pending fetch, so a fast typist sends one request, for the last
///   query, and an older reply can never paint over a newer query.
/// * **The server's hits are the ones its search matched**, not the ones
///   whose name contains [query]: `?filter=` also matches a client's number
///   and its contacts' names, emails and phones. [searchedIds] re-reads them
///   through the repository's local search, which mirrors that field set
///   (see `docs/entity-lists.md`), and the rows are then shown from [names]
///   so they keep that stream's name fallback, ordering and active-only rule.
/// * **A failed fetch** (offline) ends where the cache did.
///
/// [query] is matched case-insensitively; an empty one returns [names] as is.
Stream<List<NameRow>> namesWithServerSearch({
  required Stream<List<NameRow>> names,
  required String query,
  required Future<void> Function(String query) fetch,
  required Stream<List<String>> Function(String query) searchedIds,
  Duration debounce = const Duration(milliseconds: 280),
}) {
  final typed = query.trim();
  final q = typed.toLowerCase();
  if (q.isEmpty) return names;

  late final StreamController<List<NameRow>> out;
  StreamSubscription<List<NameRow>>? namesSub;
  StreamSubscription<List<String>>? idsSub;
  Timer? timer;
  List<NameRow>? latest;
  Set<String>? serverIds;
  var cancelled = false;

  void emit() {
    final rows = latest;
    if (rows == null || cancelled) return;
    final ids = serverIds;
    final hits = [
      for (final r in rows)
        if (r.name.toLowerCase().contains(q) || (ids?.contains(r.id) ?? false))
          r,
    ];
    // Nothing yet, and the server still to answer: wait for it.
    if (hits.isEmpty && ids == null) return;
    out.add(hits);
  }

  Future<void> askServer() async {
    try {
      await fetch(typed);
    } catch (_) {
      // Offline, or the server refused: the cache's answer stands.
    }
    if (cancelled) return;
    idsSub = searchedIds(typed).listen((list) {
      serverIds = list.toSet();
      emit();
    }, onError: out.addError);
  }

  out = StreamController<List<NameRow>>(
    onListen: () {
      namesSub = names.listen((rows) {
        latest = rows;
        emit();
      }, onError: out.addError);
      timer = Timer(debounce, () => unawaited(askServer()));
    },
    onCancel: () async {
      cancelled = true;
      timer?.cancel();
      await idsSub?.cancel();
      await namesSub?.cancel();
    },
  );
  return out.stream;
}
