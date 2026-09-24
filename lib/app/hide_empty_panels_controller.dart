import 'package:flutter/foundation.dart';

import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// Owns the user's "leave dashboard panels with nothing to show off the
/// dashboard" preference (`DevicePrefKeys.hideEmptyPanels`, device-local,
/// invoiceninja/flutter#161).
///
/// **Null means automatic**, and automatic depends on the device: on for a
/// phone, off for a tablet or a desktop, because the issue is about a phone's
/// scroll budget. That answer needs a `MediaQuery` (`Breakpoints.isPhone`), so
/// it cannot be a stored default or live in this controller — callers resolve
/// it through [effectiveFor] and [set], and every UI caller goes through the
/// `effectiveIn` / `setIn` extension (`dashboard/helpers/hide_empty_panels.dart`)
/// so the device question is asked in exactly one place. Keeping this class
/// free of UI imports is deliberate.
///
/// **Automatic stays reachable.** A switch can only say on or off, so [set]
/// stores nothing whenever the chosen value is the one this device would pick
/// anyway. Only a choice that *differs* from the device default sticks — which
/// is what keeps a foldable (a phone folded, a tablet open) or a split-screen
/// window adapting until the user actually overrides it.
///
/// Read live via a listener — the dashboard stays mounted behind
/// `/settings/**` while the switch is flipped, and its own view model never
/// notifies for a device preference. An account preference: a sign-out puts
/// the next user back on automatic.
class HideEmptyPanelsController extends ValueNotifier<bool?> {
  HideEmptyPanelsController({required DevicePrefsStore prefs})
    : _prefs = prefs,
      super(prefs.read(DevicePrefKeys.hideEmptyPanels)) {
    prefs.addListener(_sync);
  }

  final DevicePrefsStore _prefs;

  void _sync() => value = _prefs.read(DevicePrefKeys.hideEmptyPanels);

  /// Whether empty panels are hidden on this device: the stored choice, or —
  /// when the user never made one — whether this device is a phone.
  bool effectiveFor({required bool isPhone}) => value ?? isPhone;

  /// Record [enabled] as seen on a device whose automatic answer is [isPhone]:
  /// the device default is stored as nothing (automatic), anything else as an
  /// explicit override.
  Future<void> set(bool enabled, {required bool isPhone}) async {
    final next = enabled == isPhone ? null : enabled;
    if (value == next) return;
    value = next;
    await _prefs.write(DevicePrefKeys.hideEmptyPanels, next);
  }

  @override
  void dispose() {
    _prefs.removeListener(_sync);
    super.dispose();
  }
}
