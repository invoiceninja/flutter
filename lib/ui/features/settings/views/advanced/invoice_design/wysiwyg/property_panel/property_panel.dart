import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/static/google_fonts_catalog.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/page_metrics.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_actions.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_menu.dart';
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
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Wide enough for a property's name and its control on one line.
const double kDesignerPanelWidth = 320;

/// The page sizes the server prints (`JsonDesignService::cssSizeFor`). Any
/// other value — the B and JIS sizes this list used to offer — is rendered as
/// A4 portrait, dropping the orientation with it.
const List<String> kDesignerPageSizes = [
  'A3',
  'A4',
  'A5',
  'A6',
  'Letter',
  'Legal',
  'Tabloid',
  'Ledger',
];

/// The entry of [kDesignerPageSizes] a stored size names, whatever its case
/// — or null for one the server will not print.
String? _knownPageSize(String stored) {
  final wanted = stored.trim().toLowerCase();
  for (final size in kDesignerPageSizes) {
    if (size.toLowerCase() == wanted) return size;
  }
  return null;
}

/// The designer's right-hand pane: the selected block's properties, or the
/// page's.
///
/// Which of the two is showing used to be implicit — the page settings were
/// simply what appeared when nothing was selected, which nobody had a reason
/// to discover. Two tabs say it: **Block** follows the selection, and
/// **Page** is one press away from anywhere.
class PropertyPanel extends StatelessWidget {
  const PropertyPanel({super.key, required this.vm, this.onShowPage});

  final WysiwygDesignViewModel vm;

  /// What the Page tab does. By default it drops the selection, which is
  /// what shows the page where the panel is always on screen. A host that
  /// shows the panel only *for* a selection — the tablet's drawer, the
  /// phone's block sheet — would close on that, so it says here how to get to
  /// the page instead.
  final VoidCallback? onShowPage;

