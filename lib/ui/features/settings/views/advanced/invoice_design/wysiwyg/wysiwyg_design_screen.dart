import 'dart:convert';
import 'dart:io' show File;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/shortcut_hint_controller.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/services/live_design_service.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/fab_clearance.dart';
import 'package:admin/ui/core/utils/platform_modifier.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/focus_owner_keeper.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/shortcut_hint_scope.dart';
import 'package:admin/ui/features/settings/view_models/design_edit_view_model.dart'
    show kBlankDesignBody;
import 'package:admin/ui/features/settings/views/advanced/invoice_design/import_design_json_dialog.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_actions.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/company_context.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/design_suggestions.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/designer_pane.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/document_source.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/starter_gallery.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/use_design_dialog.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/wysiwyg_canvas.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/mobile/mobile_reorder_view.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/palette/component_palette.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/preview/wysiwyg_preview_sheet.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_panel.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:admin/utils/formatting.dart';

/// The visual invoice designer — sibling to the HTML editor
/// [DesignEditScreen]. Opened from the Custom Designs list: "New design →
/// Visual designer", and any design that has blocks.
///
/// Four layouts, chosen from the width of the **pane** the designer is laid
/// out in — not the window's ([DesignerPane], `docs/invoice-designer.md`):
///   - **≥ 1280:** palette · canvas · property panel.
///   - **900–1279:** canvas · property panel; the palette behind "Add block".
///   - **560–899:** the canvas alone; the palette is a sheet and the panel a
///     drawer that opens with a selection.
///   - **< 560:** the outline ([MobileReorderView]) — rows as cards.
class WysiwygDesignScreen extends StatefulWidget {
  const WysiwygDesignScreen({this.existingId, this.seedFrom, super.key});

  final String? existingId;

  /// A design to start a new one from — a starter layout, or one being
  /// copied. Ignored when [existingId] is set.
  final Design? seedFrom;

  @override
  State<WysiwygDesignScreen> createState() => _WysiwygDesignScreenState();
}

