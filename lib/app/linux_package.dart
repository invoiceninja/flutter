/// Which Linux package this process runs from: a Snap, a Flatpak, or neither.
///
/// Conditional-import seam in the house style (default file = web, the
/// `dart.library.io` override = native — see CLAUDE.md § Web). A sandbox
/// changes what a fix for a host-side problem looks like — the keyring screen
/// in `main.dart` gives a Snap a `snap connect` command and a Flatpak a
/// keyring hint (docs/flatpak.md).
library;

export 'package:admin/app/linux_package_web.dart'
    if (dart.library.io) 'package:admin/app/linux_package_io.dart';

enum LinuxPackage { snap, flatpak, none }
