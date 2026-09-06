import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
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
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.autocorrect = true,
    this.obscureText = false,
  }) : assert(
         !obscureText || maxLines == 1,
         'obscureText requires a single-line field',
       );

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;
  final int? maxLines;
  final int? minLines;
  final bool autofocus;
  final TextInputType? keyboardType;

  /// Soft-keyboard auto-capitalization. `words` for proper nouns (names,
  /// cities, streets), `characters` for postal codes, `sentences` for prose.
  /// Defaults to Flutter's own `none`, so passing nothing changes nothing.
  final TextCapitalization textCapitalization;

  /// OS autofill hints. **Only ever set these on a field describing the
  /// signed-in user or their own company** — on a client / vendor / contact
  /// record the platform would offer to fill the *admin's* own name, phone
  /// and address into somebody else's record. Note Flutter gates on null vs
  /// non-null, so an empty list does NOT opt out (see `auth_fields.dart`).
  final Iterable<String>? autofillHints;

  /// Set false on identifier-shaped values iOS would happily "correct" —
  /// invoice / PO / VAT numbers, transaction references, hostnames, keys.
  /// Also drives `enableSuggestions`, which travels with it.
  final bool autocorrect;

  /// Obscures the value behind a reveal toggle. Used for the client and
  /// vendor **portal password**, which is the contact's credential and not
  /// the signed-in user's — so [autofillHints] must stay null there.
  final bool obscureText;

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

  /// Local reveal state for [EntityEditField.obscureText]. Seeded obscured;
  /// the eye toggle flips it and nothing external resets it.
  late bool _obscured = widget.obscureText;

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
    final reseeded =
        widget.initial != old.initial && widget.initial != _controller.text;
    if (reseeded) {
      _controller.value = TextEditingValue(
        text: widget.initial,
        selection: TextSelection.collapsed(offset: widget.initial.length),
      );
    }
    // Re-arm the mask whenever the bound value is replaced or the field
    // becomes obscurable, because `_obscured` is State and would otherwise
    // keep whatever the *previous* occupant of this element left it at.
    //
    // The reassignment half is the reachable one: `client_edit_contacts_
    // section` keys unsaved rows positionally (`new_<index>`), so removing a
    // contact re-points a surviving element at a different one — and a
    // password revealed on the old contact would go on rendering in the clear
    // under the new contact's row.
    if (reseeded || widget.obscureText != old.obscureText) {
      _obscured = widget.obscureText;
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
          // Reveal toggle — a bare IconButton, matching `AuthPasswordField`.
          // Deliberately NOT wrapped in `Focus(canRequestFocus: false)`:
          // that shape appears elsewhere in the app but is inert, because
          // `FocusNode.canRequestFocus` resolves against each ancestor's
          // `descendantsAreFocusable`, never its `canRequestFocus`
          // (`focus_manager.dart`). Excluding it properly would need
          // `ExcludeFocus`, which would be wrong anyway — a keyboard user
          // should be able to reach the reveal button.
          suffixIcon: widget.obscureText
              ? IconButton(
                  tooltip: _obscured
                      ? context.tr('show_password')
                      : context.tr('hide_password'),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                    color: tokens.ink3,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                )
              : null,
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
        textCapitalization: widget.textCapitalization,
        autofillHints: widget.autofillHints,
        // One knob, not two — the pairing `AuthField` already uses. A field
        // declared obscurable never wants either.
        // Keyed on the DECLARATION, not `_obscured`: revealing a secret
        // does not make it stop being a secret. Keyed on the live reveal
        // state, a call site that declared `obscureToggle`/`obscureText` but
        // forgot `autocorrect: false` handed the IME a revealed API
        // credential the moment the user edited it.
        autocorrect: widget.autocorrect && !widget.obscureText,
        enableSuggestions: widget.autocorrect && !widget.obscureText,
        obscureText: _obscured,
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
