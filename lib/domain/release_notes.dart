import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/version.dart';
import 'package:admin/domain/entity_type.dart';

/// The release notes the "What's new" dialog shows after an update
/// (docs/whats-new-dialog.md), bundled so they read offline and match the
/// build exactly. Newest first; one entry per release, written in the same
/// pass as the GitHub notes (docs/release-notes.md).

/// Where a build runs, as far as which notes it may show is concerned.
enum ReleaseNoteSurface {
  /// Native iOS or macOS — an App Store build, which may not name another
  /// mobile platform or app marketplace (Apple guideline 2.3.10,
  /// docs/mobile-app-promo.md § Store-policy review).
  appleStore,

  /// Native iOS or Android — already the phone app, and touch-first.
  nativePhone,
}

/// The surfaces this build belongs to.
Set<ReleaseNoteSurface> releaseNoteSurfaces({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return const {};
  return switch (platform) {
    TargetPlatform.iOS => const {
      ReleaseNoteSurface.appleStore,
      ReleaseNoteSurface.nativePhone,
    },
    TargetPlatform.macOS => const {ReleaseNoteSurface.appleStore},
    TargetPlatform.android => const {ReleaseNoteSurface.nativePhone},
    _ => const {},
  };
}

/// The live build's surfaces — [releaseNoteSurfaces] for this build.
Set<ReleaseNoteSurface> currentReleaseNoteSurfaces() =>
    releaseNoteSurfaces(isWeb: kIsWeb, platform: defaultTargetPlatform);

/// Which heading a bullet sits under, from its house-style prefix.
enum ReleaseNoteKind { added, updated, fixed }

/// One house-style bullet (`Added: …` / `Updated: …` / `Fixed: …`), pasted
/// verbatim from the GitHub notes.
@immutable
class ReleaseNoteItem {
  const ReleaseNoteItem(this.text, {this.hiddenOn = const {}});

  final String text;

  /// Surfaces that must not show it — [ReleaseNoteSurface.appleStore] for
  /// anything naming Android, Google Play, F-Droid or another store.
  final Set<ReleaseNoteSurface> hiddenOn;

  static final _prefix = RegExp(r'^(Added|Updated|Fixed):\s*');

  /// Null when the bullet has no known prefix — a catalog test rejects it.
  ReleaseNoteKind? get kind => switch (_prefix.firstMatch(text)?.group(1)) {
    'Added' => ReleaseNoteKind.added,
    'Updated' => ReleaseNoteKind.updated,
    'Fixed' => ReleaseNoteKind.fixed,
    _ => null,
  };

  /// What the dialog prints: [releaseNoteDisplayText] of the bullet.
  String get displayText => releaseNoteDisplayText(text);
}

/// A bullet as the dialog prints it: no `Added:` prefix, no issue links (a
/// bare "#176" means nothing to most readers, and the dialog never links out
/// — the GitHub release page names the Android builds), other links reduced
/// to their text, and no code backticks.
String releaseNoteDisplayText(String text) => text
    .replaceFirst(ReleaseNoteItem._prefix, '')
    .replaceAll(RegExp(r'\s*\[#\d+\]\([^)]*\)'), '')
    .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1)!)
    .replaceAll('`', '')
    .trim();

/// Where tapping a highlight goes.
sealed class ReleaseHighlightTarget {
  const ReleaseHighlightTarget();
}

/// A screen in the app. The highlight is shown only when the active company
/// can open it: [module] enabled and, when set, [permission] held — the rules
/// the sidebar applies to the same row.
final class ReleaseHighlightRoute extends ReleaseHighlightTarget {
  const ReleaseHighlightRoute(this.path, {this.module, this.permission});

  final String path;
  final EntityType? module;
  final String? permission;
}

/// The "get the mobile app" promo (docs/mobile-app-promo.md). The highlight is
/// shown only where the promo itself may open.
final class ReleaseHighlightMobileApp extends ReleaseHighlightTarget {
  const ReleaseHighlightMobileApp();
}

/// A headline change, shown above the full list.
@immutable
class ReleaseHighlight {
  const ReleaseHighlight({
    required this.icon,
    required this.title,
    required this.body,
    this.target,
    this.hiddenOn = const {},
  });

  /// The destination's own sidebar icon where it has one, so the row also
  /// says where the feature lives.
  final IconData icon;
  final String title;

  /// One line.
  final String body;
  final ReleaseHighlightTarget? target;
  final Set<ReleaseNoteSurface> hiddenOn;
}

@immutable
class ReleaseNotes {
  const ReleaseNotes({
    required this.version,
    required this.items,
    this.highlights = const [],
  });

  /// `MAJOR.MINOR.PATCH`, as in `AppVersion.kClientVersion`.
  final String version;

  /// At most [kMaxReleaseHighlights]. A release without any — fixes only —
  /// opens on its full list.
  final List<ReleaseHighlight> highlights;
  final List<ReleaseNoteItem> items;

  /// This release as [surfaces] may show it.
  ReleaseNotes visibleOn(Set<ReleaseNoteSurface> surfaces) => ReleaseNotes(
    version: version,
    highlights: [
      for (final h in highlights)
        if (h.hiddenOn.intersection(surfaces).isEmpty) h,
    ],
    items: [
      for (final i in items)
        if (i.hiddenOn.intersection(surfaces).isEmpty) i,
    ],
  );
}

/// The most highlights a release — or a catch-up across several — leads with.
const int kMaxReleaseHighlights = 5;

