import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/divider_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/image_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/info_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/invoice_details_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/qrcode_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/signature_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/spacer_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/table_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/text_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/total_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Right pane of the WYSIWYG designer. Defaults to **Document Settings**
/// when nothing is selected (UX improvement over React's blank state) and
/// swaps to per-block properties when the user selects a block.
///
/// Phase-1 scope: Document Settings form (page size / margins / fonts) +
/// a generic block info card (id / type / position). Per-block property
/// editors land in Phase 2 alongside type-specific renderers.
class PropertyPanel extends StatelessWidget {
  const PropertyPanel({super.key, required this.vm});

  final WysiwygDesignViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: context.inTheme.surface,
      // A transparent Material gives descendant SwitchListTiles a Material
      // ancestor to paint ink on — without it, Flutter 3.44 asserts because
      // this Container's background would hide the ink.
      child: Material(
        type: MaterialType.transparency,
        child: vm.panelMode == PropertyPanelMode.document
            ? _DocumentSettingsForm(vm: vm)
            : _BlockPropertiesForm(vm: vm),
      ),
    );
  }
}

/// Phase 7g: full set of page sizes React exposes — A5/A4/A3/B5/B4 +
/// JIS variants + Letter/Legal/Ledger. The dropdown falls back to A4
/// when the persisted value isn't in this list.
const List<String> _kPageSizes = [
  'A5',
  'A4',
  'A3',
  'B5',
  'B4',
  'JIS-B5',
  'JIS-B4',
  'Letter',
  'Legal',
  'Ledger',
];

/// Phase 7g: every even font size 6..40 px (React's `range(6, 41, 2)`).
const List<int> _kFontSizes = [
  6,
  8,
  10,
  12,
  14,
  16,
  18,
  20,
  22,
  24,
  26,
  28,
  30,
  32,
  34,
  36,
  38,
  40,
];

/// Curated Google Fonts presets exposed in the Document Settings panel.
/// Covers serif / sans-serif / monospace / display in a list short enough
/// to scan. Free-text font names still work — `GoogleFonts.getFont` in
/// the canvas accepts any Google Fonts family.
const List<String> _kCommonFonts = [
  'Roboto',
  'Open Sans',
  'Lato',
  'Montserrat',
  'Inter',
  'Poppins',
  'Source Sans 3',
  'Merriweather',
  'Playfair Display',
  'Roboto Slab',
  'Roboto Mono',
  'JetBrains Mono',
];

class _DocumentSettingsForm extends StatelessWidget {
  const _DocumentSettingsForm({required this.vm});
  final WysiwygDesignViewModel vm;

