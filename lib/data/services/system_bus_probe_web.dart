/// Web half of the [system_bus_probe] seam: a browser has no D-Bus, and
/// `connectivity_plus` uses the browser's own online state there.
bool systemBusMissing({
  Map<String, String>? environment,
  bool Function(String path)? fileExists,
  bool? isLinux,
}) => false;