  @override
  Widget build(BuildContext context) {
    final mode = vm.panelMode;
    return Container(
      width: kDesignerPanelWidth,
      color: context.inTheme.surface,
      // A transparent Material gives the controls below a Material ancestor
      // to paint ink on — without it, Flutter asserts because this
      // Container's background would hide the ink.
      child: Material(
        type: MaterialType.transparency,
        child: DesignerPaletteScope(
          inUse: collectHexColors([for (final b in vm.blocks) b.properties]),
          brand: vm.brandColors,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  InSpacing.lg(context),
                  InSpacing.md(context),
                  InSpacing.lg(context),
                  InSpacing.sm,
                ),
                child: SegmentedButton<PropertyPanelMode>(
                  showSelectedIcon: false,
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(
                      value: PropertyPanelMode.block,
                      label: Text(context.tr('block')),
                      // Follows the selection: there is nothing to show
                      // until a block is picked.
                      enabled: mode == PropertyPanelMode.block,
                    ),
                    ButtonSegment(
                      value: PropertyPanelMode.document,
                      label: Text(context.tr('page')),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (s) {
                    if (s.first == PropertyPanelMode.document) {
                      (onShowPage ?? () => vm.selectBlock(null))();
                    }
                  },
                ),
              ),
              Expanded(
                child: mode == PropertyPanelMode.document
                    ? _PageSettingsForm(vm: vm)
                    : _BlockPropertiesForm(vm: vm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page ────────────────────────────────────────────────────────────────

class _PageSettingsForm extends StatelessWidget {
  const _PageSettingsForm({required this.vm});
  final WysiwygDesignViewModel vm;

  @override
  Widget build(BuildContext context) {
    final ds = vm.documentSettings;
    final tokens = context.inTheme;
    void set(DocumentSettings next) => vm.setDocumentSettings(next);
    final landscape = ds.pageLayout.trim().toLowerCase() == 'landscape';
    return ListView(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.sm,
        InSpacing.lg(context),
        InSpacing.lg(context),
      ),
      children: [
        if (vm.blocks.isNotEmpty && vm.selectedBlock == null)
          Padding(
            padding: EdgeInsets.only(bottom: InSpacing.md(context)),
            child: Text(
              context.tr('select_a_block'),
              style: TextStyle(fontSize: 12, color: tokens.ink3),
            ),
          ),
        _AppliesTo(vm: vm),
        const SectionDivider(labelKey: 'page'),
        PropertyRow(
          label: context.tr('page_size'),
          child: _CompactDropdown<String>(
            // The stored value is shown as stored. One the server does not
            // print keeps its own entry, saying what it will come out as,
            // rather than the field silently reading "A4".
            // Matched as the server matches it: `a4` is A4, not a size it
            // does not know.
            value: _knownPageSize(ds.pageSize) ?? ds.pageSize,
            items: {
              for (final size in kDesignerPageSizes)
                size: switch (size) {
                  'Letter' => context.tr('letter'),
                  'Legal' => context.tr('legal'),
                  'Ledger' => context.tr('ledger'),
                  _ => size,
                },
              // A stored size the list does not offer keeps its own entry.
              // It is only "printed as A4" when the server does not know it:
              // the poster sizes (A0–A2) are left out of the list, and print
              // as themselves.
              if (_knownPageSize(ds.pageSize) == null)
                ds.pageSize: serverPrintsPageSize(ds.pageSize)
                    ? ds.pageSize
                    : '${ds.pageSize} (${context.tr('prints_as_a4')})',
            },
            onChanged: (v) => set(ds.copyWith(pageSize: v)),
          ),
        ),
        // Two choices: both stay on screen rather than one behind a menu.
        PropertyRow(
          label: context.tr('orientation'),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              visualDensity: VisualDensity.compact,
            ),
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.crop_portrait, size: 16),
                tooltip: context.tr('portrait'),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.crop_landscape, size: 16),
                tooltip: context.tr('landscape'),
              ),
            ],
            selected: {landscape},
            onSelectionChanged: (s) => set(
              ds.copyWith(pageLayout: s.first ? 'landscape' : 'portrait'),
            ),
          ),
        ),
        const SectionDivider(labelKey: 'margins'),
        _Margins(settings: ds, onChanged: set),
        const SectionDivider(labelKey: 'typography'),
        _FontPicker(
          value: ds.primaryFont,
          onChanged: (id) => set(ds.copyWith(primaryFont: id)),
        ),
        SizedBox(height: InSpacing.sm),
        PxInput(
          labelKey: 'font_size',
          value: '${ds.globalFontSize}px',
          minPx: 6,
          maxPx: 40,
          presets: const ['10px', '12px', '14px', '16px', '18px', '20px'],
          onChanged: (v) {
            final px = int.tryParse((v ?? '').replaceAll('px', ''));
            if (px != null) set(ds.copyWith(globalFontSize: px));
          },
        ),
        const SectionDivider(labelKey: 'show_on_document'),
        PropertySwitch(
          labelKey: 'show_paid_stamp',
          value: ds.showPaidStamp,
          onChanged: (v) => set(ds.copyWith(showPaidStamp: v)),
        ),
        PropertySwitch(
          labelKey: 'show_shipping_address',
          value: ds.showShippingAddress,
          onChanged: (v) => set(ds.copyWith(showShippingAddress: v)),
        ),
        PropertySwitch(
          labelKey: 'page_numbering',
          value: ds.pageNumbering,
          onChanged: (v) => set(ds.copyWith(pageNumbering: v)),
        ),
        PropertySwitch(
          labelKey: 'invoice_embed_documents',
          value: ds.embedDocuments,
          onChanged: (v) => set(ds.copyWith(embedDocuments: v)),
        ),
        PropertySwitch(
          labelKey: 'hide_empty_columns',
          value: ds.hideEmptyColumns,
          onChanged: (v) => set(ds.copyWith(hideEmptyColumns: v)),
        ),
        PropertyDisclosure(children: [_CustomCssField(vm: vm)]),
      ],
    );
  }
}

/// Which document types may use this design. The design pickers hide a
/// custom design from a type it does not list, so this decides where the
/// design can be chosen at all.
class _AppliesTo extends StatelessWidget {
  const _AppliesTo({required this.vm});
  final WysiwygDesignViewModel vm;

  @override
  Widget build(BuildContext context) {
    final selected = vm.draft.entities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('applies_to'),
          style: TextStyle(fontSize: 13, color: context.inTheme.ink2),
        ),
        SizedBox(height: InSpacing.sm),
        Wrap(
          spacing: InSpacing.sm,
          runSpacing: InSpacing.sm,
          children: [
            for (final entity in WysiwygDesignViewModel.defaultEntities)
              FilterChip(
                label: Text(context.tr(entity)),
                visualDensity: VisualDensity.compact,
                selected: selected.contains(entity),
                onSelected: (_) => vm.toggleEntity(entity),
              ),
          ],
        ),
      ],
    );
  }
}

