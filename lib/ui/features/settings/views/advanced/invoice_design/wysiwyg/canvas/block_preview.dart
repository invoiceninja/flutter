import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/image_blocks.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/info_blocks.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/simple_blocks.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/table_blocks.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/text_blocks.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/total_block.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';

/// A block as it prints: its content at its natural height, with nothing
/// around it.
///
/// It used to be a bordered card with a type label on top, at a height the
/// PDF never had. The canvas is a picture of the document, so the only things
/// drawn here that will not print are the two a user could otherwise not find
/// or understand: a placeholder where a block would render nothing at all
/// ([blockRendersNothing]), and a note on a block the server cannot print.
class BlockPreview extends StatelessWidget {
  const BlockPreview({super.key, required this.block, required this.sample});

  final DesignBlock block;
  final DesignerSampleData sample;

  @override
  Widget build(BuildContext context) {
    final spec = blockSpecFor(block.type);
    if (spec == null) return _UnsupportedBlock(type: block.type);
    if (blockRendersNothing(block, sample)) {
      return _EmptyBlockPlaceholder(spec: spec, block: block);
    }
    final body = _renderBlockBody(block, sample);
    if (spec.printed) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _EditorNote(
          icon: Icons.print_disabled_outlined,
          text: context.tr('block_not_printed'),
          warning: true,
        ),
        const SizedBox(height: 6),
        body,
      ],
    );
  }
}

/// Whether [block] would print as nothing — a text block with no text, an
/// info or totals block with every row gone, a table with no columns, a
/// spacer. On a canvas that draws only what prints, such a block could
/// neither be seen nor clicked.
bool blockRendersNothing(DesignBlock block, DesignerSampleData sample) {
  final props = block.properties;
  List<dynamic> list(String key) =>
      props[key] is List ? props[key] as List : const [];
  switch (block.type) {
    case 'spacer':
      return true;
    case 'text':
      return ((props['content'] as String?) ?? '').trim().isEmpty;
    case 'client-info':
    case 'client-shipping-info':
      final showTitle = props['showTitle'] as bool? ?? false;
      if (showTitle && ((props['title'] as String?) ?? '').trim().isNotEmpty) {
        return false;
      }
      return !_anyFieldPrints(list('fieldConfigs'), sample);
    // No title prints for these two.
    case 'company-info':
    case 'invoice-details':
      return !_anyFieldPrints(list('fieldConfigs'), sample);
    case 'table':
    case 'tasks-table':
      return list('columns').isEmpty;
    case 'total':
      return !list('items').any((it) => it is Map && it['show'] != false);
    default:
      return false;
  }
}

bool _anyFieldPrints(List<dynamic> fields, DesignerSampleData sample) {
  for (final f in fields) {
    if (f is! Map) continue;
    final variable = (f['variable'] as String?) ?? '';
    final hideIfEmpty = f['hideIfEmpty'] as bool? ?? true;
    if (!hideIfEmpty) return true;
    if (!resolvesEmpty(replaceVariables(variable, data: sample))) return true;
  }
  return false;
}

/// Registry dispatch: maps `block.type` to the matching renderer widget.
/// New block types add a `case` clause here AND a renderer file under
/// `block_renderers/`.
Widget _renderBlockBody(DesignBlock block, DesignerSampleData sample) {
  switch (block.type) {
    case 'logo':
    case 'image':
      return ImageBlock(block: block, sample: sample);
    case 'text':
      return FormattedTextBlock(block: block, sample: sample);
    case 'public-notes':
      return FormattedTextBlock(
        block: block,
        sample: sample,
        defaultContent: r'$public_notes',
      );
    case 'terms':
      return FormattedTextBlock(
        block: block,
        sample: sample,
        defaultContent: r'$terms',
      );
    case 'footer':
      return FormattedTextBlock(
        block: block,
        sample: sample,
        defaultContent: r'$footer',
      );
    case 'company-info':
    case 'client-info':
    case 'client-shipping-info':
      return InfoBlock(block: block, sample: sample);
    case 'invoice-details':
      return InvoiceDetailsBlock(block: block, sample: sample);
    case 'table':
    case 'tasks-table':
      return TableBlock(block: block, sample: sample);
    case 'total':
      return TotalBlock(block: block, sample: sample);
    case 'divider':
      return DividerBlock(block: block);
    case 'spacer':
      return SpacerBlock(block: block);
    case 'qrcode':
      return QrcodeBlockPreview(block: block, sample: sample);
    case 'signature':
      return SignatureBlock(block: block, sample: sample);
    default:
      return _UnsupportedBlock(type: block.type);
  }
}

/// Stands in for a block that would print as nothing, at the height it will
/// take up (a spacer's own; otherwise one line), so there is something to see
/// and to click.
class _EmptyBlockPlaceholder extends StatelessWidget {
  const _EmptyBlockPlaceholder({required this.spec, required this.block});

  final BlockSpec spec;
  final DesignBlock block;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final isSpacer = block.type == 'spacer';
    final height = isSpacer
        ? (parsePx(block.properties['height']) ?? 40.0)
        : 44.0;
    final label = isSpacer
        ? '${context.tr(spec.labelKey)} · ${height.round()}px'
        : context.tr(spec.labelKey);
    return Container(
      // A spacer keeps its true height so the rows around it sit where they
      // will print; it only shows its label when it is tall enough for one.
      height: height < 4 ? 4 : height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: tokens.surfaceAlt.withValues(alpha: 0.6),
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r1),
      ),
      alignment: Alignment.center,
      child: height < 22
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(spec.icon, size: 16, color: tokens.ink3),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: tokens.ink3),
                  ),
                ),
              ],
            ),
    );
  }
}

/// A block of a type this app has no renderer for — another client's, or a
/// newer server's. It is kept exactly as it came and saved back untouched.
class _UnsupportedBlock extends StatelessWidget {
  const _UnsupportedBlock({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) => _EditorNote(
    icon: Icons.extension_outlined,
    text: '${context.tr('unsupported_block')} · $type',
  );
}

class _EditorNote extends StatelessWidget {
  const _EditorNote({
    required this.icon,
    required this.text,
    this.warning = false,
  });

  final IconData icon;
  final String text;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final color = warning ? tokens.overdue : tokens.ink3;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: warning ? tokens.overdueSoft : tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: color)),
          ),
        ],
      ),
    );
  }
}
