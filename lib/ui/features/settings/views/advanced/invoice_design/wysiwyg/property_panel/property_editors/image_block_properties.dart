import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Property editor for `image` and `logo` blocks. Phase 7f matches
/// React's `ImageBlockProperties.tsx` surface:
/// - in-editor preview + remove (X) for `data:` / `http(s)` sources
/// - drag-and-drop dropzone on desktop, file-picker upload everywhere
/// - **Use Company Logo** quick-button → `source = '$company.logo'`
/// - `maxWidth` + `maxHeight` + `padding` PxInputs
/// - alignment SegmentedButton + objectFit dropdown
/// - hides the uploader UI on `logo` blocks (mirrors React's
///   `block.type !== 'logo'` guard)
class ImageBlockProperties extends StatefulWidget {
  const ImageBlockProperties({
    super.key,
    required this.vm,
    required this.block,
  });

  final WysiwygDesignViewModel vm;
  final DesignBlock block;

  @override
  State<ImageBlockProperties> createState() => _ImageBlockPropertiesState();
}

class _ImageBlockPropertiesState extends State<ImageBlockProperties> {
  late final TextEditingController _source;
  String _lastBlockId = '';

  @override
  void initState() {
    super.initState();
    _source = TextEditingController();
    _sync();
  }

  void _sync() {
    if (_lastBlockId == widget.block.id) return;
    _lastBlockId = widget.block.id;
    _source.text = (widget.block.properties['source'] as String?) ?? '';
  }

  @override
  void didUpdateWidget(covariant ImageBlockProperties old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _source.dispose();
    super.dispose();
  }

  void _write(String key, Object? value) {
    widget.vm.updateBlock(
      widget.block.copyWith(
        properties: mergePropertyOrOmit(widget.block.properties, key, value),
      ),
    );
  }

  String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    return 'application/octet-stream';
  }

  Future<void> _commitBytes(Uint8List bytes, String filename) async {
    const maxBytes = 2 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (!mounted) return;
      Notify.error(context, context.tr('file_too_large'));
      return;
    }
    final mime = _mimeFor(filename);
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
    setState(() => _source.text = dataUrl);
    _write('source', dataUrl);
  }

  Future<void> _onImageFiles(List<UploadSource> sources) async {
    if (sources.isEmpty) return;
    final source = sources.first;
    try {
      final bytes = await source.readRange(0, await source.length());
      await _commitBytes(bytes, source.fileName);
    } catch (_) {
      if (!mounted) return;
      Notify.error(context, context.tr('error_unable_to_upload'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final props = widget.block.properties;
    final src = _source.text;
    final isLogo = widget.block.type == 'logo';
    final hasImage =
        src.startsWith('data:') ||
        src.startsWith('http://') ||
        src.startsWith('https://');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Uploader is hidden on the `logo` block — React's
        // `block.type !== 'logo'` guard. Logo blocks are driven by the
        // company's stored logo (and a "Use Company Logo" button
        // re-attaches if the user typed something else).
        if (!isLogo)
          _ImageUploader(
            hasImage: hasImage,
            src: src,
            onRemove: () {
              setState(() => _source.clear());
              _write('source', null);
            },
            onFiles: _onImageFiles,
          ),
        if (!isLogo) SizedBox(height: InSpacing.md(context)),
        OutlinedButton.icon(
          icon: const Icon(Icons.business_outlined, size: 16),
          label: Text(context.tr('use_company_logo')),
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () {
            setState(() => _source.text = r'$company.logo');
            _write('source', r'$company.logo');
          },
        ),
        SizedBox(height: InSpacing.md(context)),
        TextField(
          controller: _source,
          // Also accepts the `$company.logo` token and a data: URI, so no
          // formatter — the url keyboard is purely an affordance here.
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: context.tr('image_url'),
            hintText: r'$company.logo  or  https://…',
            border: const OutlineInputBorder(),
            helperText: src.startsWith('data:')
                ? context.tr('uploaded_image_data_url')
                : null,
          ),
          onChanged: (v) => _write('source', v.trim()),
        ),
        const SectionDivider(labelKey: 'dimensions'),
        PxInput(
          labelKey: 'max_width',
          value: props['maxWidth'],
          hintText: '150',
          resettable: true,
          onChanged: (v) => _write('maxWidth', v),
        ),
        SizedBox(height: InSpacing.md(context)),
        PxInput(
          labelKey: 'max_height',
          value: props['maxHeight'],
          resettable: true,
          onChanged: (v) => _write('maxHeight', v),
        ),
        const SectionDivider(labelKey: 'layout'),
        AlignmentInput(
          labelKey: 'alignment',
          value: props['align'] as String?,
          onChanged: (v) => _write('align', v),
        ),
        SizedBox(height: InSpacing.md(context)),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: context.tr('object_fit'),
            border: const OutlineInputBorder(),
          ),
          initialValue: (props['objectFit'] as String?) ?? 'contain',
          // CSS object-fit values. The stored `value` stays the CSS keyword;
          // the label routes through `context.tr` (keys in _app_pending.json,
          // except `none` which already lives in en.json).
          items: [
            DropdownMenuItem(
              value: 'contain',
              child: Text(context.tr('contain')),
            ),
            DropdownMenuItem(value: 'cover', child: Text(context.tr('cover'))),
            DropdownMenuItem(value: 'fill', child: Text(context.tr('fill'))),
            DropdownMenuItem(
              value: 'scale-down',
              child: Text(context.tr('scale_down')),
            ),
            DropdownMenuItem(value: 'none', child: Text(context.tr('none'))),
          ],
          onChanged: (v) {
            if (v != null) _write('objectFit', v);
          },
        ),
        const SectionDivider(labelKey: 'spacing'),
        PxInput(
          labelKey: 'padding',
          value: props['padding'],
          hintText: '0',
          resettable: true,
          onChanged: (v) => _write('padding', v),
        ),
      ],
    );
  }
}

class _ImageUploader extends StatelessWidget {
  const _ImageUploader({
    required this.hasImage,
    required this.src,
    required this.onRemove,
    required this.onFiles,
  });

  final bool hasImage;
  final String src;
  final VoidCallback onRemove;
  final Future<void> Function(List<UploadSource>) onFiles;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The current-image preview stays ABOVE the drop zone (not inside its
        // tappable area) so the remove (X) gesture doesn't conflict with the
        // box's click-to-pick.
        if (hasImage)
          Padding(
            padding: EdgeInsets.only(bottom: InSpacing.sm),
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: 128,
                  decoration: BoxDecoration(
                    color: tokens.surfaceAlt,
                    border: Border.all(color: tokens.border, width: 2),
                    borderRadius: BorderRadius.circular(InRadii.r2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(InRadii.r2),
                    child: Image.network(
                      src,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: tokens.ink3,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Material(
                    color: tokens.overdue,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onRemove,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        FileDropZone(
          allowedExtensions: const [
            'png',
            'jpg',
            'jpeg',
            'gif',
            'webp',
            'svg',
            'bmp',
            'heic',
          ],
          idleLabelKey: 'drag_and_drop_to_add',
          onFiles: onFiles,
        ),
      ],
    );
  }
}
