import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/feedback/markup.dart';
import 'package:admin/ui/features/feedback/contact_us_view_model.dart';
import 'package:admin/utils/file_type.dart';

/// Why a picked file can't be attached.
enum PickedImageProblem { tooLarge, notAnImage }

/// Reads [source] into a [FeedbackAttachment], or says why it can't be one
/// (docs/feedback-screenshots.md).
///
/// Refused before decoding: a file over [kFeedbackMaxSourceBytes], one that
/// isn't a jpg / png / gif / webp by its own bytes, and one whose header
/// claims more than [kFeedbackMaxSourcePixels] — on the web the browser
/// decodes an image at full size before resizing it, so a size cap at decode
/// time doesn't bound memory there. Decoded no larger than
/// [kFeedbackCaptureMaxEdge] on its longest edge; an animated GIF keeps its
/// first frame. The original bytes ride along, sent as-is when nothing is
/// drawn on the image.
Future<({FeedbackAttachment? attachment, PickedImageProblem? problem})>
loadPickedImage(UploadSource source) async {
  final length = await source.length();
  if (length > kFeedbackMaxSourceBytes) {
    return (attachment: null, problem: PickedImageProblem.tooLarge);
  }
  final bytes = await source.readRange(0, length);
  final ext = imageExtensionOf(bytes);
  if (ext == null) {
    return (attachment: null, problem: PickedImageProblem.notAnImage);
  }
  try {
    final info = img.findDecoderForData(bytes)?.startDecode(bytes);
    if (info != null && info.width * info.height > kFeedbackMaxSourcePixels) {
      return (attachment: null, problem: PickedImageProblem.tooLarge);
    }
  } catch (_) {
    // A header the pure-Dart reader can't parse: let the engine try.
  }
  final image = await decodeFeedbackImage(bytes);
  if (image == null) {
    return (attachment: null, problem: PickedImageProblem.notAnImage);
  }
  return (
    attachment: FeedbackAttachment(
      image: image,
      originalBytes: bytes,
      originalExtension: ext,
      source: source,
    ),
    problem: null,
  );
}

/// [bytes] decoded no larger than [kFeedbackCaptureMaxEdge] on the longest
/// edge, or null when the engine can't decode them.
Future<ui.Image?> decodeFeedbackImage(Uint8List bytes) async {
  ui.Codec? codec;
  try {
    // `instantiateImageCodecWithSize` disposes the buffer itself, and a
    // second dispose asserts — so this function never does.
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (w, h) {
        final longest = math.max(w, h);
        if (longest <= kFeedbackCaptureMaxEdge) {
          return ui.TargetImageSize(width: w, height: h);
        }
        final scale = kFeedbackCaptureMaxEdge / longest;
        return ui.TargetImageSize(
          width: math.max(1, (w * scale).round()),
          height: math.max(1, (h * scale).round()),
        );
      },
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  } finally {
    codec?.dispose();
  }
}
