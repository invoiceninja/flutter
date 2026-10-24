import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import 'package:admin/domain/expenses/receipt_parser.dart';

/// Reads the text on a receipt image, on the device (`docs/receipt-ocr.md`).
///
/// One channel, `invoice_ninja/receipt_ocr`, answered by a different engine
/// on each platform: Apple Vision in the iOS and macOS runners,
/// `Windows.Media.Ocr` in the Windows runner, and ML Kit in
/// `packages/store_services`' Android plugin. The F-Droid build swaps that
/// package for its FOSS twin, which has no plugin; Linux and web have no
/// handler either. All three end in a `MissingPluginException`, which this
/// latches as "unsupported" — so the feature hides itself with no platform
/// switch in Dart.
abstract class ReceiptTextRecognizer {
  /// Whether this device can read receipts at all. Cached after the first
  /// answer.
  Future<bool> isSupported();

  /// The text fragments on the image at [path], or in [bytes] (a rasterised
  /// PDF page, or a photo with no file behind it). Null when the engine
  /// couldn't read it. Coordinates are normalised, top-left origin.
  Future<List<OcrFragment>?> recognize({String? path, Uint8List? bytes});
}

class ChannelReceiptTextRecognizer implements ReceiptTextRecognizer {
  ChannelReceiptTextRecognizer({MethodChannel channel = kChannel})
    : _channel = channel;

  /// Same name as the native handlers (`AppDelegate.swift`,
  /// `MainFlutterWindow.swift`, `receipt_ocr.cpp`, `ReceiptOcrPlugin.kt`).
  static const kChannel = MethodChannel('invoice_ninja/receipt_ocr');

  final MethodChannel _channel;
  final _log = Logger('ReceiptTextRecognizer');
  Future<bool>? _supported;

  /// Latched off for the rest of the session: no handler on this platform,
  /// or one with no engine (Windows without an OCR language pack).
  bool _unavailable = false;

  @override
  Future<bool> isSupported() {
    if (_unavailable) return Future.value(false);
    return _supported ??= _ask();
  }

  Future<bool> _ask() async {
    // Nothing answers on web or Linux; skip the round trip.
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.linux) {
      _unavailable = true;
      return false;
    }
    try {
      final ok = await _channel.invokeMethod<bool>('isAvailable') ?? false;
      if (!ok) _unavailable = true;
      return ok;
    } on MissingPluginException {
      _unavailable = true;
      return false;
    } on PlatformException catch (e) {
      _log.info('Receipt reading unavailable: ${e.code}');
      _unavailable = true;
      return false;
    }
  }

  @override
  Future<List<OcrFragment>?> recognize({String? path, Uint8List? bytes}) async {
    if (!await isSupported()) return null;
    try {
      final result = await _channel.invokeMethod<List<Object?>>('recognize', {
        'path': ?path,
        'bytes': ?bytes,
      });
      return [for (final m in result ?? const []) ?OcrFragment.fromMap(m)];
    } on MissingPluginException {
      _unavailable = true;
      return null;
    } on PlatformException catch (e) {
      // The code only — never the message, which can carry recognised text,
      // and a receipt is personal data.
      _log.info('Receipt not read: ${e.code}');
      if (e.code == 'unavailable' || e.code == 'no_language') {
        _unavailable = true;
      }
      return null;
    }
  }
}
