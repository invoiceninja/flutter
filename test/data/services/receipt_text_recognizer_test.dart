import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/receipt_text_recognizer.dart';

/// The one Dart seam over every platform's OCR engine. No handler (the
/// F-Droid build, Linux, web) or no engine (Windows without a language pack)
/// latches "unsupported" for the session.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/receipt_ocr');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('fragments come back as the parser reads them', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'isAvailable') return true;
      return [
        {'text': 'TOTAL', 'x': 0.05, 'y': 0.6, 'w': 0.2, 'h': 0.03},
        {'text': '', 'x': 0, 'y': 0, 'w': 0, 'h': 0},
      ];
    });
    final r = ChannelReceiptTextRecognizer(channel: channel);

    final fragments = await r.recognize(path: '/a/IMG_1.jpg');

    expect(fragments?.single.text, 'TOTAL');
    expect(fragments?.single.top, 0.6);
    expect(calls.last.arguments, {'path': '/a/IMG_1.jpg'});
  });

  test('bytes travel when there is no file', () async {
    Object? args;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return true;
      args = call.arguments;
      return <Object?>[];
    });
    await ChannelReceiptTextRecognizer(
      channel: channel,
    ).recognize(bytes: Uint8List.fromList([1, 2]));
    expect((args as Map)['bytes'], [1, 2]);
  });

  test('no handler is unsupported, for good', () async {
    final r = ChannelReceiptTextRecognizer(channel: channel);
    expect(await r.isSupported(), isFalse);
    // A handler appearing later doesn't matter: the answer is latched.
    messenger.setMockMethodCallHandler(channel, (_) async => true);
    expect(await r.isSupported(), isFalse);
    expect(await r.recognize(path: '/a.jpg'), isNull);
  });

  test('no OCR language on the machine latches it off too', () async {
    var recognizeCalls = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return true;
      recognizeCalls++;
      throw PlatformException(code: 'no_language');
    });
    final r = ChannelReceiptTextRecognizer(channel: channel);
    expect(await r.recognize(path: '/a.jpg'), isNull);
    expect(await r.isSupported(), isFalse);
    expect(await r.recognize(path: '/a.jpg'), isNull);
    expect(recognizeCalls, 1);
  });

  test('one unreadable image is not the end of reading', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'isAvailable') return true;
      throw PlatformException(code: 'unsupported_image');
    });
    final r = ChannelReceiptTextRecognizer(channel: channel);
    expect(await r.recognize(path: '/a.heic'), isNull);
    expect(await r.isSupported(), isTrue);
  });

  test('Linux and web have no engine, and are never asked', () async {
    var asked = false;
    messenger.setMockMethodCallHandler(channel, (_) async {
      asked = true;
      return true;
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      expect(
        await ChannelReceiptTextRecognizer(channel: channel).isSupported(),
        isFalse,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
    expect(asked, isFalse);
  });
}