/// The most releases a catch-up shows.
const int kMaxReleasesShown = 5;

/// The releases to show after an update from [seen] to [current], newest
/// first, each filtered to [surfaces]; a release that filtering empties is
/// dropped.
///
/// [seen] null is an install that predates the record (docs/whats-new-dialog.md
/// § An update is told apart from an install by the store, not the session):
/// it gets the newest release this build carries, not the whole history.
List<ReleaseNotes> releasesToShow({
  required String? seen,
  required String current,
  required Set<ReleaseNoteSurface> surfaces,
  List<ReleaseNotes> catalog = kReleaseNotes,
}) {
  final inRange = [
    for (final r in catalog)
      if (compareSemver(r.version, current) <= 0 &&
          (seen == null || compareSemver(r.version, seen) > 0))
        r.visibleOn(surfaces),
  ].where((r) => r.items.isNotEmpty || r.highlights.isNotEmpty).toList();
  if (seen == null) return inRange.take(1).toList();
  return inRange.take(kMaxReleasesShown).toList();
}

const List<ReleaseNotes> kReleaseNotes = [
  ReleaseNotes(
    version: '5.1.16',
    highlights: [
      ReleaseHighlight(
        icon: Icons.bar_chart_outlined,
        title: 'Reports, rebuilt',
        body:
            'Open a report to run it, with charts, saved views and PDF / CSV '
            'export.',
        target: ReleaseHighlightRoute('/reports', permission: 'view_reports'),
      ),
      ReleaseHighlight(
        icon: Icons.description_outlined,
        title: 'A Documents list',
        body: 'Every file uploaded to the company, on the main menu.',
        target: ReleaseHighlightRoute(
          '/documents',
          module: EntityType.document,
        ),
      ),
      ReleaseHighlight(
        icon: Icons.work_outline,
        title: 'Project analytics',
        body: 'A forecast finish date, the burn-up chart and a health score.',
        target: ReleaseHighlightRoute('/projects', module: EntityType.project),
      ),
      ReleaseHighlight(
        icon: Icons.search,
        title: 'Smarter list search',
        body: 'Finds records not loaded yet and understands "this month".',
      ),
      ReleaseHighlight(
        icon: Icons.smartphone_outlined,
        title: 'Get the phone app',
        body: 'Open it here to install it on your phone.',
        target: ReleaseHighlightMobileApp(),
        hiddenOn: {ReleaseNoteSurface.nativePhone},
      ),
    ],
    items: [
      ReleaseNoteItem(
        'Added: Reports rebuilt — open a report to run it, with charts, totals '
        'per currency, saved views and PDF / CSV export. A new Task Items '
        'report lists every time entry in a date range, and the Tasks report '
        'shows one row per task instead of one per time entry.',
      ),
      ReleaseNoteItem(
        'Added: Project analytics — a forecast finish date, the burn-up chart, '
        'money, time and expense breakdowns, and a health score.',
      ),
      ReleaseNoteItem(
        'Added: A Documents list on the main menu with every file uploaded to '
        'the company, to preview, download, rename, make public or private, '
        'and delete.',
      ),
      ReleaseNoteItem(
        'Added: Custom fields on line items, bulk update for tasks, expenses '
        'and recurring invoices, Check VAT and PEPPOL delivery on clients, and '
        'comments and logged calls on tasks and projects.',
      ),
      ReleaseNoteItem(
        'Added: Custom labels now apply throughout the app, not just on '
        'documents [#84](https://github.com/invoiceninja/flutter/issues/84)',
      ),
      ReleaseNoteItem(
        'Added: F-Droid builds, reproducible and signed by Invoice Ninja '
        '[#175](https://github.com/invoiceninja/flutter/issues/175)',
        hiddenOn: {ReleaseNoteSurface.appleStore},
      ),
      ReleaseNoteItem(
        'Added: Get the phone app from the desktop app or the web: scan a QR '
        "code, or tap a store button in a phone's browser.",
        hiddenOn: {ReleaseNoteSurface.nativePhone},
      ),
      ReleaseNoteItem(
        "Added: When a self-hosted server's certificate is refused, sign-in "
        'explains why and lets you trust that exact certificate.',
      ),
      ReleaseNoteItem(
        'Updated: Smarter list search — it finds clients, vendors and projects '
        'not loaded yet, understands periods like "this month", keeps your '
        'search when you add a filter, reads pasted queries, and says when '
        'archived records are hidden, with Show archived under the last row.',
      ),
      ReleaseNoteItem(
        'Updated: Settings search opens the tab that holds the field and '
        'highlights it, and finds a section by its name or a keyword like '
        '"smtp" or "2fa".',
      ),
      ReleaseNoteItem(
        'Updated: A Compact list density, totals for selected rows, faster '
        'invoice editing, line breaks in line item descriptions, an API '
        "token's full value on its Edit screen, and saved invoices and quotes "
        "show the server's PDF, signatures included.",
      ),
      ReleaseNoteItem(
        'Fixed: A delivered email no longer shows the red bounced badge.',
      ),
      ReleaseNoteItem(
        "Fixed: Starting or stopping a timer on a task you can't edit no "
        'longer signs you out, the sign-in screen says why a session ended, '
        "and on the web you're warned before an idle sign-out.",
      ),
      ReleaseNoteItem(
        'Fixed: Very large amounts no longer lose cents when shown '
        '[#176](https://github.com/invoiceninja/flutter/issues/176)',
      ),
    ],
  ),
];
