import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:admin/ui/core/detail/related_tab_counts.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

/// A record's related rows, **handed over only when they are all of them**.
///
/// A record screen adds figures up from rows the server keeps no total for —
/// what was spent with a vendor, the hours logged on a project. Those rows are
/// paged into the local database fifty at a time, so the device may hold only
/// some, and a sum of some is a confidently wrong number
/// (`docs/detail-screen-layout.md` § A derived figure is shown only when it is
/// proven). This is what stands between the two:
///
///  * while nothing says otherwise, the rows held locally are handed over —
///    instantly, and offline;
///  * once the server has said how many there are (the count the screen
///    already asks for, for the tab's badge) and the device holds **fewer**,
///    [rows] is null and the missing pages are fetched, scoped to the record;
///    when they have landed the rows are handed over again, now complete;
///  * a record with more rows than [maxPages] pages is not fetched for — that
///    is a report, not a record screen — and stays withheld.
///
/// "Complete" is latched **against the count it was proven for**: once the
/// device has been seen to hold everything the server counted, falling short
/// of that same count is the user's own edit (a row archived from the tab
/// below, against a count taken before it), and re-fetching for that would
/// blank the figure on every archive. A *different* count — a refresh found
/// more — is a new question, and is asked.
///
/// Owned by the screen. It asks for nothing until a count is known, and then
/// only after [debounce] — long enough that stepping down a list of records
/// fetches for none of them.
///
/// **The watch and the count must mean the same rows** — both active-only,
/// both scoped by the filter the tab's own list sends — or "holds as many as
/// the server counted" proves nothing.
class RelatedRowsProof<T> extends ChangeNotifier {
  RelatedRowsProof({
    required Stream<List<T>> Function(String parentId) watch,
    required Future<bool> Function(String parentId, int page) fetchPage,
    required String Function(T row) idOf,
    required this.pageSize,
    required this.counts,
    required this.countTabId,
    required bool Function() isCurrent,
    this.maxPages = 20,
    this.debounce = const Duration(milliseconds: 400),
  }) : _watch = watch,
       _fetchPage = fetchPage,
       _idOf = idOf,
       _isCurrent = isCurrent {
    counts.addListener(_onCounts);
  }

  final Stream<List<T>> Function(String parentId) _watch;

  /// One page of the parent's **active** rows into the local database.
  /// Returns whether the server filled the page — `ensurePageLoaded`.
  final Future<bool> Function(String parentId, int page) _fetchPage;
  final String Function(T row) _idOf;
  final int pageSize;

  /// Where the server's count of the parent's active rows arrives, under
  /// [countTabId].
  final TabCounts counts;
  final String countTabId;

  /// False once the screen's company is no longer the active one: a record
  /// screen outlives a company switch, and must not then ask for anything.
  final bool Function() _isCurrent;

  /// The most pages this will fetch to complete a record's rows.
  final int maxPages;
  final Duration debounce;

  String? _parentId;
  StreamSubscription<List<T>>? _sub;
  List<T>? _rows;

  /// The server count the local rows were last proven complete against.
  int? _completeFor;
  bool _failed = false;
  bool _wasShort = false;
  int? _askedFor;
  Timer? _timer;
  int _generation = 0;
  bool _disposed = false;

  /// Call from build with the record's id as it is now — the **record's**,
  /// never the route's: a record opened while still `tmp_…` comes back with
  /// its server id once it syncs. Safe to call every frame; never notifies
  /// synchronously.
  void attach(String parentId) {
    if (_disposed || parentId == _parentId) return;
    _parentId = parentId;
    // Whatever is on the wire was asked about another record.
    _generation++;
    _timer?.cancel();
    _rows = null;
    _completeFor = null;
    _failed = false;
    _wasShort = false;
    _askedFor = null;
    unawaited(_sub?.cancel());
    _sub = _watch(parentId).listen((rows) {
      if (_disposed || parentId != _parentId) return;
      _rows = rows;
      _evaluate();
      _wasShort = isKnownShort;
      notifyListeners();
    });
  }

  /// Rows the server knows about — one created offline is not in its count
  /// yet.
  int get _heldOnServer =>
      _rows?.where((row) => !isUnsynced(_idOf(row))).length ?? 0;

  /// True while the device is known to hold fewer rows than the server
  /// counted.
  bool get isKnownShort {
    final serverCount = counts.countFor(countTabId);
    if (serverCount == null || serverCount == _completeFor) return false;
    return _heldOnServer < serverCount;
  }

  /// The rows this device holds, whether or not they are all of them — null
  /// until the local read has come back. For what may be partial without
  /// being wrong ("is there anything here to invoice?").
  List<T>? get held => _rows;

  /// The record's rows, or null while they are not known to be all of them:
  /// the local read has not come back, or the device is known to hold only
  /// some. **Add up only this.**
  List<T>? get rows => isKnownShort ? null : _rows;

  /// A count landed. It can turn rows that were being handed over into rows
  /// known to be short, which whoever is adding them up has to hear about.
  void _onCounts() {
    if (_disposed) return;
    _evaluate();
    final short = isKnownShort;
    if (short == _wasShort) return;
    _wasShort = short;
    notifyListeners();
  }

  void _evaluate() {
    final id = _parentId;
    final rows = _rows;
    if (_disposed || id == null || rows == null || isUnsynced(id)) return;
    final serverCount = counts.countFor(countTabId);
    if (serverCount == null || serverCount == _completeFor) return;
    if (_heldOnServer >= serverCount) {
      _completeFor = serverCount;
      _timer?.cancel();
      return;
    }
    if (_askedFor == serverCount) return;
    _askedFor = serverCount;
    _timer?.cancel();
    // Whatever is on the wire was fetching for another count.
    final generation = ++_generation;
    final pages = (serverCount / pageSize).ceil();
    // Too many to fetch for a figure on a record screen: withheld, and no
    // request made.
    if (pages > maxPages) return;
    _timer = Timer(
      debounce,
      () => unawaited(_fetch(id, serverCount, pages, generation)),
    );
  }

  Future<void> _fetch(
    String parentId,
    int serverCount,
    int pages,
    int generation,
  ) async {
    var complete = false;
    try {
      for (var page = 1; page <= pages; page++) {
        if (_disposed || generation != _generation || !_isCurrent()) return;
        if (!await _fetchPage(parentId, page)) break;
      }
      complete = true;
    } catch (_) {
      // Offline, or the company changed under the request. The rows stay
      // withheld; `retryIfUnanswered` asks again.
    }
    if (_disposed || generation != _generation) return;
    // Every page the server had for that count is in: complete against it,
    // whatever the local rows now number.
    if (complete) _completeFor = serverCount;
    _failed = !complete;
    _wasShort = isKnownShort;
    notifyListeners();
  }

  /// The user refreshed the record. Asks again only when the rows are being
  /// withheld — complete ones are kept current by the list's own reload, and
  /// are asked about again if the refresh comes back with a different count.
  Future<void> refresh() async {
    if (_disposed || !isKnownShort) return;
    _askedFor = null;
    _onCounts();
  }

  /// The device is back online: ask again if the last ask got no answer.
  void retryIfUnanswered() {
    if (_disposed || !_failed) return;
    _failed = false;
    _askedFor = null;
    _onCounts();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    counts.removeListener(_onCounts);
    unawaited(_sub?.cancel());
    super.dispose();
  }
}
