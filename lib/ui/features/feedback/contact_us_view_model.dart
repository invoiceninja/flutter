import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/support_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/feedback/markup.dart';

/// One image on a Contact Us message: what is shown and marked up, the marks
/// (image pixels, never flattened until Send — so reopening the editor can
/// still undo them), and for a picked file its original bytes, sent as they
/// are when nothing was drawn on them.
class FeedbackAttachment {
  FeedbackAttachment({
    required this.image,
    this.marks = const [],
    this.originalBytes,
    this.originalExtension,
    this.source,
  });

  /// Decoded for display and markup. Owned — and disposed — by the
  /// [ContactUsViewModel] holding it.
  final ui.Image image;

  final List<MarkupMark> marks;

  /// A picked file's own bytes and type (`jpg` / `png` / `gif` / `webp`);
  /// null for the screen capture.
  final Uint8List? originalBytes;
  final String? originalExtension;

  /// Where a picked photo came from, released (deleted from the app's photo
  /// folder) when the dialog goes away.
  final UploadSource? source;

  FeedbackAttachment withMarks(List<MarkupMark> next) => FeedbackAttachment(
    image: image,
    marks: List.unmodifiable(next),
    originalBytes: originalBytes,
    originalExtension: originalExtension,
    source: source,
  );
}

/// How a send ended.
sealed class ContactUsSendResult {
  const ContactUsSendResult();
}

class ContactUsSent extends ContactUsSendResult {
  const ContactUsSent();
}

/// The server (or a proxy in front of it) turned the images down — a 422 on
/// `attachments`, a 413, or, with images on board, a network error: on the
/// web a proxy's 413 carries no CORS header and reads as one. The dialog
/// offers to send the message without them.
class ContactUsImagesRefused extends ContactUsSendResult {
  const ContactUsImagesRefused();
}

/// One image could not be made small enough to send.
class ContactUsImageTooLarge extends ContactUsSendResult {
  const ContactUsImageTooLarge();
}

/// The support route allows one message a minute.
class ContactUsRateLimited extends ContactUsSendResult {
  const ContactUsRateLimited(this.retryAfter);
  final Duration? retryAfter;
}

class ContactUsFailed extends ContactUsSendResult {
  const ContactUsFailed(this.error);
  final Object error;
}

/// Flattens an image's marks and encodes it within the size budget; null when
/// it can't be made small enough. Injected so tests never touch `dart:ui`
/// encoding.
typedef FeedbackEncoder =
    Future<Uint8List?> Function(ui.Image image, List<MarkupMark> marks);

/// State behind the Contact Us dialog (docs/feedback-screenshots.md): the
/// screen capture and whether it goes, the images the user added, and the
/// send — JSON with no images, multipart `attachments[]` with some.
class ContactUsViewModel extends ChangeNotifier {
  ContactUsViewModel({
    required SupportApi Function() api,
    required this.attachmentsEnabled,
    required FeedbackEncoder encode,
    ui.Image? capture,
    Future<void> Function(Iterable<UploadSource> sources)? releaseSources,
  }) : _api = api,
       _encode = encode,
       _releaseSources = releaseSources,
       _capture = capture == null ? null : FeedbackAttachment(image: capture);

  /// Resolved when a message is sent, not before.
  final SupportApi Function() _api;
  final FeedbackEncoder _encode;
  final Future<void> Function(Iterable<UploadSource>)? _releaseSources;

  /// The server takes attachments and this isn't the demo — see
  /// `ServerFeatures.supportAttachments`.
  final bool attachmentsEnabled;

  FeedbackAttachment? _capture;
  bool _captureIncluded = false;
  final List<FeedbackAttachment> _images = [];
  bool _sending = false;
  bool _disposed = false;

  /// The screen behind the dialog, or null when it couldn't be captured.
  FeedbackAttachment? get capture => _capture;

  /// Whether the capture goes with the message. Off until the user says so:
  /// a screenshot can show client names and amounts.
  bool get captureIncluded => _captureIncluded && _capture != null;

  List<FeedbackAttachment> get images => List.unmodifiable(_images);
  bool get sending => _sending;

  /// How many images the user may add: [kFeedbackMaxImages], less one slot
  /// held for the capture while there is one — so ticking it can never make
  /// four.
  int get maxAddable =>
      !attachmentsEnabled ? 0 : kFeedbackMaxImages - (_capture == null ? 0 : 1);

  int get remainingSlots => maxAddable - _images.length;

  /// Images that would go with the message right now.
  int get attachedCount => _images.length + (captureIncluded ? 1 : 0);

