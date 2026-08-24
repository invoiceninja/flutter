import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';

/// Single labeled text field used across entity edit cards (clients,
/// products, vendors, …). Owns its own `TextEditingController` so the
/// parent doesn't need to thread one per field; reflects external changes
/// to [initial] without clobbering an active edit.
///
/// Pass [errorText] to surface a server-side validation error inline under
/// the field (driven by `GenericEditViewModel.fieldErrorFor(apiKey)`).
///
/// Uses an outlined decoration in `tokens.border`, focused `tokens.accent`,
/// label `tokens.ink3`; the error state swaps in `theme.colorScheme.error`. Matches
/// the visual rhythm of the cards.
class EntityEditField extends StatefulWidget {
  const EntityEditField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
    this.maxLines = 1,
    this.minLines,
    this.autofocus = false,
    this.keyboardType,
    this.errorText,
    this.readOnly = false,
    this.prefixText,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final TextInputType? keyboardType;

  /// When non-null, the field renders in its error state and displays this
  /// message beneath. Pass `vm.fieldErrorFor('name')` etc.
  final String? errorText;

  /// Read-only mode — the field renders its content normally but the
  /// keyboard never opens and selection-without-editing is allowed.
  /// Use for server-assigned values (e.g. project number) that the user
  /// shouldn't change but should be able to see + copy.
  final bool readOnly;

  /// Static text pinned inside the field, before the value — the company
  /// currency symbol on a money field. Not part of the value: `onChanged`
  /// still receives only what the user typed.
  final String? prefixText;

  @override
  State<EntityEditField> createState() => _EntityEditFieldState();
}

class _EntityEditFieldState extends State<EntityEditField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void didUpdateWidget(covariant EntityEditField old) {
    super.didUpdateWidget(old);
    // Reflect *external* changes to `initial` (the "row got reassigned" path —
    // e.g. a primary-contact swap) without clobbering an active edit.
    //
    // Guard on `widget.initial != old.initial`: during normal typing the VM
    // round-trips our value (keystroke → onChanged → parse → notifyListeners →
    // rebuild) and hands back the *same* `initial`, so `old.initial ==
    // widget.initial` and we skip the reseed. This is essential for `Decimal`
    // fields seeded via `decimalInputText`: typing `12.` parses to `12` whose
    // canonical text is `12`, so a blind reseed would erase the in-progress
    // decimal point (and a leading `0` would clear the field). Only reseed when
    // the bound value genuinely changed underneath us.
    if (widget.initial != old.initial && widget.initial != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.initial,
        selection: TextSelection.collapsed(offset: widget.initial.length),
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
    final theme = Theme.of(context);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(InRadii.r1),
      borderSide: BorderSide(color: tokens.border),
    );
    // Enter submits via FormSaveScope for single-line fields; multi-line
    // (notes, etc.) keep Enter for newlines.
    final isSingleLine = widget.maxLines == 1;
    final scope = isSingleLine ? FormSaveScope.maybeOf(context) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: widget.prefixText,
          prefixStyle: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink3),
          labelStyle: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink3),
          floatingLabelStyle: theme.textTheme.bodySmall?.copyWith(
            color: tokens.ink2,
          ),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(
            horizontal: InSpacing.md(context),
            vertical: 14,
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(InRadii.r1),
            borderSide: BorderSide(color: tokens.accent, width: 1.5),
          ),
          errorText: widget.errorText,
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(InRadii.r1),
            borderSide: BorderSide(color: theme.colorScheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(InRadii.r1),
            borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
          ),
          errorStyle: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
            fontSize: 11.5,
          ),
        ),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: widget.readOnly ? tokens.ink2 : tokens.ink,
        ),
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        readOnly: widget.readOnly,
        textInputAction: isSingleLine
            ? TextInputAction.done
            : TextInputAction.newline,
        onChanged: widget.onChanged,
        onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
      ),
    );
  }
}
