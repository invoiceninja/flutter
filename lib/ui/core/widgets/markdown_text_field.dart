import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/template_variables/markdown_template_variables.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_picker.dart';
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
    this.templateVariables,
    this.defaultValue,
    this.labelTrailing,
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

  /// Makes this an email-template body (invoiceninja/flutter#139): the
  /// `$variables` [scope] recognises render as chips — tap one to change or
  /// remove it — the label row gets an "Insert variable" button, and a token
  /// typed or pasted in converts to a chip. Null (every other markdown field)
  /// leaves the text alone.
  ///
  /// Chips are super_editor inline placeholders, created after deserializing
  /// and turned back into their tokens before every serialize, so a chip never
  /// reaches the markdown. (The linkify scrub and its heal-on-seed are a
  /// separate matter: those run for *every* markdown field, scope or not.) See
  /// `markdown_template_variables.dart`.
  final TemplateVariableScope? templateVariables;

  /// Rendered, muted, when [initialValue] is empty — the default template the
  /// server uses for an empty value. Nothing is emitted until a real edit
  /// makes the document differ from it, and a document edited back to it
  /// emits `''`, so an untouched default stays the per-language server
  /// default.
  final String? defaultValue;

  /// Extra widgets at the end of the label row (e.g. "Reset to default").
  final Widget? labelTrailing;

  @override
  State<MarkdownTextField> createState() => _MarkdownTextFieldState();
}

class _MarkdownTextFieldState extends State<MarkdownTextField> {
  late MutableDocument _document;
  late MutableDocumentComposer _composer;
  late Editor _editor;
  late FocusNode _focusNode;

  Timer? _debounce;

  /// The value the parent last received (or started with) — `''` while the
  /// untouched default is showing. The reseed guard compares against this.
  String _lastEmitted = '';

  /// The document's serialization at the last emit check. Distinct from
  /// [_lastEmitted] only while the default is showing.
  String _lastSerialized = '';

  /// How [MarkdownTextField.defaultValue] serializes; null without one.
  String? _defaultSerialized;

  /// The document [_reseedDefault] last replaced, until the next seed — so
  /// the Undo for a change that emptied the body can still put it back.
  MutableDocument? _clearedDocument;

  bool _isApplyingExternal = false;

  /// The reader's document layout, for hit-testing a tapped chip while the
  /// reader sits under its `SliverIgnorePointer`. Attached for every field,
  /// chips or not — without a scope the hit test simply never runs. The editor
  /// gets its own key (never shared: both can be mounted during the frame they
  /// swap).
  final _readerLayoutKey = GlobalKey();

  /// Built once per `Editor`: SuperEditor builds its tap delegates inside
  /// `_createEditContext`, i.e. when its `Editor` changes (disposing the old
  /// ones), so the list only has to stay stable across the builds that share
  /// one — it compares no factories of its own.
  List<SuperEditorContentTapDelegateFactory> _tapFactories = const [
    superEditorLaunchLinkTapHandlerFactory,
  ];

  bool get _showingDefault =>
      _defaultSerialized != null && _lastEmitted.isEmpty;

  /// The parent holds `''` — the default — but the document isn't it: the
  /// body was emptied, by hand or by removing its last chip.
  bool get _needsDefaultReseed =>
      _showingDefault && _lastSerialized != _defaultSerialized;

