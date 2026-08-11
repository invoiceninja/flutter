import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart';

/// Guards the committed app-icon rasters. Every regression here is silent — the
/// build succeeds, the tests pass, and the wrong icon only surfaces once a user
/// has the app pinned to their taskbar:
///   * Dropping `msix_config.logo_path` makes `msix` copy its own bundled
///     FLUTTER-logo assets into the AppxManifest visual tree. That shipped, and
///     is what invoiceninja/flutter#25 reported: a blue Flutter 'F' on the
///     Windows 11 taskbar.
///   * `web/icons/*` shipped the stock Flutter template logo for the same
///     reason — nothing ever regenerated them, and they feed the PWA install
///     icon, the apple-touch-icon and the link-preview cards.
///   * Feeding the macOS alpha matte to a platform straight (no `255 - alpha`
///     bake) yields an all-black silhouette, since the matte's RGB is entirely
///     black. `snap/gui/invoiceninja.png` shipped that way.
///
/// Regenerate every file checked here with `dart run tools/gen_app_icons.dart`.
/// See docs/setup.md § App icons.
void main() {
  // Every derived raster the generator emits.
  const icons = [
    'windows/runner/resources/app_icon.ico',
    'windows/runner/resources/store_logo.png',
    'snap/gui/invoiceninja.png',
    'web/icons/Icon-192.png',
    'web/icons/Icon-512.png',
    'web/icons/Icon-maskable-192.png',
    'web/icons/Icon-maskable-512.png',
  ];

  test('pubspec declares msix_config.logo_path and the logo exists', () {
    final logoPath = _msixLogoPath();

    expect(
      logoPath,
      isNotNull,
      reason:
          'pubspec.yaml msix_config is missing `logo_path`. Without it '
          '`dart run msix:create` packages the msix package\'s own Flutter-logo '
          'assets as the Start tile / taskbar / Search icons — see '
          'https://github.com/invoiceninja/flutter/issues/25.',
    );
    expect(
      File(logoPath!).existsSync(),
      isTrue,
      reason:
          'msix_config.logo_path points at $logoPath, which does not exist. '
          'Regenerate it with `dart run tools/gen_app_icons.dart`.',
    );
  });

  // Hand-authored, not emitted by the generator — but they live in web/, which
  // `flutter create .` rewrites wholesale, so they're one careless command away
  // from being template art again.
  const handMaintainedIcons = ['web/favicon.png', 'web/favicon.ico'];

  test('no shipped app icon carries the Flutter logo', () {
    for (final path in [...icons, ...handMaintainedIcons]) {
      final blue = _flutterBlueFraction(_decodeSample(path));
      final fix = icons.contains(path)
          ? 'Regenerate it with `dart run tools/gen_app_icons.dart`.'
          : 'Restore the Invoice Ninja artwork (it is hand-maintained; the '
                'same file lives in admin-portal and react).';

      expect(
        blue,
        lessThan(0.01),
        reason:
            '$path looks like the Flutter logo '
            '(${(blue * 100).toStringAsFixed(1)}% of its opaque pixels are '
            'Flutter brand blue). $fix',
      );
    }
  });

  test('web/manifest.json is not still on the Flutter template colours', () {
    // `background_color` paints the PWA splash the icon sits on and
    // `theme_color` tints the installed window's title bar, so the template's
    // #0175C2 shows the new icon on a Flutter-blue background.
    expect(
      File('web/manifest.json').readAsStringSync().toLowerCase(),
      isNot(contains('#0175c2')),
      reason:
          'web/manifest.json still carries the stock Flutter template blue. Use '
          'the design system\'s own colours (#F6F4EF / #15140F — see '
          'lib/app/design_tokens.dart).',
    );
  });

  test('every shipped app icon is a baked raster, not an alpha matte', () {
    for (final path in icons) {
      final image = _decodeSample(path);
      final hasLightPixels = image.any((p) => p.a > 128 && p.r > 240);

      expect(
        hasLightPixels,
        isTrue,
        reason:
            '$path has no light pixels — it is either an unbaked alpha matte '
            '(the macOS source is all-black RGB, so it renders as a black '
            'silhouette) or fully transparent. Regenerate it with '
            '`dart run tools/gen_app_icons.dart`.',
      );
    }
  });

  test('maskable web icons are fully opaque', () {
    // A maskable icon is cropped to a launcher-chosen shape, so any
    // transparency shows the page/launcher background through the mark.
    for (final path in icons.where((p) => p.contains('maskable'))) {
      final image = _decodeSample(path);

      expect(
        image.every((p) => p.a == 255),
        isTrue,
        reason:
            '$path is declared `purpose: maskable` in web/manifest.json but is '
            'not fully opaque.',
      );
    }
  });

  test('the Windows .ico carries every size Windows picks between', () {
    const path = 'windows/runner/resources/app_icon.ico';
    final decoder = IcoDecoder();
    final info = decoder.startDecode(File(path).readAsBytesSync());

    expect(info, isNotNull, reason: '$path is not a valid .ico');

    final sizes = {
      for (var i = 0; i < info!.numFrames; i++) decoder.decodeFrame(i)!.width,
    };

    // `encodeIco()` emits a single size; only `IcoEncoder.encodeImages` writes
    // one directory entry per frame. A single-size .ico looks fine in Explorer
    // and blurry everywhere else.
    expect(
      sizes,
      containsAll([16, 32, 48, 256]),
      reason:
          '$path is missing sizes Windows needs (found $sizes). Regenerate it '
          'with `dart run tools/gen_app_icons.dart`.',
    );
  });
}

