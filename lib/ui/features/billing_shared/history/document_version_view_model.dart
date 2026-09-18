import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/document_version.dart';
import 'package:admin/data/services/document_versions_api.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

/// Loads one billing document's version history for the History tab.
///
/// Small on purpose. The "a ViewModel must be owned by the screen, never by a
/// tab body" rule (`test/lint/comments_surface_wiring_test.dart`) exists
/// because three surfaces share the *activity* feed and a second instance
/// leaves the Comments card empty. Version history has exactly one reader, so
/// this is owned by the tab's own `State`.
class DocumentVersionViewModel extends ChangeNotifier {
  DocumentVersionViewModel({
    required this.api,
    required this.basePath,
    required this.entityId,
    this.kickDebounce = const Duration(milliseconds: 300),
  });

  final DocumentVersionsApi api;

  /// The entity's collection path, e.g. `/api/v1/invoices`.
  final String basePath;
  final String entityId;

  /// Quiet period before [kick] fetches.
  ///
  /// `MasterDetailLayout` binds J/K to step a list and the router re-keys the
  /// detail subtree per `:id`, while `EntityDetailTabs` restores the user's
  /// last tab — so a user who left History selected and holds a key would
  /// otherwise fire one **full entity GET with a nested include** per repeat.
  /// The sibling activity feed carries the same 300 ms for the same reason.
  final Duration kickDebounce;

  Timer? _kickTimer;

  DocumentVersionPage _page = const DocumentVersionPage.empty();
  Object? _error;
  bool _loading = false;
  bool _loaded = false;
  bool _disposed = false;

  List<DocumentVersion> get versions => _page.versions;
  bool get truncated => _page.truncated;
  Object? get error => _error;
  bool get isLoading => _loading;

  /// True once a fetch has settled — the empty state must not paint before
  /// the first response, or a document with history shows "no records" for
  /// the length of a round trip.
  bool get hasLoaded => _loaded;

  /// True when the record has never reached the server, so there is nothing
  /// to ask about.
  bool get isUnsyncedRecord => isUnsynced(entityId);

  /// Arms the first load. Idempotent, so a tab rebuild does not refetch.
  ///
  /// Seeds from the cache first — **without notifying**, because this runs
  /// from `initState` — so stepping back onto a record paints instantly
  /// instead of spinning. A seed, never a suppressor: the fetch always goes
  /// out, exactly as `EntityActivityViewModel.kick` does.
  void kick() {
    if (_loaded || _loading) return;
    final seed = api.peekForEntity(basePath: basePath, id: entityId);
    if (seed != null) _page = seed;
    _kickTimer?.cancel();
    _kickTimer = Timer(kickDebounce, () {
      _kickTimer = null;
      unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    // An offline create has a `tmp_<uuid>` id the server cannot decode: the
    // request 404s, and because a 404 is a plain permanent 4xx here the user
    // gets a raw server string behind a Retry button that can never succeed.
    // Bail before touching `_loading`, the same shape
    // `EntityActivityViewModel.refresh` uses — this would burn a request to
    // learn nothing.
    if (isUnsyncedRecord) {
      _loaded = true;
      _safeNotify();
      return;
    }
    _loading = true;
    _error = null;
    _safeNotify();
    try {
      final page = await api.fetchForEntity(basePath: basePath, id: entityId);
      if (_disposed) return;
      _page = page;
      _error = null;
    } catch (error) {
      if (_disposed) return;
      _error = error;
    } finally {
      if (!_disposed) {
        _loading = false;
        _loaded = true;
        _safeNotify();
      }
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _kickTimer?.cancel();
    super.dispose();
  }
}
