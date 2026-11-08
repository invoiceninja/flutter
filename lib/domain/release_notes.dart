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

  /// Every build with no home-screen widgets (docs/home-screen-widgets.md):
  /// web, Windows and Linux. A note about the widgets is `hiddenOn` this, so
  /// it is read only where it can be used. (iOS below 17 and macOS below 14
  /// have none either, but can't be told apart here.)
  withoutHomeWidgets,
}

/// The surfaces this build belongs to.
Set<ReleaseNoteSurface> releaseNoteSurfaces({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  if (isWeb) return const {ReleaseNoteSurface.withoutHomeWidgets};
  return switch (platform) {
    TargetPlatform.iOS => const {
      ReleaseNoteSurface.appleStore,
      ReleaseNoteSurface.nativePhone,
    },
    TargetPlatform.macOS => const {ReleaseNoteSurface.appleStore},
    TargetPlatform.android => const {ReleaseNoteSurface.nativePhone},
    _ => const {ReleaseNoteSurface.withoutHomeWidgets},
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
    this.major = false,
  });

  /// The destination's own sidebar icon where it has one, so the row also
  /// says where the feature lives.
  final IconData icon;
  final String title;

  /// One line.
  final String body;
  final ReleaseHighlightTarget? target;
  final Set<ReleaseNoteSurface> hiddenOn;

  /// A key feature — a new screen or a rebuilt one — that someone catching up
  /// across several releases should still be shown. In a catch-up these lead,
  /// ahead of every newer highlight that isn't one ([whatsNewHighlights]).
  final bool major;
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

/// The highlights the dialog leads with for [releases] (newest first): every
/// [ReleaseHighlight.major] one first, then the rest, each group newest
/// release first, leaving out any whose target isn't [reachable] — at most
/// [kMaxReleaseHighlights].
///
/// A catch-up merges several releases' highlights into one short list, so
/// taking them newest first would fill it with the latest release's small
/// changes and drop the key features of the releases before it.
List<ReleaseHighlight> whatsNewHighlights(
  List<ReleaseNotes> releases, {
  required bool Function(ReleaseHighlightTarget target) reachable,
}) {
  final open = [
    for (final release in releases)
      for (final h in release.highlights)
        if (h.target == null || reachable(h.target!)) h,
  ];
  return [
    ...open.where((h) => h.major),
    ...open.where((h) => !h.major),
  ].take(kMaxReleaseHighlights).toList();
}

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
    version: '5.1.23',
    highlights: [
      ReleaseHighlight(
        icon: Icons.attach_file,
        title: 'Attach files as you create',
        body: 'Add documents to any new record before you save it.',
      ),
      ReleaseHighlight(
        icon: Icons.receipt_outlined,
        title: 'Your saved tax rates',
        body: "Pick the company's tax rates on documents and line items.",
        target: ReleaseHighlightRoute('/invoices', module: EntityType.invoice),
      ),
      ReleaseHighlight(
        icon: Icons.bar_chart_outlined,
        title: 'More report columns',
        body: "Add fields from each row's client, contact or vendor.",
        target: ReleaseHighlightRoute('/reports', permission: 'view_reports'),
      ),
      ReleaseHighlight(
        icon: Icons.devices_outlined,
        title: 'Device Settings in tabs',
        body:
            'Appearance, Security, Phone, Forms and Data, each on its own tab.',
        target: ReleaseHighlightRoute('/settings/device_settings'),
      ),
    ],
    items: [
      ReleaseNoteItem(
        'Added: Passkeys. Sign in with your face, fingerprint or screen lock '
        'instead of your password, and add or remove passkeys in User Details '
        '> Two-Factor. They appear on a device once it is supported there.',
      ),
      ReleaseNoteItem(
        'Added: Documents can be attached while creating any record, not just '
        'an expense, and upload when it is saved '
        '[#173](https://github.com/invoiceninja/flutter/issues/173)',
      ),
      ReleaseNoteItem(
        "Added: A report can add fields from each row's client, contact or "
        "vendor, such as a payment's client city.",
      ),
      ReleaseNoteItem(
        "Updated: Taxes on invoices, quotes and other documents are picked from "
        "the company's saved tax rates, on a phone's line items too.",
      ),
      ReleaseNoteItem(
        'Updated: Record screens are denser on phones, and their text can be '
        'selected and copied with a long-press '
        '[#187](https://github.com/invoiceninja/flutter/issues/187) '
        '[#188](https://github.com/invoiceninja/flutter/issues/188)',
      ),
      ReleaseNoteItem(
        'Updated: Device Settings is split into tabs: Appearance, Security, '
        'Phone, Forms and Data.',
      ),
      ReleaseNoteItem(
        'Fixed: Invoices and quotes can be found by their line items again, '
        "and selecting records on a client's screen shows the bulk actions "
        '[#185](https://github.com/invoiceninja/flutter/issues/185) '
        '[#186](https://github.com/invoiceninja/flutter/issues/186)',
      ),
      ReleaseNoteItem(
        "Fixed: A phone's task list shows the full duration, and a designer "
        'image block set to the company logo now prints on the invoice '
        '[#183](https://github.com/invoiceninja/flutter/issues/183) '
        '[#184](https://github.com/invoiceninja/flutter/issues/184)',
      ),
      ReleaseNoteItem(
        "Fixed: A payment for less than an invoice's balance saves instead of "
        'failing to balance, and a price typed as 3,00 no longer saves as 300.',
      ),
      ReleaseNoteItem(
        'Fixed: A time entry keeps its description when its editor is closed, '
        "and a task's project can be picked before its client.",
      ),
      ReleaseNoteItem(
        'Fixed: A plan bought in the app completes only once the server has '
        'recorded it.',
      ),
    ],
  ),
  ReleaseNotes(
    version: '5.1.22',
    highlights: [
      ReleaseHighlight(
        icon: Icons.widgets_outlined,
        title: 'Home-screen widgets',
        body:
            'Outstanding, past-due invoices and your running timer at a glance.',
        target: ReleaseHighlightRoute('/settings/device_settings/phone'),
        hiddenOn: {ReleaseNoteSurface.withoutHomeWidgets},
        major: true,
      ),
      ReleaseHighlight(
        icon: Icons.payment_outlined,
        title: 'Pay a draft invoice',
        body:
            'Apply a payment or credit to a draft. It is marked sent, not emailed.',
        target: ReleaseHighlightRoute('/invoices', module: EntityType.invoice),
      ),
    ],
    items: [
      ReleaseNoteItem(
        'Added: Home-screen widgets on phones, tablets and Macs: a business '
        'snapshot, the invoices that need attention, and a task timer you can '
        'stop or start with one tap. Set them up in Device Settings.',
        hiddenOn: {ReleaseNoteSurface.withoutHomeWidgets},
      ),
      ReleaseNoteItem(
        'Added: A payment or credit can be applied to a draft invoice, which '
        'marks it sent without emailing it.',
      ),
      ReleaseNoteItem(
        'Fixed: Text is readable again on Intel Macs. Since 5.1.17 much of it '
        'rendered as garbled, smeared glyphs.',
      ),
      ReleaseNoteItem(
        'Fixed: Deleted records no longer appear in the dashboard lists, such '
        'as Upcoming Recurring Invoices '
        '[#181](https://github.com/invoiceninja/flutter/issues/181)',
      ),
      ReleaseNoteItem(
        "Fixed: Invoicing a task keeps its project's name on the line, even "
        "for an archived project or one the app hasn't loaded yet.",
      ),
    ],
  ),
  ReleaseNotes(
    version: '5.1.21',
    highlights: [
      ReleaseHighlight(
        icon: Icons.edit_outlined,
        title: 'Tap a line to edit it',
        body: "A line item on a document's record screen opens its editor.",
        target: ReleaseHighlightRoute('/invoices', module: EntityType.invoice),
      ),
      ReleaseHighlight(
        icon: Icons.receipt_long_outlined,
        title: 'Last Sent Date column',
        body: 'See when each invoice or quote was last sent.',
        target: ReleaseHighlightRoute('/invoices', module: EntityType.invoice),
      ),
      ReleaseHighlight(
        icon: Icons.picture_as_pdf_outlined,
        title: 'A PDF that keeps up',
        body: 'The PDF preview refreshes as soon as the document changes.',
      ),
      ReleaseHighlight(
        icon: Icons.timer_outlined,
        title: 'Show seconds',
        body: 'Task timers and time entries can show seconds.',
        target: ReleaseHighlightRoute('/settings/device_settings'),
      ),
    ],
    items: [
      ReleaseNoteItem(
        'Added: A self-hosted server can be updated from the app. An admin '
        'sees Update Available in the sidebar when a newer version is out, '
        'and About offers Update App.',
      ),
      ReleaseNoteItem(
        'Added: Tap a line item on an invoice, quote, credit, purchase order '
        "or recurring invoice's record screen to edit that line straight away.",
      ),
      ReleaseNoteItem(
        'Added: An optional Last Sent Date column on the invoice and quote '
        'lists.',
      ),
      ReleaseNoteItem(
        'Added: Show Seconds in Device Settings adds seconds to task timers, '
        'durations and time entries.',
      ),
      ReleaseNoteItem(
        'Updated: On desktop, downloads save straight to the downloads folder, '
        'with an Open button. Windows and Linux can choose the folder in '
        'Device Settings.',
      ),
      ReleaseNoteItem(
        "Fixed: A billing document's PDF preview now refreshes after an edit, "
        'instead of showing the document as first opened.',
      ),
      ReleaseNoteItem(
        'Fixed: An invoice or quote with a negative total can be saved, an '
        'expense with only a payment type shows as Paid, and a new logo block '
        "in the invoice designer starts at the stock designs' size "
        '[#179](https://github.com/invoiceninja/flutter/issues/179)',
      ),
    ],
  ),
  ReleaseNotes(
    version: '5.1.20',
    highlights: [
      ReleaseHighlight(
        icon: Icons.receipt_outlined,
        title: 'Read a receipt',
        body: 'Attach a receipt to a new expense and its fields fill in.',
        target: ReleaseHighlightRoute(
          '/expenses/new',
          module: EntityType.expense,
          permission: 'create_expense',
        ),
        major: true,
      ),
      ReleaseHighlight(
        icon: Icons.language_outlined,
        title: '36 more languages',
        body: 'Every language Invoice Ninja offers, including right-to-left.',
        major: true,
      ),
      ReleaseHighlight(
        icon: Icons.dashboard_outlined,
        title: 'Your dashboard, everywhere',
        body: 'Its cards and layout follow you to other devices.',
        target: ReleaseHighlightRoute(
          '/dashboard',
          permission: 'view_dashboard',
        ),
      ),
      ReleaseHighlight(
        icon: Icons.add_circle_outline,
        title: 'Create from a picker',
        body: 'Add a vendor, category or client without leaving the form.',
      ),
      ReleaseHighlight(
        icon: Icons.bar_chart_outlined,
        title: 'Three new reports',
        body: 'Credit Items, Recurring Expenses and Transactions.',
        target: ReleaseHighlightRoute('/reports', permission: 'view_reports'),
      ),
    ],
    items: [
      ReleaseNoteItem(
        'Added: Receipt reading. A photo or PDF attached to a new expense '
        'fills in its amount, date, vendor, currency and taxes, read on the '
        'device, with Undo. Not available on web or Linux.',
      ),
      ReleaseNoteItem(
        'Added: On a phone or tablet, documents can be added from the camera '
        'or Photos, and Scan Receipt in the create menu takes a photo straight '
        'into a new expense.',
      ),
      ReleaseNoteItem(
        'Added: 36 more languages, so the app now speaks every language '
        'Invoice Ninja offers. Arabic, Hebrew and Persian lay out '
        'right-to-left.',
      ),
      ReleaseNoteItem(
        'Added: Create a vendor, expense category or client right from its '
        'picker, without leaving the form.',
      ),
      ReleaseNoteItem(
        'Added: Credit Items, Recurring Expenses and Transactions reports, and '
        'right-click a chart bar or point to see its rows or copy its value.',
      ),
      ReleaseNoteItem(
        'Added: Spell check on line item names and descriptions, with a switch '
        'in Device Settings.',
      ),
      ReleaseNoteItem(
        'Added: On a phone, Add Text puts a line of plain text (no price or '
        'quantity) on an invoice, quote or other document, written in a '
        'full-screen editor.',
      ),
      ReleaseNoteItem(
        "Updated: The dashboard's cards, chart grouping and panel arrangement "
        'now follow you to your other devices and the web app.',
      ),
      ReleaseNoteItem(
        'Updated: New invoices, quotes, credits, purchase orders and recurring '
        'invoices start with the default tax rates, and show the default '
        'terms, footer and payment terms '
        '[#178](https://github.com/invoiceninja/flutter/issues/178)',
      ),
      ReleaseNoteItem(
        'Updated: The list search box has a button to clear what is typed, the '
        "product picker's filter sits just above the phone keyboard, and a line "
        "item's description grows as you type.",
      ),
      ReleaseNoteItem(
        'Fixed: A notes field low in a form scrolls clear of the phone '
        "keyboard, Activity's Load more no longer gets stuck, a blank client "
        "or group setting no longer hides the company's terms, and an edit "
        'screen no longer shows the record through it as it slides in.',
      ),
    ],
  ),
  ReleaseNotes(
    version: '5.1.19',
    highlights: [
      ReleaseHighlight(
        icon: Icons.search,
        title: 'Search that ignores accents',
        body: 'Case and accents are ignored, so "mu" finds "Müller".',
      ),
      ReleaseHighlight(
        icon: Icons.web_outlined,
        title: 'Client portal QR codes',
        body: 'Print a QR code for the portal login and registration links.',
      ),
    ],
    items: [
      ReleaseNoteItem(
        'Added: Client Portal settings show a QR code for the login and '
        'registration links, with a print-ready PNG download, and a notice '
        'when the client portal is turned off.',
      ),
      ReleaseNoteItem(
        'Updated: List search ignores case and accents in every language, so '
        '"mu" or "MÜ" finds "Müller".',
      ),
      ReleaseNoteItem(
        'Updated: Recurring invoices no longer offer Send Email, which always '
        'failed. Send Now on a draft sends its first invoice '
        '[#13368](https://github.com/invoiceninja/invoiceninja/issues/13368)',
      ),
      ReleaseNoteItem(
        'Fixed: Self-hosted Client Portal settings lead with the short portal '
        'address again, and a hosted account on a subdomain no longer gets a '
        'registration link that 404s.',
      ),
      ReleaseNoteItem(
        'Fixed: Custom invoice designs and tax rates save again.',
      ),
      ReleaseNoteItem(
        "Fixed: On a phone, dragging on an invoice's notes scrolls the page, "
        'and the invoice QuickBooks tab shows its content again.',
      ),
    ],
  ),
  ReleaseNotes(
    version: '5.1.18',
    items: [
      ReleaseNoteItem(
        'Updated: The F-Droid APKs now number each CPU architecture the way '
        'F-Droid expects, so a new version always installs over the previous '
        'one.',
        hiddenOn: {ReleaseNoteSurface.appleStore},
      ),
    ],
  ),
  ReleaseNotes(
    version: '5.1.17',
    highlights: [
      ReleaseHighlight(
        icon: Icons.history,
        title: 'An Activity timeline',
        body: 'Tap or drag a period to filter, or narrow it by category.',
        target: ReleaseHighlightRoute('/activity'),
        major: true,
      ),
      ReleaseHighlight(
        icon: Icons.event_repeat_outlined,
        title: 'Comments on recurring expenses',
        body: 'Recurring expenses now have comments and activity.',
        target: ReleaseHighlightRoute(
          '/recurring_expenses',
          module: EntityType.recurringExpense,
        ),
      ),
    ],
    items: [
      ReleaseNoteItem(
        'Added: An Activity timeline. Tap or drag a period to filter the feed, '
        'narrow it by date range or category with a count beside each, and use '
        'Load more to reach further back. Repeated events are folded together.',
      ),
      ReleaseNoteItem('Added: Comments and activity on recurring expenses.'),
      ReleaseNoteItem(
        'Updated: List density is now set only in Device Settings, which gives '
        "each list's search field more room.",
      ),
      ReleaseNoteItem(
        'Fixed: Contacts sync on Android could delete or change contacts of '
        'your own. It now only changes contacts it created, and leaves alone '
        'any that Android merged with one of yours.',
        hiddenOn: {ReleaseNoteSurface.appleStore},
      ),
      ReleaseNoteItem(
        'Fixed: Typing on the Expenses tab of an invoice no longer saves a '
        'duplicate line at every pause.',
      ),
      ReleaseNoteItem(
        "Fixed: Users who can't create a record no longer see New buttons, the "
        '+ button or create shortcuts for it.',
      ),
      ReleaseNoteItem(
        'Fixed: Dashboard Invoices, Payments and Expenses figures for a period '
        'still in progress now run to today, matching their trend and '
        'drill-down.',
      ),
      ReleaseNoteItem(
        'Fixed: A list no longer misses its newest records until the next full '
        'Sync, Apply to oldest invoice picks the oldest unpaid invoice, and a '
        'past-due project no longer reads "On track".',
      ),
    ],
  ),
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
        major: true,
      ),
      ReleaseHighlight(
        icon: Icons.description_outlined,
        title: 'A Documents list',
        body: 'Every file uploaded to the company, on the main menu.',
        target: ReleaseHighlightRoute(
          '/documents',
          module: EntityType.document,
        ),
        major: true,
      ),
      ReleaseHighlight(
        icon: Icons.work_outline,
        title: 'Project analytics',
        body: 'A forecast finish date, the burn-up chart and a health score.',
        target: ReleaseHighlightRoute('/projects', module: EntityType.project),
        major: true,
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
        'Added: Reports are rebuilt. Open a report to run it, with charts, '
        'totals per currency, saved views and PDF / CSV export. A new Task Items '
        'report lists every time entry in a date range, and the Tasks report '
        'shows one row per task instead of one per time entry.',
      ),
      ReleaseNoteItem(
        'Added: Project analytics, with a forecast finish date, the burn-up '
        'chart, money, time and expense breakdowns, and a health score.',
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
        'Updated: Smarter list search. It finds clients, vendors and projects '
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
