import 'package:admin/app/linux_package.dart';
import 'package:admin/app/linux_package_io.dart' as io;
import 'package:admin/app/secure_storage_unavailable_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('detectLinuxPackage', () {
    LinuxPackage detect(Map<String, String> env, {bool flatpakInfo = false}) =>
        io.detectLinuxPackage(
          environment: env,
          fileExists: (path) => flatpakInfo && path == '/.flatpak-info',
        );

    test('FLATPAK_ID or /.flatpak-info is a Flatpak', () {
      expect(
        detect({'FLATPAK_ID': 'com.invoiceninja.admin'}),
        LinuxPackage.flatpak,
      );
      expect(detect({}, flatpakInfo: true), LinuxPackage.flatpak);
    });

    test('SNAP is a Snap', () {
      expect(detect({'SNAP': '/snap/invoiceninja/42'}), LinuxPackage.snap);
    });

    test('neither (an AppImage, a dev run) is no package', () {
      expect(detect({'APPIMAGE': '/tmp/x.AppImage'}), LinuxPackage.none);
      expect(detect({'FLATPAK_ID': '', 'SNAP': ''}), LinuxPackage.none);
    });

    test('a probe that throws reads as no package', () {
      expect(
        io.detectLinuxPackage(
          environment: const {},
          fileExists: (_) => throw const FileSystemExceptionStub(),
        ),
        LinuxPackage.none,
      );
    });
  });

  group('SecureStorageUnavailableApp', () {
    testWidgets('a Snap gets the snap connect command', (tester) async {
      await tester.pumpWidget(
        const SecureStorageUnavailableApp(package: LinuxPackage.snap),
      );
      expect(
        find.text('snap connect invoiceninja:password-manager-service'),
        findsOneWidget,
      );
    });

    testWidgets('a Flatpak gets the keyring hint and no snap command — the '
        'command means nothing in a Flatpak sandbox', (tester) async {
      await tester.pumpWidget(
        const SecureStorageUnavailableApp(package: LinuxPackage.flatpak),
      );
      expect(find.textContaining('unlock your keyring'), findsOneWidget);
      expect(find.textContaining('snap connect'), findsNothing);
    });

    testWidgets('anything else is asked to unlock its keychain', (
      tester,
    ) async {
      await tester.pumpWidget(
        const SecureStorageUnavailableApp(package: LinuxPackage.none),
      );
      expect(find.textContaining('Unlock your keychain'), findsOneWidget);
      expect(find.textContaining('snap connect'), findsNothing);
    });
  });
}

class FileSystemExceptionStub implements Exception {
  const FileSystemExceptionStub();
}
