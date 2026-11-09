import 'dart:io';

/// Native half of the [system_bus_probe] seam.
///
/// True only on Linux when no system bus socket exists: the one named by
/// `DBUS_SYSTEM_BUS_ADDRESS` (`unix:path=…`), else the well-known
/// `/run/dbus/system_bus_socket` (or its `/var/run` alias). Off Linux, or
/// when the address is something other than a unix path, it answers false
/// and the plugin is asked as before. A Snap without the `network-manager`
/// plug still *has* the socket (AppArmor denies the call instead), which the
/// watcher's probe already degrades. Never throws.
bool systemBusMissing({
  Map<String, String>? environment,
  bool Function(String path)? fileExists,
  bool? isLinux,
}) {
  try {
    if (!(isLinux ?? Platform.isLinux)) return false;
    final env = environment ?? Platform.environment;
    final exists =
        fileExists ??
        (String path) =>
            FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound;
    final address = env['DBUS_SYSTEM_BUS_ADDRESS'] ?? '';
    if (address.isNotEmpty) {
      final path = RegExp(r'unix:path=([^,;]+)').firstMatch(address)?.group(1);
      if (path == null) return false;
      return !exists(path);
    }
    return !exists('/run/dbus/system_bus_socket') &&
        !exists('/var/run/dbus/system_bus_socket');
  } catch (_) {
    return false;
  }
}
