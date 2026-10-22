import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/version.dart';
import 'package:admin/domain/release_notes.dart';

/// The bundled release notes (docs/whats-new-dialog.md): a well-formed
/// catalog, the releases an update shows, the text the dialog prints, and
/// the store rule — an App Store build never names another platform's store.
void main() {
  // The release that carries the F-Droid bullet and the phone-app promo,
  // looked up by version so a newer release at the top doesn't move it.
  final withStoreNames = kReleaseNotes.firstWhere((r) => r.version == '5.1.16');

  group('the catalog', () {
    test('versions are unique and strictly newest first', () {
      for (var i = 1; i < kReleaseNotes.length; i++) {
        expect(
          compareSemver(kReleaseNotes[i - 1].version, kReleaseNotes[i].version),
          1,
          reason:
              '${kReleaseNotes[i - 1].version} must be newer than '
              '${kReleaseNotes[i].version}',
        );
      }
    });

    test('every bullet starts Added:, Updated: or Fixed:', () {
      for (final release in kReleaseNotes) {
        for (final item in release.items) {
          expect(
            item.kind,
            isNotNull,
            reason: '${release.version}: "${item.text}"',
          );
        }
      }
    });

    // House style: docs/release-notes.md § Release notes never use an em
    // dash. A hyphen is fine.
    test('no bullet, highlight or F-Droid changelog uses an em dash', () {
      for (final release in kReleaseNotes) {
        for (final item in release.items) {
          expect(item.text, isNot(contains('—')), reason: release.version);
        }
        for (final h in release.highlights) {
          expect(
            '${h.title} ${h.body}',
            isNot(contains('—')),
            reason: release.version,
          );
        }
      }
      final changelogs = Directory('fastlane/metadata/android/en-US/changelogs')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.txt'))
          .toList();
      expect(changelogs, isNotEmpty);
      for (final f in changelogs) {
        expect(f.readAsStringSync(), isNot(contains('—')), reason: f.path);
      }
    });

    test('no release is empty, and none leads with more than '
        '$kMaxReleaseHighlights highlights', () {
      for (final release in kReleaseNotes) {
        expect(release.items, isNotEmpty, reason: release.version);
        expect(
          release.highlights.length,
          lessThanOrEqualTo(kMaxReleaseHighlights),
          reason: release.version,
        );
      }
    });
  });

  group('the App Store builds (Apple guideline 2.3.10)', () {
    // Names of other mobile platforms and app marketplaces — what reviewers
    // reject in a Mac or iPhone App Store build (docs/mobile-app-promo.md).
    final forbidden = RegExp(
      r'android|google|play store|f-droid|fdroid|microsoft store|\bsnap\b|'
      r'appimage',
      caseSensitive: false,
    );

    for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
      test('${platform.name} shows nothing that names another store', () {
        final surfaces = releaseNoteSurfaces(isWeb: false, platform: platform);
        expect(surfaces, contains(ReleaseNoteSurface.appleStore));
        for (final release in kReleaseNotes) {
          final visible = release.visibleOn(surfaces);
          for (final item in visible.items) {
            expect(item.text, isNot(matches(forbidden)), reason: item.text);
          }
          for (final h in visible.highlights) {
            expect('${h.title} ${h.body}', isNot(matches(forbidden)));
          }
        }
      });
    }

    test('the web and Windows keep the F-Droid bullet', () {
      for (final surfaces in [
        releaseNoteSurfaces(isWeb: true, platform: TargetPlatform.macOS),
        releaseNoteSurfaces(isWeb: false, platform: TargetPlatform.windows),
      ]) {
        final items = withStoreNames.visibleOn(surfaces).items;
        expect(items.where((i) => i.text.contains('F-Droid')), hasLength(1));
      }
    });
  });

  test('the phone apps are not pitched the phone app', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      final visible = withStoreNames.visibleOn(
        releaseNoteSurfaces(isWeb: false, platform: platform),
      );
      expect(
        visible.highlights.where((h) => h.target is ReleaseHighlightMobileApp),
        isEmpty,
      );
      expect(
        visible.items.where((i) => i.text.contains('Get the phone app')),
        isEmpty,
      );
    }
  });

  group('releaseNoteDisplayText', () {
    test('drops the prefix and issue links, keeps other link text, and '
        'strips backticks', () {
      expect(
        releaseNoteDisplayText(
          'Fixed: Very large amounts no longer lose cents '
          '[#176](https://github.com/invoiceninja/flutter/issues/176)',
        ),
        'Very large amounts no longer lose cents',
      );
      expect(
        releaseNoteDisplayText(
          'Added: See [the docs](https://example.com) and press `R`',
        ),
        'See the docs and press R',
      );
    });

    test('maps each prefix to its heading', () {
      expect(const ReleaseNoteItem('Added: x').kind, ReleaseNoteKind.added);
      expect(const ReleaseNoteItem('Updated: x').kind, ReleaseNoteKind.updated);
      expect(const ReleaseNoteItem('Fixed: x').kind, ReleaseNoteKind.fixed);
      expect(const ReleaseNoteItem('Changed: x').kind, isNull);
    });
  });

  group('releasesToShow', () {
    ReleaseNotes release(String v, {bool appleOnly = false}) => ReleaseNotes(
      version: v,
      items: [
        ReleaseNoteItem(
          'Added: $v',
          hiddenOn: appleOnly ? const {ReleaseNoteSurface.appleStore} : {},
        ),
      ],
    );
    final catalog = [
      for (final v in ['1.0.9', '1.0.8', '1.0.7', '1.0.6', '1.0.5', '1.0.4'])
        release(v),
      release('1.0.3', appleOnly: true),
      release('1.0.2'),
    ];
    List<String> show(
      String? seen,
      String current, {
      Set<ReleaseNoteSurface> surfaces = const {},
    }) => [
      for (final r in releasesToShow(
        seen: seen,
        current: current,
        surfaces: surfaces,
        catalog: catalog,
      ))
        r.version,
    ];

    test('an install that predates the record gets the newest release this '
        'build carries — not the whole history', () {
      expect(show(null, '1.0.9'), ['1.0.9']);
      // A build bumped past its notes still has the last ones.
      expect(show(null, '1.0.10'), ['1.0.9']);
    });

    test('an update shows what came after the version it was on, newest '
        'first, and no release newer than this build', () {
      expect(show('1.0.6', '1.0.8'), ['1.0.8', '1.0.7']);
      expect(show('1.0.8', '1.0.8'), isEmpty);
    });

    test('a long catch-up stops at $kMaxReleasesShown releases', () {
      expect(show('1.0.2', '1.0.9'), hasLength(kMaxReleasesShown));
      expect(show('1.0.2', '1.0.9').first, '1.0.9');
    });

    test('a release the surface empties is dropped', () {
      expect(show('1.0.2', '1.0.4', surfaces: const {}), ['1.0.4', '1.0.3']);
      expect(
        show('1.0.2', '1.0.4', surfaces: const {ReleaseNoteSurface.appleStore}),
        ['1.0.4'],
      );
    });
  });

  group('whatsNewHighlights', () {
    ReleaseHighlight h(String title, {bool major = false, String? path}) =>
        ReleaseHighlight(
          icon: Icons.star,
          title: title,
          body: title,
          target: path == null ? null : ReleaseHighlightRoute(path),
          major: major,
        );
    ReleaseNotes release(String v, List<ReleaseHighlight> highlights) =>
        ReleaseNotes(version: v, highlights: highlights, items: const []);
    List<String> titles(
      List<ReleaseNotes> releases, {
      bool Function(ReleaseHighlightTarget)? reachable,
    }) => [
      for (final x in whatsNewHighlights(
        releases,
        reachable: reachable ?? (_) => true,
      ))
        x.title,
    ];

    test('key features lead; otherwise a release keeps its own order', () {
      expect(
        titles([
          release('1.0.2', [h('a'), h('b', major: true), h('c')]),
        ]),
        ['b', 'a', 'c'],
      );
      expect(
        titles([
          release('1.0.2', [h('a'), h('b'), h('c')]),
        ]),
        ['a', 'b', 'c'],
      );
    });

    test('a catch-up leads with the key features of every release, before '
        'the newest release\'s smaller ones', () {
      final releases = [
        release('1.0.4', [h('new 1'), h('new 2'), h('new 3')]),
        release('1.0.3', [h('key 3', major: true), h('minor 3')]),
        release('1.0.2', [
          h('key 2a', major: true),
          h('key 2b', major: true),
          h('minor 2'),
        ]),
      ];
      expect(titles(releases), ['key 3', 'key 2a', 'key 2b', 'new 1', 'new 2']);
    });

    test('stops at $kMaxReleaseHighlights, and leaves out what this user '
        'cannot open', () {
      final releases = [
        release('1.0.3', [
          for (var i = 0; i < 4; i++) h('key 3.$i', major: true),
        ]),
        release('1.0.2', [
          h('key 2', major: true, path: '/hidden'),
          h('key 2b', major: true),
          h('minor 2'),
        ]),
      ];
      final shown = titles(
        releases,
        reachable: (t) => t is! ReleaseHighlightRoute || t.path != '/hidden',
      );
      expect(shown, hasLength(kMaxReleaseHighlights));
      expect(shown, isNot(contains('key 2')));
      expect(shown.last, 'key 2b');
    });

    // The case that prompted the rule, pinned to its versions so newer
    // releases at the top of the catalog don't move it.
    test('5.1.15 to 5.1.19 leads with the key features of 5.1.16 and 5.1.17, '
        'not only the small changes of 5.1.19', () {
      final releases = releasesToShow(
        seen: '5.1.15',
        current: '5.1.19',
        surfaces: const {},
      );
      expect(
        whatsNewHighlights(
          releases,
          reachable: (_) => true,
        ).map((x) => x.title),
        [
          'An Activity timeline',
          'Reports, rebuilt',
          'A Documents list',
          'Project analytics',
          'Search that ignores accents',
        ],
      );
    });
  });

  test('surfaces: the web is no App Store build, even on a Mac or iPhone', () {
    expect(
      releaseNoteSurfaces(isWeb: true, platform: TargetPlatform.iOS),
      isEmpty,
    );
    expect(
      releaseNoteSurfaces(isWeb: false, platform: TargetPlatform.linux),
      isEmpty,
    );
    expect(
      releaseNoteSurfaces(isWeb: false, platform: TargetPlatform.android),
      {ReleaseNoteSurface.nativePhone},
    );
  });
}
