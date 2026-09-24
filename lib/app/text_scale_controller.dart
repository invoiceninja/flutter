import 'package:flutter/painting.dart';

import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// The four discrete UI text-scale factors, mirroring the legacy app
/// (`PrefState.TEXT_SCALING_*`): Small / Normal / Large / Extra Large.
const double kTextScaleSmall = 0.8;
const double kTextScaleNormal = 1.0;
const double kTextScaleLarge = 1.2;
const double kTextScaleExtraLarge = 1.4;

const List<double> kTextScaleOptions = [
  kTextScaleSmall,
  kTextScaleNormal,
  kTextScaleLarge,
  kTextScaleExtraLarge,
];

/// Localization key for the label of a given scale factor. Threshold-based so
/// it stays robust against floating-point drift.
String textScaleLabelKey(double scale) {
  if (scale < kTextScaleNormal) return 'small';
  if (scale >= kTextScaleExtraLarge) return 'extra_large';
  if (scale >= kTextScaleLarge) return 'large';
  return 'normal';
}

/// Compose the device-local [factor] with the platform/OS text scaler [os] so
/// accessibility scaling is respected: at the default factor (1.0) this returns
/// the OS scale unchanged (pure passthrough); otherwise it multiplies. Applied
/// app-wide by `MaterialApp`'s builder in `main.dart`.
TextScaler composeTextScaler(TextScaler os, double factor) =>
    TextScaler.linear(os.scale(1.0) * factor);

/// Owns the user's UI text-scale preference (`DevicePrefKeys.textScale`,
/// device-local). Absent means the default (1.0).
///
/// `MaterialApp`'s builder binds to this controller (merged into the theme
/// [Listenable]); a change rebuilds the app-wide `MediaQuery` `textScaler`
/// override in `main.dart`.
class TextScaleController extends DevicePref<double> {
  TextScaleController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.textScale, fallback: kTextScaleNormal);
}
