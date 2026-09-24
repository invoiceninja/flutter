import 'dart:async';

import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// A memory-only [DevicePrefsStore] already holding [values] — for a test that
/// needs a preference controller at a non-default value but not its
/// persistence. Each write lands synchronously: with no database, `write`
/// returns before its first `await`.
DevicePrefsStore prefsWith([Map<PrefKey<Object>, Object> values = const {}]) {
  final prefs = DevicePrefsStore(null);
  for (final MapEntry(:key, :value) in values.entries) {
    unawaited(prefs.write(key, value));
  }
  return prefs;
}
