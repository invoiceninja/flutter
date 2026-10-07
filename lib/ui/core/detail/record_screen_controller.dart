import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:admin/app/services.dart';
import 'package:admin/ui/core/detail/entity_record_page.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/related_tab_counts.dart';
import 'package:admin/ui/core/list/embedded_list_parent_scope.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

/// The plumbing every record screen on the shared layout needs, in one place
/// (`docs/detail-screen-layout.md`): the page and tab controllers, the mailbox
/// for filters sent to an embedded list, the quiet re-check of the record on
/// open, pull-to-refresh / `R`, and the counts on the related tabs.
///
/// It exists because each of those carries a rule that is invisible at the
/// call site and was learned the hard way on the first screen:
///
///  * **The re-check is decided when its timer fires**, not when the screen
///    opens, and only for a record that is on the server, is held locally for
///    *this screen's* company, and while that company is still the active one.
///    A record screen outlives a company switch; asked then, a by-id fetch is
///    a request for another company's record.
///  * **The figure requests wait for the re-check to settle.** It is what
///    brings a newer `updatedAt`; asked beside it, every count went out twice.
///  * **Ids come from the record, never the route.** A screen opened on a
///    record created offline keeps its `tmp_…` route after the record syncs.
///  * **A refresh is page 1 of the list on stage**, through the page's
///    signal — never the list's own `refresh`, which sweeps the whole entity.
///
/// A screen builds one in `initState`, calls [attach] from its body builder
/// with the record as it is now, and disposes it. Everything a host adds on
/// top (the client's past-due line) hangs off [onSettled], [refreshAfter] and
/// [onBackOnline].
class RecordScreenController extends ChangeNotifier implements TabCounts {
  RecordScreenController({
    required Services services,
    required String companyId,
    required String routeId,
    required String entityWireName,
    required Future<void> Function(String id) refreshRecord,
    required bool Function() hasRecord,
    String? countFilterKey,
    Map<String, String> countFilterKeys = const {},
    Map<String, Map<String, String>> countExtras = const {},
    Map<String, RelatedCountFetcher> countFetchers = const {},
    List<Future<void> Function()> refreshWith = const [],
    List<Future<void> Function()> refreshAfter = const [],
    VoidCallback? onSettled,
    VoidCallback? onBackOnline,
    Duration recheckDelay = const Duration(milliseconds: 300),
  }) : this.withEnvironment(
         backOnline: services.backOnline,
         activeCompanyId: () => services.auth.session.value?.currentCompanyId,
         userId: () => services.auth.session.value?.userId ?? '',
         countsCache: services.relatedTabCounts,
         isOnline: () => services.connectivity.isOnline,
         companyId: companyId,
         routeId: routeId,
         entityWireName: entityWireName,
         refreshRecord: refreshRecord,
         hasRecord: hasRecord,
         countFilterKey: countFilterKey,
         countFilterKeys: countFilterKeys,
         countExtras: countExtras,
         countFetchers: countFetchers,
         refreshWith: refreshWith,
         refreshAfter: refreshAfter,
         onSettled: onSettled,
         onBackOnline: onBackOnline,
         recheckDelay: recheckDelay,
       );

  /// The same controller over the five things it needs from the app, named
  /// one by one — what the constructor above reads off `Services`. For tests,
  /// which can then drive it without an app behind it.
  @visibleForTesting
  RecordScreenController.withEnvironment({
    required Listenable backOnline,
    required String? Function() activeCompanyId,
    required String Function() userId,
    required RelatedTabCountsCache countsCache,
    required Future<bool> Function() isOnline,
    required this.companyId,
    required String routeId,
    required this.entityWireName,
    required Future<void> Function(String id) refreshRecord,
    required bool Function() hasRecord,
    this.countFilterKey,
    this.countFilterKeys = const {},
    this.countExtras = const {},
    this.countFetchers = const {},
    this.refreshWith = const [],
    this.refreshAfter = const [],
    this.onSettled,
    this.onBackOnline,
    this.recheckDelay = const Duration(milliseconds: 300),
  }) : _backOnline = backOnline,
       _activeCompanyId = activeCompanyId,
       _userId = userId,
       _countsCache = countsCache,
       _isOnline = isOnline,
       _refreshRecord = refreshRecord,
       _hasRecord = hasRecord,
       _recordId = routeId {
    // Opening a cached record makes no request (`ensureLoaded` returns as soon
    // as it finds the row), so the figures on a record screen were only ever
    // as fresh as the last sync. Re-check quietly — after a pause, so stepping
    // down a list with J / K does not fetch every record it passes.
    if (isUnsynced(routeId)) {
      _settled = true;
    } else {
      _recheck = Timer(recheckDelay, () => unawaited(_runRecheck()));
    }
    _backOnline.addListener(_onBackOnline);
  }

