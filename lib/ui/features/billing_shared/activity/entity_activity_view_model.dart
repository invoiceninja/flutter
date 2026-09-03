import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/data/services/activities_api.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

final _log = Logger('EntityActivityViewModel');

/// State for one record's activity feed — the Activity tab, the comments-only
/// tab, and the Comments card, all reading the same fetch.
///
/// Entity-agnostic: pass the singular `entityWireName` (`'client'`,
/// `'invoice'`, `'purchase_order'`, …) and the record id. Replaces the two
/// near-verbatim twins this used to be, `ClientActivityViewModel` (which
/// hardcoded `'client'`) and `BillingDocActivityViewModel` (which lacked the
/// `_disposed` guard below and so could assert on a post-dispose notify from
/// ten screens).
///
/// **Owned by the detail screen's `State`, not by a tab.** Three surfaces need
/// the same rows and the endpoint is not cheap; a tab that built its own would
/// silently re-introduce a second request and leave the card empty.
///
/// Two slices feed the UI:
///
/// 1. **Synced activities** — `POST /api/v1/activities/entity`, kicked once
///    (debounced) and again whenever the pending outbox drains.
/// 2. **Pending mutations** — `addComment` outbox rows for this entity, so the
///    UI can render optimistic "syncing…" entries above the synced list.
class EntityActivityViewModel extends ChangeNotifier {
  EntityActivityViewModel({
    required this.api,
    required this.outbox,
    required this.companyId,
    required this.entityWireName,
    required this.entityId,
    this.kickDebounce = const Duration(milliseconds: 300),
  }) {
    _pendingSub = outbox
        .watchPendingForEntity(
          companyId: companyId,
          entityType: entityWireName,
          entityId: entityId,
          kind: MutationKind.addComment,
        )
        .listen(_onPendingTick);
  }

  final ActivitiesApi api;
  final OutboxDao outbox;
  final String companyId;

  /// Singular wire name — what `POST /activities/entity` wants. Note
  /// `ActivitiesApi.addNote` takes the *plural* form.
  final String entityWireName;
  final String entityId;

  /// Collapses a burst of mounts into one request. `MasterDetailLayout` binds
  /// J/K/↑/↓ to step through a list and the router re-keys the detail subtree
  /// per `:id`, so without this a held key issues one POST per repeat.
  final Duration kickDebounce;

  StreamSubscription<List<OutboxRow>>? _pendingSub;
  Timer? _kickTimer;

  List<Activity> _activities = const [];
  List<Activity> get activities => _activities;

  /// The human-written subset — typed comments and logged calls alike, which
  /// is the same slice `ActivityLens.comments` means on `/activity`. Computed
  /// once per refresh rather than per build.
  List<Activity> _comments = const [];
  List<Activity> get comments => _comments;

  /// Queued `addComment` rows for this record.
  ///
  /// Held here rather than left to a `StreamBuilder` in each view: two surfaces
  /// need them, and the first emission has to reach both. The old shape leaned
  /// on the view rendering that first emission while [_onPendingTick] only used
  /// it to seed a counter — so a comment queued offline *before* the screen was
  /// opened would not render until a second emission that may never come.
  List<OutboxRow> _pendingRows = const [];
  List<OutboxRow> get pendingRows => _pendingRows;

  /// Whether the Comments surfaces have anything at all to show.
  bool get hasAnyComment => _pendingRows.isNotEmpty || _comments.isNotEmpty;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Object? _error;
  Object? get error => _error;

  bool _kicked = false;

  /// A drain edge that arrived mid-fetch. See [_onPendingTick].
  bool _refetchWanted = false;
  bool _started = false;
  bool _disposed = false;
  int _lastPendingCount = 0;

