import 'dart:io';

import 'package:admin/app/linux_package.dart';

/// Native half of the [linux_package] seam.
///
/// Flatpak sets `FLATPAK_ID` and mounts `/.flatpak-info` in every sandbox;
/// snapd sets `SNAP` to the snap's mount point. Either can be stripped from
/// the environment by a wrapper, so the Flatpak file is checked too. Never
/// throws: a failed probe reads as no package.
LinuxPackage detectLinuxPackage({
  Map<String, String>? environment,
  bool Function(String path)? fileExists,
}) {
  try {
    if (environment == null && !Platform.isLinux) return LinuxPackage.none;
    final env = environment ?? Platform.environment;
    final exists = fileExists ?? (String path) => File(path).existsSync();
    if ((env['FLATPAK_ID'] ?? '').isNotEmpty || exists('/.flatpak-info')) {
      return LinuxPackage.flatpak;
    }
    if ((env['SNAP'] ?? '').isNotEmpty) return LinuxPackage.snap;
  } catch (_) {}
  return LinuxPackage.none;
}
