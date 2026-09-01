import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/utils/legacy_html_markdown.dart';

/// Handle the host can pass into [MarkdownTextField] to force the
/// editor to serialize + emit its current content immediately,
/// bypassing the debounce. Used before actions that read the parent's
/// draft synchronously (e.g. "Save as default"), so the just-typed
/// value is captured rather than the last debounced one.
///
/// Mirrors the `LineItemTableDesktopController` flush pattern.
class MarkdownFieldController {
  String? Function()? _flushHandler;

  // ignore: use_setters_to_change_properties
  void _attach(String? Function() handler) {
    _flushHandler = handler;
  }

  void _detach(String? Function() handler) {
    if (identical(_flushHandler, handler)) _flushHandler = null;
  }

  /// Cancel any pending debounce, serialize the document now, emit it
  /// through the field's `onChanged`, and return the serialized
  /// markdown. Returns null when the field isn't mounted or there's
  /// nothing to flush (the caller should fall back to its known value).
  String? flush() => _flushHandler?.call();
}

/// A reusable WYSIWYG markdown editor. Loads from a raw markdown string,
/// edits via [SuperEditor], serializes back to markdown on changes (debounced),
/// and emits the new markdown through [onChanged].
///
/// Bound to a one-way data flow: parent owns the truth and feeds [initialValue]
/// + [externalValueKey]; when the key changes and the new value differs from
/// the editor's serialized state, the document is reseeded. SuperEditor exposes
/// no `TextEditingController`-style two-way binding, so [externalValueKey] is
/// how callers force a reseed (e.g. when an override toggle resets the field
/// to a cascaded parent value).
class MarkdownTextField extends StatefulWidget {
  const MarkdownTextField({
    super.key,
    required this.initialValue,
    required this.onChanged,
    required this.label,
    this.showLabel = true,
    this.height = 200,
    this.maxHeight,
    this.expand = false,
    this.enabled = true,
    this.readOnly = false,
    this.externalValueKey,
    this.focusNode,
    this.controller,
    this.debounce = const Duration(milliseconds: 300),
  }) : assert(
         maxHeight == null || maxHeight >= height,
         'maxHeight is a ceiling above height; a contradiction is resolved in '
         'favour of the floor, silently discarding the ceiling.',
       );

  /// Starting markdown content. Null and empty are equivalent.
  final String? initialValue;

  /// Fired with the serialized markdown after [debounce] of no further edits.
  /// Also flushed synchronously when focus leaves the editor.
  final ValueChanged<String> onChanged;

  /// Visible label above the editor frame.
  final String label;

  /// When false the label row is not rendered (the host already labels the
  /// field — e.g. a `TabBar` tab name). The string is still used elsewhere
  /// (placeholder/semantics). Defaults to true.
  final bool showLabel;

  /// Minimum height of the editor's viewport, and the height it renders at
  /// while the content fits. The field grows with its content from here up to
  /// [maxHeight] and scrolls internally past that. Ignored when [expand] is
  /// true.
  final double height;

  /// Ceiling for that content-driven growth. Defaults to half the viewport
  /// height, capped at 480 and never below [height]. Ignored when [expand] is
  /// true (the parent bounds the field there).
  final double? maxHeight;

  /// When true the editor fills its parent's available height (the parent must
  /// supply a bounded height) instead of using the fixed [height]. Used inside
  /// the desktop notes pane so the textarea reaches the bottom of the panel
  /// rather than leaving dead space below it.
  final bool expand;

  /// When false, paints a disabled overlay and ignores input. The toolbar is
  /// hidden.
  final bool enabled;

  /// When true the editor is a live but non-editable reader: selection and
  /// scrolling work, tapping does not promote to the editor, and no toolbar is
  /// shown. Distinct from `!enabled`, which additionally dims the frame and
  /// blocks pointers. `OverridableMarkdownField` uses this for a cascade value
  /// the user hasn't overridden — inherited text they still need to read.
  final bool readOnly;