  @override
  Widget build(BuildContext context) {
    final ds = vm.documentSettings;
    return ListView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      children: [
        Text(
          context.tr('document_settings'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: InSpacing.md(context)),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: context.tr('page_layout')),
          initialValue: ds.pageLayout,
          items: [
            DropdownMenuItem(
              value: 'portrait',
              child: Text(context.tr('portrait')),
            ),
            DropdownMenuItem(
              value: 'landscape',
              child: Text(context.tr('landscape')),
            ),
          ],
          onChanged: (v) {
            if (v != null) vm.setDocumentSettings(ds.copyWith(pageLayout: v));
          },
        ),
        SizedBox(height: InSpacing.md(context)),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: context.tr('page_size')),
          initialValue: _kPageSizes.contains(ds.pageSize) ? ds.pageSize : 'A4',
          items: [
            // Mirrors React's `PAGE_SIZE_OPTIONS` in `DocumentSettingsPanel.tsx`.
            // A/B-series are ISO/JIS format codes (left literal); the named
            // sizes route through `context.tr` (keys live in en.json).
            DropdownMenuItem(value: 'A5', child: Text('A5')),
            DropdownMenuItem(value: 'A4', child: Text('A4')),
            DropdownMenuItem(value: 'A3', child: Text('A3')),
            DropdownMenuItem(value: 'B5', child: Text('B5')),
            DropdownMenuItem(value: 'B4', child: Text('B4')),
            DropdownMenuItem(value: 'JIS-B5', child: Text('JIS-B5')),
            DropdownMenuItem(value: 'JIS-B4', child: Text('JIS-B4')),
            DropdownMenuItem(
              value: 'Letter',
              child: Text(context.tr('letter')),
            ),
            DropdownMenuItem(value: 'Legal', child: Text(context.tr('legal'))),
            DropdownMenuItem(
              value: 'Ledger',
              child: Text(context.tr('ledger')),
            ),
          ],
          onChanged: (v) {
            if (v != null) vm.setDocumentSettings(ds.copyWith(pageSize: v));
          },
        ),
        SizedBox(height: InSpacing.md(context)),
        // Phase 7g: font-size dropdown of every even px 6..40. Mirrors
        // React's `range(6, 41, 2)`. Free numeric entry stays available
        // via the dropdown's editable text — out-of-list values still
        // round-trip from the server.
        DropdownButtonFormField<int>(
          decoration: InputDecoration(labelText: context.tr('font_size')),
          initialValue: _kFontSizes.contains(ds.globalFontSize)
              ? ds.globalFontSize
              : 16,
          items: [
            for (final size in _kFontSizes)
              DropdownMenuItem(value: size, child: Text('${size}px')),
          ],
          onChanged: (v) {
            if (v != null) {
              vm.setDocumentSettings(ds.copyWith(globalFontSize: v));
            }
          },
        ),
        SizedBox(height: InSpacing.md(context)),
        // Phase 5c: curated Google Fonts list. The canvas wraps content
        // in a DefaultTextStyle that pulls the font via
        // `GoogleFonts.getFont(primaryFont)`. Unknown values fall back
        // silently so the field doubles as free text for advanced users.
        DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: context.tr('primary_font')),
          initialValue: _kCommonFonts.contains(ds.primaryFont)
              ? ds.primaryFont
              : _kCommonFonts.first,
          items: [
            for (final f in _kCommonFonts)
              DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) {
            if (v != null) vm.setDocumentSettings(ds.copyWith(primaryFont: v));
          },
        ),
        SizedBox(height: InSpacing.md(context)),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(labelText: context.tr('secondary_font')),
          initialValue: _kCommonFonts.contains(ds.secondaryFont)
              ? ds.secondaryFont
              : _kCommonFonts.first,
          items: [
            for (final f in _kCommonFonts)
              DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) {
            if (v != null) {
              vm.setDocumentSettings(ds.copyWith(secondaryFont: v));
            }
          },
        ),
        SizedBox(height: InSpacing.lg(context)),
        Text(
          context.tr('page_margin'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        SizedBox(height: InSpacing.sm),
        _Quad(
          tKey: 'top',
          rKey: 'right',
          bKey: 'bottom',
          lKey: 'left',
          t: ds.pageMarginTop,
          r: ds.pageMarginRight,
          b: ds.pageMarginBottom,
          l: ds.pageMarginLeft,
          // React clamps each margin side to [0, 500] — a larger value
          // pushes content off-page on any supported paper size.
          minValue: 0,
          maxValue: 500,
          onChanged: (t, r, b, l) => vm.setDocumentSettings(
            ds.copyWith(
              pageMarginTop: t,
              pageMarginRight: r,
              pageMarginBottom: b,
              pageMarginLeft: l,
            ),
          ),
        ),
        SizedBox(height: InSpacing.lg(context)),
        Text(
          context.tr('padding'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        SizedBox(height: InSpacing.sm),
        _Quad(
          tKey: 'top',
          rKey: 'right',
          bKey: 'bottom',
          lKey: 'left',
          t: ds.pagePaddingTop,
          r: ds.pagePaddingRight,
          b: ds.pagePaddingBottom,
          l: ds.pagePaddingLeft,
          minValue: 0,
          maxValue: 500,
          onChanged: (t, r, b, l) => vm.setDocumentSettings(
            ds.copyWith(
              pagePaddingTop: t,
              pagePaddingRight: r,
              pagePaddingBottom: b,
              pagePaddingLeft: l,
            ),
          ),
        ),
        SizedBox(height: InSpacing.lg(context)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('show_paid_stamp')),
          value: ds.showPaidStamp,
          onChanged: (v) =>
              vm.setDocumentSettings(ds.copyWith(showPaidStamp: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('show_shipping_address')),
          value: ds.showShippingAddress,
          onChanged: (v) =>
              vm.setDocumentSettings(ds.copyWith(showShippingAddress: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('page_numbering')),
          value: ds.pageNumbering,
          onChanged: (v) =>
              vm.setDocumentSettings(ds.copyWith(pageNumbering: v)),
        ),
        // Phase 9c/9d: round-trip the embed-documents + hide-empty-columns
        // toggles that React's DocumentSettingsPanel exposes. Domain
        // model has carried these fields since the schema bridge; only
        // the UI was missing.
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          // Reuse React's `invoice_embed_documents` key — it's already
          // in en.json with the same label.
          title: Text(context.tr('invoice_embed_documents')),
          value: ds.embedDocuments,
          onChanged: (v) =>
              vm.setDocumentSettings(ds.copyWith(embedDocuments: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('hide_empty_columns')),
          value: ds.hideEmptyColumns,
          onChanged: (v) =>
              vm.setDocumentSettings(ds.copyWith(hideEmptyColumns: v)),
        ),
      ],
    );
  }
}

class _BlockPropertiesForm extends StatelessWidget {
  const _BlockPropertiesForm({required this.vm});
  final WysiwygDesignViewModel vm;

  @override
  Widget build(BuildContext context) {
    final block = vm.selectedBlock;
    if (block == null) {
      return const SizedBox.shrink();
    }
    final spec = blockSpecFor(block.type);
    return ListView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      children: [
        Row(
          children: [
            if (spec != null) ...[
              Icon(spec.icon, size: 18),
              SizedBox(width: InSpacing.sm),
            ],
            Expanded(
              child: Text(
                spec != null ? context.tr(spec.labelKey) : block.type,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        SizedBox(height: InSpacing.md(context)),
        // Phase 3b: dispatch to type-specific property editors when one
        // exists for the block type; otherwise fall back to the generic
        // content editor + position readout below.
        _typeSpecificEditor(vm, block) ??
            (block.properties.containsKey('content')
                ? _ContentEditor(vm: vm, block: block)
                : const SizedBox.shrink()),
        SizedBox(height: InSpacing.md(context)),
        _PositionReadout(block: block),
        SizedBox(height: InSpacing.md(context)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('locked')),
          value: block.locked,
          onChanged: (_) => vm.toggleLock(block.id),
        ),
        SizedBox(height: InSpacing.md(context)),
        OutlinedButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: Text(context.tr('delete')),
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => vm.deleteBlock(block.id),
        ),
      ],
    );
  }
}

/// Dispatch to the type-specific property editor for [block], or return
/// null when the block has no specialized editor and the caller should
/// fall back to the generic [_ContentEditor].
Widget? _typeSpecificEditor(WysiwygDesignViewModel vm, DesignBlock block) {
  // Key every editor on the block id so selecting a different block — even one
  // of the SAME type — tears down and rebuilds the editor's FormField state.
  // Some editors hold bare `TextFormField(initialValue:)` fields (table
  // colors, info title) whose `initialValue` is ignored on rebuild; without a
  // changing key the State is reused and they'd show (and on edit corrupt) the
  // previously-selected block's values.
  final key = ValueKey(block.id);
  switch (block.type) {
    case 'text':
    case 'public-notes':
    case 'terms':
    case 'footer':
      return TextBlockProperties(key: key, vm: vm, block: block);
    case 'client-info':
    case 'company-info':
    case 'client-shipping-info':
      return InfoBlockProperties(key: key, vm: vm, block: block);
    case 'table':
    case 'tasks-table':
      return TableBlockProperties(key: key, vm: vm, block: block);
    case 'total':
      return TotalBlockProperties(key: key, vm: vm, block: block);
    case 'image':
    case 'logo':
      return ImageBlockProperties(key: key, vm: vm, block: block);
    case 'qrcode':
      return QrcodeBlockProperties(key: key, vm: vm, block: block);
    case 'divider':
      return DividerBlockProperties(key: key, vm: vm, block: block);
    case 'spacer':
      return SpacerBlockProperties(key: key, vm: vm, block: block);
    case 'signature':
      return SignatureBlockProperties(key: key, vm: vm, block: block);
    case 'invoice-details':
      return InvoiceDetailsBlockProperties(key: key, vm: vm, block: block);
    default:
      return null;
  }
}

class _ContentEditor extends StatefulWidget {
  const _ContentEditor({required this.vm, required this.block});
  final WysiwygDesignViewModel vm;
  final DesignBlock block;

  @override
  State<_ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<_ContentEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: (widget.block.properties['content'] as String?) ?? '',
  );

  @override
  void didUpdateWidget(covariant _ContentEditor old) {
    super.didUpdateWidget(old);
    if (old.block.id != widget.block.id) {
      _controller.text = (widget.block.properties['content'] as String?) ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      maxLines: null,
      minLines: 3,
      decoration: InputDecoration(
        labelText: context.tr('content'),
        border: const OutlineInputBorder(),
      ),
      onChanged: (v) {
        final next = Map<String, dynamic>.from(widget.block.properties);
        next['content'] = v;
        widget.vm.updateBlock(widget.block.copyWith(properties: next));
      },
    );
  }
}

class _PositionReadout extends StatelessWidget {
  const _PositionReadout({required this.block});
  final DesignBlock block;
  @override
  Widget build(BuildContext context) {
    final p = block.gridPosition;
    return Container(
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: context.inTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r1),
      ),
      child: Text(
        'x=${p.x}  y=${p.y}  w=${p.w}  h=${p.h}',
        style: TextStyle(
          fontFamily: kMonoFontFamily,
          fontSize: 12,
          color: context.inTheme.ink3,
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.labelKey,
    required this.value,
    required this.onChanged,
    this.minValue,
    this.maxValue,
  });
  final String labelKey;
  final int value;
  final ValueChanged<int> onChanged;
  final int? minValue;
  final int? maxValue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Phase 19b: small static label above a compact dense input. The
    // previous Material floating-label decoration truncated to "T..." /
    // "Ri..." / "B..." / "L..." at the ~60 px cell width inside a
    // _Quad row. A 10 px Text above the input keeps the full word
    // ("Top" / "Right" / "Bottom" / "Left") legible without overflow.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr(labelKey),
          style: TextStyle(
            fontSize: 10,
            color: tokens.ink3,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: InSpacing.xs),
        TextFormField(
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(InRadii.r1),
              borderSide: BorderSide(color: tokens.border, width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(InRadii.r1),
              borderSide: BorderSide(color: tokens.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(InRadii.r1),
              borderSide: BorderSide(color: tokens.accent, width: 1.5),
            ),
          ),
          initialValue: value.toString(),
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          onChanged: (v) {
            final parsed = int.tryParse(v.trim());
            if (parsed == null) return;
            var clamped = parsed;
            if (minValue != null && clamped < minValue!) clamped = minValue!;
            if (maxValue != null && clamped > maxValue!) clamped = maxValue!;
            onChanged(clamped);
          },
        ),
      ],
    );
  }
}