class _WysiwygDesignScreenState extends State<WysiwygDesignScreen>
    with FormatterHostMixin {
  /// The names already taken, read once — a new design needs a default name
  /// the server's per-company `unique` rule will accept.
  Future<Set<String>>? _takenNames;

  final DesignerChrome _chrome = DesignerChrome();
  LiveDesignService? _previewService;

  /// "Use this design for…" is offered unprompted once, after the first save.
  bool _offeredUse = false;

  DesignerDocumentController? _document;

  @override
  void dispose() {
    _chrome.dispose();
    _document?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (companyId.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_takenNames == null) {
      final existingId = widget.existingId;
      _takenNames = existingId != null
          // Open on the server's copy, not on whatever this device last
          // kept (see `DesignRepository.refreshByIds`). Best effort, and
          // bounded: offline the builder opens on the local row.
          ? services.designs
                .refreshByIds(companyId: companyId, ids: [existingId])
                .timeout(const Duration(seconds: 4), onTimeout: () {})
                .catchError((Object _) {})
                .then((_) => const <String>{})
          // Archived and deleted designs keep their names as far as the
          // server's uniqueness rule goes, so they are taken too.
          : services.designs
                .knownNames(companyId: companyId)
                .catchError((Object _) => <String>{});
      loadFormatter(services, companyId);
    }
    // Watch the active company so the VM can seed DocumentSettings from
    // `company.settings.*` (matches React's `createDefaultDocumentSettings`).
    //
    // The `LayoutBuilder` measures the pane this route was given — the window
    // less the app's sidebar — for the toolbar and the workspace to lay
    // themselves out by.
    return LayoutBuilder(
      builder: (context, constraints) => DesignerPane(
        width: constraints.maxWidth,
        child: FutureBuilder<Set<String>>(
          future: _takenNames,
          builder: (context, names) => StreamBuilder<Company?>(
            stream: services.company.watchCompany(companyId),
            builder: (context, snapshot) {
              final company = snapshot.data;
              if (company == null || !names.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              return _buildScaffold(
                context,
                services,
                companyId,
                company,
                names.data!,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    Services services,
    String companyId,
    Company company,
    Set<String> takenNames,
  ) {
    final repo = services.designs;
    // Phase 3a: Pro gate. Save disabled and a banner shown for free users.
    final isPro = services.auth.session.value?.hasProAccess ?? false;
    final defaultName = uniqueDesignName(
      context.tr('visual_design'),
      takenNames,
    );
    final settings = company.settings;
    // The page shows the company's own letterhead, not a made-up one.
    // The company's letterhead over the made-up document; the workspace
    // lays one of the company's own invoices over that when one is chosen.
    final sample = designerSampleFor(settings);
    final document = _document ??= DesignerDocumentController(
      loadRecent: () =>
          services.invoices.watchRecent(companyId: companyId, limit: 5).first,
      loadClient: (id) async {
        Future<Client?> local() =>
            services.clients.watch(companyId: companyId, id: id).first;
        final known = await local();
        if (known != null) return known;
        // Lists load a page at a time, so an invoice can be here without
        // its client — and the page then drew an empty Client block where
        // the PDF prints a name and an address. Ask for it, once.
        await services.clients.refreshByIds(companyId: companyId, ids: [id]);
        return local();
      },
    )..load();
    final previewService = _previewService ??= LiveDesignService(
      services.apiClient,
    );
    Future<void> useDesign(
      BuildContext context,
      WysiwygDesignViewModel vm,
      String designId,
    ) async {
      await showUseDesignDialog(
        context,
        services: services,
        companyId: companyId,
        designId: designId,
        entities: vm.draft.entities,
      );
      // The dialog waits on the outbox; the create may have landed by now.
      await vm.refreshSavedId();
    }

    final hasLogo = companyHasLogo(company);
    Widget toolbar(
      BuildContext context,
      WysiwygDesignViewModel vm, {
      required bool spread,
    }) => DesignerToolbar(
      vm: vm,
      chrome: _chrome,
      spread: spread,
      sample: sample,
      companyHasLogo: hasLogo,
      // What uses it can only be said of a design the server knows — a
      // temp id equals nothing in the settings — so until its create lands
      // there is no indicator, though the menu's entry is there (and says
      // the design is still being saved).
      usedFor: vm.savedDesignId == null
          ? null
          : entitiesUsingDesign(settings, vm.savedDesignId),
      onUseDesign: !vm.hasBeenSaved
          ? null
          : () => useDesign(context, vm, vm.savedOrPendingDesignId!),
    );
    return SettingsEntityEditScaffold<Design, WysiwygDesignViewModel>(
      existingId: widget.existingId,
      backRoute: '/settings/invoice_design/custom_designs',
      createTitleKey: 'new_design',
      editTitleKey: 'edit_design',
      wireName: 'design',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete: (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) => WysiwygDesignViewModel(
        repo: repo,
        companyId: companyId,
        existing: existing,
        // The starter is the initial draft, not an edit applied after the
        // first frame: an untouched design must not ask to be discarded.
        seed: widget.seedFrom,
        defaultName: defaultName,
        // Phase 1.5 #6: seed DocumentSettings from the active company so a
        // brand-new design starts with the user's preferred page size,
        // fonts, etc.
        companySettings: settings,
        brandColors: designerBrandColors(settings),
        customFieldLabels: {
          for (final slot in company.customFields.keys)
            slot: company.customFieldLabel(slot),
        },
        sync: services.sync,
        connectivity: services.connectivity,
      ),
      isArchivedOf: (d) => d.archivedAt != null,
      isDeletedOf: (d) => d.isDeleted,
      canSave: (vm) =>
          isPro &&
          !vm.isSaving &&
          vm.hasUnsavedWork &&
          vm.blocks.isNotEmpty &&
          vm.draft.name.trim().isNotEmpty,
      // An editor, not a form: Save keeps the builder open.
      stayOpenAfterSave: true,
      savedMessageKey: 'saved_design',
      saveDisabledReason: (context, vm) {
        // A design with no blocks would print as a blank page.
        if (vm.blocks.isEmpty) return context.tr('add_a_block_to_save');
        if (vm.draft.name.trim().isEmpty) {
          return context.tr('name_design_to_save');
        }
        return null;
      },
      guardUnsavedChanges: true,
      // Phase 1.5 #8: actually clear the draft on discard so the
      // unsaved-changes guard doesn't keep firing on every navigation.
      onDiscard: (vm) => vm.resetToEmpty(settings),
      // One toolbar: the name and the tools share the app bar with Save.
      titleBuilder: (context, vm) => DesignNameField(vm: vm),
      actionsBuilder: (context, vm) =>
          DesignerPane.tierOf(context) == DesignerTier.outline
          ? const []
          : [toolbar(context, vm, spread: false)],
      // The first save of a design nothing uses yet offers, on its "Saved"
      // toast, to put it to use — the journey used to end at "Saved", with
      // the design waiting to be picked on another screen. An offer, not a
      // dialog: a save should not interrupt the work it saves.
      savedActionBuilder: (toastContext, vm, saved) {
        if (_offeredUse ||
            vm.lastSaveWasOptimistic ||
            entitiesUsingDesign(settings, saved.id).isNotEmpty) {
          return null;
        }
        _offeredUse = true;
        return NotifyAction(toastContext.tr('use_this_design'), () {
          if (mounted) useDesign(context, vm, saved.id);
        });
      },
      customBodyBuilder: (context, vm) => DesignerWorkspace(
        vm: vm,
        isPro: isPro,
        chrome: _chrome,
        sample: sample,
        document: document,
        formatter: formatter,
        toolbarBuilder: (context) => toolbar(context, vm, spread: true),
        previewBuilder: (context) => ListenableBuilder(
          listenable: vm,
          builder: (_, _) => ListenableBuilder(
            listenable: document,
            builder: (_, _) => WysiwygPreviewSheet(
              service: previewService,
              design: vm.draft,
              isPro: isPro,
              embedded: true,
              // The invoice on the page is the invoice in the preview.
              entityId: document.invoice?.id,
              documentPicker: DesignerDocumentButton(
                controller: document,
                formatter: formatter,
              ),
              initialEntityType: _chrome.previewEntityType,
              onEntityTypeChanged: (t) => _chrome.previewEntityType = t,
            ),
          ),
        ),
      ),
    );
  }
}

/// [base], or the first of "[base] 2", "[base] 3"… that [taken] does not
/// hold. Compared trimmed and case-insensitively, as the server's
/// per-company `unique:designs,name` rule does on a default collation.
@visibleForTesting
String uniqueDesignName(String base, Iterable<String> taken) {
  final used = {for (final name in taken) name.trim().toLowerCase()};
  if (!used.contains(base.trim().toLowerCase())) return base;
  for (var n = 2; ; n++) {
    final candidate = '$base $n';
    if (!used.contains(candidate.toLowerCase())) return candidate;
  }
}

/// The bits of designer state that are neither the design nor one widget's:
/// the toolbar (in the app bar) and the workspace (in the body) both act on
/// them.
class DesignerChrome extends ChangeNotifier {
  bool _preview = false;
  bool _pageSettings = false;

  /// The document type the preview was last on, so going back to it does
  /// not start again on the first. Not listened to: it is read when the
  /// preview opens.
  String? previewEntityType;

  /// Showing the server's PDF in place of the canvas.
  bool get preview => _preview;
  set preview(bool value) {
    if (_preview == value) return;
    _preview = value;
    notifyListeners();
  }

  /// The property panel is open on the page's settings — only meaningful
  /// where the panel is a drawer rather than a fixed column.
  bool get pageSettings => _pageSettings;
  set pageSettings(bool value) {
    if (_pageSettings == value) return;
    _pageSettings = value;
    notifyListeners();
  }
}

/// Everything below the screen's app bar: palette, canvas and property
/// panel, plus the keyboard layer over them. Public so it can be pumped
/// without the screen's `Services`.
class DesignerWorkspace extends StatefulWidget {
  const DesignerWorkspace({
    super.key,
    required this.vm,
    required this.isPro,
    this.chrome,
    this.sample,
    this.formatter,
    this.previewBuilder,
    this.toolbarBuilder,
    this.document,
  });

  final WysiwygDesignViewModel vm;
  final bool isPro;

  /// Shared with the toolbar. A workspace pumped on its own makes one.
  final DesignerChrome? chrome;

  final DesignerSampleData? sample;
  final Formatter? formatter;

  /// Builds the server preview shown in place of the canvas.
  final WidgetBuilder? previewBuilder;

  /// Builds the phone's tool row. A workspace pumped on its own gets the
  /// plain toolbar.
  final WidgetBuilder? toolbarBuilder;

  /// Which document the page is filled in with. Null — a workspace pumped
  /// on its own — shows [sample] as it is.
  final DesignerDocumentController? document;

  @override
  State<DesignerWorkspace> createState() => _DesignerWorkspaceState();
}

class _DesignerWorkspaceState extends State<DesignerWorkspace> {
  /// Phase 3c: dismissed by tapping "Start visual design" in the Twig
  /// coexistence banner. Stays dismissed for the session.
  bool _twigBannerDismissed = false;
  bool _gridNoteDismissed = false;

  DesignerChrome? _ownChrome;
  DesignerChrome get _chrome =>
      widget.chrome ?? (_ownChrome ??= DesignerChrome());

  /// The workspace's resting focus owner. Its `Shortcuts` are consulted only
  /// while primary focus is at or below it, and `Focus(autofocus: true)`
  /// cannot keep it there (CLAUDE.md § Design system — keyboard): it is
  /// applied once, so after the first dialog or a field losing focus every
  /// shortcut here went dead. The keeper puts focus back when it escapes
  /// upward; a press on the canvas takes it from a property field.
  final FocusNode _focus = FocusNode(debugLabel: 'designer workspace');

  WysiwygDesignViewModel get vm => widget.vm;

  @override
  void dispose() {
    _ownChrome?.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Whether the loaded design has custom Twig in `body` (anything not the
  /// blank scaffold) AND no WYSIWYG blocks yet. Builder save would
  /// overwrite the Twig last-writer-wins, so warn before the user starts
  /// editing here.
  bool _hasCustomTwig() {
    final t = vm.draft.template;
    if (t.blocks.isNotEmpty) return false;
    final body = t.body.trim();
    if (body.isEmpty) return false;
    if (body == kBlankDesignBody.trim()) return false;
    return true;
  }

  void _onSelected(void Function(String id) action) {
    final id = vm.selectedBlockId;
    if (id != null) action(id);
  }

  /// The keys, and what they do. Two kinds, with two different gates.
  ///
  /// **Chords** (⌘Z, ⌘⇧Z, ⌘D) are [_Key]s: they work wherever focus is in
  /// the workspace, standing down only for a text field, which has an undo
  /// of its own.
  ///
  /// **Canvas keys** — everything else — are [_CanvasKey]s, and act only
  /// while the workspace's own node holds focus, i.e. after a press on the
  /// page. A bare key is also how every other control is worked: with a
  /// plain guard, Tab onto a stepper and Enter was swallowed, the arrows
  /// were taken from a slider, and Backspace **deleted the selected
  /// block**; in Preview, Delete removed a block that was not on screen.
  ///
  /// Arrows move the *selection*, never the content — a bare arrow that
  /// moved a block would fight the page's own scrolling. Alt+↑/↓ moves the
  /// block's row; Shift+←/→ changes its width; Alt+Shift+←/→ moves it along
  /// its row. Plain Alt+←/→ is deliberately not here: it is the app's Back
  /// and Forward (`scaffold_with_nav.dart`), and this map is consulted first.
  static const Map<ShortcutActivator, Intent> _keys = {
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true): _Key(_Do.undo),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true): _Key(_Do.undo),
    SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true): _Key(
      _Do.redo,
    ),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): _Key(
      _Do.redo,
    ),
    SingleActivator(LogicalKeyboardKey.keyY, control: true): _Key(_Do.redo),
    SingleActivator(LogicalKeyboardKey.keyD, meta: true): _Key(_Do.duplicate),
    SingleActivator(LogicalKeyboardKey.keyD, control: true): _Key(
      _Do.duplicate,
    ),
    SingleActivator(LogicalKeyboardKey.arrowLeft): _CanvasKey(_Do.selectLeft),
    SingleActivator(LogicalKeyboardKey.arrowRight): _CanvasKey(_Do.selectRight),
    SingleActivator(LogicalKeyboardKey.arrowUp): _CanvasKey(_Do.selectUp),
    SingleActivator(LogicalKeyboardKey.arrowDown): _CanvasKey(_Do.selectDown),
    SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true, shift: true):
        _CanvasKey(_Do.moveLeft),
    SingleActivator(LogicalKeyboardKey.arrowRight, alt: true, shift: true):
        _CanvasKey(_Do.moveRight),
    SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): _CanvasKey(
      _Do.moveUp,
    ),
    SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): _CanvasKey(
      _Do.moveDown,
    ),
    SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): _CanvasKey(
      _Do.narrower,
    ),
    SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): _CanvasKey(
      _Do.wider,
    ),
    SingleActivator(LogicalKeyboardKey.delete): _CanvasKey(_Do.delete),
    SingleActivator(LogicalKeyboardKey.backspace): _CanvasKey(_Do.delete),
    SingleActivator(LogicalKeyboardKey.escape): _CanvasKey(_Do.deselect),
    SingleActivator(LogicalKeyboardKey.enter): _CanvasKey(_Do.edit),
  };

  /// Whether the canvas keys act: the page is on screen, and it — not a
  /// control in the panel or the toolbar — is what the keyboard is on.
  bool get _canvasHasKeys => _focus.hasPrimaryFocus && !_chrome.preview;

  void _handle(_Do action) {
    switch (action) {
      case _Do.undo:
        if (vm.canUndo) vm.undo();
      case _Do.redo:
        if (vm.canRedo) vm.redo();
      case _Do.duplicate:
        _onSelected(vm.duplicateBlock);
      case _Do.selectLeft:
        vm.selectNeighbour(dx: -1);
      case _Do.selectRight:
        vm.selectNeighbour(dx: 1);
      case _Do.selectUp:
        vm.selectNeighbour(dy: -1);
      case _Do.selectDown:
        vm.selectNeighbour(dy: 1);
      case _Do.moveLeft:
        _onSelected((id) => vm.moveBlockWithinRow(id, -1));
      case _Do.moveRight:
        _onSelected((id) => vm.moveBlockWithinRow(id, 1));
      case _Do.moveUp:
        _onSelected((id) => vm.moveBlockVertically(id, -1));
      case _Do.moveDown:
        _onSelected((id) => vm.moveBlockVertically(id, 1));
      case _Do.narrower:
        _onSelected((id) => vm.nudgeWidth(id, -1));
      case _Do.wider:
        _onSelected((id) => vm.nudgeWidth(id, 1));
      case _Do.delete:
        _onSelected((id) => deleteBlockWithUndo(context, vm, id));
      case _Do.deselect:
        vm.selectBlock(null);
        _chrome.pageSettings = false;
      case _Do.edit:
        if (vm.selectedBlockId != null) vm.requestContentFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mod = platformModifierLabel();
    // Every action here is a [GuardedShortcutAction]: disabled — not merely a
    // no-op — while a text field has focus, so the key falls through to it.
    // The canvas keys are disabled more widely still (see [_keys]).
    // This `Shortcuts` sits between the property panel's fields and Flutter's
    // own text-editing shortcuts; unguarded, an arrow key typed in a field
    // moved the selected block instead of the caret, and ⌘Z undid a canvas
    // change instead of the typing.
    return ShortcutHintScope(
      hints: [
        ShortcutHint(keys: [mod, 'Z'], labelKey: 'undo'),
        ShortcutHint(keys: [mod, '⇧', 'Z'], labelKey: 'redo'),
        ShortcutHint(keys: [mod, 'D'], labelKey: 'duplicate'),
      ],
      child: Shortcuts(
        shortcuts: _keys,
        child: Actions(
          actions: <Type, Action<Intent>>{
            _Key: GuardedShortcutAction<_Key>(
              onInvoke: (intent) {
                _handle(intent.action);
                return null;
              },
            ),
            _CanvasKey: _CanvasKeyAction(
              isActive: () => _canvasHasKeys,
              onInvoke: (intent) {
                _handle(intent.action);
                return null;
              },
            ),
          },
          child: FocusOwnerKeeper(
            node: _focus,
            enabled: TickerMode.valuesOf(context).enabled,
            child: Focus(
              focusNode: _focus,
              child: ListenableBuilder(
                listenable: Listenable.merge([vm, _chrome]),
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) =>
                      _content(context, constraints.maxWidth),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Everything under the keyboard layer, for a pane [width] wide — the
  /// workspace's own width, published as [DesignerPane] so the phone's
  /// toolbar row measures the same thing.
  Widget _content(BuildContext context, double width) {
    final phone = designerTierFor(width) == DesignerTier.outline;
    return DesignerPane(
      width: width,
      child: Builder(
        builder: (context) {
          return Column(
            children: [
              if (!widget.isPro) const _ProGateBanner(),
              if (!_twigBannerDismissed && _hasCustomTwig())
                _TwigCoexistenceBanner(
                  onStartVisual: () =>
                      setState(() => _twigBannerDismissed = true),
                  onStayInTwig: () => Navigator.of(context).maybePop(),
                ),
              if (!_gridNoteDismissed && vm.openedWithFreeGridLayout)
                _FreeGridNote(
                  onDismiss: () => setState(() => _gridNoteDismissed = true),
                ),
              // A phone's app bar has room for the name and Save
              // only; the tools get a row of their own.
              if (phone)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: context.inTheme.border,
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: InSpacing.sm),
                    child:
                        widget.toolbarBuilder?.call(context) ??
                        DesignerToolbar(vm: vm, chrome: _chrome, spread: true),
                  ),
                ),
              Expanded(child: _body(context, width)),
            ],
          );
        },
      ),
    );
  }

  /// The layout, under the document it is filled in with — the page and the
  /// panel's example values read the same one.
  Widget _body(BuildContext context, double width) {
    final base = widget.sample ?? DesignerSampleData.fallback;
    final document = widget.document;
    Widget under(DesignerSampleData data) => DesignerRenderScope(
      formatter: widget.formatter,
      sample: data,
      customFieldLabels: vm.customFieldLabels,
      child: Builder(builder: (context) => _layout(context, width, data)),
    );
    if (document == null) return under(base);
    return ListenableBuilder(
      listenable: document,
      builder: (_, _) =>
          under(document.documentOver(base, formatter: widget.formatter)),
    );
  }

  Widget _layout(BuildContext context, double width, DesignerSampleData data) {
    final tier = designerTierFor(width);
    final preview = _chrome.preview && widget.previewBuilder != null
        ? widget.previewBuilder!(context)
        : null;
    if (tier == DesignerTier.outline) {
      if (preview != null) return preview;
      return MobileReorderView(vm: vm, onPageSettings: _showPageSettingsSheet);
    }

    final document = widget.document;
    // Under the page: which document it is filled in with. Outside the
    // canvas's own stack, so the button floating over the canvas can never
    // sit on it.
    final showBar =
        preview == null && document != null && document.recent.isNotEmpty;
    // With no bar below, the canvas runs to the bottom of the screen.
    final safeBottom = showBar ? 0.0 : MediaQuery.paddingOf(context).bottom;
    // Only the widest layout has the palette on screen; the others reach it
    // through a button floating over the canvas's corner.
    final showAdd = preview == null && tier != DesignerTier.full;
    final panelOpen =
        tier == DesignerTier.canvas &&
        preview == null &&
        (vm.panelMode == PropertyPanelMode.block || _chrome.pageSettings);

    final page =
        preview ??
        // A press on the canvas takes focus back for the workspace's keys.
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _focus.requestFocus(),
          child: WysiwygCanvas(
            vm: vm,
            sample: data,
            formatter: widget.formatter,
            // A floating button is a bottom inset the scrollable under it
            // has to pay, or the last row's end can never be scrolled clear.
            bottomInset:
                (showAdd ? kFabClearance + InSpacing.sm : 0) + safeBottom,
          ),
        );

    final area = Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: page),
              if (showAdd)
                Positioned(
                  left: InSpacing.lg(context),
                  bottom: InSpacing.lg(context) + safeBottom,
                  child: FloatingActionButton.extended(
                    onPressed: () => showDesignerPaletteSheet(context, vm),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr('add_block')),
                  ),
                ),
              if (panelOpen)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: Material(
                    elevation: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: context.tr('close'),
                          onPressed: () {
                            vm.selectBlock(null);
                            _chrome.pageSettings = false;
                          },
                        ),
                        Expanded(
                          child: PropertyPanel(
                            vm: vm,
                            // The drawer is open for a selection or for the
                            // page: say "page" before the selection goes,
                            // or the tab that says Page closes the drawer.
                            onShowPage: () {
                              _chrome.pageSettings = true;
                              vm.selectBlock(null);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (showBar)
          DesignerDocumentBar(
            controller: document,
            formatter: widget.formatter,
          ),
      ],
    );

    return switch (tier) {
      DesignerTier.full => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (preview == null) ...[
            ComponentPalette(vm: vm),
            const VerticalDivider(width: 1),
          ],
          Expanded(child: area),
          const VerticalDivider(width: 1),
          PropertyPanel(vm: vm),
        ],
      ),
      DesignerTier.docked => Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: area),
          const VerticalDivider(width: 1),
          PropertyPanel(vm: vm),
        ],
      ),
      DesignerTier.canvas || DesignerTier.outline => area,
    };
  }

  void _showPageSettingsSheet() => showDesignerPageSettingsSheet(context, vm);
}