  final Listenable _backOnline;
  final String? Function() _activeCompanyId;
  final String Function() _userId;
  final RelatedTabCountsCache _countsCache;
  final Future<bool> Function() _isOnline;
  final String companyId;

  /// `client`, `vendor`, `project` … — the parent kind in the counts cache.
  final String entityWireName;

  final Future<void> Function(String id) _refreshRecord;
  final bool Function() _hasRecord;

  /// The list filter that scopes a related list to this record (`client_id`,
  /// `vendor_id`, `project_id`). Null for a record with no counted tabs.
  final String? countFilterKey;

  /// Tab id → a filter key that differs from [countFilterKey] for that tab.
  /// The server does not name a parent the same way on every list: a project
  /// is `project_id` on invoices, `project_tasks` on tasks and `project_ids`
  /// on expenses. **Use the key the tab's own embedded list sends** — a count
  /// taken with any other is not the number of rows the tab will show.
  final Map<String, String> countFilterKeys;

  /// Tab id → query parameters that tab's list sends *besides* the parent's
  /// id and the lifecycle state, and which change which rows come back.
  ///
  /// A repository adds some by itself, where no screen sees them: most
  /// client-bearing lists send `without_deleted_clients=true` unless they are
  /// scoped to a client (`excludeDeletedClients` in `ensurePageLoadedTemplate`),
  /// and the transactions list always sends `active_banks=true`. A count
  /// asked without them is of a different set — a project's Tasks badge then
  /// counts the tasks of an archived client that its list will never fetch.
  final Map<String, Map<String, String>> countExtras;

  /// Tab id → the count request for the entity that tab lists.
  final Map<String, RelatedCountFetcher> countFetchers;

  /// Refreshed beside the record (the activity feed).
  final List<Future<void> Function()> refreshWith;

  /// Refreshed once the record has come back, so they are asked about the
  /// record as it now is.
  final List<Future<void> Function()> refreshAfter;

  /// The re-check has come back (or was never going to run): the moment a
  /// host may start requests that depend on the record being current.
  final VoidCallback? onSettled;
  final VoidCallback? onBackOnline;
  final Duration recheckDelay;

  final TabSelectionController selectTab = TabSelectionController();
  final EntityRecordPageController page = EntityRecordPageController();
  final EmbeddedListIntents listIntents = EmbeddedListIntents();

  Timer? _recheck;
  bool _settled = false;
  bool _disposed = false;
  String _recordId;
  String? _countsFor;
  RelatedTabCountsViewModel? _counts;
  Set<String> _tabIds = const {};
  Object? _revision;

  /// The record's id as last seen: the route's until the record resolves, and
  /// different from it after a record opened as `tmp_…` has synced.
  String get recordId => _recordId;

  /// True once the quiet re-check has come back, or was never going to run.
  bool get settled => _settled;

  bool get _companyStillActive => _activeCompanyId() == companyId;

  /// Whether a by-id fetch of this record makes sense right now — see the
  /// class doc.
  bool get mayRefreshRecord =>
      !isUnsynced(_recordId) && _hasRecord() && _companyStillActive;

  @override
  int? countFor(String tabId) => _counts?.countFor(tabId);

  /// Call from the body builder with the record as it is now. Safe to call on
  /// every build; never notifies synchronously.
  ///
  /// [tabIds] are the counted tabs actually on screen (a module that is off
  /// has no tab and gets no request); [revision] is anything that changes
  /// when the record does — its `updatedAt`.
  void attach({
    required String recordId,
    Object? revision,
    Set<String> tabIds = const {},
  }) {
    if (_disposed) return;
    _recordId = recordId;
    _tabIds = tabIds;
    _revision = revision;
    _ensureCounts();
    if (_settled) _counts?.kick(tabIds: tabIds, revision: revision);
  }

