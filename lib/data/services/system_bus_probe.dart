/// Whether this process can reach the D-Bus *system* bus at all — a
/// conditional-import seam in the house style (default file = web, the
/// `dart.library.io` override = native; see CLAUDE.md § Web).
///
/// `connectivity_plus` asks NetworkManager over the system bus on Linux, and
/// when the bus socket does not exist its connect fails *inside* the plugin,
/// as an uncaught zone error that no `try` around the probe can catch. A
/// Flatpak without `--system-talk-name` has no system bus socket at all, so
/// [ConnectivityWatcher.live] checks this first and skips the plugin
/// (docs/flatpak.md § finish-args).
library;

export 'package:admin/data/services/system_bus_probe_web.dart'
    if (dart.library.io) 'package:admin/data/services/system_bus_probe_io.dart';
