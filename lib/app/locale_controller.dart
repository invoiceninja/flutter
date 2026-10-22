import 'package:flutter/widgets.dart';

import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/l10n/supported_locales.dart';

/// Owns the user's locale preference (`DevicePrefKeys.locale`, device-local).
/// `null` means "follow the device locale" — Flutter's [MaterialApp.locale]
/// parameter treats null the same way — and is stored as no row at all.
class LocaleController extends ValueNotifier<Locale?> {
  LocaleController({required DevicePrefsStore prefs})
    : _prefs = prefs,
      super(_parse(prefs.read(DevicePrefKeys.locale))) {
    prefs.addListener(_sync);
  }

  final DevicePrefsStore _prefs;

  void _sync() => value = _parse(_prefs.read(DevicePrefKeys.locale));

  Future<void> set(Locale? locale) async {
    if (value == locale) return;
    value = locale;
    await _prefs.write(
      DevicePrefKeys.locale,
      locale == null ? null : localeKey(locale),
    );
  }

  /// An empty string is what builds before v12 stored for "follow the device".
  ///
  /// A shipped locale is returned as declared, so it keeps the script code a
  /// key cannot carry (`sr` is Latin, `zh_TW` Traditional) — rebuilt from its
  /// parts, Material would draw Serbian in Cyrillic beside Latin app strings.
  static Locale? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final l in kSupportedLocales) {
      if (localeKey(l) == raw) return l;
    }
    final parts = raw.split('_');
    if (parts.length == 1) return Locale(parts[0]);
    return Locale(parts[0], parts[1]);
  }

  @override
  void dispose() {
    _prefs.removeListener(_sync);
    super.dispose();
  }
}