/// The page's margins: four numbers, each the *whole* inset on that side.
///
/// The design stores a margin and a padding per side and the server simply
/// adds them into one `@page` margin, so the panel used to show eight fields
/// for four distances. What is edited here is the sum; the split is kept as
/// stored (the padding gives way only when the total drops below it).
class _Margins extends StatelessWidget {
  const _Margins({required this.settings, required this.onChanged});

  final DocumentSettings settings;
  final ValueChanged<DocumentSettings> onChanged;

  static const _presets = <(String, int)>[
    ('none', 0),
    ('narrow', 20),
    ('normal', 40),
    ('wide', 60),
  ];

  DocumentSettings _with({int? top, int? right, int? bottom, int? left}) {
    // margin + padding = total, with the padding left alone unless the
    // total is smaller than it.
    (int margin, int padding) split(int total, int padding) {
      final t = total.clamp(0, 500);
      return t >= padding ? (t - padding, padding) : (0, t);
    }

    var s = settings;
    if (top != null) {
      final (m, p) = split(top, s.pagePaddingTop);
      s = s.copyWith(pageMarginTop: m, pagePaddingTop: p);
    }
    if (right != null) {
      final (m, p) = split(right, s.pagePaddingRight);
      s = s.copyWith(pageMarginRight: m, pagePaddingRight: p);
    }
    if (bottom != null) {
      final (m, p) = split(bottom, s.pagePaddingBottom);
      s = s.copyWith(pageMarginBottom: m, pagePaddingBottom: p);
    }
    if (left != null) {
      final (m, p) = split(left, s.pagePaddingLeft);
      s = s.copyWith(pageMarginLeft: m, pagePaddingLeft: p);
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final top = s.pageMarginTop + s.pagePaddingTop;
    final right = s.pageMarginRight + s.pagePaddingRight;
    final bottom = s.pageMarginBottom + s.pagePaddingBottom;
    final left = s.pageMarginLeft + s.pagePaddingLeft;
    final uniform = top == right && right == bottom && bottom == left;
    int? px(String? v) => int.tryParse((v ?? '').replaceAll('px', ''));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('margins_hint'),
          style: TextStyle(fontSize: 11.5, color: context.inTheme.ink3),
        ),
        SizedBox(height: InSpacing.sm),
        Wrap(
          spacing: InSpacing.sm,
          runSpacing: InSpacing.sm,
          children: [
            for (final (key, value) in _presets)
              ChoiceChip(
                label: Text(context.tr(key)),
                visualDensity: VisualDensity.compact,
                selected: uniform && top == value,
                onSelected: (_) => onChanged(
                  _with(top: value, right: value, bottom: value, left: value),
                ),
              ),
          ],
        ),
        SizedBox(height: InSpacing.sm),
        PxInput(
          labelKey: 'top',
          value: '${top}px',
          minPx: 0,
          maxPx: 500,
          onChanged: (v) {
            // Emptied is mid-edit, not zero: writing 0 snapped the field to
            // "0" under the caret, and the next digits landed after it.
            final n = px(v);
            if (n != null) onChanged(_with(top: n));
          },
        ),
        PxInput(
          labelKey: 'right',
          value: '${right}px',
          minPx: 0,
          maxPx: 500,
          onChanged: (v) {
            // Emptied is mid-edit, not zero: writing 0 snapped the field to
            // "0" under the caret, and the next digits landed after it.
            final n = px(v);
            if (n != null) onChanged(_with(right: n));
          },
        ),
        PxInput(
          labelKey: 'bottom',
          value: '${bottom}px',
          minPx: 0,
          maxPx: 500,
          onChanged: (v) {
            // Emptied is mid-edit, not zero: writing 0 snapped the field to
            // "0" under the caret, and the next digits landed after it.
            final n = px(v);
            if (n != null) onChanged(_with(bottom: n));
          },
        ),
        PxInput(
          labelKey: 'left',
          value: '${left}px',
          minPx: 0,
          maxPx: 500,
          onChanged: (v) {
            // Emptied is mid-edit, not zero: writing 0 snapped the field to
            // "0" under the caret, and the next digits landed after it.
            final n = px(v);
            if (n != null) onChanged(_with(left: n));
          },
        ),
      ],
    );
  }
}

