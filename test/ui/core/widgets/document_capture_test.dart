import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/services/shared_intake_files.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/ui/core/widgets/document_capture.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

import '../../../_localization_helper.dart';

/// The phone's Camera / Photos / Files tiles on a documents surface — the old
/// app's camera button (`DocumentGrid`), back — and the conversion every photo
/// goes through before it reaches `onFiles`.
void main() {
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1, 2, 3, 4]);
  final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 1, 2]);
  // `ftypheic` at offset 4 — what an unconverted iPhone photo starts with.
  final heic = Uint8List.fromList([
    0, 0, 0, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, //
  ]);

  late _FakePicker picker;
  final defaultFactory = imagePickerFactory;
  setUp(() {
    picker = _FakePicker();
    imagePickerFactory = () => picker;
  });
  tearDown(() {
    imagePickerFactory = defaultFactory;
    // A pick a failed test never finished must not block the next test's.
    if (picker.hold case final hold? when !hold.isCompleted) hold.complete();
    debugResetPhotoPicking();
  });

  group('releaseCapturedPhotos', () {
    // A photo a surface didn't keep — rejected, refused, or arriving after
    // the screen closed — is handed straight back, not left for a day.
    test('deletes the app\'s own copies and nothing else', () async {
      final support = Directory.systemTemp.createTempSync('release');
      addTearDown(() => support.deleteSync(recursive: true));
      final intake = SharedIntakeFiles(
        supportDirectory: () async => support,
        referencedPaths: () async => const {},
      );
      final ours = File(
        p.join(support.path, SharedIntakeFiles.kFolderName, 'u1', 'IMG_1.jpg'),
      )..createSync(recursive: true);
      final theirs = File(p.join(support.path, 'picked.jpg'))..createSync();

      await releaseCapturedPhotos(intake, [
        fileUploadSource(ours.path),
        fileUploadSource(theirs.path),
        BytesUploadSource(jpeg, 'IMG_2.jpg'),
      ]);

      expect(ours.existsSync(), isFalse);
      expect(theirs.existsSync(), isTrue, reason: 'not ours to delete');
    });

    test('a no-op with no folder', () async {
      final orphan = File(
        p.join(Directory.systemTemp.createTempSync('noop').path, 'IMG_1.jpg'),
      )..createSync();
      addTearDown(() => orphan.parent.deleteSync(recursive: true));

      await releaseCapturedPhotos(null, [fileUploadSource(orphan.path)]);

      expect(orphan.existsSync(), isTrue);
    });
  });

  group('imageExtensionOf', () {
    test('names the four types the server takes from their first bytes', () {
      expect(imageExtensionOf(jpeg), 'jpg');
      expect(imageExtensionOf(png), 'png');
      expect(imageExtensionOf(Uint8List.fromList('GIF89a'.codeUnits)), 'gif');
      expect(
        imageExtensionOf(
          Uint8List.fromList('RIFF\x00\x00\x00\x00WEBP'.codeUnits),
        ),
        'webp',
      );
    });

    test('anything else — a HEIC the plugin could not convert — is null', () {
      expect(imageExtensionOf(heic), isNull);
      expect(imageExtensionOf(Uint8List(0)), isNull);
      expect(imageExtensionOf(Uint8List.fromList([0xFF, 0xD8])), isNull);
    });
  });

  group('FileDropZone.allowPhotos', () {
    testWidgets(
      'a phone gets Camera / Photos / Files instead of the box',
      (tester) async {
        await _pump(tester, onFiles: (_) async {});
        expect(find.text('Camera'), findsOneWidget);
        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('Files'), findsOneWidget);
        expect(find.byIcon(Icons.upload_file_outlined), findsNothing);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );

    testWidgets(
      'a desktop keeps the drop-or-click box',
      (tester) async {
        await _pump(tester, onFiles: (_) async {});
        expect(find.byIcon(Icons.upload_file_outlined), findsOneWidget);
        expect(find.text('Camera'), findsNothing);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }),
    );

    testWidgets(
      'a surface that does not ask for photos keeps the box on a phone',
      (tester) async {
        await _pump(tester, allowPhotos: false, onFiles: (_) async {});
        expect(find.byIcon(Icons.upload_file_outlined), findsOneWidget);
        expect(find.text('Camera'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('Camera hands one photo to onFiles, named the camera way', (
      tester,
    ) async {
      picker.next = [XFile.fromData(jpeg, path: '/cache/image_picker_9F2.jpg')];
      final got = <UploadSource>[];
      await _pump(tester, onFiles: (s) async => got.addAll(s));

      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      expect(picker.calls, ['camera']);
      expect(got, hasLength(1));
      expect(got.single.fileName, matches(RegExp(r'^IMG_\d{8}_\d{6}\.jpg$')));
      // No app folder to keep it in here (no Services): the bytes travel in
      // the outbox row instead, so nothing can vanish under it.
      expect(got.single, isA<BytesUploadSource>());
      expect((got.single as BytesUploadSource).bytes, jpeg);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets(
      'Photos names each photo the camera way, typed by its content, and '
      'refuses an unconverted HEIC',
      (tester) async {
        picker.next = [
          // Android re-encodes to JPEG but keeps the original name.
          XFile.fromData(jpeg, path: '/cache/PXL_2026.heic'),
          XFile.fromData(png, path: '/cache/screenshot.png'),
          XFile.fromData(heic, path: '/cache/IMG_0001.heic'),
        ];
        final toasts = ToastController();
        addTearDown(toasts.dispose);
        final got = <UploadSource>[];
        await _pump(
          tester,
          toasts: toasts,
          onFiles: (s) async => got.addAll(s),
        );

        await tester.tap(find.text('Photos'));
        await tester.pumpAndSettle();

        expect(picker.calls, ['multi']);
        // Neither the original name nor its extension survives: the content
        // says JPEG, and the plugin's names are its own temp names.
        expect(got.map((s) => s.fileName), [
          matches(RegExp(r'^IMG_\d{8}_\d{6}\.jpg$')),
          matches(RegExp(r'^IMG_\d{8}_\d{6}_2\.png$')),
        ]);
        expect(toasts.toasts.single.variant, NotifyVariant.warning);
        expect(
          toasts.toasts.single.message,
          "You can't upload files of this type.",
        );
        toasts.clearAll();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    // What the plugins really hand back: iOS re-saves every library pick as
    // `image_picker_<GUID>.jpg`, Android as `scaled_<name>`. Either reached
    // the server — and the client portal — as the document's name.
    testWidgets('a library photo never keeps the plugin\'s temp name', (
      tester,
    ) async {
      picker.next = [
        XFile.fromData(
          jpeg,
          path: '/tmp/image_picker_3F2A1C55-0B1E-4E7D-9F00-1A2B3C4D5E6F.jpg',
        ),
        XFile.fromData(jpeg, path: '/cache/scaled_receipt.jpg'),
      ];
      final got = <UploadSource>[];
      await _pump(tester, onFiles: (s) async => got.addAll(s));

      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();

      for (final source in got) {
        expect(source.fileName, startsWith('IMG_'));
        expect(source.fileName, isNot(contains('image_picker')));
        expect(source.fileName, isNot(contains('scaled_')));
      }
      expect(got, hasLength(2));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    // Android writes each resized library photo to `cache/scaled_<name>`, so
    // two picks sharing a name come back as one path. The second used to
    // throw out of the whole pick, attaching nothing.
    testWidgets('two picks at the same path attach once, without failing', (
      tester,
    ) async {
      picker.next = [
        XFile.fromData(jpeg, path: '/cache/scaled_receipt.jpg'),
        XFile.fromData(jpeg, path: '/cache/scaled_receipt.jpg'),
      ];
      final got = <UploadSource>[];
      await _pump(tester, onFiles: (s) async => got.addAll(s));

      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();

      expect(got, hasLength(1));
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('a photo that cannot be read is skipped, the rest kept', (
      tester,
    ) async {
      picker.next = [
        _UnreadableFile('/cache/gone.jpg'),
        XFile.fromData(png, path: '/cache/ok.png'),
      ];
      final toasts = ToastController();
      addTearDown(toasts.dispose);
      final got = <UploadSource>[];
      await _pump(tester, toasts: toasts, onFiles: (s) async => got.addAll(s));

      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();

      expect(got.map((s) => s.fileName), [endsWith('.png')]);
      expect(toasts.toasts.single.variant, NotifyVariant.warning);
      toasts.clearAll();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    // One picker at a time, app-wide: the tablet's Scan Receipt button has no
    // `FileDropZone` guard, and a second request made the plugin refuse it
    // (Android) or cancel the first (iOS), toasting an error over a camera
    // that was opening fine.
    testWidgets('a second request while a picker is open is ignored', (
      tester,
    ) async {
      picker.next = [XFile.fromData(jpeg, path: '/cache/a.jpg')];
      picker.hold = Completer<void>();
      await _pump(tester, onFiles: (_) async {});
      final context = tester.element(find.byType(FileDropZone));

      final first = captureDocumentPhoto(context);
      final second = await captureDocumentPhoto(context);
      expect(second, isEmpty);
      expect(picker.calls, ['camera'], reason: 'no second picker');

      picker.hold!.complete();
      expect(await first, hasLength(1));
      // And the next request after it is served again.
      expect(await captureDocumentPhoto(context), hasLength(1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a single-file surface asks the library for one photo', (
      tester,
    ) async {
      picker.next = [XFile.fromData(jpeg, path: '/cache/a.jpg')];
      await _pump(tester, allowMultiple: false, onFiles: (_) async {});

      await tester.tap(find.text('Photos'));
      await tester.pumpAndSettle();

      expect(picker.calls, ['gallery']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('backing out of the camera hands nothing on', (tester) async {
      picker.next = const [];
      var called = false;
      await _pump(tester, onFiles: (_) async => called = true);

      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets(
      'a refused permission says so, with a way to Settings',
      (tester) async {
        picker.error = PlatformException(code: 'camera_access_denied');
        final toasts = ToastController();
        addTearDown(toasts.dispose);
        var called = false;
        await _pump(
          tester,
          toasts: toasts,
          onFiles: (_) async => called = true,
        );

        await tester.tap(find.text('Camera'));
        await tester.pumpAndSettle();

        expect(called, isFalse);
        final toast = toasts.toasts.single;
        expect(toast.variant, NotifyVariant.warning);
        expect(toast.message, contains('Settings'));
        expect(toast.action?.label, 'Settings');
        toasts.clearAll();
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
    );

    for (final (code, tile) in [
      ('photo_access_denied', 'Photos'),
      ('no_available_camera', 'Camera'),
      ('already_active', 'Camera'),
    ]) {
      testWidgets('$code from $tile reads right', (tester) async {
        picker.error = PlatformException(code: code);
        final toasts = ToastController();
        addTearDown(toasts.dispose);
        await _pump(tester, toasts: toasts, onFiles: (_) async {});

        await tester.tap(find.text(tile));
        await tester.pumpAndSettle();

        switch (code) {
          case 'photo_access_denied':
            expect(toasts.toasts.single.message, contains('Settings'));
          case 'no_available_camera':
            expect(
              toasts.toasts.single.message,
              'No camera is available on this device.',
            );
          default:
            // A second picker raced the first, which is opening: silence.
            expect(toasts.toasts, isEmpty);
        }
        toasts.clearAll();
      }, variant: TargetPlatformVariant.only(TargetPlatform.android));
    }

    testWidgets('anything else the picker throws is an error, not a crash', (
      tester,
    ) async {
      picker.error = StateError('boom');
      final toasts = ToastController();
      addTearDown(toasts.dispose);
      var called = false;
      await _pump(tester, toasts: toasts, onFiles: (_) async => called = true);

      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(toasts.toasts.single.variant, NotifyVariant.error);
      toasts.clearAll();
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('each tile is a button to a screen reader, and says when it '
        'is dimmed', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, onFiles: (_) async {});
      expect(
        tester.getSemantics(find.text('Camera')),
        isSemantics(label: 'Camera', isButton: true, isEnabled: true),
      );

      await _pump(tester, enabled: false, onFiles: (_) async {});
      expect(
        tester.getSemantics(find.text('Camera')),
        isSemantics(isButton: true, hasEnabledState: true, isEnabled: false),
      );
      handle.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    // Screen Time or a managed device: iOS says `…_access_restricted`, and
    // the way back is the same Settings page.
    testWidgets('a restricted camera reads as a refused one', (tester) async {
      picker.error = PlatformException(code: 'camera_access_restricted');
      final toasts = ToastController();
      addTearDown(toasts.dispose);
      await _pump(tester, toasts: toasts, onFiles: (_) async {});

      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      expect(toasts.toasts.single.variant, NotifyVariant.warning);
      expect(toasts.toasts.single.action?.label, 'Settings');
      toasts.clearAll();
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    // "Don't ask again" leaves the system settings as the only way back, and
    // no URL reaches this app's page there on Android.
    testWidgets('on Android the Settings action asks MainActivity', (
      tester,
    ) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        appSettingsChannel,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          appSettingsChannel,
          null,
        ),
      );
      picker.error = PlatformException(code: 'camera_access_denied');
      final toasts = ToastController();
      addTearDown(toasts.dispose);
      await _pump(tester, toasts: toasts, onFiles: (_) async {});
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      toasts.toasts.single.action!.onPressed();
      await tester.pump();

      expect(calls, ['openAppSettings']);
      toasts.clearAll();
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    // A big photo from iCloud, or a re-encode, takes seconds after the
    // picker closes; the dimmed row alone looked like the locked state.
    testWidgets('the tapped tile shows a spinner while its work runs', (
      tester,
    ) async {
      picker.next = [XFile.fromData(jpeg, path: '/cache/a.jpg')];
      picker.hold = Completer<void>();
      await _pump(tester, onFiles: (_) async {});

      await tester.tap(find.text('Camera'));
      await tester.pump();

      Finder spinnerIn(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        matching: find.byType(CircularProgressIndicator),
      );
      expect(spinnerIn('Camera'), findsOneWidget);
      expect(spinnerIn('Photos'), findsNothing);
      expect(spinnerIn('Files'), findsNothing);

      picker.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    // The photo has to leave the plugin's temp folder, which the OS may
    // empty before an offline upload is sent.
    testWidgets('on a phone a photo is moved into the app\'s own folder', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('capture');
      addTearDown(() => dir.deleteSync(recursive: true));
      final intake = SharedIntakeFiles(
        supportDirectory: () async => Directory(p.join(dir.path, 'support')),
        referencedPaths: () async => const {},
      );
      final shot = File(p.join(dir.path, 'image_picker_9F2.jpg'))
        ..writeAsBytesSync([...jpeg, 0, 0, 0, 0]);
      picker.next = [XFile(shot.path)];
      final got = <UploadSource>[];
      await _pump(
        tester,
        services: _IntakeServices(intake),
        onFiles: (s) async => got.addAll(s),
      );

      await tester.tap(find.text('Camera'));
      await _settleIo(tester, until: () => got.isNotEmpty);

      final path = SharedIntakeFiles.localPathOf(got.single);
      expect(path, isNotNull);
      expect(await intake.owns(path!), isTrue);
      expect(shot.existsSync(), isFalse, reason: 'moved out of temp');
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    // Left the screen with the camera up: the photo still leaves the temp
    // folder, and — nothing being there to take it — is handed straight back.
    testWidgets('a photo that arrives after the zone is gone is released', (
      tester,
    ) async {
      final dir = Directory.systemTemp.createTempSync('capture');
      addTearDown(() => dir.deleteSync(recursive: true));
      final support = Directory(p.join(dir.path, 'support'));
      final intake = SharedIntakeFiles(
        supportDirectory: () async => support,
        referencedPaths: () async => const {},
      );
      final shot = File(p.join(dir.path, 'image_picker_1.jpg'))
        ..writeAsBytesSync([...jpeg, 0, 0, 0, 0]);
      picker.next = [XFile(shot.path)];
      picker.hold = Completer<void>();
      var called = false;
      await _pump(
        tester,
        services: _IntakeServices(intake),
        onFiles: (_) async => called = true,
      );
      await tester.tap(find.text('Camera'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      picker.hold!.complete();
      final folder = Directory(
        p.join(support.path, SharedIntakeFiles.kFolderName),
      );
      bool empty() =>
          !folder.existsSync() ||
          folder.listSync(recursive: true).whereType<File>().isEmpty;
      await _settleIo(tester, until: () => !shot.existsSync() && empty());

      expect(shot.existsSync(), isFalse, reason: 'left the temp folder');
      expect(empty(), isTrue, reason: 'and was handed back');
      expect(called, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a disabled zone opens nothing', (tester) async {
      picker.next = [XFile.fromData(jpeg, path: '/cache/a.jpg')];
      await _pump(tester, enabled: false, onFiles: (_) async {});

      await tester.tap(find.text('Camera'), warnIfMissed: false);
      await tester.tap(find.text('Photos'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(picker.calls, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('the tiles fit a narrow phone at a large text size', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, textScale: 2, onFiles: (_) async {});
      expect(tester.takeException(), isNull);
      // Each tile still meets the touch target.
      for (final label in ['Camera', 'Photos', 'Files']) {
        final tile = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        expect(
          tester.getSize(tile).height,
          greaterThanOrEqualTo(InSizes.touchTarget),
        );
      }
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function(List<UploadSource>) onFiles,
  bool allowPhotos = true,
  bool allowMultiple = true,
  bool enabled = true,
  double textScale = 1,
  ToastController? toasts,
  Services? services,
}) async {
  final controller = toasts ?? ToastController();
  if (toasts == null) addTearDown(controller.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ToastController>.value(value: controller),
        if (services != null) Provider<Services>.value(value: services),
      ],
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: FileDropZone(
              allowedExtensions: const ['pdf', 'jpg', 'png'],
              allowMultiple: allowMultiple,
              allowPhotos: allowPhotos,
              enabled: enabled,
              onFiles: onFiles,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

class _FakePicker extends Fake implements ImagePicker {
  List<XFile> next = const [];
  Object? error;
  final calls = <String>[];

  /// When set, a pick waits on it — a picker still on screen.
  Completer<void>? hold;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    calls.add(source == ImageSource.camera ? 'camera' : 'gallery');
    // Every pick asks for a resize: it is what makes iOS write a HEIC as JPEG.
    expect(maxWidth, isNotNull);
    expect(imageQuality, isNotNull);
    await hold?.future;
    if (error case final e?) throw e;
    return next.firstOrNull;
  }

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    calls.add('multi');
    expect(maxWidth, isNotNull);
    expect(imageQuality, isNotNull);
    await hold?.future;
    if (error case final e?) throw e;
    return next;
  }
}

/// A pick whose file vanished before it could be read.
class _UnreadableFile extends Fake implements XFile {
  _UnreadableFile(this.path);

  @override
  final String path;

  @override
  String get name => path.split('/').last;

  @override
  Stream<Uint8List> openRead([int? start, int? end]) =>
      Stream.error(const FileSystemException('gone'));

  @override
  Future<Uint8List> readAsBytes() =>
      Future.error(const FileSystemException('gone'));
}

/// File IO is real time, which a widget test's clock doesn't advance: let it
/// run, then let the frames it scheduled build, until [until] holds.
Future<void> _settleIo(
  WidgetTester tester, {
  required bool Function() until,
}) async {
  for (var i = 0; i < 100 && !until(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

/// Just enough `Services` for `intakeOf`.
class _IntakeServices implements Services {
  _IntakeServices(this.sharedIntakeFiles);

  @override
  final SharedIntakeFiles sharedIntakeFiles;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
