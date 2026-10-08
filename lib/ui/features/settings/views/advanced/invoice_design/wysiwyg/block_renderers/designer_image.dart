import 'dart:typed_data';

import 'package:flutter/material.dart';

/// An image in the designer, from wherever a design keeps one.
///
/// An uploaded image is stored in the design itself, as a `data:` URL, and
/// `Image.network` cannot draw one outside a browser — `dart:io`'s client
/// refuses the scheme — so every uploaded image drew as a broken-image box on
/// the native apps. A `data:` source is decoded here, once per source, into
/// an in-memory image; an `http(s)` one is fetched as before; anything else
/// (an unset image, a logo the company has not uploaded, a path that is not
/// a URL) is [placeholder].
///
/// The placeholder never prints the source: for an upload that is megabytes
/// of base64 in a label.
class DesignerImage extends StatefulWidget {
  const DesignerImage({
    super.key,
    required this.source,
    required this.placeholder,
    this.fit = BoxFit.contain,
    this.loading,
  });

  final String source;
  final BoxFit fit;

  /// Shown when there is nothing to draw, or it cannot be drawn.
  final Widget placeholder;

  /// Shown while a network image loads; the image's own box when null.
  final Widget? loading;

  /// Whether [source] is something this can draw at all.
  static bool canShow(String source) =>
      source.startsWith('data:') ||
      source.startsWith('http://') ||
      source.startsWith('https://');

  @override
  State<DesignerImage> createState() => _DesignerImageState();
}

class _DesignerImageState extends State<DesignerImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant DesignerImage old) {
    super.didUpdateWidget(old);
    // The same string instance survives every rebuild and every edit of the
    // block's other properties, so this is a pointer comparison nearly
    // always — and never a second decode of an image that has not changed.
    if (identical(old.source, widget.source)) return;
    if (old.source == widget.source) return;
    _decode();
  }

  void _decode() {
    _bytes = null;
    final source = widget.source;
    if (!source.startsWith('data:')) return;
    try {
      _bytes = UriData.parse(source).contentAsBytes();
    } on FormatException {
      // Not a data URL after all: the placeholder.
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: widget.fit,
        gaplessPlayback: true,
        // An SVG, or a file that is not the image its name said.
        errorBuilder: (_, _, _) => widget.placeholder,
      );
    }
    if (source.startsWith('http://') || source.startsWith('https://')) {
      final loading = widget.loading;
      return Image.network(
        source,
        fit: widget.fit,
        errorBuilder: (_, _, _) => widget.placeholder,
        loadingBuilder: loading == null
            ? null
            : (_, child, progress) => progress == null ? child : loading,
      );
    }
    return widget.placeholder;
  }
}