/// Reads `msix_config.logo_path` out of pubspec.yaml without pulling in a YAML
/// parser — the block is flat, so a scan to the next top-level key is enough.
String? _msixLogoPath() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final start = lines.indexWhere((line) => line.trimRight() == 'msix_config:');
  if (start == -1) return null;

  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    // A non-indented line ends the block.
    if (!line.startsWith(' ')) break;
    final match = RegExp(r'''^\s+logo_path:\s*(.+?)\s*$''').firstMatch(line);
    if (match != null) {
      // Tolerate a quoted value — YAML allows it and the raw capture would
      // otherwise fail the existence check with a confusing message.
      return match.group(1)!.replaceAll(RegExp(r'''^["']|["']$'''), '');
    }
  }
  return null;
}

/// Share of opaque pixels that sit within tolerance of a Flutter brand blue.
/// The logo is dominated by these two; the Invoice Ninja mark is pure
/// grayscale, whose closest approach to either is ~109 — well outside the
/// tolerance, so a clean icon scores a flat zero.
double _flutterBlueFraction(Image image) {
  const flutterBlues = [
    [0x54, 0xC5, 0xF8],
    [0x01, 0x57, 0x9B],
  ];
  const tolerance = 60.0;

  var matches = 0;
  var total = 0;
  for (final p in image) {
    if (p.a < 8) continue;
    total++;
    for (final blue in flutterBlues) {
      final distance = math.sqrt(
        math.pow(p.r - blue[0], 2) +
            math.pow(p.g - blue[1], 2) +
            math.pow(p.b - blue[2], 2),
      );
      if (distance <= tolerance) {
        matches++;
        break;
      }
    }
  }
  return matches / math.max(total, 1);
}

/// Decodes an icon down to a small sample. Colour ratios and light/dark extremes
/// survive the downsample, and it keeps the whole file well under a second.
Image _decodeSample(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path should exist');

  final decoded = decodeImage(file.readAsBytesSync());
  expect(decoded, isNotNull, reason: '$path could not be decoded');

  // `decodeImage` on a multi-size .ico returns the first directory entry (16px)
  // with the rest attached as frames; take the largest.
  final largest = decoded!.frames.reduce((a, b) => b.width > a.width ? b : a);
  return largest.width > 128
      ? copyResize(largest, width: 128, height: 128)
      : largest;
}