  /// Bump to force the editor to reseed its document from [initialValue].
  /// Hash of `(apiKey, value, isOverridden)` works well for the overridable
  /// settings pattern.
  final Object? externalValueKey;

  /// Optional focus node for tab-order chaining.
  final FocusNode? focusNode;

  /// Optional handle the host uses to force an immediate serialize +
  /// emit (see [MarkdownFieldController]).
  final MarkdownFieldController? controller;

  /// Quiet period before the serialized markdown is emitted to [onChanged].
  /// Keystroke-rate edits get coalesced into a single VM write.
  final Duration debounce;

  @override
  State<MarkdownTextField> createState() => _MarkdownTextFieldState();
}

class _MarkdownTextFieldState extends State<MarkdownTextField> {
  late MutableDocument _document;
  late MutableDocumentComposer _composer;
  late Editor _editor;
  late FocusNode _focusNode;

  Timer? _debounce;
  String _lastEmitted = '';
  bool _isApplyingExternal = false;
  // When false, the heavy editing `SuperEditor` (which attaches an IME
  // client) is replaced by a read-only `SuperReader` (no IME). Only the
  // focused field mounts a `SuperEditor`, so at most one IME input is ever
  // registered — screens that show many markdown fields at once (Defaults'
  // 8 fields, the invoice notes TabBarView's 4) no longer collide on the
  // null IME input id, and `ExcludeFocus` around the readers keeps the
  // focus-traversal policy from probing unlaid-out reader render boxes.
  bool _editing = false;
  // `_seedDocument` is called from both `initState` and `didUpdateWidget` —
  // this flag tells it whether the late-initialized fields below carry a
  // previous-generation document/composer that needs tearing down.
  bool _initialized = false;
  // True when this widget created its own FocusNode and is therefore
  // responsible for disposing it. False when a caller-owned node was passed
  // in via `widget.focusNode`.
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _ownsFocusNode = false;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChanged);
    _seedDocument(widget.initialValue ?? '');
    widget.controller?._attach(_flushNow);
  }

  /// Cancel the debounce, serialize now, emit if changed, return the
  /// markdown. Wired to [MarkdownFieldController.flush].
  String _flushNow() {
    _debounce?.cancel();
    _debounce = null;
    final md = serializeDocumentToMarkdown(_document);
    if (md != _lastEmitted) {
      _lastEmitted = md;
      widget.onChanged(md);
    }
    return md;
  }

  @override
  void didUpdateWidget(covariant MarkdownTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach(_flushNow);
      widget.controller?._attach(_flushNow);
    }

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (_ownsFocusNode) _focusNode.dispose();
      if (widget.focusNode != null) {
        _focusNode = widget.focusNode!;
        _ownsFocusNode = false;
      } else {
        _focusNode = FocusNode();
        _ownsFocusNode = true;
      }
      _focusNode.addListener(_onFocusChanged);
    }

    // Reseed only when the parent signals that the underlying value changed
    // from somewhere other than our own emission (e.g. override toggle).
    // The `_lastEmitted` guard prevents echoing our own writes back through
    // the document.
    if (widget.externalValueKey != oldWidget.externalValueKey) {
      final next = widget.initialValue ?? '';
      if (next != _lastEmitted) {
        _seedDocument(next);
      }
    }
  }

  @override
  void dispose() {
    // Capture any pending debounced emit BEFORE teardown, then schedule it
    // on a microtask. Calling `widget.onChanged` synchronously here would
    // call the parent VM's `notifyListeners`, which can rebuild widgets
    // mid-dispose and trip "setState after dispose" assertions.
    String? pending;
    if (_debounce != null) {
      _debounce!.cancel();
      _debounce = null;
      final md = serializeDocumentToMarkdown(_document);
      if (md != _lastEmitted) pending = md;
    }
    widget.controller?._detach(_flushNow);
    _document.removeListener(_onDocumentChange);
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    _composer.dispose();
    if (pending != null) {
      final emit = widget.onChanged;
      scheduleMicrotask(() => emit(pending!));
    }
    super.dispose();
  }

  void _seedDocument(String markdown) {
    _isApplyingExternal = true;

    // Tear down the previous generation before creating new instances.
    // `_initialized` is false only on the very first call (from initState),
    // when the late fields are still uninitialized.
    if (_initialized) {
      _document.removeListener(_onDocumentChange);
      _composer.dispose();
    }

    final sanitized = _sanitize(markdown);
    _document = sanitized.isEmpty
        ? MutableDocument.empty()
        : deserializeMarkdownToDocument(sanitized);
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
    );
    _document.addListener(_onDocumentChange);
    // Baseline against what the editor would actually serialize right now —
    // not against the unsanitized input. The deserialize → serialize round
    // trip normalizes whitespace, so a literal equality against the input
    // string would flag the first keystroke as "different" against a stale
    // baseline.
    _lastEmitted = serializeDocumentToMarkdown(_document);
    _initialized = true;
    _isApplyingExternal = false;
  }

  /// Folds the HTML that the React (TinyMCE) client and the pre-v5 apps store
  /// in these fields into markdown. Left raw, a block-level tag doesn't just
  /// render as literal text — it takes its whole block out of the document —
  /// so this runs on every seed. See `markdownFromLegacyHtml`.
  String _sanitize(String md) => markdownFromLegacyHtml(md);

  void _onDocumentChange(DocumentChangeLog _) {
    if (_isApplyingExternal) return;
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, _emitNow);
  }

  void _emitNow() {
    final md = serializeDocumentToMarkdown(_document);
    if (md == _lastEmitted) return;
    _lastEmitted = md;
    widget.onChanged(md);
  }

  void _onFocusChanged() {
    // Flush any pending edits the moment focus leaves the editor so that
    // blur-then-save races don't drop the last keystroke.
    if (!_focusNode.hasFocus && _debounce != null) {
      _debounce!.cancel();
      _debounce = null;
      _emitNow();
    }
    // Drop back to the read-only `SuperReader` when focus leaves so the
    // IME client is released and this field stops participating in focus
    // traversal. Entering edit mode is driven by `_enterEditing` (tap or
    // keyboard activation on the reader host) — the editor focus node isn't
    // attached to a Focus widget until the `SuperEditor` mounts, so it can't
    // receive focus from here first.
    if (!_focusNode.hasFocus && _editing && mounted) {
      setState(() => _editing = false);
    }
  }

  /// Promote this field from the read-only `SuperReader` to the editing
  /// `SuperEditor`. Drops any other field's editor first and defers the
  /// rebuild to the next frame so the previously-edited field has already
  /// torn its `SuperEditor` down — guaranteeing at most one `SuperEditor`
  /// (one IME client) is ever mounted in a single frame, even when the user
  /// taps straight from one markdown field to another.
  void _enterEditing() {
    if (_editing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_editing) setState(() => _editing = true);
    });
  }

  bool _selectionHas(Attribution a) {
    final selection = _composer.selection;
    if (selection == null) return false;
    if (selection.isCollapsed) {
      return _composer.preferences.currentAttributions.contains(a);
    }
    return _document.doesSelectedTextContainAttributions(selection, {a});
  }

  void _toggleAttribution(Attribution a) {
    final selection = _composer.selection;
    if (selection == null) return;
    if (selection.isCollapsed) {
      _composer.preferences.toggleStyle(a);
      return;
    }
    _editor.execute([
      ToggleTextAttributionsRequest(
        documentRange: _document.getRangeBetween(
          selection.base,
          selection.extent,
        ),
        attributions: {a},
      ),
    ]);
  }

  void _convertSelectedToList(ListItemType type) {
    final selection = _composer.selection;
    if (selection == null) return;
    final nodeId = selection.extent.nodeId;
    _editor.execute([
      ConvertParagraphToListItemRequest(nodeId: nodeId, type: type),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    final disabled = !widget.enabled;
    final canEdit = widget.enabled && !widget.readOnly;
    final showEditor = canEdit && _editing;
    final showToolbar = showEditor;

    // The sliver fed into the CustomScrollView host below. Must stay a raw
    // SuperEditor/SuperReader — they return a Sliver when hosted in a
    // Scrollable, so RenderBox wrappers (ExcludeFocus / GestureDetector) go
    // *around* the scroll host, never between it and the editor.
    //
    // Only the focused field mounts a `SuperEditor` (and therefore one IME
    // client); every other field renders a read-only `SuperReader` with no
    // IME, so the many-editor screens never collide on the null input id.
    final Widget sliver = showEditor
        ? SuperEditor(
            editor: _editor,
            focusNode: _focusNode,
            // The reader had no editing focus to hand over, so grab focus on
            // mount. Caret lands at the document edge rather than the exact
            // tap offset — an accepted tradeoff for never colliding IME
            // registrations across the many-editor screens.
            autofocus: true,
            stylesheet: _buildStylesheet(t),
            // Caret color isn't stylesheet-controllable in super_editor; the
            // only seam is the overlay-builder list. The package default caret
            // (`DefaultCaretOverlayBuilder`) hardcodes black — invisible in
            // dark mode — so reuse the default builders (keeping the mobile
            // selection/handle overlays untouched) and swap just the desktop
            // caret for a theme-aware one. `t.ink` is the primary foreground
            // token: near-black in light mode, near-white in dark, matching
            // the editor's body text color above.
            documentOverlayBuilders: [
              ...defaultSuperEditorDocumentOverlayBuilders.where(
                (b) => b is! DefaultCaretOverlayBuilder,
              ),
              DefaultCaretOverlayBuilder(
                caretStyle: CaretStyle(width: 2, color: t.ink),
              ),
            ],
          )
        : SuperReader(editor: _editor, stylesheet: _buildStylesheet(t));

    // Wrap the editor frame in [TextInputFocusScope] so the app-wide
    // `isTextInputFocused()` guard returns true while the caret is in
    // `SuperEditor` — super_editor isn't an `EditableText`, so without
    // this marker the pane / shell single-key shortcuts (F / J / K /
    // arrows / `/` / `?`) would fire mid-typing in a Notes field.
    final frame = TextInputFocusScope(
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          border: Border.all(color: t.border),
          borderRadius: BorderRadius.circular(InRadii.r1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (showToolbar)
              _MarkdownToolbar(
                composer: _composer,
                isActive: _selectionHas,
                onBold: () => _toggleAttribution(boldAttribution),
                onItalic: () => _toggleAttribution(italicsAttribution),
                onUnderline: () => _toggleAttribution(underlineAttribution),
                onBulletList: () =>
                    _convertSelectedToList(ListItemType.unordered),
                onNumberedList: () =>
                    _convertSelectedToList(ListItemType.ordered),
              ),
            _EditorHost(
              height: widget.height,
              maxHeight: widget.maxHeight,
              expand: widget.expand,
              // In reader mode the inner `SuperReader` subtree is `ExcludeFocus`'d
              // so its deep, possibly-unlaid render objects stay out of the
              // geometry-based `ReadingOrderTraversalPolicy` sort (closes the
              // `hasSize` crash), while a single lightweight host `Focus` node
              // remains Tab-reachable and keyboard-activatable. Tap or keyboard
              // activation promotes the field to the editing `SuperEditor`.
              // These wrappers sit *outside* the sliver host — never between it
              // and the editor — so the sliver protocol stays intact.
              //
              // Edge: a field scrolled off-screen in a `TabBarView` while still
              // focused/editing keeps its `SuperEditor` mounted; switching tabs
              // normally unfocuses it (→ reader), so this is not a live path.
              excludeFocus: !showEditor,
              // Everything but the live `readOnly` reader blocks pointers into
              // the document: the tap-to-edit reader so its tap layer wins the
              // arena, and a disabled field because it takes no input at all.
              // This used to be inferred from `enterEditing != null`, which
              // left the disabled case to a frame-level `IgnorePointer` —
              // i.e. to the very construct #107 was about.
              ignorePointer:
                  !showEditor && !(widget.readOnly && widget.enabled),
              enterEditing: (!showEditor && canEdit) ? _enterEditing : null,
              sliver: sliver,
            ),
          ],
        ),
      ),
    );

    // Dim only — the pointer block lives on the sliver (see `ignorePointer`
    // above). An `IgnorePointer` here would switch off the editor's own
    // `CustomScrollView` too, leaving a disabled field's overflowing content
    // unreachable. Nothing else in a disabled frame takes input: the toolbar
    // is hidden and `enterEditing` is null.
    final body = disabled ? Opacity(opacity: 0.55, child: frame) : frame;

    if (!widget.showLabel) return body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: InSpacing.xs, left: 2),
          child: Text(
            widget.label,
            style: TextStyle(
              color: disabled ? t.ink3 : t.ink2,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        body,
      ],
    );
  }

  Stylesheet _buildStylesheet(InTheme t) {
    // Replace the default block-level rule (which hardcodes black text + 640
    // max width + horizontal padding sized for a full-screen editor) with one
    // tuned for a settings-form field. Subsequent rules from defaultStylesheet
    // still apply for headers, lists, blockquote, etc.
    return defaultStylesheet.copyWith(
      addRulesAfter: [
        StyleRule(
          BlockSelector.all,
          (doc, docNode) => {
            Styles.maxWidth: double.infinity,
            Styles.padding: CascadingPadding.symmetric(
              horizontal: InSpacing.md(context),
              vertical: InSpacing.xs,
            ),
            Styles.textStyle: TextStyle(
              color: t.ink,
              fontSize: 14,
              height: 1.4,
            ),
          },
        ),
      ],
    );
  }
}

