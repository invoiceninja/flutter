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
