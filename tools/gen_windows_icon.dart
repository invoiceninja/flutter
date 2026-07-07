// Generates windows/runner/resources/app_icon.ico from the 1024x1024 macOS
// app-icon source, as a multi-size .ico (16..256) so Windows has crisp icons at
// every UI scale (taskbar, Alt-Tab, Explorer, title bar).
//
//   dart run tools/gen_windows_icon.dart
//
// The source is a macOS "glass" alpha matte, NOT a finished raster: its RGB is
// entirely black and the envelope shape lives only in the ALPHA channel (icon.json
// sets glass:true — macOS fills the matte with the system material). Windows has no
// such treatment, so resizing the matte straight through draws an all-dark icon with
// no white anywhere. We therefore BAKE the alpha into real pixels — white where the
// source is opaque (the envelope), black where transparent (linework + background) —
// on a solid opaque black tile. Do NOT swap in assets/images/icon.png: it's circular
// (a mask is baked in) and only 152px, which would look wrong and soft on Windows.
//
// Uses the `image` package's IcoEncoder.encodeImages, which writes one ICO
// directory entry per supplied image (each keeps its own width/height) — unlike
// the top-level encodeIco() helper, which only emits a single size.

import 'dart:io';

import 'package:image/image.dart';

const _source = 'macos/AppIcon.icon/Assets/Image.png';
const _output = 'windows/runner/resources/app_icon.ico';
// Full-res baked PNG for `msix_config.logo_path` — msix generates the whole
// AppxManifest visual-asset tree (Start tile, taskbar, Store logo, splash)
// from this one file; without it the package ships the msix package's
// default FLUTTER-logo assets.
const _pngOutput = 'windows/runner/resources/store_logo.png';
const _sizes = [16, 24, 32, 48, 64, 128, 256];

void main() {
  final src = decodePng(File(_source).readAsBytesSync());
  if (src == null) {
    stderr.writeln('Could not decode $_source');
    exit(1);
  }
  // Bake the alpha matte into a white envelope on an opaque black tile, at full
  // resolution, then downsample for clean anti-aliasing. In the source matte the
  // envelope body is the TRANSPARENT negative space (alpha 0) and the surround +
  // flap linework are opaque — so the gray value is the INVERTED alpha (255 - a):
  // transparent envelope -> white, opaque surround -> black. Output is fully opaque
  // (alpha 255) so the icon never lets the dark taskbar show through and wash out.
  final baked = Image(width: src.width, height: src.height, numChannels: 4);
  for (final p in src) {
    final v = 255 - p.a.toInt();
    baked.setPixelRgba(p.x, p.y, v, v, v, 255);
  }
  final frames = [
    for (final size in _sizes)
      copyResize(
        baked,
        width: size,
        height: size,
        interpolation: Interpolation.average,
      ),
  ];
  File(_output).writeAsBytesSync(IcoEncoder().encodeImages(frames));
  stdout.writeln('Wrote $_output (${_sizes.length} sizes: $_sizes)');
  File(_pngOutput).writeAsBytesSync(encodePng(baked));
  stdout.writeln('Wrote $_pngOutput (${baked.width}x${baked.height})');
}