  void _ensureCounts() {
    final key = countFilterKey;
    if (key == null || countFetchers.isEmpty) return;
    if (isUnsynced(_recordId) || _recordId == _countsFor) return;
    final retired = _counts;
    _countsFor = _recordId;
    final counts = RelatedTabCountsViewModel(
      cache: _countsCache,
      // The user too: what one may count, another may not.
      scope: '${_userId()}|$companyId|$entityWireName|$_recordId',
      // What every one of those tabs' lists opens on.
      filters: {key: _recordId, 'status': 'active'},
      filterOverrides: {
        for (final tab in {...countFilterKeys.keys, ...countExtras.keys})
          tab: {
            countFilterKeys[tab] ?? key: _recordId,
            'status': 'active',
            ...?countExtras[tab],
          },
      },
      fetchers: countFetchers,
      isOnline: _isOnline,
      isCurrent: () => _companyStillActive,
    )..addListener(_forward);
    _counts = counts;
    if (retired != null) {
      retired.removeListener(_forward);
      // Not mid-build: it may still be being read this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => retired.dispose());
    }
  }

  void _forward() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _runRecheck() async {
    await refreshRecord();
    if (_disposed) return;
    _settled = true;
    _counts?.kick(tabIds: _tabIds, revision: _revision);
    // The kick adopts whatever the session already knows about this record
    // without a word — it was written to be called from build, where the tabs
    // are built straight afterwards and read the counts for themselves. This
    // is not build. Unless something is said here, a record re-opened with
    // its counts still cached shows no badges until something else happens to
    // rebuild it (nothing does offline, or when the counts come back
    // unchanged), and a `RelatedRowsProof` never learns the count says it is
    // short.
    notifyListeners();
    onSettled?.call();
  }

  void _onBackOnline() {
    _counts?.retryIfUnanswered();
    onBackOnline?.call();
  }

  /// Dirty-preserving at the repository; a no-op when [mayRefreshRecord] says
  /// no. Errors are the repository's to swallow — a failed re-check leaves
  /// the cached record on screen, which is what was there anyway.
  Future<void> refreshRecord() async {
    if (_disposed || !mayRefreshRecord) return;
    // Not offline. The request would only fail, and `refreshByIdsTemplate`
    // logs every failure at WARNING — one line in the diagnostics log for
    // each cached record a user opens without a connection, which is an
    // ordinary thing to do in this app.
    try {
      if (!await _isOnline()) return;
    } catch (_) {
      // Unknown is not offline: ask.
    }
    if (_disposed || !mayRefreshRecord) return;
    try {
      await _refreshRecord(_recordId);
    } catch (_) {
      // A host's refresh that throws must not take the others down with it.
    }
  }

  /// Pull-to-refresh and `R`: the record, whatever refreshes beside it, the
  /// related list on stage (page 1, through the page's signal), then the
  /// figures that depend on the record being current.
  Future<void> refresh() async {
    if (_disposed) return;
    page.refreshSignal.fire();
    await Future.wait([
      refreshRecord(),
      for (final extra in refreshWith) _quiet(extra),
    ]);
    if (_disposed) return;
    await Future.wait([
      _counts?.refresh() ?? Future<void>.value(),
      for (final extra in refreshAfter) _quiet(extra),
    ]);
  }

  static Future<void> _quiet(Future<void> Function() run) async {
    try {
      await run();
    } catch (_) {
      // One part of a refresh failing is not a reason to fail the rest.
    }
  }

  /// The page for an `EntityDetailTabs.layoutBuilder`: the pinned strip, the
  /// active tab's body and whatever sits above them, with pull-to-refresh.
  Widget buildPage({
    required Widget strip,
    required Widget body,
    required Widget top,
  }) => EntityRecordPage(
    controller: page,
    onRefresh: refresh,
    tabStrip: strip,
    tabBody: body,
    top: top,
  );

  @override
  void dispose() {
    _disposed = true;
    _recheck?.cancel();
    _backOnline.removeListener(_onBackOnline);
    _counts
      ?..removeListener(_forward)
      ..dispose();
    listIntents.dispose();
    selectTab.dispose();
    page.dispose();
    super.dispose();
  }
}