  bool get _chipsEditable => widget.enabled && !widget.readOnly;
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
    return _emitCurrent();
  }

  /// Every serialize goes through here: chips back into tokens, stray U+FFFC
  /// dropped — the markdown serializer knows nothing of placeholders.
  String _serialize() =>
      serializeDocumentToMarkdown(detokenizeTemplateVariables(_document));

  /// The value the parent should hold for markdown [md]: `''` when it is the
  /// default template, so editing back to the default restores it.
  String _valueFor(String md) => md == _defaultSerialized ? '' : md;

  /// Serialize, and emit when the value changed. Returns the value the parent
  /// now holds.
  String _emitCurrent() {
    final md = _serialize();
    if (md == _lastSerialized) return _lastEmitted;
    _lastSerialized = md;
    final value = _valueFor(md);
    if (value != _lastEmitted) {
      _lastEmitted = value;
      widget.onChanged(value);
    }
    return _lastEmitted;
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
      final md = _serialize();
      if (md != _lastSerialized) {
        final value = _valueFor(md);
        if (value != _lastEmitted) pending = value;
      }
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
    _clearedDocument = null;

    // Tear down the previous generation before creating new instances.
    // `_initialized` is false only on the very first call (from initState),
    // when the late fields are still uninitialized.
    if (_initialized) {
      _document.removeListener(_onDocumentChange);
      _composer.dispose();
    }

    final sanitized = _sanitize(markdown);
    final defaultMarkdown = _sanitize(widget.defaultValue ?? '');
    // An empty value shows the default template, when there is one.
    final source = sanitized.isEmpty ? defaultMarkdown : sanitized;
    final scope = widget.templateVariables;
    var document = source.isEmpty
        ? MutableDocument.empty()
        : deserializeMarkdownToDocument(source);
    // Every field: undo linkify's `$client.name` → link corruption in content
    // saved while it was live. Before the baseline, so it emits nothing.
    document = healTemplateVariableLinks(document);
    if (scope != null) document = tokenizeTemplateVariables(document, scope);
    _document = document;
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(
      document: _document,
      composer: _composer,
    );
    installTemplateVariableReactions(_editor, scope: scope);
    _tapFactories = [
      if (scope != null)
        (editContext) => TemplateVariableTapDelegate(
          document: editContext.document,
          onChipTap: (hit) => _onChipTap(hit, fromEditor: true),
        ),
      superEditorLaunchLinkTapHandlerFactory,
    ];
    _document.addListener(_onDocumentChange);
    _defaultSerialized = defaultMarkdown.isEmpty
        ? null
        : serializeDocumentToMarkdown(
            healTemplateVariableLinks(
              deserializeMarkdownToDocument(defaultMarkdown),
            ),
          );
    // Baseline against what the editor would actually serialize right now —
    // not against the unsanitized input. The deserialize → serialize round
    // trip normalizes whitespace, so a literal equality against the input
    // string would flag the first keystroke as "different" against a stale
    // baseline. The parent of a field showing its default holds `''`.
    _lastSerialized = _serialize();
    _lastEmitted = sanitized.isEmpty && _defaultSerialized != null
        ? ''
        : _lastSerialized;
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
    final wasDefault = _showingDefault;
    _emitCurrent();
    if (!mounted) return;
    if (!_editing && _needsDefaultReseed) {
      // At rest, a body just emptied shows the default it now holds. While
      // editing that waits for the blur (see `_onFocusChanged`).
      _reseedDefault();
    } else if (wasDefault != _showingDefault) {
      // The first real edit un-mutes the default (and the reverse).
      setState(() {});
    }
  }

  /// An emptied body holds `''`, which *is* the default, so it shows the
  /// default again rather than an empty box under the "Default" badge.
  void _reseedDefault() {
    final cleared = _document;
    setState(() => _seedDocument(''));
    _clearedDocument = cleared;
  }

  /// Puts [value] back after the body was emptied and reseeded, and hands it
  /// to the parent — the seed baselines as though the parent already held it.
  void _restore(String value) {
    _debounce?.cancel();
    _debounce = null;
    if (_editing) {
      // Same reason `_onFocusChanged` defers: a reseed disposes the composer
      // a mounted `SuperEditor` is still holding. Undo can be tapped while the
      // field has focus, so let the frame finish first.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreNow(value);
      });
      return;
    }
    _restoreNow(value);
  }

  void _restoreNow(String value) {
    final held = _lastEmitted;
    setState(() => _seedDocument(value));
    if (_lastEmitted != held) widget.onChanged(_lastEmitted);
  }

  /// A chip was tapped (in the editor, or through the reader's hit-test):
  /// open the picker, then change or remove it. The target is captured before
  /// the picker opens — the route takes focus, which demotes the editor and
  /// clears the selection — and re-checked after, since the text can change
  /// while the picker is up.
  Future<void> _onChipTap(
    TemplateVariableChipHit hit, {
    required bool fromEditor,
  }) async {
    final scope = widget.templateVariables;
    if (scope == null || !_chipsEditable) return;
    final pick = await showTemplateVariablePicker(
      context,
      scope: scope,
      currentToken: hit.token,
    );
    if (pick == null || !mounted) return;
    // Settle an edit still in its debounce first, so the Undo below knows
    // exactly what the parent held before this change.
    _debounce?.cancel();
    _debounce = null;
    _emitNow();
    final node = _document.getNodeById(hit.nodeId);
    if (node is! TextNode ||
        node.text.placeholders[hit.offset] !=
            TemplateVariablePlaceholder(hit.token)) {
      return;
    }
    final document = _document;
    final valueBefore = _lastEmitted;
    // Captured before the edit: a chip inside a bold run has to come back
    // bold, and `replaceTemplateVariableChipRequests` preserves these only for
    // the change itself, not for the Undo.
    final attributions = node.text.getAllAttributionsAt(hit.offset);
    final replacement = pick is TemplateVariablePicked ? pick.token : null;
    _editor.execute(
      replaceTemplateVariableChipRequests(
        node,
        hit.offset,
        token: replacement,
        caretAfter: fromEditor,
      ),
    );
    if (fromEditor) {
      _enterEditing();
    } else {
      // At rest a chip change is one command, not keystrokes to coalesce, so
      // it's emitted now — and a body it emptied shows its default at once.
      _debounce?.cancel();
      _debounce = null;
      _emitNow();
    }
    _offerUndo(
      hit,
      replacement,
      document: document,
      valueBefore: valueBefore,
      attributions: attributions,
      serializedAfter: _serialize(),
    );
  }

  /// super_editor's history is off in this app, so a chip change or removal
  /// gets its own Undo. [document] and [valueBefore] are the body before the
  /// change, for when the change emptied it and the default replaced it.
  void _offerUndo(
    TemplateVariableChipHit hit,
    String? replacement, {
    required MutableDocument document,
    required String valueBefore,
    required Set<Attribution> attributions,
    required String serializedAfter,
  }) {
    Notify.info(
      context,
      context.tr(replacement == null ? 'removed' : 'updated'),
      action: NotifyAction(context.tr('undo'), () {
        if (!mounted) return;
        if (!identical(document, _document)) {
          // Only our own reseed of the default is undone, and only while the
          // default is untouched; any other reseed (Reset to default, an
          // override toggle) was a later choice of the user's, and stays.
          if (identical(document, _clearedDocument) &&
              _serialize() == _defaultSerialized) {
            _restore(valueBefore);
          }
          return;
        }
        final node = _document.getNodeById(hit.nodeId);
        if (node is! TextNode) return;
        // Nothing may have changed since: any other edit moves `hit.offset`,
        // and undoing onto a stale offset drops the chip into the middle of
        // what the user has just typed.
        if (_serialize() != serializedAfter) return;
        if (replacement == null) {
          if (hit.offset > node.text.length) return;
          _editor.execute([
            InsertAttributedTextRequest(
              templateVariablePosition(hit.nodeId, hit.offset),
              templateVariableChipText(hit.token, attributions: attributions),
            ),
          ]);
        } else if (node.text.placeholders[hit.offset] ==
            TemplateVariablePlaceholder(replacement)) {
          _editor.execute(
            replaceTemplateVariableChipRequests(
              node,
              hit.offset,
              token: hit.token,
            ),
          );
        }
      }),
    );
  }

  /// The label row's "Insert variable": at the caret while editing (replacing
  /// a selection), appended to the end otherwise — with no promotion to the
  /// editor, since the picker's route would take focus straight back.
  Future<void> _insertVariable() async {
    final scope = widget.templateVariables;
    if (scope == null || !_chipsEditable) return;
    final selection = _editing ? _composer.selection : null;
    final pick = await showTemplateVariablePicker(context, scope: scope);
    if (pick is! TemplateVariablePicked || !mounted) return;

    final range = selection == null || selection.isCollapsed
        ? null
        : _document.getRangeBetween(selection.base, selection.extent);
    final caretPosition = range?.start ?? selection?.extent;
    final atCaret =
        caretPosition != null &&
        caretPosition.nodePosition is TextNodePosition &&
        _document.getNodeById(caretPosition.nodeId) is TextNode;
    final at = atCaret
        ? caretPosition
        : templateVariableAppendPosition(_document);
    if (at == null) return;
    final node = _document.getNodeById(at.nodeId)! as TextNode;
    final offset = (at.nodePosition as TextNodePosition).offset;
    final plain = node.text.toPlainText();
    final before = offset > 0 ? plain[offset - 1] : '';
    final after = range == null && offset < plain.length ? plain[offset] : '';
    // Appending takes a space from the text before it; at the caret the user
    // put the caret exactly where they want the token.
    final leadingSpace = !atCaret && before.trim().isNotEmpty;
    final trailingSpace = templateVariableContinuesToken(after);
    final caret = offset + (leadingSpace ? 1 : 0) + 1 + (trailingSpace ? 1 : 0);
    _editor.execute([
      if (range != null) DeleteContentRequest(documentRange: range),
      InsertAttributedTextRequest(
        at,
        templateVariableChipText(
          pick.token,
          leadingSpace: leadingSpace,
          trailingSpace: trailingSpace,
        ),
      ),
      if (atCaret)
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: templateVariablePosition(at.nodeId, caret),
          ),
          SelectionChangeType.insertContent,
          SelectionReason.userInteraction,
        ),
    ]);
    if (atCaret) _enterEditing();
  }

  /// The reader sits under a `SliverIgnorePointer`, so a tap on one of its
  /// chips arrives here, as the promote tap, and is hit-tested against the
  /// reader's layout. True when it was a chip (and the promote is swallowed).
  bool _readerChipTapAt(Offset globalPosition) {
    if (widget.templateVariables == null || !_chipsEditable) return false;
    // `Object?` so the `is` check can promote: `State` and `DocumentLayout`
    // are unrelated types.
    final Object? layout = _readerLayoutKey.currentState;
    if (layout is! DocumentLayout) return false;
    final hit = hitTestTemplateVariableChip(
      _document,
      layout,
      layout.getDocumentOffsetFromAncestorOffset(globalPosition),
    );
    if (hit == null) return false;
    _onChipTap(hit, fromEditor: false);
    return true;
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
      // A body emptied while editing holds `''` — the default — so it shows
      // the default again, once the editor has gone: SuperEditor's own blur
      // handler runs after this one and executes a `ClearSelectionRequest`
      // against the composer a reseed would already have disposed.
      if (_needsDefaultReseed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_editing && _needsDefaultReseed) _reseedDefault();
        });
      }
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

    // The sliver fed into the CustomScrollView host below. Nothing that
    // creates a `RenderObject` may sit between that host and the
    // SuperEditor/SuperReader — they return a Sliver when hosted in a
    // Scrollable, so RenderBox wrappers (ExcludeFocus / GestureDetector) go
    // *around* the scroll host, never between it and the editor. The `Theme`
    // below is the one permitted wrapper, and only because it builds nothing
    // but `InheritedWidget`s (see the third bullet).
    //
    // Only the focused field mounts a `SuperEditor` (and therefore one IME
    // client); every other field renders a read-only `SuperReader` with no
    // IME, so the many-editor screens never collide on the null input id.
    //
    // The `Theme` override is what makes the caret visible on Android and iOS.
    // super_editor paints the *mobile* caret, the drag handles, the iOS
    // magnifier border, and `SuperReader`'s handles with
    // `Theme.of(context).primaryColor` whenever no explicit color is supplied
    // — and `buildInTheme` leaves `primaryColor` unset, so Flutter derives it
    // (`isDark ? colorScheme.surface : colorScheme.primary`). In dark mode
    // that lands on `surface`, i.e. exactly this field's own background: the
    // caret was painted invisible (invoiceninja/flutter#108). Light mode
    // already resolved to the accent, so nothing changes there. Three reasons
    // it's this seam and not another:
    //
    //  * The `DefaultCaretOverlayBuilder` below is **desktop-only** —
    //    `CaretDocumentOverlay` returns an empty box on Android/iOS unless
    //    `displayOnAllPlatforms` is set — so it never covered the mobile caret,
    //    and setting that flag would double-paint against the platform layer's
    //    own caret while still leaving every handle invisible.
    //  * `primaryColor` is the single fallback all of those sites consult. The
    //    per-builder `caretColor` / `handleColor` params reach the caret but
    //    not the Android handles (those read the controls controller, whose
    //    `controlsColor` is final — so retinting on an accent change means
    //    disposing a controller out from under live descendants), and
    //    `SuperReader` consults no controls scope at all.
    //  * `Theme` builds only `InheritedWidget`s and creates no `RenderObject`,
    //    so it may sit inside the sliver host without breaking the protocol
    //    described above.
    //
    // `t.accent` matches every other caret and selection handle in the app —
    // M3 defaults a `TextField` cursor to `colorScheme.primary`, which is the
    // same token.
    final Widget sliver = Theme(
      data: Theme.of(context).copyWith(primaryColor: t.accent),
      child: showEditor
          ? SuperEditor(
              editor: _editor,
              focusNode: _focusNode,
              // The reader had no editing focus to hand over, so grab focus on
              // mount. Caret lands at the document edge rather than the exact
              // tap offset — an accepted tradeoff for never colliding IME
              // registrations across the many-editor screens.
              autofocus: true,
              stylesheet: _buildStylesheet(t, muted: _showingDefault),
              contentTapDelegateFactories: _tapFactories,
              // The *desktop* caret color isn't stylesheet-controllable in
              // super_editor; the only seam is the overlay-builder list. The
              // package default (`DefaultCaretOverlayBuilder`) hardcodes black
              // — invisible in dark mode — so reuse the default builders
              // (keeping the mobile selection/handle overlays untouched; those
              // are themed by the `primaryColor` override above) and swap just
              // the desktop caret for a theme-aware one. `t.ink` is the primary
              // foreground token: near-black in light mode, near-white in dark,
              // matching the editor's body text color above.
              documentOverlayBuilders: [
                ...defaultSuperEditorDocumentOverlayBuilders.where(
                  (b) => b is! DefaultCaretOverlayBuilder,
                ),
                DefaultCaretOverlayBuilder(
                  caretStyle: CaretStyle(width: 2, color: t.ink),
                ),
              ],
            )
          : SuperReader(
              editor: _editor,
              documentLayoutKey: _readerLayoutKey,
              stylesheet: _buildStylesheet(t, muted: _showingDefault),
            ),
    );

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
              chipTapAt: widget.templateVariables == null
                  ? null
                  : _readerChipTapAt,
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
    final scope = widget.templateVariables;
    Widget body = disabled ? Opacity(opacity: 0.55, child: frame) : frame;
    if (scope != null) {
      // super_editor has no semantics layer (and its inline widgets sit under
      // an IgnorePointer), so the chips are summarised on the frame.
      body = Semantics(
        container: true,
        label: widget.label,
        value: [
          for (final token in templateVariableTokensIn(_document))
            describeTemplateVariable(context, token, scope)?.label ?? token,
        ].join(', '),
        child: body,
      );
    }
    final showingDefault = _showingDefault;
    if (_defaultSerialized != null) {
      // The wrapper stays for as long as there is a default; only the caption
      // comes and goes. Wrapping on `showingDefault` itself re-parented the
      // frame at the first keystroke into the default, remounting the live
      // editor under the user's caret.
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
          if (showingDefault)
            Padding(
              padding: const EdgeInsets.only(top: InSpacing.xs, left: 2),
              child: Text(
                context.tr('default_template_caption'),
                style: TextStyle(color: t.ink3, fontSize: 12),
              ),
            ),
        ],
      );
    }

    final insert = scope != null && _chipsEditable;
    final trailing = widget.labelTrailing;
    if (!widget.showLabel && !insert && trailing == null) return body;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: InSpacing.xs, left: 2),
          child: Row(
            children: [
              if (widget.showLabel)
                Text(
                  widget.label,
                  style: TextStyle(
                    color: disabled ? t.ink3 : t.ink2,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (showingDefault) ...[
                const SizedBox(width: InSpacing.sm),
                _DefaultBadge(label: context.tr('default')),
              ],
              const SizedBox(width: InSpacing.sm),
              // The actions take what the label leaves, end-aligned, and wrap
              // rather than overflow a narrow phone at large text.
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (insert)
                        TextButton.icon(
                          onPressed: _insertVariable,
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(context.tr('insert_variable')),
                          style: TextButton.styleFrom(
                            // No density on touch: `compact` subtracts 8 from
                            // `minimumSize` (§ Design system, touch-target
                            // trap 2), so the 44 below would render as 36 —
                            // and `shrinkWrap` drops the 48 px `padded` floor
                            // that would otherwise have masked it.
                            visualDensity: Env.isTouchPrimary
                                ? null
                                : VisualDensity.compact,
                            minimumSize: Size(
                              0,
                              Env.isTouchPrimary ? InSizes.touchTarget : 32,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ?trailing,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        body,
      ],
    );
  }

  Stylesheet _buildStylesheet(InTheme t, {bool muted = false}) {
    final scope = widget.templateVariables;
    // Replace the default block-level rule (which hardcodes black text + 640
    // max width + horizontal padding sized for a full-screen editor) with one
    // tuned for a settings-form field. Subsequent rules from defaultStylesheet
    // still apply for headers, lists, blockquote, etc. The chip builder leads
    // the inline-widget chain and claims every chip placeholder.
    return defaultStylesheet.copyWith(
      inlineWidgetBuilders: [
        if (scope != null)
          templateVariableChipBuilder(
            scope: scope,
            muted: muted,
            editable: _chipsEditable,
          ),
        ...defaultInlineWidgetBuilderChain,
      ],
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
              // The untouched default template reads muted.
              color: muted ? t.ink2 : t.ink,
              fontSize: 14,
              height: 1.4,
            ),
          },
        ),
      ],
    );
  }
}

/// Neutral "Default" marker beside the label of a field showing its default
/// template.
class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r1),
        border: Border.all(color: t.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: t.ink2,
          fontWeight: FontWeight.w600,
        ),
      ),
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
    this.chipTapAt,
  });

  final double height;
  final double? maxHeight;
  final bool expand;
  final bool excludeFocus;

  /// Template fields: hit-tests the tap-to-edit reader's tap for a chip and
  /// handles it, returning true — the promote is then swallowed. The chips
  /// themselves can't take the tap: inline widgets sit under an
  /// `IgnorePointer`, and so does this whole reader.
  final bool Function(Offset globalPosition)? chipTapAt;

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
      final chipTap = chipTapAt;
      // Set by `onTapUp`, which fires before `onTap` for the same tap.
      var tappedChip = false;
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
          onTapUp: chipTap == null
              ? null
              : (details) => tappedChip = chipTap(details.globalPosition),
          onTap: () {
            if (tappedChip) {
              tappedChip = false;
              return;
            }
            enter();
          },
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
