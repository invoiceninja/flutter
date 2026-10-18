import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:admin/app/native_window.dart';

/// One screenshot target, in physical pixels — the units App Store / Play
/// Store screenshot specs are written in. The Debug Panel divides by the
/// display's devicePixelRatio at apply time, so a captured window lands on
/// exactly these pixel dimensions.
class ScreenshotPreset {
  const ScreenshotPreset({
    this.descriptionKey,
    required this.widthPx,
    required this.heightPx,
  });

  /// Localization key for the device class ('phone_portrait', …); null when
  /// the dimensions alone are the label (the Mac sizes).
  final String? descriptionKey;
  final int widthPx;
  final int heightPx;

  String get dimensionLabel => '$widthPx × $heightPx';
}

class ScreenshotPresetGroup {
  const ScreenshotPresetGroup({required this.labelKey, required this.presets});

  final String labelKey;
  final List<ScreenshotPreset> presets;
}

/// Store screenshot sizes offered by the Debug Panel's size menu.
///
/// Mac App Store accepts exactly these four 16:10 sizes. Google Play requires
/// **16:9 or 9:16** for every slot, with per-slot side bounds: phone and 7″
/// tablet 320–3,840 px/side, 10″ tablet 1,080–7,680 px/side. Both orientations
/// are offered.
///
/// Because the tool resizes the Mac window (px ÷ display scale → logical
/// points), a full-res 10″ portrait (2160×3840 → 1920 pt tall at 2×) is taller
/// than any Mac display: an on-screen capture clamps to the screen and the
/// mismatch warning reports the achieved size. So 10″ portrait carries both a
/// full-res entry (for a large/scaled display or on-device capture) and a
/// Mac-fitting compact entry; 7″ portrait is reachable on a 27″ display and
/// its landscape fits a laptop, so it needs no compact variant.
const kScreenshotPresetGroups = <ScreenshotPresetGroup>[
  ScreenshotPresetGroup(
    labelKey: 'mac_app_store',
    presets: [
      ScreenshotPreset(widthPx: 1280, heightPx: 800),
      ScreenshotPreset(widthPx: 1440, heightPx: 900),
      ScreenshotPreset(widthPx: 2560, heightPx: 1600),
      ScreenshotPreset(widthPx: 2880, heightPx: 1800),
    ],
  ),
  ScreenshotPresetGroup(
    labelKey: 'google_play',
    presets: [
      // 9:16 / 16:9, sides within each slot's bounds. Phone-portrait and the
      // landscape sizes fit a typical Mac; the full-res tablet portraits do
      // not (see the class doc) — hence the 10″ compact variant.
      ScreenshotPreset(
        descriptionKey: 'phone_portrait',
        widthPx: 1080,
        heightPx: 1920,
      ),
      ScreenshotPreset(
        descriptionKey: 'phone_landscape',
        widthPx: 1920,
        heightPx: 1080,
      ),
      ScreenshotPreset(
        descriptionKey: 'tablet_7_inch_portrait',
        widthPx: 1440,
        heightPx: 2560,
      ),
      ScreenshotPreset(
        descriptionKey: 'tablet_7_inch_landscape',
        widthPx: 2560,
        heightPx: 1440,
      ),
      ScreenshotPreset(
        descriptionKey: 'tablet_10_inch_portrait',
        widthPx: 2160,
        heightPx: 3840,
      ),
      ScreenshotPreset(
        descriptionKey: 'tablet_10_inch_portrait_compact',
        widthPx: 1080,
        heightPx: 1920,
      ),
      ScreenshotPreset(
        descriptionKey: 'tablet_10_inch_landscape',
        widthPx: 3840,
        heightPx: 2160,
      ),
    ],
  ),
];

/// The groups the size menu may show. A Mac App Store build must not name
/// another platform's store anywhere a reviewer can reach — About → Debug
/// Panel included (App Review 2.3.10, docs/mobile-app-promo.md) — so a
/// **release** macOS build drops the Google Play sizes. Debug and profile
/// runs, where the store screenshots are captured, keep them.
List<ScreenshotPresetGroup> visibleScreenshotPresetGroups({
  bool isWeb = kIsWeb,
  bool isRelease = kReleaseMode,
  TargetPlatform? platform,
}) {
  final macStoreBuild =
      !isWeb &&
      isRelease &&
      (platform ?? defaultTargetPlatform) == TargetPlatform.macOS;
  return [
    for (final group in kScreenshotPresetGroups)
      if (!(macStoreBuild && group.labelKey == 'google_play')) group,
  ];
}