enum _Do {
  undo,
  redo,
  duplicate,
  selectLeft,
  selectRight,
  selectUp,
  selectDown,
  moveLeft,
  moveRight,
  moveUp,
  moveDown,
  narrower,
  wider,
  delete,
  deselect,
  edit,
}

class _Key extends Intent {
  const _Key(this.action);
  final _Do action;
}

/// A key that belongs to the page: see `_DesignerWorkspaceState._keys`.
class _CanvasKey extends Intent {
  const _CanvasKey(this.action);
  final _Do action;
}

/// Enabled only while [isActive] — and, like every shortcut here, never
/// while a text field has focus. Disabled is not a no-op: the key carries on
/// to whatever control does have focus.
class _CanvasKeyAction extends GuardedShortcutAction<_CanvasKey> {
  _CanvasKeyAction({required this.isActive, required super.onInvoke});

  final bool Function() isActive;

  @override
  bool isEnabled(_CanvasKey intent) => isActive() && super.isEnabled(intent);

  @override
  bool consumesKey(_CanvasKey intent) =>
      isActive() && super.consumesKey(intent);
}

/// The page's settings as a sheet, for the phone. Deselecting first is what
/// puts the panel in its page mode.
void showDesignerPageSettingsSheet(
  BuildContext context,
  WysiwygDesignViewModel vm,
) {
  vm.selectBlock(null);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final insets = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: SizedBox(
          height: (MediaQuery.sizeOf(ctx).height - insets) * 0.8,
          child: ListenableBuilder(
            listenable: vm,
            builder: (_, _) => PropertyPanel(vm: vm),
          ),
        ),
      );
    },
  );
}

