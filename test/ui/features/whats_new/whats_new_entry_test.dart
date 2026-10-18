// The notes' permanent ways back (docs/whats-new-dialog.md): About's
// "See what's new" button and the command palette's Release Notes row.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/whats_new_controller.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/release_notes.dart';
import 'package:admin/ui/features/shell/widgets/about_dialog.dart';
import 'package:admin/ui/features/shell/widgets/command_palette.dart';

import '../shell/_shell_test_helpers.dart';

void main() {
  late ShellFixture fixture;

  setUp(() async {
    fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme')],
    );
  });

  tearDown(() async => fixture.dispose());

  WhatsNewController controller() {
    final c = WhatsNewController(
      prefs: DevicePrefsStore(null),
      currentVersion: '2.0.2',
      catalog: const [
        ReleaseNotes(
          version: '2.0.2',
          items: [ReleaseNoteItem('Added: Something new.')],
        ),
      ],
      surfaces: const {},
      isDemoBuild: false,
      demoMode: false,
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Pumps a trigger under the root provider the app puts above its router.
  Future<void> pump(
    WidgetTester tester,
    WhatsNewController? c,
    void Function(BuildContext) onPressed,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final app = wrapWithShell(
      fixture.services,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => onPressed(context),
          child: const Text('trigger'),
        ),
      ),
    );
    await tester.pumpWidget(
      c == null ? app : ChangeNotifierProvider.value(value: c, child: app),
    );
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
  }

  group('About', () {
    testWidgets("offers this build's notes, and opens them", (tester) async {
      await pump(tester, controller(), showAppAboutDialog);
      await tester.tap(find.text("See what's new in v2.0.2"));
      await tester.pumpAndSettle();
      expect(find.text("What's new in v2.0.2"), findsOneWidget);
      expect(find.text('Something new.'), findsOneWidget);
    });

    testWidgets('reading a waiting update there marks it seen, so it does '
        'not open again on its own', (tester) async {
      final c = controller();
      await c.noteLaunch(existingInstall: true);
      expect(c.autoOpens, isTrue);
      await pump(tester, c, showAppAboutDialog);
      await tester.tap(find.text("See what's new in v2.0.2"));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text('Got it!'));
      await tester.pumpAndSettle();
      expect(c.autoOpens, isFalse);
      expect(c.state.seenVersion, '2.0.2');
      expect(c.state.shownAt, isNotNull, reason: "the promo's day starts");
    });

    testWidgets('absent without a controller', (tester) async {
      await pump(tester, null, showAppAboutDialog);
      expect(find.textContaining("See what's new"), findsNothing);
    });
  });

  group('command palette', () {
    Future<void> search(WidgetTester tester, String query) async {
      await pump(tester, controller(), showCommandPalette);
      await tester.enterText(find.byType(TextField), query);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    for (final query in ["what's new", 'changelog', 'release', 'version']) {
      testWidgets('"$query" finds the release notes', (tester) async {
        await search(tester, query);
        expect(find.text('Release Notes'), findsOneWidget);
        expect(find.text("See what's new in v2.0.2"), findsOneWidget);
      });
    }

    testWidgets('a word that merely contains one of the terms does not', (
      tester,
    ) async {
      await search(tester, 'date');
      expect(find.text("See what's new in v2.0.2"), findsNothing);
    });

    testWidgets('choosing it opens the notes over the current screen', (
      tester,
    ) async {
      await search(tester, 'changelog');
      await tester.tap(find.text("See what's new in v2.0.2"));
      await tester.pumpAndSettle();
      expect(find.text("What's new in v2.0.2"), findsOneWidget);
    });
  });
}