  /// Whether closing the dialog would throw away markup work.
  bool get hasMarks =>
      (_capture?.marks.isNotEmpty ?? false) ||
      _images.any((i) => i.marks.isNotEmpty);

  void setCaptureIncluded(bool value) {
    if (_capture == null || _captureIncluded == value) return;
    _captureIncluded = value;
    notifyListeners();
  }

  /// The editor's Done on the capture: keeps the marks and includes it.
  void markUpCapture(List<MarkupMark> marks) {
    final c = _capture;
    if (c == null) return;
    _capture = c.withMarks(marks);
    _captureIncluded = true;
    notifyListeners();
  }

  /// Adds [added] up to [remainingSlots]; the rest are disposed and released.
  /// Returns how many didn't fit.
  int addImages(List<FeedbackAttachment> added) {
    final room = remainingSlots.clamp(0, kFeedbackMaxImages);
    final kept = added.take(room).toList();
    final dropped = added.skip(room).toList();
    for (final d in dropped) {
      d.image.dispose();
    }
    _release(dropped);
    if (kept.isNotEmpty) {
      _images.addAll(kept);
      notifyListeners();
    }
    return dropped.length;
  }

  void removeImage(int index) {
    if (index < 0 || index >= _images.length) return;
    final removed = _images.removeAt(index);
    removed.image.dispose();
    _release([removed]);
    notifyListeners();
  }

  void markUpImage(int index, List<MarkupMark> marks) {
    if (index < 0 || index >= _images.length) return;
    _images[index] = _images[index].withMarks(marks);
    notifyListeners();
  }

  /// Sends [message] (already trimmed) with the included images, or without
  /// any when [withImages] is false — the "Send without images" retry.
  Future<ContactUsSendResult> send({
    required String message,
    required String appVersion,
    bool withImages = true,
  }) async {
    if (_sending) return const ContactUsFailed('already sending');
    _sending = true;
    notifyListeners();
    // Whether the request that failed carried images — what decides between
    // "the images were refused" and an ordinary failure.
    var sentImages = false;
    try {
      final parts = <SupportAttachment>[];
      if (withImages && attachmentsEnabled) {
        final c = _capture;
        if (c != null && _captureIncluded) {
          final bytes = await _encode(c.image, c.marks);
          if (bytes == null) return const ContactUsImageTooLarge();
          parts.add(
            SupportAttachment(bytes: bytes, fileName: 'screenshot.png'),
          );
        }
        for (var i = 0; i < _images.length; i++) {
          final a = _images[i];
          final original = a.originalBytes;
          final Uint8List? bytes;
          final String ext;
          if (a.marks.isEmpty &&
              original != null &&
              a.originalExtension != null &&
              original.lengthInBytes <= kFeedbackMaxImageBytes) {
            // Untouched and small enough: the file as the user picked it.
            bytes = original;
            ext = a.originalExtension!;
          } else {
            bytes = await _encode(a.image, a.marks);
            ext = 'png';
          }
          if (bytes == null) return const ContactUsImageTooLarge();
          parts.add(
            SupportAttachment(bytes: bytes, fileName: 'image-${i + 1}.$ext'),
          );
        }
      }
      if (parts.isEmpty) {
        await _api().sendMessage(message: message, appVersion: appVersion);
      } else {
        sentImages = true;
        await _api().sendMessageWithAttachments(
          message: message,
          appVersion: appVersion,
          attachments: parts,
        );
      }
      return const ContactUsSent();
    } on RateLimitedException catch (e) {
      return ContactUsRateLimited(e.retryAfter);
    } on ValidationException catch (e) {
      final aboutImages = e.fieldErrors.keys.any(
        (k) => k == 'attachments' || k.startsWith('attachments.'),
      );
      return aboutImages && sentImages
          ? const ContactUsImagesRefused()
          : ContactUsFailed(e);
    } on ServerException catch (e) {
      return e.statusCode == 413 && sentImages
          ? const ContactUsImagesRefused()
          : ContactUsFailed(e);
    } on NetworkException catch (e) {
      return sentImages ? const ContactUsImagesRefused() : ContactUsFailed(e);
    } catch (e) {
      return ContactUsFailed(e);
    } finally {
      _sending = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _release(Iterable<FeedbackAttachment> attachments) {
    final sources = attachments.map((a) => a.source).nonNulls.toList();
    if (sources.isEmpty) return;
    _releaseSources?.call(sources).catchError((Object _) {});
  }

  @override
  void dispose() {
    _disposed = true;
    _capture?.image.dispose();
    for (final i in _images) {
      i.image.dispose();
    }
    _release(_images);
    _images.clear();
    super.dispose();
  }
}
