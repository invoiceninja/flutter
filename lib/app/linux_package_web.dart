import 'package:admin/app/linux_package.dart';

/// Web half of the [linux_package] seam: a browser tab is never a package.
/// The parameters mirror the native half's test seams.
LinuxPackage detectLinuxPackage({
  Map<String, String>? environment,
  bool Function(String path)? fileExists,
}) => LinuxPackage.none;
