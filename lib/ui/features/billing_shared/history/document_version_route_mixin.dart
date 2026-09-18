import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/document_version.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

final Logger _log = Logger('DocumentVersionRoute');

/// Version-picker state for a `/:id/pdf` route screen.
///
/// Mixed into all five billing-document PDF route screens so the fetch, the
/// selection and the `?activity_id=` seeding live in one place.
///
/// **Selection is local state seeded from the URL, not written back to it.**
/// That is deliberately the same contract as the delivery-note toggle sitting
/// beside it in this very screen: `?delivery_note=true` seeds
/// `BillingDocPdfView._deliveryNote` and the toggle then owns it. Writing each
/// pick back through `context.go` would append one entry to `NavHistoryController`
/// per tap — the browser-style back/forward arrows are a shipped feature, and
/// a user comparing four versions should not have to press back four times to
/// leave the screen.
mixin DocumentVersionRouteMixin<T extends StatefulWidget> on State<T> {
  List<DocumentVersion> _versions = const [];
  String? _selected;

  /// The record whose versions these are.
  String get entityId;

  /// The `?activity_id=` the route arrived with, if any.
  String? get initialActivityId;

  /// Versions available to the picker, newest first. Empty until the fetch
  /// lands, and empty forever on a route that carries no `?activity_id=` —
  /// a plain "View PDF" is not a request for history.
  List<DocumentVersion> get versions => _versions;

  /// Null selects the live document.
  String? get selectedActivityId => _selected;

  /// Starts the version fetch when the route opened on a version.
  ///
  /// Call from `initState`. [basePath] is the entity's collection path.
  void initVersions(Services services, {required String basePath}) {
    _selected = initialActivityId;
    // Nothing to pick between on a plain PDF route, and an offline-created
    // record has no server id to ask about.
    if (_selected == null || isUnsynced(entityId)) return;
    // Usually a real request: `EntityDetailTabs` builds tab bodies lazily, so
    // in the common path the History tab has never run and the cache is cold.
    // It is shared with the tab when both are live.
    services.documentVersions
        .fetchForEntity(basePath: basePath, id: entityId)
        .then((page) {
          if (!mounted) return;
          setState(() => _versions = page.versions);
        })
        // A failed version list is not a failed screen — the PDF the route
        // was opened for still renders, just without a picker. Logged rather
        // than swallowed: the user is then stranded on one version with no
        // way to reach another, and nothing else would say why.
        .catchError((Object error, StackTrace stack) {
          _log.warning('Version list fetch failed for $entityId', error, stack);
        });
  }

  /// Switches the rendered version. Null returns to the live document.
  void selectVersion(String? activityId) {
    if (_selected == activityId) return;
    setState(() => _selected = activityId);
  }
}
