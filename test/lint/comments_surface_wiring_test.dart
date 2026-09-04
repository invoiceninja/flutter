import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Source-level guards for the comments surfaces (invoiceninja/flutter#121).
///
/// Scanned rather than exercised, for the reason `call_note_wiring_test.dart`
/// and `status_tab_wiring_test.dart` are: every failure here is **silent**.
/// The screen still builds, the tabs still open, the comment is still saved —
/// the card is simply never visible, or a drift subscription leaks per record.
/// Reaching these paths for real needs the whole app graph.
///
/// The file set is **derived, not listed**: any file that mounts the shared
/// activity tab is expected to carry the rest of the wiring, so a twelfth
/// detail screen is covered the day it is written rather than the day someone
/// remembers to add it here.
void main() {
  // The shared implementation lives under `billing_shared/activity/` and
  // names both classes; only the hosts are being pinned here.
  bool isHost(File f) => !f.path.contains('billing_shared/activity/');

  final mounts = _dartFiles('lib/ui/features')
      .where(isHost)
      .where((f) => f.readAsStringSync().contains('EntityActivityTab('))
      .toList(growable: false);

  /// The screen that owns the ViewModel and the widget that builds the tabs
  /// are the same file everywhere except Client and Project, which extract a
  /// `<Entity>DetailTabs`. Pair them so a check can look at both halves.
  final pairs = <String, List<String>>{
    for (final f in mounts) f.path: [f.path],
  };
  pairs['lib/ui/features/clients/widgets/detail/client_detail_tabs.dart']?.add(
    'lib/ui/features/clients/views/client_detail_screen.dart',
  );
  pairs['lib/ui/features/projects/widgets/detail/project_detail_tabs.dart']
      ?.add('lib/ui/features/projects/views/project_detail_screen.dart');

  test('the scan finds every detail screen that mounts the activity tab', () {
    // Eleven entities: client, vendor, invoice, quote, credit, purchase order,
    // recurring invoice, payment, expense, project, task.
    expect(mounts.length, 11, reason: mounts.map((f) => f.path).join('\n'));
  });

  test('every one of them also mounts the Comments card and tab', () {
    for (final entry in pairs.entries) {
      final joined = entry.value
          .map(File.new)
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(
        joined,
        contains('EntityCommentsCard('),
        reason:
            '${entry.key} mounts the Activity tab but no Comments card, so a '
            'comment on that record is only readable from a tab again',
      );
      expect(
        joined,
        contains('commentsOnly: true'),
        reason: '${entry.key} has no Comments tab',
      );
    }
  });

  test('a card that offers View All is wired to a tab strip that listens', () {
    // Task shipped with `onViewAll:` and a `TabSelectionController` it built,
    // fired and disposed — but never passed `selectTab:` to `EntityDetailTabs`,
    // so the link was dead: no tab change, no scroll, no error, no log. The
    // controller and the strip live in different files on Client and Project,
    // so pair them the way the test above does.
    for (final entry in pairs.entries) {
      final joined = entry.value
          .map(File.new)
          .map((f) => f.readAsStringSync())
          .join('\n');
      if (!joined.contains('onViewAll:')) continue;
      expect(
        joined,
        contains('selectTab:'),
        reason:
            '${entry.key} renders a View All link but never hands its '
            'TabSelectionController to EntityDetailTabs, so the link is dead',
      );
    }
  });

  test('the strip leads with Comments then Activity', () {
    // invoiceninja/flutter#122: Activity used to sit LAST — 15th of 15 on a
    // client, four screens of horizontal scrolling away on the 440-560 px
    // pane — while Comments, which is only a filtered view of the same feed,
    // sat first. Nothing in the type system notices a twelfth host, or a new
    // tab, quietly splitting the pair again.
    //
    // Anchored on the entry constructors, not on `label: context.tr('…')`:
    // the billing screens carry unrelated `label:` lines (KPI cells), seven
    // Documents tabs come from `buildStandardDocumentsTab` and so carry no
    // label in the host file at all, and the other four compute theirs.
    final entryPattern = RegExp(
      r'\b(?:EntityDetailTab|buildStandardDocumentsTab)\(',
    );
    for (final path in pairs.keys) {
      final src = File(path).readAsStringSync();
      final starts = entryPattern
          .allMatches(src)
          .map((m) => m.start)
          .toList(growable: false);
      String entry(int i) => src.substring(
        starts[i],
        i + 1 < starts.length ? starts[i + 1] : src.length,
      );
      expect(
        starts.length,
        greaterThanOrEqualTo(2),
        reason: '$path has fewer than two tabs',
      );
      expect(
        entry(0),
        contains('commentsOnly: true'),
        reason: '$path does not lead with its Comments tab',
      );
      expect(
        entry(1),
        allOf(
          contains('EntityActivityTab('),
          isNot(contains('commentsOnly: true')),
        ),
        reason:
            '$path does not put Activity immediately after Comments — the two '
            'are one feed and belong beside each other at the head',
      );
    }
  });

  test('every View All link targets the Comments tab at index 0', () {
    // What makes the hardcoded 0 safe. Project and Task used to say `-2`
    // because Comments sat second-to-last there; a host that reorders its
    // strip without re-aiming this opens the wrong tab, silently.
    //
    // Every `select(…)` argument is checked, not just "the source contains
    // `select(0)` somewhere" — that weaker form passes a host whose View All
    // regressed to `select(3)` as long as a stray `select(0)` survives
    // elsewhere in either paired file.
    final selectArg = RegExp(r'\.select\((-?\d+)\)');
    for (final entry in pairs.entries) {
      final joined = entry.value
          .map(File.new)
          .map((f) => f.readAsStringSync())
          .join('\n');
      if (!joined.contains('onViewAll:')) continue;
      final args = selectArg
          .allMatches(joined)
          .map((m) => m.group(1))
          .toList(growable: false);
      expect(
        args,
        isNotEmpty,
        reason: '${entry.key} renders a View All link that selects no tab',
      );
      expect(
        args.toSet(),
        {'0'},
        reason:
            '${entry.key} aims a tab selection somewhere other than the '
            'leading Comments tab',
      );
    }
  });

  test('every host keeps its landing tab with initialIndex: 2', () {
    // The pair takes indices 0 and 1, so the tab the screen used to open on is
    // now at 2. A host that leads with Comments + Activity and forgets this
    // opens every record on the comment feed instead of its content — silent,
    // and only visible to someone who remembers what the screen used to do.
    for (final entry in pairs.entries) {
      final joined = entry.value
          .map(File.new)
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(
        joined,
        contains('initialIndex: 2'),
        reason:
            '${entry.key} leads with the Comments + Activity pair but does not '
            'push its landing tab past them',
      );
    }
  });

  test('a ViewModel is always both armed and disposed by its owner', () {
    // Two failures with real blast radius, neither of which throws:
    // forgetting `kick()` leaves the card permanently hidden and the tab
    // permanently empty with no error and no log; forgetting `dispose()`
    // leaks a live drift `watchPendingForEntity` subscription per record,
    // which stepping a list with J/K turns into a pile.
    for (final file in _dartFiles('lib/ui').where(isHost)) {
      final src = file.readAsStringSync();
      if (!src.contains('EntityActivityViewModel(')) continue;
      expect(
        src,
        contains('.kick()'),
        reason: '${file.path} builds the VM but never arms its fetch',
      );
      expect(
        src,
        contains('_activityVm.dispose()'),
        reason: '${file.path} builds the VM but never disposes it',
      );
    }
  });

  test('no tab body builds its own ViewModel', () {
    // The whole point is one fetch shared by the card and both tabs. A VM
    // built inside a `bodyBuilder` would re-introduce the second request and
    // leave the card reading an empty feed of its own.
    for (final file in _dartFiles('lib/ui/features').where(isHost)) {
      final src = file.readAsStringSync();
      final vmAt = src.indexOf('EntityActivityViewModel(');
      if (vmAt < 0) continue;
      final builderAt = src.indexOf('bodyBuilder:');
      expect(
        builderAt < 0 || vmAt < builderAt,
        isTrue,
        reason:
            '${file.path} constructs an EntityActivityViewModel after its '
            'first bodyBuilder — it belongs in the screen State\'s initState',
      );
    }
  });
}

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
