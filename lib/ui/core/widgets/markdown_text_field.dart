import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/user_activity_notification.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/ui/core/widgets/field_action_button.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/template_variables/markdown_template_variables.dart';
import 'package:admin/ui/core/widgets/template_variables/template_default_badge.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_chip.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_picker.dart';
import 'package:admin/utils/editor_html.dart';
import 'package:admin/utils/html_source.dart';
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
  /// through the field's `onChanged`, and return the value the parent now
  /// holds (HTML — see [MarkdownTextField]). Returns null when the field isn't
  /// mounted or there's nothing to flush (the caller should fall back to its
  /// known value) — which is always the case for a field showing HTML source
  /// that nobody has edited: the stored string must reach the caller as
  /// stored, and the caller is the one holding it.
  String? flush() => _flushHandler?.call();
}

/// A reusable WYSIWYG editor for the note-shaped fields. Loads a stored value,
/// edits via [SuperEditor], and emits the new value through [onChanged]
/// (debounced).
///
/// **The value is HTML in and HTML out; markdown is only how this widget
/// thinks.** `public_notes` / `private_notes` / `terms` / `footer` and the
/// settings templates are HTML to every other Invoice Ninja client, so the
/// stored string is folded to markdown on the way in by `markdownFromLegacyHtml`
/// and written back out by `htmlFromEditorDocument` — each of which carries the
/// evidence for that in its own library comment (invoiceninja/flutter#159).
/// Plain text and legacy markdown still load correctly; they are rewritten to
/// HTML on the user's first real edit, never merely by being opened.
///
/// **A value the document cannot hold is shown as its own HTML instead**
/// (invoiceninja/flutter#174): one containing a table, or one the fold would
/// silently delete text from — see `richEditorCannotHold`. The frame then
/// hosts a plain source box holding the stored string verbatim, and nothing
/// about it is converted in either direction except line breaks on the way out
/// (`wireHtmlFromSource`). Any other field can be switched to its source from
/// the formatting toolbar, and back from the strip above the box.
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
    this.values,
    this.defaultValue,
    this.defaultCaption,
    this.onEditing,
    this.labelTrailing,
  }) : assert(
         maxHeight == null || maxHeight >= height,
         'maxHeight is a ceiling above height; a contradiction is resolved in '
         'favour of the floor, silently discarding the ceiling.',
       );

  /// Starting content, as stored: HTML, or legacy markdown / plain text. Null
  /// and empty are equivalent.
  final String? initialValue;

  /// Fired with the serialized HTML after [debounce] of no further edits.
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

  /// The document's values, per token (the Send Email probe). Chips then read
  /// label + value — "Amount  £10.00" — instead of the label alone, matching
  /// the single-line [TemplateVariableFieldShell]. Null in Templates &
  /// Reminders, which edits a template with no document to resolve against.
  final ValueListenable<Map<String, TemplateVariableValue>>? values;

  /// Rendered, muted, when [initialValue] is empty — the default template the
  /// server uses for an empty value. Nothing is emitted until a real edit
  /// makes the document differ from it, and a document edited back to it
  /// emits `''`, so an untouched default stays the per-language server
  /// default.
  final String? defaultValue;

  /// The line under a field showing its [defaultValue]. Defaults to the
  /// settings copy ("…your first edit saves a custom copy"), which is a lie on
  /// a surface that saves nothing — the Send Email composer passes its own.
  final String? defaultCaption;

  /// Whether the document now differs from the value the parent holds.
  ///
  /// **Both edges, and the true one is synchronous** — fired on the user's
  /// first document change, before [debounce] and therefore before
  /// [onChanged]. A host whose "is this form dirty?" answer is read during
  /// build (`PopScope.canPop`) cannot wait for the debounced value, and one
  /// that reads it before an `await` (the Send Email schedule warning) would
  /// read a stale one.
  ///
  /// The **false** edge matters just as much: an edit that round-trips —
  /// typing a character and deleting it, or clearing a default and letting it
  /// come back — settles with the value unchanged, so [onChanged] never fires.
  /// A host latching on the true edge alone would stay dirty for ever.
  final ValueChanged<bool>? onEditing;

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

  /// True while the frame shows the value's own HTML in [_htmlController]
  /// instead of the document — because the document cannot hold it
  /// ([_htmlForced]) or because the user asked ([_userChoseHtml]).
  ///
  /// The document, composer and editor are still built on every seed: `dispose`
  /// and the chip summary read them, and the way back to rich text needs
  /// somewhere to land. They are simply not shown, and — this is the part the
  /// guards scattered through this class are for — **not written**.
  bool _htmlMode = false;

  /// The source cannot be put through the document without rewriting or
  /// deleting part of it (`richEditorCannotHold`). Decided on every seed and
  /// re-decided on every emit from the box's own text, so deleting the table
  /// brings the way back to rich text with it.
  bool _htmlForced = false;

  /// The user switched this field to its source. Kept for the life of the
  /// State and across reseeds: it is a choice about the field, not about the
  /// value in it.
  bool _userChoseHtml = false;

  /// The source box. Holds the stored string **verbatim** — no fold, no
  /// re-serialization — which is the entire point of the mode.
  final _htmlController = TextEditingController();

  /// [_htmlController]'s text at the last emit check: [_lastSerialized]'s twin
  /// for the source box, and what makes a type-and-revert emit nothing.
  String _lastHtmlText = '';

  /// The base64 image payloads the box is showing placeholders for — see
  /// `elideDataPayloads`. **The box's text is therefore not quite the source**:
  /// everything that reads it for its meaning goes through [_htmlSourceOf],
  /// and only comparisons of the box against itself use the text directly.
  List<String> _htmlPayloads = const [];

  /// The string the parent holds, **as stored**: what the last seed was given,
  /// until this field emits, and then what it emitted.
  ///
  /// Not [_lastEmitted], which in rich mode is baselined to the *canonical
  /// re-serialization* of the seed (so that opening a record emits nothing).
  /// That is the right thing to compare a serialize against and the wrong
  /// thing to show somebody as "the source": switching an untouched field to
  /// HTML and back must be able to change nothing at all.
  String _held = '';

  /// Whether this field has handed the parent a value since the last seed.
  bool _emittedSinceSeed = false;

  /// [MarkdownTextField.defaultValue] as stored, at the last seed — `''` when
  /// there is none worth showing. The source box's counterpart to
  /// [_defaultSerialized], and frozen at the seed for the same reason: a
  /// default that changes mid-edit is adopted on the blur, not underfoot.
  String _seededDefault = '';

  /// The document [_reseedDefault] last replaced, until the next seed — so
  /// the Undo for a change that emptied the body can still put it back.
  MutableDocument? _clearedDocument;

  bool _isApplyingExternal = false;

  /// Where the promote tap landed, until the editor has mounted to receive it.
  DocumentPosition? _pendingCaret;

  /// A [MarkdownTextField.defaultValue] that arrived while the document was
  /// not safe to replace — mid-edit, or with a live editor over it. Adopted
  /// on the blur instead. See the reseed rules in [didUpdateWidget].
  bool _pendingDefaultSeed = false;

  /// True once [MarkdownTextField.onEditing] has reported that the document
  /// differs from what the parent holds, until it reports otherwise.
  bool _reportedEditing = false;

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
  ///
  /// In the source box "isn't it" can only mean *emptied*: the box maps its
  /// text to `''` in exactly two cases, and the other one is the default.
  bool get _needsDefaultReseed =>
      _showingDefault &&
      (_htmlMode
          ? _lastHtmlText.trim().isEmpty
          : _lastSerialized != _defaultSerialized);

  /// The document is exactly what the parent believes it is: no edit waiting
  /// on the debounce, and what it serializes to is still the default's (or
  /// empty, where there is no default).
  ///
  /// Distinct from `_lastEmitted.isEmpty`, which is what the PARENT holds and
  /// stays `''` for a whole typing burst — the debounce restarts on every
  /// keystroke, so "the parent has nothing" is true right up until the user
  /// pauses. Reseeding on that reads as losing everything they just typed.
  ///
  /// The source box answers from its own text. [_lastSerialized] describes a
  /// document nobody is looking at there, and a default reseeded on its say-so
  /// would replace what the user is in the middle of typing.
  bool get _isPristine =>
      _debounce == null &&
      (_htmlMode
          ? _htmlController.text == _lastHtmlText
          : _lastSerialized == (_defaultSerialized ?? ''));

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
    widget.values?.addListener(_onValuesChanged);
  }

  /// The probe answered. Chips are built by the stylesheet's inline-widget
  /// chain, and `Stylesheet` declares no `==`, so the fresh one `build` makes
  /// always compares unequal and super_editor rebuilds its layout presenter —
  /// a plain `setState` is enough to repaint them.
  void _onValuesChanged() {
    if (mounted) setState(() {});
  }

  Map<String, TemplateVariableValue> get _values =>
      widget.values?.value ?? const <String, TemplateVariableValue>{};

  /// What a screen reader hears for one chip. With a probed value the label
  /// alone would under-report the field: the single-line shell speaks
  /// "Amount, £10.00", so a body reading only "Amount" is a regression against
  /// its own sibling.
  String _semanticsChipLabel(
    BuildContext context,
    String token,
    TemplateVariableScope scope,
  ) {
    final display = describeTemplateVariable(
      context,
      token,
      scope,
      value: _values[token],
    );
    if (display == null) return token;
    // `''` is a value, not the absence of one — the chip paints an em dash for
    // it, and a reader hearing only "Amount" would be told the document has
    // something there. Matched to the shell's own chip semantics.
    final detail =
        display.warning ??
        switch (display.value) {
          null => null,
          '' => context.tr('empty'),
          final value => value,
        };
    return detail == null ? display.label : '${display.label}, $detail';
  }

  /// Cancel the debounce, serialize now, emit if changed, return the value the
  /// parent now holds. Wired to [MarkdownFieldController.flush].
  ///
  /// Null from an untouched source box. There is nothing to flush, and the
  /// caller's own copy is the stored string — every caller already falls back
  /// to it. The rich path keeps answering with its baseline, as it always has.
  String? _flushNow() {
    _debounce?.cancel();
    _debounce = null;
    final value = _emitCurrent();
    _reportEditing(false);
    return _htmlMode && !_emittedSinceSeed ? null : value;
  }

  /// Every serialize goes through here: chips back into tokens, stray U+FFFC
  /// dropped — the markdown serializer knows nothing of placeholders.
  String _serialize() =>
      serializeDocumentToMarkdown(detokenizeTemplateVariables(_document));

  /// The value the parent should hold, given the markdown [md] this document
  /// currently serializes to: `''` when that is the default template (so
  /// editing back to the default restores it), and otherwise **HTML**.
  ///
  /// Markdown is this editor's private representation; these fields are HTML
  /// on the wire, which is the whole of invoiceninja/flutter#159 — see
  /// `htmlFromEditorDocument`. The markdown still drives every *internal*
  /// comparison ([_lastSerialized], [_defaultSerialized], the chip-undo
  /// staleness guard), so only the value handed to the parent changes.
  String _valueFor(String md) => md == _defaultSerialized
      ? ''
      : htmlFromEditorDocument(detokenizeTemplateVariables(_document));

  /// Serialize, and emit when the value changed. Returns the value the parent
  /// now holds.
  String _emitCurrent() {
    if (_htmlMode) return _emitHtml();
    final md = _serialize();
    if (md == _lastSerialized) return _lastEmitted;
    _lastSerialized = md;
    final value = _valueFor(md);
    if (value != _lastEmitted) {
      _lastEmitted = value;
      _held = value;
      _emittedSinceSeed = true;
      widget.onChanged(value);
    }
    return _lastEmitted;
  }

  /// What the parent should hold for the source box's [text]: the text itself,
  /// with only its line breaks resolved (`wireHtmlFromSource` — the server
  /// `nl2br`s these fields), and `''` when that is the default template, so
  /// editing back to the default restores it exactly as the rich path does.
  String _htmlValueFor(String text) {
    final wire = wireHtmlFromSource(_htmlSourceOf(text));
    return _seededDefault.isNotEmpty &&
            wire == wireHtmlFromSource(_seededDefault)
        ? ''
        : wire;
  }

  /// [_emitCurrent] for the source box.
  String _emitHtml() {
    final text = _htmlController.text;
    if (text == _lastHtmlText) return _lastEmitted;
    _lastHtmlText = text;
    final value = _htmlValueFor(text);
    if (value != _lastEmitted) {
      _lastEmitted = value;
      _held = value;
      _emittedSinceSeed = true;
      widget.onChanged(value);
    }
    // Whether the way back to rich text is open follows the text, not the
    // seed: deleting the table opens it, typing one closes it.
    final forced = richEditorCannotHold(_htmlSource(text));
    if (forced != _htmlForced) {
      if (mounted) {
        setState(() => _htmlForced = forced);
      } else {
        _htmlForced = forced;
      }
    }
    return _lastEmitted;
  }

  /// The string the source box stands for — its source, or the default
  /// template the server uses while it is empty.
  String _htmlSource(String text) =>
      text.trim().isEmpty ? _seededDefault : _htmlSourceOf(text);

  /// The box's [text] with its image payloads put back: the HTML itself.
  String _htmlSourceOf(String text) => restoreDataPayloads(text, _htmlPayloads);

  /// Puts [stored] in the source box, with any embedded image data stood in
  /// for by a placeholder. The only writer of the box besides the user (and
  /// "Insert variable", which edits the text that is already there).
  void _showInSourceBox(String stored) {
    final shown = elideDataPayloads(stored);
    _htmlPayloads = shown.payloads;
    if (_htmlController.text != shown.text) {
      _htmlController.value = TextEditingValue(text: shown.text);
    }
    _lastHtmlText = shown.text;
  }

  @override
  void didUpdateWidget(covariant MarkdownTextField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?._detach(_flushNow);
      widget.controller?._attach(_flushNow);
    }

    if (widget.values != oldWidget.values) {
      oldWidget.values?.removeListener(_onValuesChanged);
      widget.values?.addListener(_onValuesChanged);
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
    //
    // A changed `defaultValue` is the second trigger, and it needs its own
    // arm: `_defaultSerialized` is computed nowhere but `_seedDocument`, so a
    // default that lands after the first build (statics arriving late in
    // settings; the Send Email composer, whose default comes from a preview
    // render and is therefore ALWAYS late) would otherwise never render — the
    // value is still `''`, so the `next != _lastEmitted` arm is false too.
    //
    // That arm cannot fire on `_lastEmitted.isEmpty` alone, though. Two things
    // are true while the parent still holds `''`:
    //
    //  * the user may be **mid-burst** — the debounce restarts on every
    //    keystroke, so nothing has been emitted yet and the document is full
    //    of their text. `_isPristine` is the real question, not `_lastEmitted`.
    //  * a **live `SuperEditor`** may be mounted over it, and `_seedDocument`
    //    disposes the composer it is holding — the hazard `_restore` and
    //    `_onFocusChanged` both defer a frame for, and which additionally
    //    re-parents the frame here when `_defaultSerialized` flips off null.
    //
    // So a default-only change waits for the blur when either is true. An
    // external *value* change still reseeds at once: that is a deliberate
    // overwrite by the parent (an override toggle, Reset) and predates this.
    final defaultChanged = widget.defaultValue != oldWidget.defaultValue;
    if (widget.externalValueKey != oldWidget.externalValueKey ||
        defaultChanged) {
      final next = widget.initialValue ?? '';
      if (next != _lastEmitted) {
        _seedDocument(next);
      } else if (defaultChanged && _lastEmitted.isEmpty) {
        if (_isPristine && !_editing) {
          _seedDocument(next);
        } else {
          _pendingDefaultSeed = true;
        }
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
      if (_htmlMode) {
        // Read before the controller goes: the source box's pending edit is
        // its text, not the document's serialization.
        final text = _htmlController.text;
        if (text != _lastHtmlText) {
          final value = _htmlValueFor(text);
          if (value != _lastEmitted) pending = value;
        }
      } else {
        final md = _serialize();
        if (md != _lastSerialized) {
          final value = _valueFor(md);
          if (value != _lastEmitted) pending = value;
        }
      }
    }
    widget.controller?._detach(_flushNow);
    widget.values?.removeListener(_onValuesChanged);
    _document.removeListener(_onDocumentChange);
    _focusNode.removeListener(_onFocusChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    _composer.dispose();
    _htmlController.dispose();
    if (pending != null) {
      final emit = widget.onChanged;
      scheduleMicrotask(() => emit(pending!));
    }
    super.dispose();
  }

  /// Seeds the field from [value], the string as stored (HTML, or legacy
  /// markdown / plain text), and decides whether it is shown as a document or
  /// as its own source.
  void _seedDocument(String value) {
    _isApplyingExternal = true;
    _clearedDocument = null;
    _pendingDefaultSeed = false;

    // Tear down the previous generation before creating new instances.
    // `_initialized` is false only on the very first call (from initState),
    // when the late fields are still uninitialized.
    if (_initialized) {
      _document.removeListener(_onDocumentChange);
      _composer.dispose();
    }

    final sanitized = _sanitize(value);
    final defaultMarkdown = _sanitize(widget.defaultValue ?? '');
    // An empty value shows the default template, when there is one.
    final source = sanitized.isEmpty ? defaultMarkdown : sanitized;
    final scope = widget.templateVariables;
    // super_editor's visitor throws on a few malformed shapes. That used to
    // take the whole field down; a value the document cannot even be built
    // from is now simply one more that is shown as source (below).
    final parsed = source.isEmpty ? null : _tryDeserialize(source);
    final seedFailed = source.isNotEmpty && parsed == null;
    var document = parsed ?? MutableDocument.empty();
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
    final defaultDocument = defaultMarkdown.isEmpty
        ? null
        : _tryDeserialize(defaultMarkdown);
    _defaultSerialized = defaultMarkdown.isEmpty
        ? null
        // A default that will not parse still *is* a default — the badge, the
        // caption and "an empty value means the default" all hang off this
        // being non-null — so it keeps its fold as a stand-in.
        : defaultDocument == null
        ? defaultMarkdown
        : serializeDocumentToMarkdown(
            healTemplateVariableLinks(defaultDocument),
          );
    // Baseline against what the editor would actually serialize right now —
    // not against the unsanitized input. The deserialize → serialize round
    // trip normalizes whitespace, so a literal equality against the input
    // string would flag the first keystroke as "different" against a stale
    // baseline. The parent of a field showing its default holds `''`.
    _lastSerialized = _serialize();
    // `_lastEmitted` is what the parent holds, so it baselines in the value's
    // own space (HTML), not the editor's. Nothing is emitted here: a record
    // stored as legacy plain text or markdown is rewritten on the user's first
    // real edit, never merely by being opened or saved untouched — the
    // `md == _lastSerialized` guard in `_emitCurrent` is what makes that true.
    final showsDefault = sanitized.isEmpty && _defaultSerialized != null;
    _lastEmitted = showsDefault ? '' : _valueFor(_lastSerialized);
    _held = value;
    _emittedSinceSeed = false;

    // Document or source? Asked of what the frame actually stands for — the
    // value, or the default template it falls back to — and of the string *as
    // stored*, before the fold has stripped the tags that answer it. A table in
    // the default matters exactly as much as one in the value: the Send Email
    // body is an empty value over a default, and one edited word there used to
    // send the flattened table.
    _seededDefault = _defaultSerialized == null
        ? ''
        : (widget.defaultValue ?? '');
    final stored = showsDefault ? _seededDefault : value;
    _htmlForced = seedFailed || richEditorCannotHold(stored);
    _htmlMode = _htmlForced || _userChoseHtml;
    if (_htmlMode) {
      _showInSourceBox(stored);
      // The parent holds the stored string, so that — not the document's
      // re-serialization of it — is the baseline. It is what keeps the reseed
      // guard in `didUpdateWidget` exact here: against the canonical form a
      // table's value always "differs" (it is the flattened one), and every
      // rebuild that bumped the key would reseed the box under the caret.
      if (!showsDefault) _lastEmitted = value;
    }
    _initialized = true;
    _isApplyingExternal = false;
  }

  MutableDocument? _tryDeserialize(String markdown) {
    try {
      return deserializeMarkdownToDocument(markdown);
    } catch (_) {
      return null;
    }
  }

  /// Folds the HTML that the React (TinyMCE) client and the pre-v5 apps store
  /// in these fields into markdown. Left raw, a block-level tag doesn't just
  /// render as literal text — it takes its whole block out of the document —
  /// so this runs on every seed. See `markdownFromLegacyHtml`.
  String _sanitize(String md) => markdownFromLegacyHtml(md);

  /// The source box's `onChanged` — [_onDocumentChange] for the other mode,
  /// deliberately the same three steps. Wired through `TextField.onChanged`
  /// and not a controller listener: a listener also fires for every caret move
  /// and for the reseed's own write, and would report an edit for both.
  void _onHtmlChanged(String _) {
    _reportEditing(true);
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, _emitNow);
    if (mounted) const UserActivityNotification().dispatch(context);
  }

  void _onDocumentChange(DocumentChangeLog _) {
    // The document is hidden behind the source box and is not the value; an
    // edit to it there (a late chip Undo) must not be emitted over the source.
    if (_isApplyingExternal || _htmlMode) return;
    // Before the debounce: a host whose dirty flag is read during build can't
    // wait for `onChanged`. `_isApplyingExternal` above is what keeps this to
    // genuine user edits — a seed installs a *new* document and this listener
    // with it, so a reseed emits no change events of its own. No serialize
    // here: any change means the document *may* differ, which is the honest
    // answer this early, and `_emitNow` retracts it when it turns out not to.
    _reportEditing(true);
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, _emitNow);
    // Typing here is activity the idle timeout cannot otherwise see: the
    // document is no `TextEditingController`, and a soft keyboard sends no
    // key events. Same `_isApplyingExternal` gate — a reseed is not the user.
    if (mounted) const UserActivityNotification().dispatch(context);
  }

  void _reportEditing(bool editing) {
    if (_reportedEditing == editing) return;
    _reportedEditing = editing;
    widget.onEditing?.call(editing);
  }

  void _emitNow() {
    final wasDefault = _showingDefault;
    _emitCurrent();
    // Unconditional, and it is the whole point of the false edge: once this
    // returns the parent holds the current value by construction — either
    // `onChanged` just handed it over, or it was already equal and
    // `_emitCurrent` returned early without saying so. Either way the document
    // no longer differs from what the parent holds, and a host that latched on
    // the true edge would otherwise stay dirty for an edit that round-tripped.
    _reportEditing(false);
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
    if (_lastEmitted != held) {
      _held = _lastEmitted;
      _emittedSinceSeed = true;
      widget.onChanged(_lastEmitted);
    }
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
    if (scope == null || !_chipsEditable || _htmlMode) return;
    final pick = await showTemplateVariablePicker(
      context,
      scope: scope,
      currentToken: hit.token,
      values: _values,
    );
    // The mode can change while the picker is up, and there are no chips in
    // the source box to change.
    if (pick == null || !mounted || _htmlMode) return;
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
        // The toast outlives a switch to the source box, where this would
        // edit a document nobody can see.
        if (!mounted || _htmlMode) return;
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
    if (_htmlMode) return _insertVariableIntoSource(scope);
    final selection = _editing ? _composer.selection : null;
    final pick = await showTemplateVariablePicker(
      context,
      scope: scope,
      values: _values,
    );
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

  /// "Insert variable" for the source box: the raw `$token` at the caret,
  /// replacing a selection, or at the end when the box has never had one.
  /// There are no chips in source — the token is the text.
  ///
  /// The selection is read **before** the picker opens (its route takes the
  /// focus) and checked against the text **after**, since the box can be
  /// reseeded while the picker is up.
  Future<void> _insertVariableIntoSource(TemplateVariableScope scope) async {
    final selection = _htmlController.selection;
    final pick = await showTemplateVariablePicker(
      context,
      scope: scope,
      values: _values,
    );
    if (pick is! TemplateVariablePicked || !mounted || !_htmlMode) return;
    final text = _htmlController.text;
    final atCaret = selection.isValid && selection.end <= text.length;
    final start = atCaret ? selection.start : text.length;
    final end = atCaret ? selection.end : text.length;
    // Same rule as the document: a token must not run into the word after it,
    // or `$client.name` followed by `x` reads as a different variable.
    final after = end < text.length ? text[end] : '';
    final token = templateVariableContinuesToken(after)
        ? '${pick.token} '
        : pick.token;
    final next = text.replaceRange(start, end, token);
    _htmlController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    // A programmatic write does not come back through `TextField.onChanged`.
    _onHtmlChanged(next);
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

  /// The document position under [globalPosition], from the reader's layout.
  /// Null when the reader isn't laid out yet (or this is the editor already).
  DocumentPosition? _readerPositionAt(Offset globalPosition) {
    final Object? layout = _readerLayoutKey.currentState;
    if (layout is! DocumentLayout) return null;
    return layout.getDocumentPositionNearestToOffset(
      layout.getDocumentOffsetFromAncestorOffset(globalPosition),
    );
  }

  void _onFocusChanged() {
    // Flush any pending edits the moment focus leaves the editor so that
    // blur-then-save races don't drop the last keystroke.
    if (!_focusNode.hasFocus && _debounce != null) {
      _debounce!.cancel();
      _debounce = null;
      _emitNow();
    }
    // The source box has no reader to promote from — it takes the focus node
    // directly — so `_editing` has to follow focus here or the blur below
    // never runs for it: an emptied box would not get its default back, and a
    // default that arrived mid-edit would never be adopted.
    if (_htmlMode && _focusNode.hasFocus && !_editing && mounted) {
      setState(() => _editing = true);
    }
    // Drop back to the read-only `SuperReader` when focus leaves so the
    // IME client is released and this field stops participating in focus
    // traversal. Entering edit mode is driven by `_enterEditing` (tap or
    // keyboard activation on the reader host) — the editor focus node isn't
    // attached to a Focus widget until the `SuperEditor` mounts, so it can't
    // receive focus from here first.
    if (!_focusNode.hasFocus && _editing && mounted) {
      setState(() => _editing = false);
      // Two reseeds wait for this moment, for the same reason: SuperEditor's
      // own blur handler runs after this one and executes a
      // `ClearSelectionRequest` against the composer a reseed would already
      // have disposed. A body emptied while editing holds `''` — the default —
      // so it shows the default again; and a `defaultValue` that arrived while
      // the user was in the field is adopted now.
      if (_needsDefaultReseed || _pendingDefaultSeed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _editing) return;
          if (_pendingDefaultSeed) {
            setState(() => _seedDocument(widget.initialValue ?? ''));
          } else if (_needsDefaultReseed) {
            _reseedDefault();
          }
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
  void _enterEditing({Offset? at}) {
    if (_editing) return;
    // Where the user actually pointed, resolved against the READER's layout —
    // the editor doesn't exist yet. Captured here because the reader is torn
    // down in the same frame the editor mounts.
    _pendingCaret = at == null ? null : _readerPositionAt(at);
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_editing) {
        setState(() => _editing = true);
        _applyPendingCaret();
      }
    });
  }

  /// Put the caret where the promote tap landed. `SuperEditor.autofocus` with
  /// `placeCaretAtEndOfDocumentOnGainFocus` (its default) otherwise drops it
  /// past the end of the document — on a compose surface the usual act is
  /// "fix the greeting on line 1", so that cost a second tap every time.
  /// Runs after the editor has mounted and taken focus, or its own
  /// place-at-end would land last.
  void _applyPendingCaret() {
    final position = _pendingCaret;
    _pendingCaret = null;
    if (position == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing || _htmlMode) return;
      // The document was reseeded between the tap and this frame (a default
      // reseed, an external value): the captured node id no longer exists.
      if (_document.getNodeById(position.nodeId) == null) return;
      _editor.execute([
        ChangeSelectionRequest(
          DocumentSelection.collapsed(position: position),
          SelectionChangeType.placeCaret,
          SelectionReason.userInteraction,
        ),
      ]);
    });
  }

  /// The toolbar's `</>`: show this field's HTML instead of the document.
  ///
  /// Three things it must not do. **Emit** — the box opens on [_held], the
  /// string the parent already holds, so a look at the source changes nothing
  /// (a rich edit still in its debounce is settled first, and that emit is the
  /// edit's, not the switch's). **Reseed** — the toolbar is only up while a
  /// `SuperEditor` is mounted, and it is still holding the composer a reseed
  /// would dispose (the hazard [_restore] defers a frame for). And **lose the
  /// focus** — the user was typing; the box takes the same focus node.
  void _showSource() {
    if (_htmlMode) return;
    _debounce?.cancel();
    _debounce = null;
    _emitNow();
    final showsDefault = _showingDefault;
    final stored = showsDefault ? _seededDefault : _held;
    setState(() {
      _userChoseHtml = true;
      _htmlMode = true;
      _htmlForced = richEditorCannotHold(stored);
      _showInSourceBox(stored);
      // From here the baseline is the stored string — see `_seedDocument`.
      if (!showsDefault) _lastEmitted = _held;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _htmlMode) _focusNode.requestFocus();
    });
  }

  /// The strip's "Rich text": back to the document, seeded from [_held].
  ///
  /// Refused while the source is one the document cannot hold — the strip
  /// shows why instead of the button, and this re-checks because the edit
  /// being settled here may be the one that typed the table.
  void _showRichText() {
    if (!_htmlMode) return;
    _debounce?.cancel();
    _debounce = null;
    _emitNow();
    if (!mounted || !_htmlMode || _htmlForced) return;
    setState(() {
      _userChoseHtml = false;
      // Land on the reader, as every other way into rich text does; no
      // `SuperEditor` is mounted over the source box, so this reseed is safe
      // to run at once.
      _editing = false;
      _seedDocument(_held);
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
    // The source box is neither reader nor editor: it replaces both, so no
    // `SuperEditor` (and no toolbar) is ever mounted while it is showing.
    final showEditor = canEdit && _editing && !_htmlMode;
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
    final Widget? sliver = _htmlMode
        ? null
        : Theme(
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
                onSource: _showSource,
              ),
            if (_htmlMode) ...[
              _HtmlSourceStrip(
                forced: _htmlForced,
                // Only an editable field can leave: a read-only or disabled
                // one is here because its value is, and has no say in it.
                onRichText: canEdit ? _showRichText : null,
              ),
              _buildSourceHost(t, canEdit: canEdit),
            ] else
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
                sliver: sliver!,
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
    if (scope != null && !_htmlMode) {
      // super_editor has no semantics layer (and its inline widgets sit under
      // an IgnorePointer), so the chips are summarised on the frame. The
      // source box needs none of this: it is a real text field, it has no
      // chips, and it reads its own tokens out as the text they are.
      body = Semantics(
        container: true,
        label: widget.label,
        // Semicolons, not commas: a chip's own label now reads
        // "Amount, £10.00", so comma-joining three of them gives a reader no
        // way to hear where one chip ends and the next begins.
        value: [
          for (final token in templateVariableTokensIn(_document))
            _semanticsChipLabel(context, token, scope),
        ].join('; '),
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
                widget.defaultCaption ?? context.tr('default_template_caption'),
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
                TemplateDefaultBadge(label: context.tr('default')),
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
                      if (insert) _insertVariableButton(context),
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

  Widget _insertVariableButton(BuildContext context) {
    final button = FieldActionButton(
      icon: Icons.add,
      label: context.tr('insert_variable'),
      onPressed: _insertVariable,
    );
    // Over the source box the button joins the text field's tap region, so
    // pressing it is not a "tap outside" and does not blur the box on the way
    // down — the token goes in at a caret the user can still see. (The rich
    // editor is not a text field and has no such region to join.)
    return _htmlMode ? TextFieldTapRegion(child: button) : button;
  }

  /// The source box: a plain multi-line text field over [_htmlController],
  /// sized by the same three rules as the document host — `height` is a
  /// floor, the content grows it to the same ceiling, and `expand` hands the
  /// height to the parent.
  ///
  /// **`readOnly`, never `enabled: false`.** A disabled `TextField` wraps
  /// itself in an `IgnorePointer`, which switches off its own scrolling too —
  /// a footer longer than the box could then not be read at all, which is
  /// invoiceninja/flutter#107 over again. A field that is disabled or showing
  /// an inherited value is read-only and still scrolls; the frame's dim is
  /// what says "disabled".
  ///
  /// Every text-assist feature is off, and that is not tidiness: iOS smart
  /// quotes rewrite `style="width: 33%"` into the curly-quoted shape that
  /// makes the fold refuse the tag — the very thing that blanked the reporter's
  /// footer — and autocorrect has opinions about `colspan`.
  Widget _buildSourceHost(InTheme t, {required bool canEdit}) {
    final field = TextField(
      controller: _htmlController,
      focusNode: _focusNode,
      readOnly: !canEdit,
      canRequestFocus: widget.enabled,
      maxLines: null,
      expands: widget.expand,
      textAlignVertical: TextAlignVertical.top,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      textCapitalization: TextCapitalization.none,
      style: TextStyle(
        fontFamily: kMonoFontFamily,
        fontSize: 13,
        height: 1.4,
        // The untouched default template reads muted, as it does as a document.
        color: _showingDefault ? t.ink2 : t.ink,
        // JetBrains Mono draws `</` and `/>` as single ligature glyphs. Fine in
        // an IDE; in a box whose whole content is tags it makes every closing
        // tag look like a different character from the one that was typed.
        fontFeatures: const [
          FontFeature.disable('calt'),
          FontFeature.disable('liga'),
        ],
      ),
      cursorColor: t.accent,
      decoration: InputDecoration(
        isCollapsed: true,
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: InSpacing.md(context),
          vertical: InSpacing.sm,
        ),
      ),
      onChanged: _onHtmlChanged,
    );
    if (widget.expand) return Expanded(child: field);
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: widget.height,
        maxHeight: _resolveEditorMaxHeight(
          context,
          height: widget.height,
          maxHeight: widget.maxHeight,
        ),
      ),
      child: field,
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
            values: _values,
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

/// Sizes the editor and gives SuperEditor/SuperReader their own (closer)
/// sliver host.
///
/// SuperEditor/SuperReader walk the ancestor chain for a vertical Scrollable
/// and return their content as a Sliver when they find one. Settings screens
/// sit inside a `ListView` (SettingsFormShell), so without this nested
/// CustomScrollView the returned Sliver would collide with the non-sliver
/// parent. The focus/tap wrappers are applied *around* the scroll host so the
/// sliver protocol between CustomScrollView and the editor is never broken.
class _EditorHost extends StatefulWidget {
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
  /// host, or by Enter/Space activating it). [at] is the tap's global position
  /// when there was one, so the caret can land where the user pointed; Tab and
  /// Enter/Space pass none and keep SuperEditor's place-at-end.
  final void Function({Offset? at})? enterEditing;
  final Widget sliver;

  @override
  State<_EditorHost> createState() => _EditorHostState();
}

class _EditorHostState extends State<_EditorHost> {
  /// Set by `onTapDown`, read by `onTap`. **State, not a `build` local**: a
  /// `TapGestureRecognizer` reports `onTapDown` at `kPressTimeout` (100 ms)
  /// and `onTap` at pointer-up, so all but the briefest taps span a frame
  /// boundary — and a rebuild in that window (a variable probe answering, a
  /// preview landing) would install fresh closures over a fresh null and drop
  /// the caret back to the end of the document, intermittently.
  Offset? _tapPosition;

  /// Set by `onTapUp`, which fires before `onTap` for the same tap.
  bool _tappedChip = false;

  @override
  Widget build(BuildContext context) {
    final height = widget.height;
    final expand = widget.expand;
    final excludeFocus = widget.excludeFocus;
    final ignorePointer = widget.ignorePointer;
    final enterEditing = widget.enterEditing;
    final chipTapAt = widget.chipTapAt;
    final sliver = widget.sliver;
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
              maxHeight: _resolveEditorMaxHeight(
                context,
                height: height,
                maxHeight: widget.maxHeight,
              ),
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
      final enter = enterEditing;
      final chipTap = chipTapAt;
      host = FocusableActionDetector(
        // Tab lands on this single lightweight host node; focusing or
        // activating (Enter/Space) it promotes to the editor — markdown
        // fields stay keyboard-reachable.
        onFocusChange: (focused) {
          // Keyboard promotion has no tap offset, so the caret keeps
          // SuperEditor's own place-at-end behaviour.
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
              : (details) => _tappedChip = chipTap(details.globalPosition),
          onTapDown: (details) => _tapPosition = details.globalPosition,
          onTap: () {
            if (_tappedChip) {
              _tappedChip = false;
              return;
            }
            enter(at: _tapPosition);
          },
          child: MouseRegion(
            // Without this the body reads as a block of grey text rather than
            // a field: the reader is under a `SliverIgnorePointer`, so nothing
            // below claims a cursor. The single-line shell does the same.
            cursor: SystemMouseCursors.text,
            child: host,
          ),
        ),
      );
    }
    // In expand mode the host fills the remaining height of the frame's
    // Column (toolbar takes its intrinsic height, the editor takes the rest)
    // so there's no dead space below the editor inside a fixed-height panel.
    return expand ? Expanded(child: host) : host;
  }
}

/// Ceiling on the content-driven growth, for the document host and the source
/// box alike. Half the viewport keeps a long note from crowding out the fields
/// around it while still showing several times what the old fixed box did; the
/// 480 cap keeps a desktop settings field from turning into a page of its own.
/// Never below [height], so a caller's floor always wins.
double _resolveEditorMaxHeight(
  BuildContext context, {
  required double height,
  required double? maxHeight,
}) => math.max(
  height,
  maxHeight ?? math.min(MediaQuery.sizeOf(context).height * 0.5, 480.0),
);

class _MarkdownToolbar extends StatelessWidget {
  const _MarkdownToolbar({
    required this.composer,
    required this.isActive,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onBulletList,
    required this.onNumberedList,
    required this.onSource,
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

  /// Switch the field to its HTML source. Lives here, with the formatting
  /// tools and only while editing, so a resting field gains no chrome — eight
  /// of these sit on the Defaults page alone — and under the web app's own
  /// name for it (`source_code`), where its users already know to look.
  final VoidCallback onSource;

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
              const SizedBox(width: InSpacing.sm),
              _ToolbarButton(
                icon: Icons.code,
                tooltip: context.tr('source_code'),
                onPressed: onSource,
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

/// The bar above the source box: says what the box is, and is the way back.
///
/// Always shown in HTML mode, focused or not — unlike the formatting toolbar —
/// because a field full of tags needs to say why at rest, not only once it is
/// clicked into. While the source is one the document cannot hold ([forced])
/// there is no way back to offer, so the button gives its place to the reason:
/// a disabled button would say only that something is unavailable.
class _HtmlSourceStrip extends StatelessWidget {
  const _HtmlSourceStrip({required this.forced, required this.onRichText});

  final bool forced;

  /// Null for a field the user cannot edit.
  final VoidCallback? onRichText;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    final onRichText = this.onRichText;
    return Container(
      decoration: BoxDecoration(
        color: t.surfaceAlt,
        border: Border(bottom: BorderSide(color: t.border)),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(InRadii.r1),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.md(context),
        vertical: 2,
      ),
      // A floor, not a height: the reason wraps on a phone, and at large text
      // scale a fixed box would slice it.
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        children: [
          Icon(Icons.code, size: 16, color: t.ink3),
          const SizedBox(width: InSpacing.xs),
          Text(
            context.tr('html'),
            style: TextStyle(
              color: t.ink2,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: InSpacing.sm),
          Expanded(
            child: forced
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
                    child: Text(
                      context.tr('html_only_notice'),
                      style: TextStyle(color: t.ink3, fontSize: 12),
                    ),
                  )
                : Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: onRichText == null
                        ? null
                        : FieldActionButton(
                            icon: Icons.notes,
                            label: context.tr('rich_text'),
                            onPressed: onRichText,
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
