// The state behind Contact Us: the opt-in capture, the slot rule, what is
// sent, and how a failed send with images reads (docs/feedback-screenshots.md).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/support_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/feedback/markup.dart';
import 'package:admin/ui/features/feedback/contact_us_view_model.dart';

class _FakeSupport implements SupportApi {
  final jsonSends = <String>[];
  final multipartSends = <List<SupportAttachment>>[];
  Object? throwOnMultipart;
  Object? throwOnJson;

  @override
  Future<void> sendMessage({
    required String message,
    required String appVersion,
    bool includeLogs = false,
  }) async {
    if (throwOnJson case final e?) throw e;
    jsonSends.add(message);
  }

  @override
  Future<void> sendMessageWithAttachments({
    required String message,
    required String appVersion,
    required List<SupportAttachment> attachments,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    if (throwOnMultipart case final e?) throw e;
    multipartSends.add(attachments);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

final _box = BoxMark(
  MarkRect.fromPoints(MarkPoint(1, 1), MarkPoint(5, 5)),
  width: 2,
);

void main() {
  late _FakeSupport api;
  late List<List<MarkupMark>> encoded;
  late List<UploadSource> released;

  setUp(() {
    api = _FakeSupport();
    encoded = [];
    released = [];
  });

  Future<ui.Image> image(WidgetTester tester) async =>
      (await tester.runAsync(() => createTestImage(width: 4, height: 4)))!;

  ContactUsViewModel vm({ui.Image? capture, bool enabled = true}) =>
      ContactUsViewModel(
        api: () => api,
        attachmentsEnabled: enabled,
        capture: capture,
        encode: (img, marks) async {
          encoded.add(marks);
          return Uint8List.fromList([9, 9]);
        },
        releaseSources: (s) async => released.addAll(s),
      );

  Future<FeedbackAttachment> picked(
    WidgetTester tester, {
    int bytes = 10,
    String name = 'p.jpg',
  }) async => FeedbackAttachment(
    image: await image(tester),
    originalBytes: Uint8List(bytes),
    originalExtension: 'jpg',
    source: BytesUploadSource(Uint8List(bytes), name),
  );

  testWidgets('the capture starts unticked and is not sent', (tester) async {
    final m = vm(capture: await image(tester));
    expect(m.captureIncluded, isFalse);
    await m.send(message: 'Hi', appVersion: 'v');
    expect(api.jsonSends, ['Hi']);
    expect(api.multipartSends, isEmpty);
    m.dispose();
  });

  testWidgets('marks on an unticked capture still send nothing', (
    tester,
  ) async {
    final m = vm(capture: await image(tester));
    m.markUpCapture([_box]);
    m.setCaptureIncluded(false);
    await m.send(message: 'Hi', appVersion: 'v');
    expect(api.multipartSends, isEmpty);
    m.dispose();
  });

  testWidgets('Done in the editor ticks the capture; it goes as a PNG with '
      'its marks', (tester) async {
    final m = vm(capture: await image(tester));
    m.markUpCapture([_box]);
    expect(m.captureIncluded, isTrue);
    expect(await m.send(message: 'Hi', appVersion: 'v'), isA<ContactUsSent>());
    expect(api.multipartSends.single.single.fileName, 'screenshot.png');
    expect(encoded.single, [_box]);
    m.dispose();
  });

  testWidgets('a slot is kept for the capture, so ticking it never makes '
      'four', (tester) async {
    final m = vm(capture: await image(tester));
    expect(m.maxAddable, 2);
    final dropped = m.addImages([
      await picked(tester),
      await picked(tester),
      await picked(tester, name: 'third.jpg'),
    ]);
    expect(dropped, 1);
    expect(m.images, hasLength(2));
    expect(m.remainingSlots, 0);
    expect(released.map((s) => s.fileName), ['third.jpg']);
    m.setCaptureIncluded(true);
    expect(m.attachedCount, kFeedbackMaxImages);
    m.dispose();
  });

  testWidgets('without a capture three may be added', (tester) async {
    final m = vm();
    expect(m.maxAddable, 3);
    m.dispose();
  });

  testWidgets('an untouched picked image goes as its own bytes; a marked one '
      'is re-encoded', (tester) async {
    final m = vm();
    m.addImages([await picked(tester), await picked(tester)]);
    m.markUpImage(1, [_box]);
    await m.send(message: 'Hi', appVersion: 'v');
    final parts = api.multipartSends.single;
    expect(parts.map((p) => p.fileName), ['image-1.jpg', 'image-2.png']);
    expect(parts.first.bytes, Uint8List(10));
    expect(encoded, [
      [_box],
    ]);
    m.dispose();
  });

  testWidgets('an untouched image over budget is re-encoded too', (
    tester,
  ) async {
    final m = vm();
    m.addImages([await picked(tester, bytes: kFeedbackMaxImageBytes + 1)]);
    await m.send(message: 'Hi', appVersion: 'v');
    expect(api.multipartSends.single.single.fileName, 'image-1.png');
    m.dispose();
  });

  group('a send with images that fails', () {
    Future<ContactUsSendResult> failWith(
      WidgetTester tester,
      Object error,
    ) async {
      api.throwOnMultipart = error;
      final m = vm();
      m.addImages([await picked(tester)]);
      final result = await m.send(message: 'Hi', appVersion: 'v');
      expect(m.images, hasLength(1), reason: 'everything is kept');
      m.dispose();
      return result;
    }

    testWidgets('a 422 on attachments.N: images refused', (tester) async {
      expect(
        await failWith(
          tester,
          const ValidationException('bad', {
            'attachments.0': ['must be an image'],
          }),
        ),
        isA<ContactUsImagesRefused>(),
      );
    });

    testWidgets('a 413: images refused', (tester) async {
      expect(
        await failWith(tester, const ServerException(413, 'too large')),
        isA<ContactUsImagesRefused>(),
      );
    });

    // On the web a proxy's 413 has no CORS header and reads as a network
    // error.
    testWidgets('a network error: images refused', (tester) async {
      expect(
        await failWith(tester, const NetworkException('offline')),
        isA<ContactUsImagesRefused>(),
      );
    });

    // Offline: nothing reached the server, so it wasn't the images.
    testWidgets('a request never sent: an ordinary failure', (tester) async {
      expect(
        await failWith(tester, const RequestNotSentException('offline')),
        isA<ContactUsFailed>(),
      );
    });

    testWidgets('a 429: rate limited, with the wait', (tester) async {
      final r = await failWith(
        tester,
        const RateLimitedException(retryAfter: Duration(seconds: 42)),
      );
      expect((r as ContactUsRateLimited).retryAfter?.inSeconds, 42);
    });

    testWidgets('a 422 on the message is an ordinary failure', (tester) async {
      expect(
        await failWith(
          tester,
          const ValidationException('bad', {
            'message': ['required'],
          }),
        ),
        isA<ContactUsFailed>(),
      );
    });
  });

  testWidgets('Send without images goes as JSON', (tester) async {
    final m = vm();
    m.addImages([await picked(tester)]);
    await m.send(message: 'Hi', appVersion: 'v', withImages: false);
    expect(api.jsonSends, ['Hi']);
    expect(api.multipartSends, isEmpty);
    m.dispose();
  });

  testWidgets('a network error without images is an ordinary failure', (
    tester,
  ) async {
    api.throwOnJson = const NetworkException('offline');
    final m = vm();
    expect(
      await m.send(message: 'Hi', appVersion: 'v'),
      isA<ContactUsFailed>(),
    );
    m.dispose();
  });

  testWidgets('an image too large to encode stops the send', (tester) async {
    final m = ContactUsViewModel(
      api: () => api,
      attachmentsEnabled: true,
      encode: (_, _) async => null,
    );
    m.addImages([await picked(tester)]);
    m.markUpImage(0, [_box]);
    expect(
      await m.send(message: 'Hi', appVersion: 'v'),
      isA<ContactUsImageTooLarge>(),
    );
    expect(api.multipartSends, isEmpty);
    m.dispose();
  });

  testWidgets('disposing releases the picked photos', (tester) async {
    final m = vm();
    m.addImages([await picked(tester, name: 'a.jpg')]);
    m.dispose();
    expect(released.map((s) => s.fileName), ['a.jpg']);
  });

  testWidgets('attachments off: nothing can be added, the message goes as '
      'JSON', (tester) async {
    final m = vm(capture: await image(tester), enabled: false);
    expect(m.maxAddable, 0);
    m.markUpCapture([_box]);
    await m.send(message: 'Hi', appVersion: 'v');
    expect(api.jsonSends, ['Hi']);
    m.dispose();
  });
}