  /// Arm the initial fetch. Idempotent — call it from the host's `bodyBuilder`
  /// rather than `initState`: the scaffold only builds a body once the record
  /// resolves, so a deep link to a deleted or out-of-permission record never
  /// spends a request that can only come back 422.
  ///
  /// A cached feed is adopted synchronously first (see
  /// [ActivitiesApi.peekForEntity]) so a re-opened record paints its comments
  /// in the same frame; the request still goes out.
  ///
  /// That adoption **must not notify**. This runs inside the host's `build`,
  /// and a `ChangeNotifier` notified mid-build makes any already-built
  /// `ListenableBuilder` on it call `setState` during build — the crash
  /// CLAUDE.md records for the shortcut-hint controller. On the intended path
  /// nothing is listening yet (the card is built after this returns, and reads
  /// the fields directly), so silence costs nothing; if a listener somehow does
  /// exist it simply repaints when the refresh lands instead of throwing.
  void kick() {
    if (_kicked || _disposed) return;
    _kicked = true;
    final seed = api.peekForEntity(entity: entityWireName, entityId: entityId);
    if (seed != null) _adopt(seed.map(Activity.fromApi), notify: false);
    _kickTimer = Timer(kickDebounce, () {
      _kickTimer = null;
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (_disposed) return;
    // A `tmp_` record exists only in the outbox. `ShowActivityRequest`
    // validates `entity_id` with `Rule::exists`, which `Handler` renders as a
    // 422 — so this would burn a request to learn nothing.
    if (isUnsynced(entityId)) {
      _started = true;
      return;
    }
    _started = true;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await api.fetchForEntity(
        entity: entityWireName,
        entityId: entityId,
      );
      _adopt(raw.map(Activity.fromApi), notify: false);
    } on NetworkException catch (e) {
      // Same policy as the sidebar prefetch: an offline blip is expected and
      // must not pollute the WARNING+ diagnostics log.
      _error = e;
      _log.fine('activity feed skipped for $entityWireName: ${e.message}');
    } catch (e, st) {
      _error = e;
      // Deliberately NOT claimed to cover a permission-narrowed user: the
      // endpoint answers 200 with only that user's own rows rather than 403,
      // so a thin feed for a restricted user is indistinguishable from an
      // empty one and nothing here can see it.
      _log.warning('activity feed failed for $entityWireName', e, st);
    } finally {
      _isLoading = false;
      // The fetch is awaited — the screen may have been disposed while it was
      // in flight, and `ChangeNotifier` asserts on a post-dispose notify.
      if (!_disposed) notifyListeners();
      if (_refetchWanted && !_disposed) {
        // Cleared before re-entering, so this can run at most once per edge.
        _refetchWanted = false;
        unawaited(refresh());
      }
    }
  }

  void _adopt(Iterable<Activity> rows, {bool notify = true}) {
    final mapped = rows.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _activities = mapped;
    _comments = mapped.where((a) => a.isComment).toList(growable: false);
    if (notify && !_disposed) notifyListeners();
  }

  void _onPendingTick(List<OutboxRow> rows) {
    if (_disposed) return;
    final count = rows.length;
    _pendingRows = rows;
    // A pending row just landed in the synced state — refetch so the
    // server-confirmed activity replaces the optimistic entry.
    //
    // When a fetch is already in flight the refetch is **deferred, not
    // dropped**. That request went out *before* `addNote` reached the server,
    // so its response cannot contain the new note — and this is a falling edge
    // that Drift emits exactly once, so consuming it here loses the comment
    // outright: the optimistic row disappears when the stale response lands,
    // and on a record whose only comment that was, the card animates itself
    // shut over a note the server has.
    if (_started && _lastPendingCount > 0 && count == 0) {
      if (_isLoading) {
        _refetchWanted = true;
      } else {
        unawaited(refresh());
      }
    }
    _lastPendingCount = count;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // A pending `Timer` outliving the tree is a hard `testWidgets` failure,
    // and this one is armed on every detail screen.
    _kickTimer?.cancel();
    unawaited(_pendingSub?.cancel());
    super.dispose();
  }
}
