import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// `normal` — the default row spacing every list shipped with.
const String kListDensityNormal = 'normal';

/// `compact` — tighter rows and list chrome, so more records fit on screen.
const String kListDensityCompact = 'compact';

/// Owns "how tightly do entity lists pack their rows"
/// (`DevicePrefKeys.listDensity`, device-local). Defaults to Normal.
///
/// Read through [isCompact], never by comparing [value] to
/// [kListDensityNormal]: a value this build doesn't know (written by a newer
/// one) must still resolve to one of the two choices, and to the default.
/// `ListDensityScope` publishes it to the widget tree; see
/// `docs/list-density.md`.
class ListDensityController extends DevicePref<String> {
  ListDensityController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.listDensity, fallback: kListDensityNormal);

  bool get isCompact => value == kListDensityCompact;

  Future<void> setCompact(bool compact) =>
      set(compact ? kListDensityCompact : kListDensityNormal);

  Future<void> toggle() => setCompact(!isCompact);
}
