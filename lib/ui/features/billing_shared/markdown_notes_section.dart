import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';

/// One named markdown section (terms / footer / public notes / private
/// notes). The host (typically the Invoice edit screen's Notes tab)
/// composes any subset of these.
///
/// Each section can optionally surface a "Save as default" button that
/// hands the current value back to the host, which is expected to persist
/// it on the company's settings cascade. Hide via `onSaveAsDefault: null`.
class MarkdownNotesField extends StatefulWidget {
  const MarkdownNotesField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onSaveAsDefault,
    this.externalValueKey,
    this.registerBeforeSaveHook,
    this.showLabel = true,
    this.height = 180,
    this.maxHeight,
    this.expand = false,
  });

  /// Localized label shown above the editor.
  final String label;

  /// When false the header label is not rendered — the host already labels
  /// this section (e.g. a `TabBar` tab name). The "Save as default" button,
  /// when present, still surfaces (right-aligned). Defaults to true.
  final bool showLabel;

  /// Current markdown content. Empty string for no value.
  final String value;

  /// Fired on debounced edit. The host writes this back into its draft.
  final ValueChanged<String> onChanged;

  /// Optional. When provided, a "Save as default" button surfaces
  /// beside the label. On tap the editor is flushed synchronously
  /// (bypassing the debounce) and this callback fires with the
  /// *current* serialized markdown — the host persists it to
  /// `company.settings.<key>`. Receiving the value as a parameter
  /// (rather than reading the parent draft) removes the debounce race.
  final ValueChanged<String>? onSaveAsDefault;

  /// Bump to force a reseed (e.g. after the host loaded a draft from
  /// the server and the editor is already mounted).
  final Object? externalValueKey;

  /// Optional `vm.addBeforeSaveHook`-shaped registrar (returns the
  /// unregister callback). When provided, the field registers a synchronous
  /// editor flush so Save / ⌘S captures text still sitting inside the
  /// editor's 300 ms debounce — without it, the last words typed before an
  /// immediate save silently missed the payload while the toast said
  /// "Saved" (and the post-save pop discarded the late emit).
  final VoidCallback Function(VoidCallback hook)? registerBeforeSaveHook;

  /// Minimum editor body height — the field grows with its content from here
  /// up to [maxHeight]. Ignored when [expand] is true.
  final double height;

  /// Ceiling for that growth; see [MarkdownTextField.maxHeight] for the
  /// default. Ignored when [expand] is true.
  final double? maxHeight;

  /// When true the editor stretches to fill the parent's available height
  /// (the parent must bound it) instead of using the fixed [height]. Set on
  /// the desktop notes pane so the textarea reaches the bottom of the panel
  /// instead of leaving empty space below it.
  final bool expand;

  @override
  State<MarkdownNotesField> createState() => _MarkdownNotesFieldState();
}

class _MarkdownNotesFieldState extends State<MarkdownNotesField> {
  final _controller = MarkdownFieldController();
  VoidCallback? _unregisterBeforeSave;

  @override
  void initState() {
    super.initState();
    // `flush()` emits the pending debounced value through `onChanged`
    // (same side effect _handleSaveAsDefault documents), landing it in the
    // host draft synchronously before the VM serializes the save payload.
    _unregisterBeforeSave = widget.registerBeforeSaveHook?.call(
      () => _controller.flush(),
    );
  }

  @override
  void dispose() {
    _unregisterBeforeSave?.call();
    super.dispose();
  }

  void _handleSaveAsDefault() {
    // Flush the editor so the just-typed value is captured even if the
    // 300 ms debounce hasn't fired yet; fall back to the parent's known
    // value when there's nothing pending.
    //
    // Side effect (intentional): flushing emits through `onChanged`,
    // which writes the value into the host's draft and marks it dirty
    // immediately — the same end state the debounce would reach ~300 ms
    // later, just sooner. A "Save as default" tap therefore also
    // commits the field into the in-progress entity edit; that's the
    // desired no-lost-edit behavior, not a bug.
    final current = _controller.flush() ?? widget.value;
    widget.onSaveAsDefault!(current);
  }

  @override
  Widget build(BuildContext context) {
    final saveButton = widget.onSaveAsDefault == null
        ? null
        : TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 32)),
            onPressed: _handleSaveAsDefault,
            child: Text(context.tr('save_as_default')),
          );

    // When the host labels the section (e.g. a TabBar tab name) we drop the
    // redundant header label. The "Save as default" action, if any, now
    // surfaces *below* the editor — right-aligned on its own row.
    final Widget? header = widget.showLabel
        ? Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.inTheme.ink,
              ),
            ),
          )
        : null;

    // The inner editor never labels itself: when [showLabel] is true the
    // `header` above already provides the single section label; when false the
    // host (e.g. a TabBar tab name) does. Forwarding `widget.showLabel` here
    // would double the label in the stacked (non-tabbed) Notes layout.
    final editor = MarkdownTextField(
      initialValue: widget.value,
      onChanged: widget.onChanged,
      label: widget.label,
      showLabel: false,
      height: widget.height,
      maxHeight: widget.maxHeight,
      expand: widget.expand,
      externalValueKey: widget.externalValueKey,
      controller: _controller,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (header != null) header,
        if (widget.expand) Expanded(child: editor) else editor,
        if (saveButton != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [saveButton],
            ),
          ),
      ],
    );
  }
}