/// One sentence for a design saved on the old free grid: it opens looking
/// different — blocks that sat side by side at different heights are now one
/// above the other — and that is how it has always printed.
class _FreeGridNote extends StatelessWidget {
  const _FreeGridNote({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      width: double.infinity,
      color: tokens.surfaceAlt,
      padding: EdgeInsets.only(
        left: InSpacing.lg(context),
        right: InSpacing.sm,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: tokens.ink3),
          SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              context.tr('free_grid_note'),
              style: TextStyle(color: tokens.ink2, fontSize: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: context.tr('dismiss'),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

/// Phase 3c: warns the user when this design already carries non-default
/// Twig code (legacy custom design). Saving from the visual builder would
/// overwrite the whole template last-writer-wins, so we surface the
/// choice up front: stay in the Twig editor or start the visual design.
class _TwigCoexistenceBanner extends StatelessWidget {
  const _TwigCoexistenceBanner({
    required this.onStartVisual,
    required this.onStayInTwig,
  });

  final VoidCallback onStartVisual;
  final VoidCallback onStayInTwig;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      width: double.infinity,
      color: tokens.partialSoft,
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.md(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                size: 18,
                color: tokens.partial,
              ),
              SizedBox(width: InSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('twig_coexistence_banner'),
                  style: TextStyle(color: tokens.ink, fontSize: 13),
                ),
              ),
            ],
          ),
          SizedBox(height: InSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: onStayInTwig,
                child: Text(context.tr('stay_in_twig_editor')),
              ),
              SizedBox(width: InSpacing.md(context)),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                onPressed: onStartVisual,
                child: Text(context.tr('start_visual_design')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Phase 3a: shown to free users above the workspace. The editor stays
/// fully interactive (so they can "Try it") but Save is disabled at the
/// scaffold level — the upgrade nudge is honest about the gate.
class _ProGateBanner extends StatelessWidget {
  const _ProGateBanner();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      width: double.infinity,
      color: tokens.accentSoft,
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.md(context),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_outlined, size: 18, color: tokens.ink),
          SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              context.tr('pro_required_to_save_visual_designer'),
              style: TextStyle(fontSize: 13, color: tokens.ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Phase 8e + 8k: export / import menu items.
enum _FileAction { useDesign, replaceLayout, download, copy, importJson }

/// The designer's tools: undo and redo, Design ⇄ Preview, the page settings
/// (where the panel is not always on screen) and the import / export menu.
///
/// It sits in the app bar beside Save, so the screen has one toolbar; a
/// phone's app bar has no room, and it gets a row of its own ([spread]).
class DesignerToolbar extends StatelessWidget {
  const DesignerToolbar({
    super.key,
    required this.vm,
    required this.chrome,
    this.spread = false,
    this.companyHasLogo = true,
    this.usedFor,
    this.onUseDesign,
    this.sample,
  });

  final WysiwygDesignViewModel vm;
  final DesignerChrome chrome;

  /// For the logo suggestion.
  final bool companyHasLogo;

  /// The document types this design is the default for. Null for a design
  /// that has not been saved, which cannot be used yet.
  final List<String>? usedFor;

  /// Opens "Use this design for…". Null hides the entry.
  final VoidCallback? onUseDesign;

  /// The document the starter gallery's thumbnails are filled from.
  final DesignerSampleData? sample;

  /// Fill the width, with the editing tools at the start and the rest at the
  /// end — the phone's row. Otherwise the tools pack together.
  final bool spread;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([vm, chrome]),
      builder: (context, _) {
        // The pane's width, not the window's — see [DesignerPane].
        final width = DesignerPane.widthOf(context);
        final tier = designerTierFor(width);
        final panelDocked =
            tier == DesignerTier.docked || tier == DesignerTier.full;
        final mod = platformModifierLabel();
        final preview = chrome.preview;
        return Row(
          mainAxisSize: spread ? MainAxisSize.max : MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.undo_outlined),
              tooltip: '${context.tr('undo')} ($mod Z)',
              onPressed: vm.canUndo && !preview ? vm.undo : null,
            ),
            IconButton(
              icon: const Icon(Icons.redo_outlined),
              tooltip: '${context.tr('redo')} ($mod ⇧ Z)',
              onPressed: vm.canRedo && !preview ? vm.redo : null,
            ),
            if (!preview)
              _SuggestionsButton(vm: vm, companyHasLogo: companyHasLogo),
            if (usedFor != null &&
                onUseDesign != null &&
                tier == DesignerTier.full)
              _UsageButton(usedFor: usedFor!, onPressed: onUseDesign!),
            if (spread) const Spacer() else SizedBox(width: InSpacing.sm),
            if (panelDocked)
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(
                      Icons.dashboard_customize_outlined,
                      size: 16,
                    ),
                    label: Text(context.tr('design_mode')),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.visibility_outlined, size: 16),
                    label: Text(context.tr('preview')),
                    enabled: vm.blocks.isNotEmpty,
                  ),
                ],
                selected: {preview},
                onSelectionChanged: (s) => chrome.preview = s.first,
              )
            else
              IconButton(
                isSelected: preview,
                icon: const Icon(Icons.visibility_outlined),
                selectedIcon: const Icon(Icons.visibility),
                tooltip: context.tr('preview'),
                onPressed: vm.blocks.isEmpty && !preview
                    ? null
                    : () => chrome.preview = !preview,
              ),
            // Where the property panel is not docked it is not always on
            // screen, which left the page settings with no way in at all.
            if (!panelDocked)
              IconButton(
                isSelected: chrome.pageSettings,
                icon: const Icon(Icons.description_outlined),
                tooltip: context.tr('document_settings'),
                onPressed: preview
                    ? null
                    : () {
                        if (tier == DesignerTier.outline) {
                          showDesignerPageSettingsSheet(context, vm);
                        } else {
                          vm.selectBlock(null);
                          chrome.pageSettings = !chrome.pageSettings;
                        }
                      },
              ),
            PopupMenuButton<_FileAction>(
              tooltip: context.tr('more_actions'),
              // Always enabled — Import doesn't need an existing draft;
              // Export items disable themselves inside the menu when
              // blocks are empty.
              icon: const Icon(Icons.more_vert),
              onSelected: (action) => switch (action) {
                _FileAction.useDesign => onUseDesign?.call(),
                _FileAction.replaceLayout => _replaceLayout(context),
                _FileAction.copy => _copyJson(context),
                _FileAction.download => _downloadJson(context),
                _FileAction.importJson => _importJson(context),
              },
              itemBuilder: (ctx) => [
                if (onUseDesign != null)
                  _fileItem(
                    ctx,
                    _FileAction.useDesign,
                    Icons.task_alt_outlined,
                    'use_this_design',
                  ),
                _fileItem(
                  ctx,
                  _FileAction.replaceLayout,
                  Icons.auto_awesome_mosaic_outlined,
                  'replace_layout',
                ),
                const PopupMenuDivider(),
                _fileItem(
                  ctx,
                  _FileAction.download,
                  Icons.save_alt_outlined,
                  'download_json',
                  enabled: vm.blocks.isNotEmpty,
                ),
                _fileItem(
                  ctx,
                  _FileAction.copy,
                  Icons.content_copy_outlined,
                  'copy_to_clipboard',
                  enabled: vm.blocks.isNotEmpty,
                ),
                const PopupMenuDivider(),
                _fileItem(
                  ctx,
                  _FileAction.importJson,
                  Icons.file_upload_outlined,
                  'import_design',
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  PopupMenuItem<_FileAction> _fileItem(
    BuildContext context,
    _FileAction value,
    IconData icon,
    String labelKey, {
    bool enabled = true,
  }) => PopupMenuItem(
    value: value,
    enabled: enabled,
    child: Row(
      children: [
        Icon(icon, size: 16),
        SizedBox(width: InSpacing.sm),
        // A menu is as wide as the screen lets it be, not as wide as its
        // longest translation.
        Flexible(
          child: Text(context.tr(labelKey), overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );

  /// Swap the page's blocks for a starter layout. Confirmed when there is
  /// something to lose — though it is one undo away.
  Future<void> _replaceLayout(BuildContext context) async {
    final layout = await showStarterGallery(
      context,
      sample: sample,
      accent: vm.brandColors.firstOrNull,
      titleKey: 'replace_layout',
    );
    if (layout == null || !context.mounted) return;
    if (vm.blocks.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('replace_layout')),
          content: Text(ctx.tr('replace_layout_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.tr('cancel')),
            ),
            PrimaryDialogAction(
              label: ctx.tr('replace'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    vm.replaceLayout(layout);
  }

  String _encode() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(vm.draft.toApiJson(preserveTempId: false));
  }

  Future<void> _copyJson(BuildContext context) {
    // Name the design rather than the JSON blob it serializes to; an unsaved
    // draft has no name yet, so fall back to the generic noun.
    final name = vm.draft.name;
    return copyToClipboard(
      context,
      _encode(),
      label: name.isNotEmpty ? name : context.tr('design'),
    );
  }

  /// Phase 8e: write the design JSON to a file the user picks. Filename
  /// `invoice-design-{epoch-ms}.json` mirrors React's
  /// `InvoiceBuilder.tsx` Blob anchor. `FilePicker.saveFile` handles
  /// both desktop (path returned, write defensively) and web (the
  /// package shim downloads via a Blob anchor when `bytes:` is passed).
  Future<void> _downloadJson(BuildContext context) async {
    final toasts = Notify.capture(context);
    final tr = context.tr;
    final bytes = Uint8List.fromList(utf8.encode(_encode()));
    // lint: allow-raw-file-name — the only interpolation is an epoch int.
    final name = 'invoice-design-${DateTime.now().millisecondsSinceEpoch}.json';
    try {
      final path = await FilePicker.saveFile(fileName: name, bytes: bytes);
      if (path == null) return;
      // Desktop returns a path without writing; web writes via `bytes`
      // and may return a synthesized URL. Native: write defensively.
      if (!kIsWeb) {
        final file = File(path);
        if (!await file.exists() || await file.length() == 0) {
          await file.writeAsBytes(bytes);
        }
      }
      toasts?.success(tr('exported'));
    } catch (_) {
      toasts?.error(tr('an_error_occurred'));
    }
  }

  /// Phase 8k: import a design JSON payload into the **current** draft
  /// (replaces blocks + documentSettings). When the draft is non-empty
  /// we confirm first since this replaces the layout — it is one undo step.
  Future<void> _importJson(BuildContext context) async {
    if (vm.blocks.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('import_design')),
          content: Text(ctx.tr('import_design_overwrite_confirm')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.tr('cancel')),
            ),
            PrimaryDialogAction(
              label: ctx.tr('replace'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    final raw = await showImportDesignJsonDialog(context);
    if (raw == null || raw.trim().isEmpty || !context.mounted) return;
    final err = vm.importFromJson(raw);
    if (!context.mounted) return;
    if (err != null) {
      Notify.error(context, context.tr(err));
    } else {
      Notify.success(context, context.tr('imported'));
    }
  }
}

/// Whether any document uses this design, and the way to change that.
///
/// Saying it here is what tells the user a saved design is not yet a used
/// one — and, once it is, that saving changes real documents.
class _UsageButton extends StatelessWidget {
  const _UsageButton({required this.usedFor, required this.onPressed});

  final List<String> usedFor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final inUse = usedFor.isNotEmpty;
    final names = [for (final e in usedFor) context.tr('${e}s')];
    // One name and a count: four names would not fit beside the tools.
    final label = !inUse
        ? context.tr('not_in_use')
        : '${context.tr('used_for')} ${names.first}'
              '${names.length > 1 ? ' +${names.length - 1}' : ''}';
    return Tooltip(
      message: inUse
          ? '${names.join(', ')}\n${context.tr('design_in_use_hint')}'
          : context.tr('design_not_in_use_hint'),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: inUse ? tokens.paid : tokens.ink3,
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        icon: Icon(
          inUse ? Icons.check_circle_outline : Icons.radio_button_unchecked,
          size: 16,
        ),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: onPressed,
      ),
    );
  }
}

/// Things about the layout worth a second look — a count, opening the list.
/// Hidden when there are none. Never blocks a save.
class _SuggestionsButton extends StatelessWidget {
  const _SuggestionsButton({required this.vm, required this.companyHasLogo});

  final WysiwygDesignViewModel vm;
  final bool companyHasLogo;

  @override
  Widget build(BuildContext context) {
    final suggestions = designSuggestions(
      vm.blocks,
      companyHasLogo: companyHasLogo,
    );
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final tokens = context.inTheme;
    return Builder(
      builder: (buttonContext) => Tooltip(
        message: context.tr('suggestions'),
        child: TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: tokens.partial,
            minimumSize: const Size(44, 40),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          icon: const Icon(Icons.lightbulb_outline, size: 18),
          label: Text('${suggestions.length}'),
          onPressed: () async {
            final box = buttonContext.findRenderObject()! as RenderBox;
            final picked = await showMenu<DesignSuggestion>(
              context: buttonContext,
              position: menuAnchor(
                buttonContext,
                box.localToGlobal(box.size.bottomLeft(Offset.zero)) & Size.zero,
              ),
              constraints: const BoxConstraints(maxWidth: 360),
              items: [
                for (final s in suggestions)
                  PopupMenuItem(
                    value: s,
                    // One that adding a block settles does so on a press;
                    // the others are only said.
                    enabled: s.fixWithBlock != null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            buttonContext.tr(s.messageKey),
                            style: TextStyle(fontSize: 13, color: tokens.ink),
                          ),
                        ),
                        if (s.fixWithBlock != null) ...[
                          SizedBox(width: InSpacing.md(buttonContext)),
                          Text(
                            buttonContext.tr('add_it'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: tokens.accent,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
            final type = picked?.fixWithBlock;
            final spec = type == null ? null : blockSpecFor(type);
            if (spec != null) vm.addBlock(spec);
          },
        ),
      ),
    );
  }
}

/// The design's name, edited in place in the app bar — the title of the
/// screen *is* the name.
///
/// Reseeds when the draft becomes a different design (an import), and shows
/// the server's verdict on the name: it must be unique in the company, and a
/// rejection that named no field would leave Save failing for no visible
/// reason.
class DesignNameField extends StatefulWidget {
  const DesignNameField({super.key, required this.vm});
  final WysiwygDesignViewModel vm;

  @override
  State<DesignNameField> createState() => _DesignNameFieldState();
}

class _DesignNameFieldState extends State<DesignNameField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.vm.draft.name,
  );

  /// The name as this field last knew it — what it showed, or what was typed
  /// into it. A draft name that is neither came from somewhere else.
  late String _known = widget.vm.draft.name;

  @override
  void didUpdateWidget(covariant DesignNameField old) {
    super.didUpdateWidget(old);
    // Re-seed when the name changed underneath the field: a Discard, which
    // puts the draft back; an import. It used to wait for the draft's *id*
    // to change, which neither does — so after a Discard the field showed a
    // name the draft no longer had, over a Save disabled for want of one.
    final name = widget.vm.draft.name;
    if (name == _known) return;
    _known = name;
    if (name != _controller.text) {
      _controller.value = TextEditingValue(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(InRadii.r2),
          borderSide: BorderSide(color: color, width: width),
        );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          // Not "Untitled": a placeholder that reads like a name hid the
          // fact that the field was empty and Save was waiting on it.
          hintText: context.tr('design_name'),
          errorText: widget.vm.fieldErrorFor('name'),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 9,
          ),
          border: border(tokens.border),
          enabledBorder: border(tokens.border),
          focusedBorder: border(tokens.accent, 1.5),
        ),
        onChanged: (v) {
          _known = v;
          widget.vm.setName(v);
        },
        onSubmitted: (_) => FormSaveScope.maybeOf(context)?.trySubmit(),
      ),
    );
  }
}