/// The document's font, searchable over the whole Google catalog.
///
/// The value is stored the way the company setting is — the catalog id
/// (`Abril_Fatface`) — though the server resolves a name as well. A stored
/// value this catalog does not hold is listed as it is, so the field never
/// claims a font the document is not using (it used to read "Roboto" for
/// anything outside a list of twelve).
class _FontPicker extends StatelessWidget {
  const _FontPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    GoogleFont? current;
    for (final font in kGoogleFonts) {
      if (font.id == value || font.name == value) current = font;
    }
    final items = [
      if (current == null && value.isNotEmpty)
        (id: value, name: value.replaceAll('_', ' ')),
      ...kGoogleFonts,
    ];
    return SearchableDropdownField<GoogleFont>(
      label: context.tr('primary_font'),
      items: items,
      initialValue: current ?? (value.isEmpty ? null : items.first),
      displayString: (f) => f.name,
      idOf: (f) => f.id,
      onChanged: (f) {
        if (f != null) onChanged(f.id);
      },
    );
  }
}

/// Extra CSS for the document — the server appends `design.customCss` to the
/// page's styles.
class _CustomCssField extends StatefulWidget {
  const _CustomCssField({required this.vm});
  final WysiwygDesignViewModel vm;

  @override
  State<_CustomCssField> createState() => _CustomCssFieldState();
}

class _CustomCssFieldState extends State<_CustomCssField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.vm.customCss,
  );

  @override
  void didUpdateWidget(covariant _CustomCssField old) {
    super.didUpdateWidget(old);
    // An undo, or an import, changed it from outside.
    final stored = widget.vm.customCss;
    if (stored != _controller.text) _controller.text = stored;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('custom_css'),
          style: TextStyle(fontSize: 13, color: context.inTheme.ink2),
        ),
        SizedBox(height: InSpacing.xs),
        Text(
          context.tr('custom_css_hint'),
          style: TextStyle(fontSize: 11.5, color: context.inTheme.ink3),
        ),
        SizedBox(height: InSpacing.sm),
        TextField(
          controller: _controller,
          minLines: 4,
          maxLines: 12,
          autocorrect: false,
          enableSuggestions: false,
          style: const TextStyle(fontFamily: kMonoFontFamily, fontSize: 12),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '.invoice-widget--total { … }',
          ),
          onChanged: widget.vm.setCustomCss,
        ),
      ],
    );
  }
}

/// A short fixed list as a one-line dropdown.
class _CompactDropdown<T> extends StatelessWidget {
  const _CompactDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return DropdownButtonHideUnderline(
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r1),
        ),
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          style: DefaultTextStyle.of(
            context,
          ).style.copyWith(fontSize: 13, color: tokens.ink),
          items: [
            for (final e in items.entries)
              DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ── Block ───────────────────────────────────────────────────────────────

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
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        0,
        InSpacing.lg(context),
        InSpacing.lg(context),
      ),
      children: [
        // The block's name and what can be done to it, where they are always
        // in reach — Delete used to sit under the last property, a long
        // scroll down for a table.
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
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 18),
              tooltip: context.tr('duplicate'),
              onPressed: () => vm.duplicateBlock(block.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              tooltip: context.tr('delete'),
              onPressed: () => deleteBlockWithUndo(context, vm, block.id),
            ),
            Builder(
              builder: (buttonContext) => IconButton(
                icon: const Icon(Icons.more_vert, size: 18),
                tooltip: context.tr('more_actions'),
                onPressed: () {
                  final box = buttonContext.findRenderObject()! as RenderBox;
                  showBlockMenu(
                    buttonContext,
                    vm,
                    block.id,
                    globalPosition: box.localToGlobal(
                      box.size.bottomLeft(Offset.zero),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        SizedBox(height: InSpacing.sm),
        _typeSpecificEditor(vm, block) ??
            (block.properties.containsKey('content')
                ? _ContentEditor(
                    key: ValueKey('${block.id}#${vm.templateEpoch}'),
                    vm: vm,
                    block: block,
                  )
                : const SizedBox.shrink()),
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
  // Some editors hold bare `TextFormField(initialValue:)` fields (info title)
  // whose `initialValue` is ignored on rebuild; without a changing key the
  // State is reused and they'd show (and on edit corrupt) the
  // previously-selected block's values.
  //
  // And on the template's epoch, for the same reason: after an undo, an
  // import or a new layout the block's values are different though its id is
  // not, and an editor left alone went on showing the old text — which the
  // next keystroke wrote back over what had just been restored.
  final key = ValueKey('${block.id}#${vm.templateEpoch}');
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
  const _ContentEditor({super.key, required this.vm, required this.block});
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
