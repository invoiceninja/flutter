import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/activity/activity_view_events.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';

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

  test('every tab selection in lib/ui names one of the two constants', () {
    // What makes the index safe. Project and Task used to say `-2` because
    // Comments sat second-to-last there; a host that reorders its strip
    // without re-aiming this opens the wrong tab, silently.
    //
    // Three things changed with invoiceninja/flutter#154, each making this
    // stricter rather than looser:
    //
    // 1. The literal `0` became `kCommentsTabIndex`, and a second channel
    //    (`kActivityTabIndex`, the `Viewed` status pill) joined it. A bare `0`
    //    still passes a host whose Comments tab has MOVED; a named constant
    //    cannot, because `detail_tab_indices_test.dart` pins the values to the
    //    strip's real shape and "the strip leads with Comments then Activity"
    //    above pins that shape.
    // 2. The scan is every file under `lib/ui`, not just the paired hosts, so
    //    the shared link widget — and the next file anyone writes — is covered
    //    by construction. (Drift's `.select(<Table>)` lives in `lib/data`.)
    // 3. The capture is deliberately `[^()]+` and not `\w+`: a regressed
    //    `select(-2)` must be CAUGHT and fail the membership check, not slip
    //    past the regex unseen. Negative indices are a documented API.
    const allowed = {'kCommentsTabIndex', 'kActivityTabIndex'};
    final selectArg = RegExp(r'\.select\(([^()]+)\)');
    final offenders = <String>[];
    var seen = 0;
    for (final f in _dartFiles('lib/ui')) {
      for (final m in selectArg.allMatches(f.readAsStringSync())) {
        seen++;
        final arg = m.group(1)!.trim();
        if (!allowed.contains(arg)) offenders.add('${f.path}: select($arg)');
      }
    }
    expect(
      seen,
      greaterThan(0),
      reason: 'the scan found no tab selections at all — regex rotted?',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'A tab selection must name kCommentsTabIndex or kActivityTabIndex '
          '(lib/ui/core/detail/detail_tab_indices.dart) so it survives the '
          'strip being reordered: $offenders',
    );
  });

  test('every View All link aims at Comments', () {
    // The membership test above cannot tell the two constants apart, so this
    // pins the *aim*: a `View All` that started opening the Activity tab would
    // pass there and fail here.
    final viewAll = RegExp(r'onViewAll:[^,]*?\.select\(([^()]+)\)');
    for (final entry in pairs.entries) {
      final joined = entry.value
          .map(File.new)
          .map((f) => f.readAsStringSync())
          .join('\n');
      if (!joined.contains('onViewAll:')) continue;
      final args = viewAll
          .allMatches(joined)
          .map((m) => m.group(1)!.trim())
          .toSet();
      expect(
        args,
        {'kCommentsTabIndex'},
        reason:
            '${entry.key} renders a View All link that opens something other '
            'than the leading Comments tab',
      );
    }
  });

  test('the two constants match the strip they name', () {
    // Closes the chain the membership test leans on: constant value <-> strip
    // position <-> what `select()` is handed. "The strip leads with Comments
    // then Activity" above already proves entry 0 is the `commentsOnly` tab and
    // entry 1 the Activity one, on all eleven hosts.
    expect(kCommentsTabIndex, 0);
    expect(kActivityTabIndex, 1);
  });

  test('every billing doc with a viewed status links its pill', () {
    // invoiceninja/flutter#154. Nothing in the type system notices a fifth
    // billing doc gaining a viewed status with no link, or one of the four
    // losing its — and there is no widget test on any of the four detail
    // headers to catch it either. Derived from the id map rather than a list,
    // the idiom `entity_copy_link_coverage_test.dart` uses.
    final mountPattern = RegExp(r'ViewedStatusPillLink\(');
    final wireNamePattern = RegExp("entityWireName:\\s*'([a-z_]+)'");
    final wired = <String>{};
    for (final f in _dartFiles('lib/ui')) {
      final src = f.readAsStringSync();
      if (!mountPattern.hasMatch(src)) continue;
      if (f.path.endsWith('viewed_status_pill_link.dart')) continue;
      wired.addAll(wireNamePattern.allMatches(src).map((m) => m.group(1)!));
      // A leaked controller is silent — no error, no log, just a live listener
      // per record visited. Mirrors the ViewModel arm/dispose test below.
      expect(
        src,
        contains('ActivityRevealController('),
        reason:
            '${f.path} links its status pill but builds no reveal '
            'controller, so the tap changes tabs and highlights nothing',
      );
      // The controller by name, not a bare `.dispose()`: every detail screen
      // already disposes a view model and a tab controller, so the loose form
      // passes whatever happens to the reveal controller — which is the leak
      // (a live listener per record visited) this is here to catch.
      expect(
        src,
        contains('_revealActivity.dispose()'),
        reason: '${f.path} builds a reveal controller it never disposes',
      );
    }
    expect(
      wired,
      kViewActivityTypeIds.keys.toSet(),
      reason:
          'The set of entities whose status pill links to their view activity '
          'must equal the set that HAS a view activity id. A mismatch means '
          'either a doc shipped with no way to reach the record of who looked, '
          'or a link aimed at an entity the server writes no view event for.',
    );
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

  test('every host names itself, because that now decides navigation', () {
    // `hostWireName` started as a label — which record a *note* was filed
    // against (#121) — so a host that forgot it lost a meta-line suffix and
    // nothing else. Since invoiceninja/flutter#143 it also decides whether a
    // row is a navigation target at all: the record on screen is skipped when
    // resolving one, so a host that omits it ships a chevron on every row
    // about itself, opening the screen the user is already standing on.
    // Silent, and only on the one screen that forgot.
    //
    // Sliced per `EntityActivityTab(` call rather than searched across the
    // file: every host also passes `hostWireName` to `EntityCommentsCard`, so
    // a whole-file `contains` stays green for exactly the mistake this is
    // here to catch — dropping it from the *tab* alone.
    for (final entry in pairs.entries) {
      final joined = entry.value
          .map(File.new)
          .map((f) => f.readAsStringSync())
          .join('\n');
      final mounts = _argumentsOf(joined, 'EntityActivityTab(');
      expect(
        mounts,
        isNotEmpty,
        reason: '${entry.key} no longer mounts the tab this pins',
      );
      for (final args in mounts) {
        expect(
          args,
          contains('hostWireName:'),
          reason:
              '${entry.key} mounts the Activity tab without a hostWireName, '
              'so its rows link back to the record already on screen',
        );
      }
    }
  });
}

/// The argument text of every `name` invocation in [source], parens balanced.
/// Value-blind on purpose: what has to hold is that the argument reaches *this*
/// call, not which literal it carries.
List<String> _argumentsOf(String source, String name) {
  final out = <String>[];
  for (
    var at = source.indexOf(name);
    at >= 0;
    at = source.indexOf(name, at + 1)
  ) {
    var depth = 1;
    var i = at + name.length;
    while (i < source.length && depth > 0) {
      if (source[i] == '(') {
        depth++;
      } else if (source[i] == ')') {
        depth--;
      }
      i++;
    }
    out.add(source.substring(at + name.length, i - 1));
  }
  return out;
}

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));
