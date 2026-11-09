import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/linux_package.dart';
import 'package:flutter/material.dart';

/// Minimal full-screen error shown when the OS secret store (keychain /
/// keyring) is unreachable and the encrypted DB can't be opened. `Services`
/// and localization aren't available this early, so the copy is plain English.
///
/// The fix depends on the package the app runs from ([detectLinuxPackage]):
/// - a Snap whose `password-manager-service` plug isn't connected gets the
///   `snap connect` command;
/// - a Flatpak reaches the keyring only through the Secret portal: Flathub
///   refused the host Secret Service permission, so on a desktop with no
///   portal backend the user grants it with the `flatpak override` command
///   (docs/flatpak.md § finish-args). The user may also have dismissed the
///   portal's unlock prompt;
/// - anything else is asked to unlock its keychain or keyring.
/// Grants the Flatpak the host Secret Service, which its manifest doesn't
/// (Flathub's permission review refused it). The ID is the Flathub one,
/// `linux/CMakeLists.txt`'s `APPLICATION_ID`.
const kFlatpakKeyringOverride =
    'flatpak override --user --talk-name=org.freedesktop.secrets '
    'com.invoiceninja.InvoiceNinja';

class SecureStorageUnavailableApp extends StatelessWidget {
  const SecureStorageUnavailableApp({super.key, required this.package});

  final LinuxPackage package;

  @override
  Widget build(BuildContext context) {
    final (hint, command) = switch (package) {
      LinuxPackage.snap => (
        'Connect the snap\'s keyring permission, then relaunch:',
        'snap connect invoiceninja:password-manager-service',
      ),
      LinuxPackage.flatpak => (
        'If you were asked to unlock your keyring, relaunch and accept. '
            'Otherwise make sure GNOME Keyring or KWallet is running. If it '
            'is, your desktop may not offer keyring access to Flatpak apps: '
            'allow it with this command, then relaunch:',
        kFlatpakKeyringOverride,
      ),
      LinuxPackage.none => (
        'Unlock your keychain or keyring (on Linux, make sure GNOME Keyring '
            'or KWallet is running), then relaunch.',
        null,
      ),
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Secure storage unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Invoice Ninja stores its data encrypted and could not reach '
                    'your system keyring to unlock it.\n\n$hint',
                    textAlign: TextAlign.center,
                  ),
                  if (command != null) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      command,
                      style: const TextStyle(fontFamily: kMonoFontFamily),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
