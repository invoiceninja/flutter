import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/outbox_dao.dart';
import 'package:admin/data/models/api/activity_api_model.dart'
    show kCommentActivityTypeId;
import 'package:admin/data/models/domain/activity.dart';
import 'package:admin/data/services/activities_api.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/activity/activity_refs.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

final _log = Logger('EntityActivityViewModel');

/// The types the comments-only follow-up asks for — see [kEntityActivityRows].
const Set<int> _kCommentTypes = {kCommentActivityTypeId};

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
///    (debounced) and again whenever the pending outbox drains. A feed that
///    fills the [kEntityActivityRows] window is followed by a comments-only
///    fetch, so a comment older than the window still reaches [comments].
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
  ///
  /// Not always a subset of [activities]: it also carries what the last
  /// comments-only fetch found beyond the window ([_commentsBeyondWindow]).
  List<Activity> _comments = const [];
  List<Activity> get comments => _comments;

  /// The last comments-only fetch, kept across refreshes so a re-fetch of the
  /// main feed doesn't drop the older comments for the round trip until the
  /// follow-up lands again. Comments are never deleted server-side, so a kept
  /// row cannot be one that has gone.
  List<Activity> _commentsBeyondWindow = const [];

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

  /// The server has no feed for this record type at all — a recurring expense
  /// on a server without invoiceninja/invoiceninja#13365. Not an [error]: there
  /// is nothing to retry until the server is updated.
  bool _isUnsupported = false;
  bool get isUnsupported => _isUnsupported;

  bool _kicked = false;
  bool _settled = false;

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
    // Known before the first frame, so a type refused once this session never
    // draws the note buttons it would then have to take away.
    _isUnsupported = api.isEntityUnsupported(entityWireName);
    final seed = api.peekForEntity(entity: entityWireName, entityId: entityId);
    final seedComments = api.peekForEntity(
      entity: entityWireName,
      entityId: entityId,
      activityTypeIds: _kCommentTypes,
    );
    if (seedComments != null) {
      _commentsBeyondWindow = seedComments
          .map(Activity.fromApi)
          .toList(growable: false);
    }
    if (seed != null) _adopt(seed.map(Activity.fromApi), notify: false);
    _kickTimer = Timer(kickDebounce, () {
      _kickTimer = null;
      unawaited(refresh());
    });
  }

  /// True once a [refresh] has finished — with rows, with an error, or without
  /// going out at all for a `tmp_` id.
  ///
  /// The gate for *giving up* on an [ActivityRevealController] request: a
  /// consumer that asked for a row the feed does not have must not keep hoping
  /// forever, and "the list is empty" alone cannot tell it whether the fetch
  /// has landed. Deliberately not a notifier of its own — every path that sets
  /// it either notifies immediately after (the `finally` below) or is the
  /// `tmp_` early return, which no reveal can reach anyway: a `tmp_` document
  /// has never been sent, so it has never been viewed.
  bool get hasSettled => _settled;

  Future<void> refresh() async {
    if (_disposed) return;
    // A `tmp_` record exists only in the outbox. `ShowActivityRequest`
    // validates `entity_id` with `Rule::exists`, which `Handler` renders as a
    // 422 — so this would burn a request to learn nothing.
    if (isUnsynced(entityId)) {
      _started = true;
      _settled = true;
      return;
    }
    // Refused once this session — asking again would only repeat the 422.
    if (api.isEntityUnsupported(entityWireName)) {
      _started = true;
      _settled = true;
      _isUnsupported = true;
      notifyListeners();
      return;
    }
    _started = true;
    _isLoading = true;
    _error = null;
    _isUnsupported = false;
    notifyListeners();
    try {
      final raw = await api.fetchForEntity(
        entity: entityWireName,
        entityId: entityId,
      );
      _adopt(raw.map(Activity.fromApi), notify: false);
      // A full window may have cut comments off; a shorter one holds all of
      // them, so only a full one pays for the second request.
      if (raw.length >= kEntityActivityRows &&
          !api.ignoresActivityTypeFilter &&
          !_disposed) {
        // Paint the window now rather than one round trip later. After an
        // await, so never mid-build; `isLoading` stays true until `finally`,
        // and the tab only spins while it has no rows.
        notifyListeners();
        await _fetchCommentsBeyondWindow();
      }
    } on ActivityFeedUnsupportedException {
      _isUnsupported = true;
      _log.fine('no activity feed for $entityWireName on this server');
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
      _settled = true;
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

  /// The comments-only follow-up. Its failure costs only the comments past
  /// the window — the main feed is already adopted — so it never becomes
  /// [error].
  Future<void> _fetchCommentsBeyondWindow() async {
    try {
      final notes = await api.fetchForEntity(
        entity: entityWireName,
        entityId: entityId,
        activityTypeIds: _kCommentTypes,
      );
      _commentsBeyondWindow = notes
          .map(Activity.fromApi)
          .toList(growable: false);
      // Re-adopting the adopted feed is idempotent; it only re-merges.
      _adopt(_activities, notify: false);
    } on NetworkException catch (e) {
      _log.fine('comments fetch skipped for $entityWireName: ${e.message}');
    } catch (e, st) {
      _log.warning('comments fetch failed for $entityWireName', e, st);
    }
  }

  void _adopt(Iterable<Activity> rows, {bool notify = true}) {
    final mapped =
        rows
            .where((a) => !isMisfiledExpenseNote(a, host: entityWireName))
            .toList()
          ..sort(_newestFirst);
    _activities = mapped;
    final comments = mapped.where((a) => a.isComment).toList();
    if (_commentsBeyondWindow.isNotEmpty) {
      // By id, and only a non-blank one: a row without a `hashed_id` can't be
      // matched, and collapsing those would lose comments rather than dupes.
      final seen = {
        for (final a in comments)
          if (a.id.isNotEmpty) a.id,
      };
      comments
        ..addAll(
          _commentsBeyondWindow.where(
            (a) =>
                a.isComment &&
                a.id.isNotEmpty &&
                !seen.contains(a.id) &&
                !isMisfiledExpenseNote(a, host: entityWireName),
          ),
        )
        ..sort(_newestFirst);
    }
    _comments = List.unmodifiable(comments);
    if (notify && !_disposed) notifyListeners();
  }

  static int _newestFirst(Activity a, Activity b) =>
      b.createdAt.compareTo(a.createdAt);

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
