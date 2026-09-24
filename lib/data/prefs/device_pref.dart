import 'package:flutter/foundation.dart';

import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// One device preference as a [ValueNotifier]: its stored value, or
/// [fallback] when there is none.
///
/// It follows the store, so the boot load, and a data wipe that forgets an
/// account key, both reach it without anyone wiring a hook: before this, each
/// controller copied its column once at boot and had to be told — through a
/// `resetInMemory()` that every new preference had to remember — when the
/// row it mirrored was destroyed.
class DevicePref<T extends Object> extends ValueNotifier<T> {
  DevicePref(DevicePrefsStore prefs, this.key, {required this.fallback})
    : _prefs = prefs,
      super(prefs.read(key) ?? fallback) {
    prefs.addListener(_sync);
  }

  final DevicePrefsStore _prefs;
  final PrefKey<T> key;
  final T fallback;

  void _sync() => value = _prefs.read(key) ?? fallback;

  Future<void> set(T next) async {
    if (value == next) return;
    value = next;
    await _prefs.write(key, next);
  }

  @override
  void dispose() {
    _prefs.removeListener(_sync);
    super.dispose();
  }
}
