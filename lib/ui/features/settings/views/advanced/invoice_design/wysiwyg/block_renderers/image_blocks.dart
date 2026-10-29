import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/designer_image.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';

/// Renders `logo` and `image` blocks. Both use the same shape: an
/// optionally-aligned image with `maxWidth` (px, or a percentage of the
/// block's width) clamped by a `ConstrainedBox` and `objectFit` mapped to
/// Flutter's `BoxFit`.
///
/// `logo` defaults `source` to `$company.logo`; `image` uses an empty
/// string and shows a placeholder when no image is set. Variable
/// substitution turns the token into the real URL (sample data carries
/// `'/logo180.png'` — a relative path that won't actually load in tests,
/// so the renderer shows the placeholder icon for those). The drawing is
/// [DesignerImage]'s, which is what makes an *uploaded* image draw.
class ImageBlock extends StatelessWidget {
  const ImageBlock({super.key, required this.block, required this.sample});

  final DesignBlock block;
  final DesignerSampleData sample;

  @override
  Widget build(BuildContext context) {
    final props = block.properties;
    final rawSource = (props['source'] as String?)?.trim() ?? '';
    // Only a token is substituted. An uploaded image is a `data:` URL of a
    // megabyte or two, and running every variable's pattern over it on each
    // rebuild was the cost of drawing the page.
    final resolvedSource = rawSource.startsWith(r'$')
        ? replaceVariables(rawSource, data: sample)
        : rawSource;
    final widthShare = parsePercent(props['maxWidth']);
    final maxWidth = widthShare == null ? parsePx(props['maxWidth']) : null;
    final maxHeight = parsePx(props['maxHeight']);
    final fit = parseObjectFit(props['objectFit'] as String?);
    final alignment = parseAlignment(props['align'] as String?);

    Widget image = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth ?? double.infinity,
        maxHeight: maxHeight ?? double.infinity,
      ),
      child: _imageOrPlaceholder(context, resolvedSource, fit),
    );
    if (widthShare != null) {
      // The server prints `max-width: 65%` as a share of the block's column:
      // the image keeps its own size up to that share, and is placed in it by
      // `align`.
      image = FractionallySizedBox(
        widthFactor: widthShare.clamp(0.0, 1.0),
        alignment: alignment,
        child: Align(alignment: alignment, child: image),
      );
    }

    return Align(alignment: alignment, child: image);
  }

  // Nothing to show — an unset image, a logo the company has not uploaded,
  // one that will not load — is a stand-in, never the token, path or data
  // it resolved to.
  Widget _imageOrPlaceholder(BuildContext context, String src, BoxFit fit) =>
      DesignerImage(
        source: src,
        fit: fit,
        placeholder: const _Placeholder(),
        loading: const _PlaceholderSpinner(),
      );
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border.all(color: tokens.border, width: 0.5),
      ),
      child: Icon(Icons.image_outlined, color: tokens.ink3, size: 32),
    );
  }
}

class _PlaceholderSpinner extends StatelessWidget {
  const _PlaceholderSpinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}
