import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// Owns the user's "underline spelling mistakes in line items" preference
/// (`DevicePrefKeys.spellCheck`, device-local).
///
/// Defaults to **on** — the feature was asked for, and a user who never opens
/// Settings should see it. The switch exists because an item name is often a
/// SKU or a code (`WID-001`) that every checker flags.
///
/// Read through its root provider as `context.watch<SpellCheckController?>()`
/// (`lineItemSpellCheck`), so a line-item field rebuilds when it flips and a
/// test without the provider simply gets no spell check.
class SpellCheckController extends DevicePref<bool> {
  SpellCheckController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.spellCheck, fallback: true);
}
