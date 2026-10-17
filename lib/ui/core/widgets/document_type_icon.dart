import 'package:flutter/material.dart';

/// The extensions drawn with the image glyph. Wider than what the in-app
/// viewer can render (`previewKindForType`): this only picks an icon.
const Set<String> _kImageTypes = {
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'heic',
  'svg',
  'bmp',
};

/// The leading glyph for an attachment of file [type] (its extension, as the
/// server reports it). One copy for every document list — a record's
/// Documents tab, Company Details → Documents and the Documents screen.
IconData documentTypeIcon(String type) =>
    _kImageTypes.contains(type.toLowerCase())
    ? Icons.image_outlined
    : Icons.description_outlined;