/// Sizes the editor and gives SuperEditor/SuperReader their own (closer)
/// sliver host.
///
/// SuperEditor/SuperReader walk the ancestor chain for a vertical Scrollable
/// and return their content as a Sliver when they find one. Settings screens
/// sit inside a `ListView` (SettingsFormShell), so without this nested
/// CustomScrollView the returned Sliver would collide with the non-sliver
/// parent. The focus/tap wrappers are applied *around* the scroll host so the
/// sliver protocol between CustomScrollView and the editor is never broken.
class _EditorHost extends StatelessWidget {
  const _EditorHost({
    required this.height,
    required this.maxHeight,
    required this.expand,
    required this.excludeFocus,
    required this.ignorePointer,
    required this.enterEditing,
    required this.sliver,
  });

  final double height;
  final double? maxHeight;
  final bool expand;
  final bool excludeFocus;

  /// Whether the document itself is inert to pointers. Blocked at the
  /// **sliver**, so the enclosing scroll view keeps working.
  final bool ignorePointer;

  /// Non-null only in the editable read-only state: invoked to promote the
  /// field to the editing `SuperEditor` (by pointer tap, by Tab focusing the
  /// host, or by Enter/Space activating it).
  final VoidCallback? enterEditing;
  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    Widget content = sliver;
    if (ignorePointer) {
      // Make the document inert to pointers: in the tap-to-edit reader so the
      // tap layer below deterministically wins the gesture arena over
      // SuperReader's own mouse/selection interactor, and in a disabled field
      // because it takes no input at all. Read-mode text selection is
      // sacrificed — acceptable; the field's purpose is editing.
      //
      // This MUST block at the sliver, never around the scroll host. An
      // `IgnorePointer` there also switches off the `CustomScrollView`, so a
      // value taller than the box could not be scrolled into view by drag or
      // by mouse wheel — it was simply cut off (invoiceninja/flutter#107).
      // `SliverIgnorePointer` is a sliver-to-sliver proxy, so it satisfies the
      // rule above that only slivers sit between the host and the editor, and
      // it covers super_editor's gesture detectors, which are box children
      // hit-tested through the returned sliver. The one thing outside its
      // reach is the drag-handle / toolbar layer, which super_editor mounts in
      // an `OverlayPortal` — moot here, since a reader wrapped in
      // `ExcludeFocus` can never take the selection that raises it.
      content = SliverIgnorePointer(sliver: content);
    }
    Widget host = expand
        ? CustomScrollView(slivers: [content])
        : ConstrainedBox(
            // [height] is the floor, not the size: the field grows with its
            // content and only starts scrolling internally past [maxHeight].
            // A hard `SizedBox` gave a one-line note and a forty-line note
            // the same box, which is the other half of #107.
            constraints: BoxConstraints(
              minHeight: height,
              maxHeight: _resolveMaxHeight(context),
            ),
            // `shrinkWrap` is cheap here despite its reputation: super_editor
            // hands us a single `SliverToBoxAdapter` that lays the whole
            // document out either way, so no lazy build is being defeated.
            child: CustomScrollView(shrinkWrap: true, slivers: [content]),
          );
    if (excludeFocus) {
      // Keep the reader's deep (possibly-unlaid) render objects out of the
      // focus-traversal tree so the geometry-based traversal policy can't
      // read `.rect` on them.
      host = ExcludeFocus(child: host);
    }
    if (enterEditing != null) {
      final enter = enterEditing!;
      host = FocusableActionDetector(
        // Tab lands on this single lightweight host node; focusing or
        // activating (Enter/Space) it promotes to the editor — markdown
        // fields stay keyboard-reachable.
        onFocusChange: (focused) {
          if (focused) enter();
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              enter();
              return null;
            },
          ),
        },
        // A tap still promotes the field even though the scroll view below is
        // live again: `ScrollView` hit-tests opaquely, so its drag recognizer
        // joins the arena first and then rejects on a movement-free pointer
        // up, leaving this tap to win the sweep. A drag scrolls instead.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enter,
          child: host,
        ),
      );
    }
    // In expand mode the host fills the remaining height of the frame's
    // Column (toolbar takes its intrinsic height, the editor takes the rest)
    // so there's no dead space below the editor inside a fixed-height panel.
    return expand ? Expanded(child: host) : host;
  }

  /// Ceiling on the content-driven growth. Half the viewport keeps a long
  /// note from crowding out the fields around it while still showing several
  /// times what the old fixed box did; the 480 cap keeps a desktop settings
  /// field from turning into a page of its own. Never below [height], so a
  /// caller's floor always wins.
  double _resolveMaxHeight(BuildContext context) => math.max(
    height,
    maxHeight ?? math.min(MediaQuery.sizeOf(context).height * 0.5, 480.0),
  );
}

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({
    required this.composer,
    required this.isActive,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onBulletList,
    required this.onNumberedList,
  });

  final MutableDocumentComposer composer;

  /// Returns whether the given attribution applies to the current selection
  /// (or composer preferences when the selection is collapsed). Used to paint
  /// the active state of the corresponding button.
  final bool Function(Attribution) isActive;

  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onBulletList;
  final VoidCallback onNumberedList;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        border: Border(bottom: BorderSide(color: t.border)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(InRadii.r1),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: InSpacing.xs,
        vertical: 2,
      ),
      child: ListenableBuilder(
        // Repaint button active states as the selection (and composer
        // preferences when the selection is collapsed) changes.
        listenable: composer,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                icon: Icons.format_bold,
                tooltip: context.tr('bold'),
                active: isActive(boldAttribution),
                onPressed: onBold,
              ),
              _ToolbarButton(
                icon: Icons.format_italic,
                tooltip: context.tr('italic'),
                active: isActive(italicsAttribution),
                onPressed: onItalic,
              ),
              _ToolbarButton(
                icon: Icons.format_underline,
                tooltip: context.tr('underline'),
                active: isActive(underlineAttribution),
                onPressed: onUnderline,
              ),
              const SizedBox(width: InSpacing.sm),
              _ToolbarButton(
                icon: Icons.format_list_bulleted,
                tooltip: context.tr('bullet_list'),
                onPressed: onBulletList,
              ),
              _ToolbarButton(
                icon: Icons.format_list_numbered,
                tooltip: context.tr('numbered_list'),
                onPressed: onNumberedList,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      color: active ? t.accent : t.ink2,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => active ? t.accentSoft : null,
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(InRadii.r1),
          ),
        ),
      ),
    );
  }
}
