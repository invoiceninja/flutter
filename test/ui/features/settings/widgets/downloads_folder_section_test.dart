import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/downloads_folder_controller.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/ui/core/utils/save_download.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/settings/widgets/downloads_folder_section.dart';

import '../../../../_localization_helper.dart';
import '../../../../_support/fake_url_launcher.dart';

/// The old app's *Downloads Folder*: Windows and Linux choose one, macOS shows
/// its Downloads read-only (a sandboxed pick would not survive a relaunch),
/// and a phone has no card (docs/file-downloads.md).
void main() {
  const osFolder = '/home/jo/Downloads';
  final realLookup = downloadsFolderLookup;
  final realPicker = directoryPicker;
  late DownloadsFolderController controller;
  late ToastController toasts;
  late UrlLauncherPlatform realLauncher;

  setUp(() {
    controller = DownloadsFolderController(prefs: DevicePrefsStore(null));
    toasts = ToastController();
    downloadsFolderLookup = () async => osFolder;
    realLauncher = UrlLauncherPlatform.instance;
  });
  tearDown(() {
    downloadsFolderLookup = realLookup;
    directoryPicker = realPicker;
    UrlLauncherPlatform.instance = realLauncher;
    toasts.dispose();
  });

  Future<void> pump(WidgetTester tester, {bool provided = true}) async {
    const section = Scaffold(
      body: SingleChildScrollView(child: DownloadsFolderSection()),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ToastController>.value(value: toasts),
          if (provided)
            ChangeNotifierProvider<DownloadsFolderController>.value(
              value: controller,
            ),
        ],
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: section,
        ),
      ),
    );
    await tester.pump();
  }

  final select = find.byKey(const ValueKey('downloads_folder_select'));
  final reset = find.byKey(const ValueKey('downloads_folder_reset'));
  final open = find.byKey(const ValueKey('downloads_folder_open'));

  testWidgets(
    'Windows / Linux: the OS folder by default, Select picks one, Reset '
    'goes back',
    (tester) async {
      String? pickedFrom;
      directoryPicker = ({dialogTitle, initialDirectory}) async {
        pickedFrom = initialDirectory;
        return '/data/invoices';
      };
      await pump(tester);

      expect(find.text('Downloads Folder'), findsOneWidget);
      expect(find.text(osFolder), findsOneWidget);
      expect(find.text('Default'), findsOneWidget);
      expect(reset, findsNothing);
      expect(open, findsNothing);

      await tester.tap(select);
      await tester.pump();
      expect(pickedFrom, osFolder);
      expect(controller.value, '/data/invoices');
      expect(find.text('/data/invoices'), findsOneWidget);
      expect(find.text('Default'), findsNothing);

      await tester.tap(reset);
      await tester.pump();
      expect(controller.value, '');
      expect(find.text(osFolder), findsOneWidget);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
  );

  testWidgets('a picker that throws toasts instead of crashing', (
    tester,
  ) async {
    directoryPicker = ({dialogTitle, initialDirectory}) async =>
        throw Exception('no portal');
    await pump(tester);
    await tester.tap(select);
    await tester.pump();
    expect(controller.value, '');
    expect(toasts.toasts.single.message, 'An error occurred');
    await tester.pump(const Duration(seconds: 10));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
    'macOS: Downloads read-only, with Open, even when a folder was stored',
    (tester) async {
      final launcher = FakeUrlLauncher();
      UrlLauncherPlatform.instance = launcher;
      await controller.set('/Volumes/elsewhere');
      await pump(tester);

      expect(find.text(osFolder), findsOneWidget);
      expect(select, findsNothing);
      expect(reset, findsNothing);
      await tester.tap(open);
      await tester.pump();
      expect(launcher.launched, [Uri.directory(osFolder).toString()]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'no card on a phone',
    (tester) async {
      await pump(tester);
      expect(find.text('Downloads Folder'), findsNothing);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  testWidgets('no card without its controller', (tester) async {
    await pump(tester, provided: false);
    expect(find.text('Downloads Folder'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  test('the search gate is the card\'s own', () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(downloadsFolderSectionShown(), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(downloadsFolderSectionShown(), isFalse);
  });
}