/// Outcome of a programmatic window resize. [achievedPx] is null when the
/// native side couldn't answer (non-desktop platform, channel error, or a
/// runner without the handler).
class ScreenshotResizeResult {
  const ScreenshotResizeResult({
    required this.requestedPx,
    required this.achievedPx,
  });

  final ({int width, int height}) requestedPx;
  final ({int width, int height})? achievedPx;

  /// Whether the window landed on the requested pixel size. A 1-device-px
  /// tolerance absorbs fractional-DPR rounding.
  bool get matched {
    final a = achievedPx;
    if (a == null) return false;
    return (a.width - requestedPx.width).abs() <= 1 &&
        (a.height - requestedPx.height).abs() <= 1;
  }
}

/// Debug Panel screenshot helpers: programmatic window sizing to App Store /
/// Play Store pixel dimensions, plus hiding the native window buttons (macOS
/// traffic lights) for clean captures.
///
/// Lives on `Services` rather than in the panel widget because the capture
/// workflow is: pick a size + hide the buttons → close the panel (it would be
/// in the shot) → capture → reopen → restore. All state is in-memory and
/// resets on launch; the native side deliberately never persists the hidden
/// buttons, so a cold start is always consistent (buttons visible). After a
/// hot restart the Dart flags reset while the native window keeps its last
/// size/buttons — re-toggle from the panel if that happens.
///
/// A requested size taller/wider than the current display can't be reached —
/// AppKit clamps the window to the visible screen, so the full-res tablet
/// portraits exceed a laptop and [ScreenshotResizeResult.matched] is false.
/// The menu surfaces that via a warning; use a landscape/compact preset, a
/// larger or scaled display, or capture on the target device.
class ScreenshotWindowController extends ChangeNotifier {
  ({int width, int height})? _appliedSizePx;
  Size? _originalLogicalSize;
  bool _windowButtonsHidden = false;
  bool _capturing = false;

  /// Wraps the app's root `child` in `main.dart`; the Debug Panel's camera button
  /// snapshots this boundary to a PNG. One key, reachable from both `main.dart`
  /// (via `Services`) and the panel (via the injected `windowController`).
  final GlobalKey boundaryKey = GlobalKey();

  /// The last applied target in physical px (preset or custom); null until a
  /// size is applied and again after [restoreOriginalSize].
  ({int width, int height})? get appliedSizePx => _appliedSizePx;

  bool get windowButtonsHidden => _windowButtonsHidden;

  /// True only while a screenshot is being taken: the Debug Panel goes `Offstage`
  /// so it isn't in the shot and the window content is captured at full size.
  /// Transient and distinct from `debugPanelRevealed` (the user's open/closed
  /// state) — always starts false on a fresh controller.
  bool get capturing => _capturing;

  void setCapturing(bool value) {
    if (_capturing == value) return;
    _capturing = value;
    notifyListeners();
  }

  bool get canRestoreOriginalSize => _appliedSizePx != null;

  /// Resize the window so a capture of it is [widthPx]×[heightPx] physical
  /// pixels: sends `px / devicePixelRatio` logical points to the native side.
  /// [currentLogicalSize] (the pre-resize window size, from `View.of`) is
  /// captured as the restore target on the first successful apply only, so
  /// repeated preset switches still restore to where the user started.
  Future<ScreenshotResizeResult> applySizePx({
    required int widthPx,
    required int heightPx,
    required double devicePixelRatio,
    required Size currentLogicalSize,
  }) async {
    final requested = (width: widthPx, height: heightPx);
    final achieved = await NativeWindow.instance.setContentSize(
      widthPx / devicePixelRatio,
      heightPx / devicePixelRatio,
    );
    if (achieved == null) {
      return ScreenshotResizeResult(requestedPx: requested, achievedPx: null);
    }
    _originalLogicalSize ??= currentLogicalSize;
    _appliedSizePx = requested;
    notifyListeners();
    return ScreenshotResizeResult(
      requestedPx: requested,
      achievedPx: (
        width: (achieved.width * devicePixelRatio).round(),
        height: (achieved.height * devicePixelRatio).round(),
      ),
    );
  }

  Future<void> setWindowButtonsHidden(bool hidden) async {
    if (_windowButtonsHidden == hidden) return;
    _windowButtonsHidden = hidden;
    notifyListeners();
    await NativeWindow.instance.setWindowButtonsHidden(hidden);
  }

  /// Return the window to its size from before the first [applySizePx].
  Future<void> restoreOriginalSize() async {
    final original = _originalLogicalSize;
    if (original == null) return;
    await NativeWindow.instance.setContentSize(original.width, original.height);
    // Keep _originalLogicalSize so apply → restore cycles keep working.
    _appliedSizePx = null;
    notifyListeners();
  }
}