class _Quad extends StatelessWidget {
  const _Quad({
    required this.tKey,
    required this.rKey,
    required this.bKey,
    required this.lKey,
    required this.t,
    required this.r,
    required this.b,
    required this.l,
    required this.onChanged,
    this.minValue,
    this.maxValue,
  });
  final String tKey;
  final String rKey;
  final String bKey;
  final String lKey;
  final int t;
  final int r;
  final int b;
  final int l;
  final void Function(int t, int r, int b, int l) onChanged;
  final int? minValue;
  final int? maxValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _NumberField(
            labelKey: tKey,
            value: t,
            minValue: minValue,
            maxValue: maxValue,
            onChanged: (v) => onChanged(v, r, b, l),
          ),
        ),
        SizedBox(width: InSpacing.sm),
        Expanded(
          child: _NumberField(
            labelKey: rKey,
            value: r,
            minValue: minValue,
            maxValue: maxValue,
            onChanged: (v) => onChanged(t, v, b, l),
          ),
        ),
        SizedBox(width: InSpacing.sm),
        Expanded(
          child: _NumberField(
            labelKey: bKey,
            value: b,
            minValue: minValue,
            maxValue: maxValue,
            onChanged: (v) => onChanged(t, r, v, l),
          ),
        ),
        SizedBox(width: InSpacing.sm),
        Expanded(
          child: _NumberField(
            labelKey: lKey,
            value: l,
            minValue: minValue,
            maxValue: maxValue,
            onChanged: (v) => onChanged(t, r, b, v),
          ),
        ),
      ],
    );
  }
}
